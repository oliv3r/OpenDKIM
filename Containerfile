# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (C) 2023 Olliver Schinagl <oliver@schinagl.nl>

ARG ALPINE_VERSION="latest"
ARG TARGET_ARCH="library"

FROM docker.io/${TARGET_ARCH}/alpine:${ALPINE_VERSION} AS builder

WORKDIR /src

COPY . /src/

RUN apk add --no-cache \
        'autoconf' \
        'automake' \
        'gcc' \
        'libmilter-dev' \
        'libtool' \
        'make' \
        'openssl-dev>3' \
        'musl-dev' \
    && \
    autoreconf \
               --force \
               --install \
               --verbose \
    && \
    ./configure \
                --docdir='/nop/doc' \
                --includedir='/nop/include' \
                --mandir='/nop/man' \
                --prefix='/usr/local' \
                --sysconfdir='/etc/opendkim' \
    && \
    make DESTDIR='/opendkim' -j$(($(nproc) - 1)) install && \
    install -D -m 775 \
        'opendkim/opendkim.conf.simple' \
        '/opendkim/usr/local/etc/opendkim/opendkim.conf' && \
    rm -f -r '/opendkim/nop'

FROM docker.io/${TARGET_ARCH}/alpine:${ALPINE_VERSION}

LABEL maintainer="Olliver Schinagl <oliver@schinagl.nl>"

EXPOSE 1234

RUN apk add --no-cache \
        'libcrypto3' \
        'libmilter' \
        'libssl3' \
        'perl' \
    && \
    addgroup -S 'opendkim' && \
    adduser -D -G 'opendkim' -h '/home/opendkim' -s '/bin/nologin' -S 'opendkim' && \
    install -d -m 775 -g 'opendkim' -o 'opendkim' '/var/log/opendkim/'

COPY --from=builder "/opendkim" "/"
COPY "./contrib/init/container/container-entrypoint.sh" "/init"

USER opendkim

ENTRYPOINT [ "/init" ]
