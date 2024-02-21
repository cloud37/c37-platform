#!/bin/bash

while getopts u:f flag
do
    case "${flag}" in
        u) url=${OPTARG};;
        f) force=true;;
    esac
done

if [ -z "${force}" ]; then
  read -p "Do you really want to delete all schemas on [$url] yes/no ? " var
  if [ "$var" != "yes" ]; then
    exit 1
  fi
fi

KAFKA_CLEANUP_TOPICS=$(curl -s ${url}/subjects | jq -r '.[]'|tr '\n' ',')

IFS=', ' read -r -a topics <<<  "${KAFKA_CLEANUP_TOPICS}"
for hardDelete in false true; do
  for topic in "${topics[@]}"; do
      curl -s -X DELETE "${url}/subjects/${topic}?permanent=${hardDelete}"
  done
done