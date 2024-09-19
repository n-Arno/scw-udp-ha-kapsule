FROM golang:alpine as builder

COPY log.go /log.go

RUN go build -o /log /log.go

FROM alpine:latest

RUN mkdir -p /out
VOLUME /out

COPY --from=builder /log /log

EXPOSE 80

ENTRYPOINT "/log"
