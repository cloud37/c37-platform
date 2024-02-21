# https://wwwvs.cs.hs-rm.de/lehre/material/extern/pr04ss/dokumente/makefiles.htm#probleme
# https://hublog.hubmed.org/archives/002027
MAKEFLAGS += --warn-undefined-variables --no-print-directory
.SHELLFLAGS := -eu -o pipefail -c

all: help
.PHONY: all

# Use bash for inline if-statements
SHELL:=bash

# Artifact settings
export APP_NAME?=c37-platform
export DOCKER_LOCATION?=docker.cloud37.io
export DOCKER_OWNER?=cloud37
export DOCKER_REPOSITORY_ROOT:=$(DOCKER_LOCATION)/$(DOCKER_OWNER)
export DOCKER_REPOSITORY:=$(DOCKER_REPOSITORY_ROOT)/$(APP_NAME)

export DOCKER_NETWORK?=cloud37-streaming

# Stack settings
# https://www.buesing.dev/post/confluent-community-versions/
export KAFKA_VERSION=3.5.1
export SCALA_VERSION=2.13

# Docker
DOCKER?=podman
DOCKER_COMPOSE?=podman-compose

KAFKA_TOOLS = $(DOCKER) run \
	--rm -it --network=$(DOCKER_NETWORK) \
	-e KAFKA_BOOTSTRAP_SERVERS=broker:29092 \
    -e KAFKA_CLUSTER_CLEANUP=$(1) \
    -e SERVICE_SCHEMAREGISTRY=http://schema-registry:8081 \
    -e SERVICE_KSQLDB=http://ksqldb-server:8088 \
    -e SERVICE_CONNECT=http://connect:8083 \
	$(DOCKER_REPOSITORY)/kafka-tools \
	$(2)

# Helm
HELM_CHART := helm-charts

# Kubernetes
KAFKA_UI_HTTP_PORT := 30000
KAFKA_UI_HTTP_ADDR := http://localhost:$(KAFKA_UI_HTTP_PORT)

KAFKA_PROXY_PORT := 32400
KAFKA_PROXY_BROKER_ADDR := localhost:$(KAFKA_PROXY_PORT)

POD_NAME := $(shell kubectl get pods --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep $(APP_NAME))
ENDPOINT := $(shell kubectl get endpoints | grep $(APP_NAME) | awk '{print $$1}')
KAFKA_POD_FULLNAME := $(strip $(patsubst %, %.$(ENDPOINT).default.svc.cluster.local:9092, $(POD_NAME)))

KAFKA_BROKERS := $(shell echo $(KAFKA_POD_FULLNAME) | sed 's/ /,/g')
KAFKA_BROKERS_FIRST := $(firstword $(KAFKA_POD_FULLNAME))

KAFKA_EXEC = kubectl exec -it $(firstword $(POD_NAME)) -- $(1)

##@ helpers
help: ## display this help
	@echo "$(APP_NAME)"
	@echo "====================="
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m"} /^[a-zA-Z0-9_%\/-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@printf "\n"

docker-login: DOCKER_LOGIN_CREDENTIALS?=
docker-login: ## auto login to docker repository
	docker login $(DOCKER_LOGIN_CREDENTIALS) $(DOCKER_REPOSITORY)

##@ docker -> Containerizing
docker-build: ## build stack images
	$(DOCKER_COMPOSE) build --no-cache
db: docker-build

docker-up: ## create and start the entire stack
	$(DOCKER_COMPOSE) up
du: docker-up

docker-down: ## tear down entire stack
	$(DOCKER_COMPOSE) down
dd: docker-down

docker-restart: docker-down docker-up ## combines the `down` and `up` targets in sequence
dr: docker-restart

##@ docker -> Kafka
docker-cleanup: ## cleans up the Kafka cluster
	$(call KAFKA_TOOLS,true,)

##@ k8s -> Helm
helm-install: ## installs the Helm chart
	helm install $(APP_NAME) $(HELM_CHART) --set kafka-ui.service.nodePort=$(KAFKA_UI_HTTP_PORT) || true
hi: helm-install

helm-upgrade: ## upgrades the application via Helm
	helm upgrade $(APP_NAME) $(HELM_CHART)

helm-update: helm-install helm-upgrade ## updates the application using Helm
hu: helm-update

helm-uninstall: ## uninstalls the Helm chart
	helm uninstall $(APP_NAME)
hd: helm-uninstall

helm-show: ## shows details of the Helm installation
	helm get all $(APP_NAME)

helm-deps-add: ## adds Helm chart repositories
	@helm repo add ricardo https://ricardo-ch.github.io/helm-charts/

helm-deps-install: ## adds Helm chart repositories
	helm install kafka-proxy ricardo/kafka-proxy --set 'config.kafkaClient.brokers={$(KAFKA_BROKERS_FIRST)}' --set config.proxyClientTlsEnabled=false || true

helm-deps-uninstall: ## uninstalls Helm chart dependencies
	helm uninstall kafka-proxy || true

##@ k8s -> Kafka
kafka-bash: ## opens a Bash shell in a Kafka pod
	$(call KAFKA_EXEC,bash)

kafka-topic/%: ## creates a Kafka topic e.g. kafka-topic/test
	$(call KAFKA_EXEC,kafka-topics --create --topic $(notdir $@) --bootstrap-server $(firstword $(KAFKA_POD_FULLNAME)) --partitions 3 --replication-factor 3)

kafka-producer/%: ## starts a Kafka producer for a topic e.g. kafka-producer/test
	$(call KAFKA_EXEC,kafka-console-producer --topic $(notdir $@) --bootstrap-server $(firstword $(KAFKA_POD_FULLNAME)))

kafka-consumer/%: ## starts a Kafka consumer for a topic e.g. kafka-consumer/test
	$(call KAFKA_EXEC,kafka-console-consumer --topic $(notdir $@) --bootstrap-server $(firstword $(KAFKA_POD_FULLNAME)))

##@ k8s -> kcat (kafkacat)
kcat-meta: ## displays Kafka cluster metadata with kcat
	kcat -L -b $(KAFKA_PROXY_BROKER_ADDR) -J | jq

kcat-topic-all: ## lists all Kafka topics with kcat
	kcat -L -b $(KAFKA_PROXY_BROKER_ADDR) -J | jq '.topics[].topic'

kcat-consumer/%: ## consumes messages from a topic with kcat e.g. kcat-consumer/test
	kcat -b $(KAFKA_PROXY_BROKER_ADDR) -t $(notdir $@) -C

kcat-producer/%: ## produces a message to a topic with kcat e.g. kcat-producer/test/abc
	echo "echo '$(notdir $@)' | kcat -b $(KAFKA_PROXY_BROKER_ADDR) -t $(notdir $(patsubst %/,%,$(dir $@))) -P"

##@ k8s -> Kafka Proxy
kill-proxy-port: ## frees up the Kafka proxy port by killing the process
	kill -9 $(shell sudo lsof -i :$(KAFKA_PROXY_PORT) | awk '{print $$2}' | tail -1)

##@ k8s -> Kafka UI
ui-open: ##  opens the Kafka UI in a web browser
	open $(KAFKA_UI_HTTP_ADDR)