FROM alpine:latest 
RUN apk add --no-cache unbound ca-certificates
VOLUME /etc/unbound
COPY unbound.conf /etc/unbound/unbound.conf
ENTRYPOINT "/usr/sbin/unbound"
EXPOSE 53/udp
EXPOSE 53/tcp