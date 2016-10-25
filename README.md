# Overview

Based on the [official Zabbix Agent container](https://hub.docker.com/r/zabbix/zabbix-agent/) (alpine build) with modifications inspired by https://github.com/bhuisgen/docker-zabbix-coreos to support:

* container discovery
* process discovery within each container
* Host OS monitoring with standard Zabbix Agent items

# How to use this image

## Start `zabbix-agent`

Start a Zabbix agent container as follows:

    docker run --name some-container-name -h $(hostname) -p 10050:10050/tcp -v /var/run/docker.sock:/var/run/docker.sock -v /:/zbx:ro -e ZBX_HOSTNAME="$(hostname)" -e ZBX_SERVER_HOST="some-zabbix-server" -e ZBX_ACTIVE_ALLOW=false -e ZBX_TIMEOUT=30 -e ZBX_ENABLEREMOTECOMMANDS="1" -d --privileged gmichels/zabbix-agent

Where `some-container-name` is the name you want to assign to your container.

## Container shell access and viewing Zabbix agent logs

The `docker exec` command allows you to run commands inside a Docker container. The following command line will give you a bash shell inside your `zabbix-agent` container:

```console
$ docker exec -ti some-zabbix-agent /bin/bash/
```

The Zabbix agent log is available through Docker's container log:

```console
$ docker logs some-zabbix-agent
```

## Environment Variables

All environment variables available in the [original project](https://hub.docker.com/r/zabbix/zabbix-agent/) can be passed on to this one as well.

abbix_agentd) to get more information about the variables.

# Supported Docker versions

This image is officially supported on Docker version 1.8 and newer.
