FROM extremeshok/baseimage-alpine:latest AS BUILD

LABEL mantainer="Adrian Kriel <admin@extremeshok.com>" vendor="eXtremeSHOK.com"

RUN echo "**** install nginx ****" \
  && apk-install nginx

RUN echo "**** install node with work around due to segfault ****" \
  && apk-install \
    paxctl \
    nodejs \
    nodejs-npm \
  && paxctl -cm $(which node) \
  && apk del paxctl

RUN echo "**** install xmysql ****" \
  && npm install -g xmysql

RUN echo "**** install bash runtime packages ****" \
  && apk-install \
    bash \
    coreutils \
    curl \
    inotify-tools \
    mariadb-client \
    openssl \
    tzdata

# add local files
COPY ./rootfs/ /

RUN echo "**** configure ****" \
  && mkdir -p /tmp/xmysql \
  && mkdir -p /certs \
  && chown -R nginx:nginx /var/www \
  && chmod 777 /xshok_gen_nginx_api_conf.sh \
  && chmod 777 /xshok-monitor-certs.sh

EXPOSE 443/tcp

WORKDIR /tmp

ENTRYPOINT ["/init"]
