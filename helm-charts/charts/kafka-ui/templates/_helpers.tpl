{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "kafka-ui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kafka-ui.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kafka-ui.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kafka-ui.labels" -}}
helm.sh/chart: {{ include "kafka-ui.chart" . }}
{{ include "kafka-ui.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kafka-ui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kafka-ui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kafka-ui.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kafka-ui.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
This allows us to check if the registry of the image is specified or not.
*/}}
{{- define "kafka-ui.imageName" -}}
{{- $registryName := .Values.image.registry -}}
{{- if .Values.global }}
    {{- if .Values.global.imageRegistry }}
     {{- $registryName = .Values.global.imageRegistry -}}
    {{- end -}}
{{- end -}}
{{- $repository := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repository $tag -}}
{{- else }}
{{- printf "%s:%s" $repository $tag -}}
{{- end }}
{{- end -}}

{{/*
Create a default fully qualified kafka headless name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "kafka-ui.cp-kafka-headless.fullname" -}}
{{- $name := "cp-kafka-headless" -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Form the Kafka URL. If Kafka is installed as part of this chart, use k8s service discovery,
else use user-provided URL
*/}}
{{- define "kafka-ui.kafka.bootstrapServers" -}}
{{- if .Values.kafka.bootstrapServers -}}
{{- .Values.kafka.bootstrapServers -}}
{{- else -}}
{{- printf "PLAINTEXT://%s:9092" (include "kafka-ui.cp-kafka-headless.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Form the Zookeeper URL. If zookeeper is installed as part of this chart, use k8s service discovery,
else use user-provided URL
*/}}
{{- define "kafka-ui.cp-zookeeper.service-name" }}
{{- if (index .Values "cp-zookeeper" "enabled") -}}
{{- $clientPort := default 2181 (index .Values "cp-zookeeper" "clientPort") | int -}}
{{- printf "%s:%d" (include "cp-control-center.cp-zookeeper.fullname" .) $clientPort }}
{{- else -}}
{{- $zookeeperConnect := printf "%s" (index .Values "cp-zookeeper" "url") }}
{{- default $zookeeperConnect }}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified ksql name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "kafka-ui.cp-ksql-server.fullname" -}}
{{- $name := default "cp-ksql-server" (index .Values "cp-ksql-server" "nameOverride") -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kafka-ui.cp-ksql-server.service-name" -}}
{{- if (index .Values "cp-ksql-server" "url") -}}
{{- printf "%s" (index .Values "cp-ksql-server" "url") -}}
{{- else -}}
{{- printf "http://%s:8088" (include "kafka-ui.cp-ksql-server.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified connect name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "kafka-ui.cp-kafka-connect.fullname" -}}
{{- $name := default "cp-kafka-connect" (index .Values "cp-kafka-connect" "nameOverride") -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kafka-ui.cp-kafka-connect.service-name" -}}
{{- if (index .Values "cp-kafka-connect" "url") -}}
{{- printf "%s" (index .Values "cp-kafka-connect" "url") -}}
{{- else -}}
{{- printf "http://%s:8083" (include "kafka-ui.cp-kafka-connect.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified schema registry name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "kafka-ui.cp-schema-registry.fullname" -}}
{{- $name := default "cp-schema-registry" (index .Values "cp-schema-registry" "nameOverride") -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kafka-ui.cp-schema-registry.service-name" -}}
{{- if (index .Values "cp-schema-registry" "url") -}}
{{- printf "%s" (index .Values "cp-schema-registry" "url") -}}
{{- else -}}
{{- printf "http://%s:8081" (include "kafka-ui.cp-schema-registry.fullname" .) -}}
{{- end -}}
{{- end -}}