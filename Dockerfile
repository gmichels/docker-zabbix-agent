FROM alpine:latest
MAINTAINER Gustavo Michels <gustavo.michels@gmail.com>

ARG APK_FLAGS_COMMON="-q"
ARG APK_FLAGS_PERSISTANT="${APK_FLAGS_COMMON} --clean-protected --no-cache"
ARG APK_FLAGS_DEV="${APK_FLAGS_COMMON} --no-cache"
ENV TERM=xterm

RUN addgroup zabbix && \
    adduser -S \
            -D -G zabbix \
            -h /var/lib/zabbix/ \
        zabbix && \
    mkdir -p /etc/zabbix && \
    mkdir -p /etc/zabbix/zabbix_agentd.d && \
    mkdir -p /var/lib/zabbix && \
    mkdir -p /var/lib/zabbix/enc && \
    mkdir -p /var/lib/zabbix/modules && \
    chown --quiet -R zabbix:root /var/lib/zabbix && \
    apk update && \
    apk add ${APK_FLAGS_PERSISTANT} \
            supervisor \
            bash \
            curl \
            coreutils \
            jq \
            sudo \
            libssl1.0  && \
    rm -rf /var/cache/apk/*

ARG MAJOR_VERSION=3.2
ARG ZBX_VERSION=${MAJOR_VERSION}.1
ARG ZBX_SOURCES=svn://svn.zabbix.com/tags/${ZBX_VERSION}/
ENV ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES}

RUN apk update && \
    apk add ${APK_FLAGS_DEV} --virtual build-dependencies \
            alpine-sdk \
            automake \
            autoconf \
            openssl-dev \
            subversion && \
    cd /tmp/ && \
    svn --quiet export ${ZBX_SOURCES} zabbix-${ZBX_VERSION} 1>/dev/null

ADD patches/*.patch /tmp/zabbix-${ZBX_VERSION}/

RUN cd /tmp/zabbix-${ZBX_VERSION} && \
    zabbix_revision=`svn info ${ZBX_SOURCES} |grep "Last Changed Rev"|awk '{print $4;}'` && \
    patch -p1 < fs_discovery.patch && \
    sed -i "s/{ZABBIX_REVISION}/$zabbix_revision/g" include/version.h && \
    grep -rl \"\/proc/mounts * | xargs sed -i.orig 's|"/proc/mounts|"/zbx/proc/1/mounts|g' && \
    grep -rl \"\/proc/net * | xargs sed -i.orig 's|"/proc/net|"/zbx/proc/1/net|g' && \
    grep -rl \"\/proc * | xargs sed -i.orig 's|"/proc|"/zbx/proc|g' && \
    grep -rl \"\/dev\/ * | xargs sed -i.orig 's|"/dev/|"/zbx/dev/|g' && \
    grep -rl \"\/sys * | xargs sed -i.orig 's|"/sys|"/zbx/sys|g' && \
    ./bootstrap.sh 1>/dev/null && \
    ./configure \
            --prefix=/usr \
            --silent \
            --sysconfdir=/etc/zabbix \
            --libdir=/usr/lib/zabbix \
            --enable-agent \
            --enable-ipv6 \
            --with-openssl && \
    make -j"$(nproc)" -s 1>/dev/null && \
    cp src/zabbix_agent/zabbix_agentd /usr/sbin/zabbix_agentd && \
    cp src/zabbix_sender/zabbix_sender /usr/sbin/zabbix_sender && \
    cp conf/zabbix_agentd.conf /etc/zabbix && \
    chown --quiet -R zabbix:root /etc/zabbix && \
    cd /tmp/ && \
    rm -rf /tmp/zabbix-${ZBX_VERSION}/ && \
    apk del --purge \
            build-dependencies && \
    rm -rf /var/cache/apk/*

EXPOSE 10050/TCP

WORKDIR /var/lib/zabbix

VOLUME ["/etc/zabbix/zabbix_agentd.d", "/var/lib/zabbix/enc", "/var/lib/zabbix/modules"]

ADD conf/etc/supervisor/ /etc/supervisor/
ADD conf/etc/zabbix/ /etc/zabbix/
ADD conf/etc/sudoers.d/ /etc/sudoers.d/
ADD run_zabbix_component.sh /

RUN chmod +x /etc/zabbix/scripts/*.sh

ENTRYPOINT ["/bin/bash"]

CMD ["/run_zabbix_component.sh", "agentd", "none"]
