#!/bin/bash

waiter () {
  local url="${1}"
  while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' "${url}")" != "200" && "$(curl -s -o /dev/null -w ''%{http_code}'' "${url}")" != "307" ]]; do
    printf "Waiting for [%s] ...\n" "${url}"
    sleep 2
  done
}

if [ -z "${KAFKA_BOOTSTRAP_SERVERS}" ]; then
    echo "KAFKA_BOOTSTRAP_SERVERS is not been set"
    exit 1
fi
if [ -z "${SERVICE_CONNECT}" ]; then
    echo "SERVICE_CONNECT is not been set"
    exit 1
fi
if [ -z "${SERVICE_KSQLDB}" ]; then
    echo "SERVICE_KSQLDB is not been set"
    exit 1
fi
if [ -z "${SERVICE_SCHEMAREGISTRY}" ]; then
    echo "SERVICE_SCHEMAREGISTRY is not been set"
    exit 1
fi

while getopts f flag
do
    case "${flag}" in
        f) force=true;;
    esac
done

KAFKA_CONFIGS_OPTIONS=""

if [[ -n ${BROKER_CONFIG_PROPERTIES} ]]; then
  CONFIG_PROPERTIES=/tmp/${BROKER_CONFIG_PROPERTIES}
  interpol "/etc/kafka/configs/${BROKER_CONFIG_PROPERTIES}" > "${CONFIG_PROPERTIES}"
  KAFKA_CONFIGS_OPTIONS+="--command-config ${CONFIG_PROPERTIES}"
fi

if [ -z "${force}" ]
then
  read -p "Do you really want to delete all on [$KAFKA_BOOTSTRAP_SERVERS, $SERVICE_CONNECT, $SERVICE_KSQLDB, $SERVICE_SCHEMAREGISTRY] yes/no ? " var
  if [ "$var" != "yes" ]; then
    exit 1
  fi
else
  printf '\n%s\n' "All content in the kafka cluster [$KAFKA_BOOTSTRAP_SERVERS, $SERVICE_CONNECT, $SERVICE_KSQLDB, $SERVICE_SCHEMAREGISTRY] will be deleted!"
fi

# delete all connectors
waiter $SERVICE_CONNECT
printf '\n%s\n' "delete all connectors on $SERVICE_CONNECT"
connect-drop-all.sh -u $SERVICE_CONNECT -f;

# delete all ksqlDB streams/tables/queries
waiter $SERVICE_KSQLDB
printf '\n%s\n' "delete all ksqlDB streams/tables/queries on $SERVICE_KSQLDB"
for i in $(seq 1 3); do
  ksql-drop-tables-all.sh -u $SERVICE_KSQLDB -f;
  ksql-drop-streams-all.sh -u $SERVICE_KSQLDB -f;
done

# delete all schemas
waiter $SERVICE_SCHEMAREGISTRY
printf '\n%s\n' "delete all schemas on $SERVICE_SCHEMAREGISTRY"
schemaregistry-drop-all.sh -u $SERVICE_SCHEMAREGISTRY -f;

# delete all topics
printf '\n%s\n' "delete all topics on $KAFKA_BOOTSTRAP_SERVERS"
topics=$(kafka-topics.sh --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS $KAFKA_CONFIGS_OPTIONS --list)

for topic in $topics; do
  echo "${topic}"
  kafka-topics.sh --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS $KAFKA_CONFIGS_OPTIONS --delete --topic ${topic} || true
done
