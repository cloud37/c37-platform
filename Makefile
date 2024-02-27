# Makefile Configuration for c37-platform

# Global Flags and Shell Configuration
MAKEFLAGS += --warn-undefined-variables --no-print-directory
.SHELLFLAGS := -eu -o pipefail -c
SHELL := bash # Use bash for inline if-statements for better control structures

# Check if debug mode is enabled
DEBUG ?= 0

# Depending on the DEBUG variable, set the prefix to suppress command echo
ifeq ($(DEBUG),1)
    QUIET :=
else
    QUIET := @
endif

# Artifact and Docker Settings
export APP_NAME ?= c37-platform
export DOCKER_LOCATION ?= docker.cloud37.io
export DOCKER_OWNER ?= cloud37
export DOCKER_REPOSITORY_ROOT := $(DOCKER_LOCATION)/$(DOCKER_OWNER)
export DOCKER_REPOSITORY := $(DOCKER_REPOSITORY_ROOT)/$(APP_NAME)
export DOCKER_NETWORK ?= $(APP_NAME)
export DOCKER_NETWORK_EXTERNAL ?= false

# Stack Versions
export KAFKA_VERSION = 3.5.1
export SCALA_VERSION = 2.13

# Docker Engine and Compose Settings
DOCKER ?= podman
DOCKER_COMPOSE ?= podman-compose

# Kafka Tools Command Wrapper
# Utilizes Docker to run Kafka tooling within the specified network and environment
KAFKA_TOOLS = $(DOCKER) run \
    --rm -it --network=$(DOCKER_NETWORK) \
    -e KAFKA_BOOTSTRAP_SERVERS=broker:29092 \
    -e KAFKA_CLUSTER_CLEANUP=$(1) \
    -e SERVICE_SCHEMAREGISTRY=http://schema-registry:8081 \
    -e SERVICE_KSQLDB=http://ksqldb-server:8088 \
    -e SERVICE_CONNECT=http://connect:8083 \
    $(DOCKER_REPOSITORY)/kafka-tools \
    $(2)

# Helper Function
kafka_exec = kubectl exec -it $(firstword $(call find_kubectl_pod_name,$(1))) -- $(2)

get_kafka_pod_fullname = $(strip $(patsubst %, %.$(KAFKA_BOOTSTRAP_SERVER).default.svc.cluster.local:9092, $(call find_kubectl_pod_name,$(1))))

find_kubectl_node_port = $(shell kubectl get service | awk '/$(APP_NAME)-$(1)/ {split($$5, a, ":"); split(a[2], b, "/"); print b[1]}')
find_kubectl_endpoint = $(shell kubectl get endpoints | awk '/$(APP_NAME)/$(and $(foreach term,$(1),&& /$(term)/)) {print $$1}')
find_kubectl_pod_name = $(shell kubectl get pods | awk '/$(APP_NAME)/$(and $(foreach term,$(1),&& /$(term)/)) {print $$1}')

# Helm Chart Configuration
HELM_CHART := helm-charts

# Kubernetes Service Endpoints and Ports
KAFKA_BOOTSTRAP_SERVER = $(call find_kubectl_endpoint,kafka headless)

KAFKA_UI_HTTP_PORT := $(call find_kubectl_node_port,kafka-ui)
KAFKA_UI_HTTP_ADDR := http://localhost:$(KAFKA_UI_HTTP_PORT)

##@ Helpers
# Displays this help message, dynamically generating the command list
help: ## Displays this help message
	@echo "$(APP_NAME)"
	@echo "====================="
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m"} /^[a-zA-Z0-9_%\/-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@printf "\n"

##@ Docker Operations
docker-login: DOCKER_LOGIN_CREDENTIALS?=
docker-login: ## Auto login to the Docker repository
	$(QUIET)docker login $(DOCKER_LOGIN_CREDENTIALS) $(DOCKER_REPOSITORY)

docker-build: ## Build stack images with no cache
	$(QUIET)$(DOCKER_COMPOSE) build --no-cache
db: docker-build

docker-up: ## Create and start the entire stack
	$(QUIET)$(DOCKER_COMPOSE) up
du: docker-up

docker-down: ## Tear down the entire stack
	$(QUIET)$(DOCKER_COMPOSE) down
dd: docker-down

docker-restart: docker-down docker-up ## Restart the stack by tearing it down and then starting it up again
dr: docker-restart

docker-cleanup: ## Cleans up the Kafka cluster by removing all data
	$(QUIET)$(call KAFKA_TOOLS,true,)

##@ Kubernetes Operations with Helm
helm-install: ## Install the Helm chart for the application
	$(QUIET)helm install $(APP_NAME) $(HELM_CHART) || true
hi: helm-install

helm-upgrade: ## Upgrade the application via Helm
	$(QUIET)helm upgrade $(APP_NAME) $(HELM_CHART)

helm-update: helm-install helm-upgrade ## Update the application using Helm by reinstalling and upgrading
hu: helm-update

helm-uninstall: ## Uninstall the Helm chart
	$(QUIET)helm uninstall $(APP_NAME)
hd: helm-uninstall

helm-show: ## Show details of the Helm installation
	$(QUIET)helm get all $(APP_NAME)

helm-deps-add: ## Add Helm chart repositories
	$(QUIET)helm repo add ricardo https://ricardo-ch.github.io/helm-charts/

##@ Kafka Operations in Kubernetes
kafka-bash: POD_NAME=cp-kafka-0
kafka-bash: ## Open a Bash shell in a Kafka pod for manual operations
	$(QUIET)$(call kafka_exec,$(POD_NAME),bash)

kafka-topic/%: POD_NAME=cp-kafka-0
kafka-topic/%: ## Create a Kafka topic, e.g., `make kafka-topic/test` for a topic named "test"
	$(QUIET)$(call kafka_exec,$(POD_NAME),kafka-topics --create --topic $(notdir $@) --bootstrap-server $(firstword $(call get_kafka_pod_fullname,$(POD_NAME))) --partitions 3 --replication-factor 3)

kafka-producer/%: POD_NAME=cp-kafka-0
kafka-producer/%: ## Start a Kafka producer for a given topic, e.g., `make kafka-producer/test` for topic "test"
	$(QUIET)$(call kafka_exec,$(POD_NAME),kafka-console-producer --topic $(notdir $@) --bootstrap-server $(firstword $(call get_kafka_pod_fullname,$(POD_NAME))))
kp: kafka-producer/test

kafka-rand-producer/%: ## Start a Kafka rand producer for a given topic, e.g., `make kafka-rand-producer/test` for topic "test"
	$(QUIET)$(call kafka_exec,kafka-tools,kafka-c37-console-producer.sh -t $(notdir $@))
kp: kafka-rand-producer/test

kafka-consumer/%: POD_NAME=cp-kafka-0
kafka-consumer/%: ## Start a Kafka consumer for a given topic, e.g., `make kafka-consumer/test` for topic "test"
	$(QUIET)$(call kafka_exec,$(POD_NAME),kafka-console-consumer --topic $(notdir $@) --bootstrap-server $(firstword $(call get_kafka_pod_fullname,$(POD_NAME))) | grep -v "WARN")
kc: kafka-consumer/test

##@ Kafka UI Operations
ui-open: ## Open the Kafka UI in a web browser
	open $(KAFKA_UI_HTTP_ADDR)
