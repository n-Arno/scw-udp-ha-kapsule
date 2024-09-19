udp-ha-test
===========

Demonstrate how to setup an HA UDP entrypoint on a Kapsule cluster.

pre-requisite
=============

- 2 set of Scaleway API Keys:
  - one to create the needed resources via Terraform (KubernetesFullAccess, VPCFullAccess, PrivateNetworksFullAccess, VPCGatewayFullAccess)
  - one to modify the dns entries (DomainsDNSFullAccess)
- kubectl and terraform CLI installed (optional GNU/Make, dig)
- A registered domain zone in Scaleway Domain and DNS (in this example, we use `kube.arno-scw.fr`)

setup
=====

Setup the API key for Terraform using environment variables:
- SCW_ACCESS_KEY
- SCW_SECRET_KEY
- SCW_DEFAULT_ORGANIZATION_ID
- SCW_DEFAULT_PROJECT_ID

Modify `main.tf` to change if needed the `region`, `zone` and `zones` local variables.

```
locals {
  region = "fr-par"
  zone   = "fr-par-2"
  zones  = toset(["fr-par-1", "fr-par-2"])
}
```

Create the needed resources using Terraform with `make` or `terraform init && terraform apply -auto-approve`

Connect to your cluster using the generated `kubeconfig.yaml` file or one downloaded from the console.

```
export KUBECONFIG=$(pwd)/kubeconfig.yaml
```

Annotate the udp nodes with a short TTL for the DNS entry

```
kubectl annotate node --overwrite -l "external-dns.alpha.kubernetes.io/publish=true" external-dns.alpha.kubernetes.io/ttl=1m
```

Update the `external-dns.yaml` to add the correct domain zone, target DNS entry and API key

```
apiVersion: v1
kind: Secret
metadata:
  name: scaleway-api-key
  namespace: kube-system
stringData:
  SCW_ACCESS_KEY: SCWxxxx
  SCW_SECRET_KEY: yyyy-yyyy-yyyy-yyyy-yyyy
```

```
(snip)
        - --provider=scaleway
        - --source=node
        - --source=service
        - --zone-name-filter=kube.arno-scw.fr
        - --domain-filter=kube.arno-scw.fr
        - --fqdn-template=udp.kube.arno-scw.fr
        - --label-filter=external-dns.alpha.kubernetes.io/publish==true
        - --registry=txt
        - --txt-owner-id=udp-ha-test # Unique identifier for the cluster in the domain, can be its name or id
        - --events
        - --interval=5m # Longer pooling but events trigger updates
        - --policy=sync
        - --log-level=info
(snip)
```

Deploy external-DNS

```
kubectl apply -f external-dns.yaml
```

You can verify after a few seconds that the entry is OK

```
dig +short udp.kube.arno-scw.fr
```

Edit the test application to input the target url for the logserver

```
(snip)
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "log.kube.arno-scw.fr."
    external-dns.alpha.kubernetes.io/ttl: "1m"
    service.beta.kubernetes.io/scw-loadbalancer-type: "LB-S"
  labels:
    external-dns.alpha.kubernetes.io/publish: "true"
    app: logserver
(snip)
```

Deploy the test application

```
kubectl apply -f test-app.yaml
```

You can now download the test client for your environment from the release and start a test

```
curl -sSL -o client https://github.com/n-Arno/scw-udp-ha-kapsule/releases/download/v1.0/client-darwin-amd64
chmod +x client
./client udp.kube.arno-scw.fr
```

Exit the client execution using Ctrl+C

The logs are also sent in the backend app (logserver) and can be displayed via `http://log.kube.arno-scw.fr`

To finish testing, you can test replacing a node to check the behaviour while executing the client.

test-app
========

The test app is very simple:
- The udp client loops generating random numbers in [0,1000) and sent them to the udp server. It will get back an answer from the server and display it.
- The udp server is receiving a message from the udp client, timestamp it and send it back to the udp client and log it via HTTP POST to the log server.
- The log server is adding messages received via HTTP POST to a log file which is display when query via HTTP GET.

The udp server is running only on the dedicated udp nodes using hostPort and their public IPs, secured via Instances Security Group. The multiple IPs are grouped via DNS entry roundrobin.

The log server is running only on the application nodes with no public IP and accessed via a LoadBalancer service, connected to only those nodes via VPC as backend.


