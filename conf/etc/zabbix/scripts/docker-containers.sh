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
    NAME=$(echo $CTS | jq ".[$I].Names[0]" | sed -e 's/^"\//"/')

    DATA="$DATA,"'{"{#NAME}":'$NAME'}'
done

echo '{"data":['${DATA#,}']}'
