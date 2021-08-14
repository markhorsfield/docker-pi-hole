FROM debian:buster-slim

ENV S6_OVERLAY_VERSION v2.1.0.2

RUN apt update && apt install --no-install-recommends -y curl procps ca-certificates git

ARG TARGETPLATFORM
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then ARCHITECTURE=amd64; elif [ "$TARGETPLATFORM" = "linux/arm/v7" ]; then ARCHITECTURE=arm; elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then ARCHITECTURE=aarch64; else ARCHITECTURE=amd64; fi \
    && echo $ARCHITECTURE \
    && curl -L -s "https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-${ARCHITECTURE}.tar.gz" | tar xvzf - -C / \
    && mv /init /s6-init

COPY install.sh /usr/local/bin/install.sh
COPY VERSIONS /etc/pi-hole-versions
ENV PIHOLE_INSTALL /etc/.pihole/automated\ install/basic-install.sh

RUN bash -ex install.sh 2>&1 && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

ENTRYPOINT [ "/s6-init" ]

ADD s6/debian-root /
COPY s6/service /usr/local/bin/service

# php config start passes special ENVs into
ARG PHP_ENV_CONFIG
ENV PHP_ENV_CONFIG /etc/lighttpd/conf-enabled/15-fastcgi-php.conf
ARG PHP_ERROR_LOG
ENV PHP_ERROR_LOG /var/log/lighttpd/error.log
COPY ./start.sh /
COPY ./bash_functions.sh /

# IPv6 disable flag for networks/devices that do not support it
ENV IPv6 True

EXPOSE 53 53/udp
EXPOSE 67/udp
EXPOSE 80

ENV S6_LOGGING 0
ENV S6_KEEP_ENV 1
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS 2

ENV ServerIP 0.0.0.0
ENV FTL_CMD no-daemon
ENV DNSMASQ_USER root

ARG PIHOLE_VERSION
ENV VERSION "${PIHOLE_VERSION}"
ENV PATH /opt/pihole:${PATH}

# ARG NAME
# LABEL image="${NAME}:${PIHOLE_VERSION}_${PIHOLE_ARCH}"
# ARG MAINTAINER
# LABEL maintainer="${MAINTAINER}"
# LABEL url="https://www.github.com/pi-hole/docker-pi-hole"

HEALTHCHECK CMD dig +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

SHELL ["/bin/bash", "-c"]