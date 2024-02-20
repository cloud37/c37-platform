# https://wwwvs.cs.hs-rm.de/lehre/material/extern/pr04ss/dokumente/makefiles.htm#probleme
# https://hublog.hubmed.org/archives/002027
MAKEFLAGS += --warn-undefined-variables --no-print-directory
.SHELLFLAGS := -eu -o pipefail -c

# Use bash for inline if-statements
SHELL:=bash

all: help
.PHONY: all

# Artifact settings
export APP_NAME?=cloud37-platform
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
HELM_CHART := helm/cp-kraft-helm-charts

# Kubernetes
KAFKA_UI_HTTP_PORT := 30000

POD_NAME := $(shell kubectl get pods --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep $(APP_NAME))
ENDPOINT := $(shell kubectl get endpoints | grep $(APP_NAME) | awk '{print $$1}')
KAFKA_POD_FULLNAME := $(strip $(patsubst %, %.$(ENDPOINT).default.svc.cluster.local:9092, $(POD_NAME)))
KAFKA_BROKERS := $(shell echo $(KAFKA_POD_FULLNAME) | sed 's/ /,/g')

KAFKA_BROKERS_FIRST := $(firstword $(KAFKA_POD_FULLNAME))

KAFKA_PROXY_PORT := 32400
KAFKA_PROXY_BROKER_ADDR := localhost:$(KAFKA_PROXY_PORT)

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
build: ## build stack images
	$(DOCKER_COMPOSE) build --no-cache

up: ## create and start the entire stack
	$(DOCKER_COMPOSE) up

down: ## tear down entire stack
	$(DOCKER_COMPOSE) down

start: up ## simply an alias for the target `up`
restart: down up ## combines the `down` and `up` targets in sequence

##@ docker -> Kafka Commands
kafka-cluster-cleanup: ## ...
	$(call KAFKA_TOOLS,true,)

##@ k8s -> Helm Commands
helm-install: ## ...
	helm install $(APP_NAME) $(HELM_CHART) --set kafka-ui.service.nodePort=$(KAFKA_UI_HTTP_PORT) || true
hi: helm-install

helm-upgrade: ## ...
	helm upgrade $(APP_NAME) $(HELM_CHART)

helm-update: helm-install helm-upgrade ## ...
hu: helm-update

helm-uninstall: ## ...
	helm uninstall $(APP_NAME)
hd: helm-uninstall

helm-show: ## ...
	helm get all $(APP_NAME)

helm-deps-add: ## ...
	@helm repo add ricardo https://ricardo-ch.github.io/helm-charts/

helm-deps-install: ## ...
	helm install kafka-proxy ricardo/kafka-proxy --set 'config.kafkaClient.brokers={$(KAFKA_BROKERS_FIRST)}' --set config.proxyClientTlsEnabled=false || true

helm-deps-uninstall: ## ...
	helm uninstall kafka-proxy || true

##@ k8s -> Kafka
kafka-bash: ## ...
	$(call KAFKA_EXEC,bash)

kafka-topic/%: ## ...
	$(call KAFKA_EXEC,kafka-topics --create --topic $(notdir $@) --bootstrap-server $(firstword $(KAFKA_POD_FULLNAME)) --partitions 3 --replication-factor 3)

kafka-producer/%: ## ...
	$(call KAFKA_EXEC,kafka-console-producer --topic $(notdir $@) --bootstrap-server $(firstword $(KAFKA_POD_FULLNAME)))

kafka-consumer/%: ## ...
	$(call KAFKA_EXEC,kafka-console-consumer --topic $(notdir $@) --bootstrap-server $(firstword $(KAFKA_POD_FULLNAME)))

##@ k8s -> kcat (kafkacat)
kcat-meta: ## ...
	kcat -L -b $(KAFKA_PROXY_BROKER_ADDR) -J | jq

kcat-topic-all: ## ...
	kcat -L -b $(KAFKA_PROXY_BROKER_ADDR) -J | jq '.topics[].topic'

kcat-consumer/%: ## ...
	kcat -b $(KAFKA_PROXY_BROKER_ADDR) -t $(notdir $@) -C

kcat-producer/%: ## ...
	echo "echo '$(notdir $@)' | kcat -b $(KAFKA_PROXY_BROKER_ADDR) -t $(notdir $(patsubst %/,%,$(dir $@))) -P"

##@ k8s -> Kafka Proxy
kill-proxy-port: ## ...
	kill -9 $(shell sudo lsof -i :$(KAFKA_PROXY_PORT) | awk '{print $$2}' | tail -1)

##@ k8s -> Kafka UI
open: ## ...
	open http://localhost:30000