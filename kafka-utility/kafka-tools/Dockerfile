FROM openjdk:11-jre-slim

# https://gist.github.com/ursuad/e5b8542024a15e4db601f34906b30bb5

ARG kafka_version
ARG scala_version

ENV KAFKA_VERSION=$kafka_version \
    SCALA_VERSION=$scala_version \
    KAFKA_HOME=/opt/kafka

ENV PATH=${PATH}:${KAFKA_HOME}/bin

COPY ./kafka-utility/kafka-tools/download-kafka.sh /tmp2/

RUN set -eux ; \
    apt-get update ; \
    apt-get upgrade -y ; \
    apt-get install -y --no-install-recommends jq net-tools curl wget ; \
    chmod a+x /tmp2/*.sh ; \
    sync ; \
    /tmp2/download-kafka.sh ; \
    tar xfz /tmp2/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C /opt ; \
    rm /tmp2/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz ; \
    ln -s /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} ; \
    rm -rf /tmp2 ; \
    rm -rf /var/lib/apt/lists/*

COPY ./bin/* /usr/bin

RUN curl -L https://github.com/cloud37/template-interpolator/releases/download/1.0.0/interpol-amd64 -o /usr/bin/interpol && \
    chmod +x /usr/bin/interpol

COPY ./kafka-utility/kafka-tools/entrypoint /entrypoint
RUN sed -i 's/\r$//g' /entrypoint
RUN chmod +x /entrypoint

ENTRYPOINT ["/entrypoint"]