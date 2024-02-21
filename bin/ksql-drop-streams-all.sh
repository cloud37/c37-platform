#!/bin/bash

while getopts u:f flag
do
    case "${flag}" in
        u) url=${OPTARG};;
        f) force=true;;
    esac
done

if [ -z "${force}" ]; then
  read -p "Do you really want to delete all ksql streams on [$url] yes/no ? " var
  if [ "$var" != "yes" ]; then
    exit 1
  fi
fi

curl -s -X "POST" "$url/ksql" \
           -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
           -d '{"ksql": "SHOW STREAMS;"}' | \
    jq '.[].streams[].name' | \
    xargs -Ifoo curl -X "POST" "$url/ksql" \
             -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
             -d '{"ksql": "DROP STREAM 'foo';"}'
