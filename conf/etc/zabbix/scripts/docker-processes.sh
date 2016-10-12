#!/bin/bash

CONFIG_FILE=/etc/zabbix/scripts/docker.cfg

[ -r "$CONFIG_FILE" ] && . $CONFIG_FILE

if [ -z "$DOCKER_SOCKET" ]
then
    DOCKER_SOCKET=/var/run/docker.sock
fi

CTS=$(sudo curl -s --unix-socket $DOCKER_SOCKET http://localhost/containers/json)
LEN=$(echo $CTS | jq 'length')

for I in $(seq 0 $((LEN-1)))
do
    ID=$(echo $CTS | jq ".[$I].Id" | sed -e 's/^"//' -e 's/"$//')
    NAME=$(echo $CTS | jq ".[$I].Names[0]" | sed -e 's/^"\//"/')
    CT=$(sudo curl -s --unix-socket $DOCKER_SOCKET http://localhost/containers/$ID/json)
    RUNNING=$(echo $CT | jq ".State.Running" | sed -e 's/^"//' -e 's/"$//')
    if [ "$RUNNING" = "true" ]; then
        TOP=$(sudo curl -s --unix-socket $DOCKER_SOCKET http://localhost/containers/$ID/top?ps_args=-aux)
        PS=$(echo $TOP | jq ".Processes")
        PS_LEN=$(echo "$PS"|jq "length")

        for J in $(seq 0 $((PS_LEN-1)))
        do
            P=$(echo $PS | jq ".[$J]")

            PID=$(echo $P | jq ".[1]" | sed -e 's/^"//' -e 's/"$//')
            CMD=$(basename $(echo $P | jq ".[10]" | sed -e 's/^"//' -e 's/"$//' | cut -d' ' -f1))

            DATA="$DATA,"'{"{#NAME}":'$NAME',"{#PID}":'$PID',"{#CMD}":"'$CMD'"}'
        done
    fi
done

echo '{"data":['${DATA#,}']}'
