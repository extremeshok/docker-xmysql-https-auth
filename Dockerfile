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
    mariadb-client \
    openssl \
    tzdata

RUN echo "**** cleanup ****" \
  && find /usr/local \( -type d -a -name test -o -name tests \) -o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' + \
  && apk del .build-deps \
  && rm -rf /var/cache/apk/*

# add local files
COPY ./rootfs/ /

RUN echo "**** configure ****" \
  && mkdir -p /tmp/xmysql \
  && mkdir -p /certs \
  && chown -R nginx:nginx /var/www \
  && chmod 777 /xshok_gen_nginx_api_conf.sh

EXPOSE 443/tcp

WORKDIR /tmp

ENTRYPOINT ["/init"]
