FROM coredns/coredns:1.14.4 AS coredns

FROM alpine:3.22

RUN apk add --no-cache busybox

COPY --from=coredns /coredns /coredns

ENTRYPOINT ["/bin/sh", "-c"]
