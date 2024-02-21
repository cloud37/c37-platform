ARG image
FROM ${image}

USER root

RUN apk add --no-cache jq util-linux

COPY ./kafka-connect-restarter/start /start
