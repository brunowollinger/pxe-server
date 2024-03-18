FROM debian:bullseye

RUN mkdir -p /tftpboot/windows/iso

RUN apt update && apt install -y dnsmasq samba nginx-light

EXPOSE 67 69 80 445 4011
