#!/bin/bash

while getopts u:f flag
do
    case "${flag}" in
        u) url=${OPTARG};;
        f) force=true;;
    esac
done

if [ -z "${force}" ]; then
  read -p "Do you really want to delete all ksql tables on [$url] yes/no ? " var
  if [ "$var" != "yes" ]; then
    exit 1
  fi
fi

curl -s -X "POST" "$url/ksql" \
             -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
             -d '{"ksql": "SHOW TABLES;"}' | \
      jq '.[].tables[].name' | \
      xargs -Ifoo curl -X "POST" "$url/ksql" \
               -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
               -d '{"ksql": "DROP TABLE 'foo';"}'