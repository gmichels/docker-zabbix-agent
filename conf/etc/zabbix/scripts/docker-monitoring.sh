#!/bin/bash

USAGE="Usage: $(basename "$0") [-s <SOCKET>]"

CONFIG_FILE=/etc/zabbix/scripts/docker.cfg

[ -r "$CONFIG_FILE" ] && . $CONFIG_FILE

if [ -z "$DOCKER_SOCKET" ]
then
    DOCKER_SOCKET=/var/run/docker.sock
fi

while getopts hs: OPT; do
    case "$OPT" in
        h)
            echo "$USAGE"
            exit 0
            ;;
        s)
            DOCKER_SOCKET=$OPTARG
            ;;
        \?)
            echo "$USAGE" >&2
            exit 1
            ;;
    esac
done


send_to_zabbix() {
    zabbix_server=$(grep Server= /etc/zabbix/zabbix_agentd.conf | grep -v "#" | cut -d'=' -f2)
    zabbix_sender -T -z $zabbix_server -i "${1}" > /tmp/docker.zabbix_sender.log 2>&1
}

CTS=$(sudo curl -s --unix-socket $DOCKER_SOCKET http://localhost/containers/json)
LEN=$(echo $CTS | jq "length")

timestamp=$(date +'%s')
hostname=$(hostname)
rm -f /tmp/docker.containers.dat

for I in $(seq 0 $((LEN-1)))
do
    ID=$(echo $CTS | jq ".[$I].Id" | sed -e 's/^"//' -e 's/"$//')
    NAME=$(echo $CTS | jq ".[$I].Names[0]" | sed -e 's/^"\//"/' | sed -e 's/^"//' -e 's/"$//')
    
    CT=$(sudo curl -s --unix-socket $DOCKER_SOCKET http://localhost/containers/$ID/json)
    RUNNING=$(echo $CT | jq ".State.Running" | sed -e 's/^"//' -e 's/"$//')
    PID=$(echo $CT | jq ".State.Pid" | sed -e 's/^"//' -e 's/"$//')
    EXITCODE=$(echo $CT | jq ".State.ExitCode" | sed -e 's/^"//' -e 's/"$//')

    echo "${hostname} docker.containers.running[$NAME] ${timestamp} $RUNNING" >> /tmp/docker.containers.dat~
    echo "${hostname} docker.containers.pid[$NAME] ${timestamp} $PID" >> /tmp/docker.containers.dat~
    echo "${hostname} docker.containers.exitcode[$NAME] ${timestamp} $EXITCODE" >> /tmp/docker.containers.dat~

    if [ "$RUNNING" = "true" ]; then
        TOP=$(sudo curl -s --unix-socket $DOCKER_SOCKET http://localhost/containers/$ID/top?ps_args=-aux)
        PS=$(echo $TOP | jq ".Processes")
        PS_LEN=$(echo "$PS" | jq "length")

        for J in $(seq 0 $((PS_LEN-1)))
        do
            P=$(echo $PS | jq ".[$J]")

            PID=$(echo $P | jq ".[1]" | sed -e 's/^"//' -e 's/"$//')
            CPU=$(echo $P | jq ".[2]" | sed -e 's/^"//' -e 's/"$//')
            MEM=$(echo $P | jq ".[3]" | sed -e 's/^"//' -e 's/"$//')
            VSZ=$(echo $P | jq ".[4]" | sed -e 's/^"//' -e 's/"$//')
            RSS=$(echo $P | jq ".[5]" | sed -e 's/^"//' -e 's/"$//')
            COMMAND=$(echo $P | jq ".[10]" | sed -e 's/^"//' -e 's/"$//')

            echo "${hostname} docker.top.cpu[$NAME,$PID] ${timestamp} $CPU" >> /tmp/docker.containers.dat~
            echo "${hostname} docker.top.mem[$NAME,$PID] ${timestamp} $MEM" >> /tmp/docker.containers.dat~
            echo "${hostname} docker.top.vsz[$NAME,$PID] ${timestamp} $VSZ" >> /tmp/docker.containers.dat~
            echo "${hostname} docker.top.rss[$NAME,$PID] ${timestamp} $RSS" >> /tmp/docker.containers.dat~
            echo "${hostname} docker.top.command[$NAME,$PID] ${timestamp} \"$COMMAND\"" >> /tmp/docker.containers.dat~
        done
    fi
done

if [ -e /tmp/docker.containers.dat~ ]
then
    mv /tmp/docker.containers.dat~ /tmp/docker.containers.dat
    send_to_zabbix /tmp/docker.containers.dat && echo 1 || echo 0
else
    echo 2
fi