FROM confluentinc/cp-kafka-connect:7.2.2

## Install connectors
RUN echo "\nInstalling all required connectors...\n"
RUN confluent-hub install --no-prompt confluentinc/connect-transforms:1.4.3
RUN confluent-hub install --no-prompt redhatinsights/expandjsonsmt:0.0.7
RUN confluent-hub install --no-prompt debezium/debezium-connector-postgresql:2.2.1
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-elasticsearch:14.0.10
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-http:1.7.4

# https://github.com/castorm/kafka-connect-http
COPY ./kafka-connect/kafka-connect-http-0.8.11-plugin.tar.gz /
RUN tar -xf /kafka-connect-http-0.8.11-plugin.tar.gz -C /usr/share/confluent-hub-components/

# https://github.com/canelmas/kafka-connect-field-and-time-partitioner
# https://stackoverflow.com/questions/57499274/implementing-a-kafka-connect-custom-partitioner
#COPY ./kafka-connect/connect-fieldandtime-partitioner-1.1.0-SNAPSHOT.jar /usr/share/confluent-hub-components/confluentinc-kafka-connect-s3/lib/

# https://github.com/university-of-auckland/kafka-http-sink-connector
#COPY ./kafka-connect/uoa-kafka-http-sink-connector-1.0.18-SNAPSHOT.jar /usr/local/share/kafka/plugins/

# https://tech.willhaben.at/kafka-connect-custom-single-message-transform-using-jslt-2fc57ae98395
COPY ./kafka-connect/wh-kafka-connect-jslt-transform-1.1.0.jar /usr/local/share/kafka/plugins/

# https://github.com/Aiven-Open/http-connector-for-apache-kafka
COPY ./kafka-connect/http-connector-for-apache-kafka-0.7.0.tar /
RUN tar -xf /http-connector-for-apache-kafka-0.7.0.tar -C /usr/share/confluent-hub-components/