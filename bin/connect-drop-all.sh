#!/bin/bash

#URL=https://connect-kafka-streaming.ewe.onpower.cloud
#URL=https://connect-kafka-streaming-release.ewe-test.onpower.cloud

while getopts u:fs: flag
do
    case "${flag}" in
        u) url=${OPTARG};;
        f) force=true;;
    esac
done

if [ -z "${force}" ]; then
  read -p "Do you really want to delete all connectors on [$url] yes/no ? " var
  if [ "$var" != "yes" ]; then
    exit 1
  fi
fi

CONNECTORS=$(curl -s ${url}/connectors | jq -r '.[]'|tr '\n' ',')

IFS=', ' read -r -a connectors <<<  "${CONNECTORS}"
for connector in "${connectors[@]}"; do
    curl -s -X DELETE "${url}/connectors/${connector}"
done
