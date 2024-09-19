FROM golang:alpine as builder

COPY udp.go /udp.go

RUN go build -o /udp /udp.go

FROM alpine:latest

COPY --from=builder /udp /udp

EXPOSE 1053/udp

ENTRYPOINT "/udp"
