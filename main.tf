locals {
  region = "fr-par"
  zone   = "fr-par-2"
  zones  = toset(["fr-par-1", "fr-par-2"])
}

data "scaleway_k8s_version" "latest" {
  region = local.region
  name   = "latest"
}

resource "scaleway_vpc" "kapsule" {
  region         = local.region
  name           = "kapsule-demo"
  tags           = ["kapsule"]
  enable_routing = true
}

resource "scaleway_vpc_private_network" "kapsule" {
  region = local.region
  name   = "kapsule-demo"
  tags   = ["kapsule"]
  vpc_id = scaleway_vpc.kapsule.id
}

resource "scaleway_vpc_public_gateway_ip" "kapsule" {
  zone = local.zone
}

resource "scaleway_vpc_public_gateway" "kapsule" {
  zone       = local.zone
  name       = "pgw-kapsule"
  type       = "VPC-GW-S"
  ip_id      = scaleway_vpc_public_gateway_ip.kapsule.id
  tags       = ["kapsule"]
  depends_on = [scaleway_vpc_private_network.kapsule]
  # to avoid race conditions, create PGW after PN
}

resource "scaleway_vpc_gateway_network" "kapsule" {
  zone               = local.zone
  gateway_id         = scaleway_vpc_public_gateway.kapsule.id
  private_network_id = scaleway_vpc_private_network.kapsule.id
  enable_masquerade  = true
  ipam_config {
    push_default_route = true
  }
}

resource "scaleway_k8s_cluster" "kapsule" {
  region                      = local.region
  name                        = "udp-ha-test"
  version                     = data.scaleway_k8s_version.latest.name
  cni                         = "cilium"
  private_network_id          = scaleway_vpc_private_network.kapsule.id
  delete_additional_resources = true
  depends_on                  = [scaleway_vpc_private_network.kapsule]
  autoscaler_config {
    disable_scale_down               = false
    scale_down_unneeded_time         = "2m"
    scale_down_delay_after_add       = "30m"
    scale_down_utilization_threshold = 0.5
    estimator                        = "binpacking"
    expander                         = "random"
    ignore_daemonsets_utilization    = true
    balance_similar_node_groups      = true
  }
}

resource "scaleway_instance_security_group" "kapsule" {
  for_each                = local.zones
  zone                    = each.key
  name                    = "kubernetes ${split("/", scaleway_k8s_cluster.kapsule.id)[1]}"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  stateful                = true
  inbound_rule {
    action   = "accept"
    protocol = "UDP"
    port     = "1053"
  }
  depends_on = [scaleway_k8s_cluster.kapsule]
}

resource "scaleway_k8s_pool" "udp" {
  for_each            = local.zones
  zone                = each.key
  cluster_id          = scaleway_k8s_cluster.kapsule.id
  name                = format("udp-%s", each.key)
  node_type           = "PLAY2-NANO"
  size                = 1
  autohealing         = true
  wait_for_pool_ready = true
  upgrade_policy {
    max_surge       = 1
    max_unavailable = 1
  }
  tags = [
    "noprefix=node.kubernetes.io/role=udp",
    "noprefix=external-dns.alpha.kubernetes.io/publish=true",
    "taint=noprefix=node.kubernetes.io/role=udp:NoSchedule",
    "node.kubernetes.io/exclude-from-external-load-balancers"
  ]
  depends_on = [scaleway_instance_security_group.kapsule]
}

resource "scaleway_instance_placement_group" "ha" {
  for_each    = local.zones
  zone        = each.key
  name        = format("pg-ha-%s", each.key)
  policy_type = "max_availability"
  policy_mode = "enforced"
}

resource "scaleway_k8s_pool" "app" {
  for_each            = local.zones
  zone                = each.key
  cluster_id          = scaleway_k8s_cluster.kapsule.id
  name                = format("app-%s", each.key)
  node_type           = "PLAY2-NANO"
  autoscaling         = true
  min_size            = 1
  max_size            = 3
  size                = 1
  autohealing         = true
  wait_for_pool_ready = true
  public_ip_disabled  = true
  placement_group_id  = scaleway_instance_placement_group.ha[each.key].id
  depends_on          = [scaleway_vpc_gateway_network.kapsule]
  tags                = ["no-prefix=node.kubernetes.io/role=app"]
}

variable "hide" { # Workaround to hide local-exec output
  default   = "yes"
  sensitive = true
}

resource "null_resource" "kubeconfig" {
  depends_on = [scaleway_k8s_pool.udp, scaleway_k8s_pool.app]
  triggers = {
    name                   = scaleway_k8s_cluster.kapsule.name
    host                   = scaleway_k8s_cluster.kapsule.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.kapsule.kubeconfig[0].token
    cluster_ca_certificate = scaleway_k8s_cluster.kapsule.kubeconfig[0].cluster_ca_certificate
  }

  provisioner "local-exec" {
    environment = {
      HIDE_OUTPUT = var.hide # Workaround to hide local-exec output
    }
    command = <<-EOT
    cat<<EOF>kubeconfig.yaml
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: ${self.triggers.cluster_ca_certificate}
        server: ${self.triggers.host}
      name: ${self.triggers.name}
    contexts:
    - context:
        cluster: ${self.triggers.name}
        user: admin
      name: admin@${self.triggers.name}
    current-context: admin@${self.triggers.name}
    kind: Config
    preferences: {}
    users:
    - name: admin
      user:
        token: ${self.triggers.token}
    EOF
    EOT
  }
}
