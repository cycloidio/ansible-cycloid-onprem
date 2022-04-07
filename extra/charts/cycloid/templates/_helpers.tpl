{{/*
========
Cycloid
========
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "cycloid.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cycloid.fullname" -}}
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
{{- define "cycloid.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cycloid.labels" -}}
helm.sh/chart: {{ include "cycloid.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Create a default fully qualified mysql name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cycloid.mysql.fullname" -}}
{{- if .Values.mysql.fullnameOverride }}
{{- .Values.mysql.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.mysql.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Return the MySQL Hostname
*/}}
{{- define "cycloid.mysqlHost" -}}
{{- if .Values.mysql.enabled }}
    {{- if eq .Values.mysql.architecture "replication" }}
        {{- printf "%s-primary" (include "cycloid.mysql.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- printf "%s" (include "cycloid.mysql.fullname" .) -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s" .Values.externalMysql.host -}}
{{- end -}}
{{- end -}}

{{/*
Return the MySQL Port
*/}}
{{- define "cycloid.mysqlPort" -}}
{{- if .Values.mysql.enabled }}
    {{- printf "3306" -}}
{{- else -}}
    {{- printf "%d" (.Values.externalMysql.port | int ) -}}
{{- end -}}
{{- end -}}

{{/*
Return the MySQL Database
*/}}
{{- define "cycloid.mysqlDatabase" -}}
{{- if .Values.mysql.enabled }}
    {{- printf "%s" .Values.mysql.auth.database -}}
{{- else -}}
    {{- printf "%s" .Values.externalMysql.database -}}
{{- end -}}
{{- end -}}

{{/*
Return the MySQL User
*/}}
{{- define "cycloid.mysqlUser" -}}
{{- if .Values.mysql.enabled }}
    {{- printf "%s" .Values.mysql.auth.username -}}
{{- else -}}
    {{- printf "%s" .Values.externalMysql.user -}}
{{- end -}}
{{- end -}}

{{/*
Return the MySQL Secret Name
*/}}
{{- define "cycloid.mysqlSecretName" -}}
{{- if .Values.mysql.enabled }}
    {{- if .Values.mysql.auth.existingSecret -}}
        {{- printf "%s" .Values.mysql.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s" (include "cycloid.mysql.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalMysql.existingSecret -}}
    {{- printf "%s" .Values.externalMysql.existingSecret -}}
{{- else -}}
    {{- printf "%s-externalmysql" (include "cycloid.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified redis name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cycloid.redis.fullname" -}}
{{- if .Values.redis.fullnameOverride }}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.redis.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Return the Redis Hostname
*/}}
{{- define "cycloid.redisHost" -}}
{{- if .Values.redis.enabled }}
    {{- $releaseNamespace := .Release.Namespace }}
    {{- $clusterDomain := .Values.redis.clusterDomain }}
    {{- printf "%s-master.%s.svc.%s" (include "cycloid.redis.fullname" .) $releaseNamespace $clusterDomain -}}
{{- else -}}
    {{- printf "%s" .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis Port
*/}}
{{- define "cycloid.redisPort" -}}
{{- if .Values.redis.enabled }}
    {{- printf "6379" -}}
{{- else -}}
    {{- printf "%d" (.Values.externalRedis.port | int ) -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis Database
*/}}
{{- define "cycloid.redisDatabase" -}}
{{- if .Values.redis.enabled }}
    {{- printf "0" -}}
{{- else -}}
    {{- printf "%s" .Values.externalRedis.database -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis Secret Name
*/}}
{{- define "cycloid.redisSecretName" -}}
{{- if .Values.redis.enabled }}
    {{- if .Values.redis.auth.existingSecret -}}
        {{- printf "%s" .Values.redis.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s" (include "cycloid.redis.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalRedis.existingSecret -}}
    {{- printf "%s" .Values.externalRedis.existingSecret -}}
{{- else -}}
    {{- printf "%s-externalredis" (include "cycloid.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis URI
*/}}
{{- define "cycloid.redisUri" -}}
{{- if .Values.redis.enabled -}}
  {{- if .Values.redis.auth.enabled -}}
    {{- printf "redis://:$(REDIS_PASSWORD)@$(REDIS_HOST):$(REDIS_PORT)/$(REDIS_DB)" -}}
  {{- else -}}
    {{- printf "redis://$(REDIS_HOST):$(REDIS_PORT)/$(REDIS_DB)" -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return the Elasticsearch URL
*/}}
{{- define "cycloid.elasticsearchURL" -}}
    {{- printf "%s://%s:%d" .Values.externalElasticsearch.scheme .Values.externalElasticsearch.host (.Values.externalElasticsearch.port | int) -}}
{{- end -}}

{{/*
Return the Elasticsearch User
*/}}
{{- define "cycloid.elasticsearchUser" -}}
    {{- printf "%s" .Values.externalElasticsearch.username -}}
{{- end -}}

{{/*
Return the Elasticsearch Secret Name
*/}}
{{- define "cycloid.elasticsearchSecretName" -}}
{{- if .Values.externalElasticsearch.existingSecret -}}
    {{- printf "%s" .Values.externalElasticsearch.existingSecret -}}
{{- else -}}
    {{- printf "%s-externalelasticsearch" (include "cycloid.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the Elasticsearch Secret Key
*/}}
{{- define "cycloid.elasticsearchSecretKey" -}}
{{- if .Values.externalElasticsearch.existingSecret -}}
    {{- printf "%s" (.Values.externalElasticsearch.existingSecretKey | default "elasticsearch-password") -}}
{{- else -}}
    {{- printf "elasticsearch-password" -}}
{{- end -}}
{{- end -}}

{{/*
Inject extra environment vars in the format key:value, if populated
*/}}
{{- define "cycloid.extraEnvVars" -}}
{{- if .extraEnvVars -}}
{{- range $key, $value := .extraEnvVars }}
- name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Inject extra environment populated by secrets, if populated
*/}}
{{- define "cycloid.extraSecretEnvVars" -}}
{{- if .extraSecretEnvVars -}}
{{- range .extraSecretEnvVars }}
- name: {{ .envName }}
  valueFrom:
   secretKeyRef:
     name: {{ .secretName }}
     key: {{ .secretKey }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Inject extra environment populated by configmaps, if populated
*/}}
{{- define "cycloid.extraConfigMapEnvVars" -}}
{{- if .extraConfigMapEnvVars -}}
{{- range .extraConfigMapEnvVars }}
- name: {{ .envName }}
  valueFrom:
   configMapKeyRef:
     name: {{ .configMapName }}
     key: {{ .configMapKey }}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
========
Backend
========
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "backend.name" -}}
{{- default .Chart.Name .Values.backend.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "backend.fullname" -}}
{{- if .Values.backend.fullnameOverride }}
{{- .Values.backend.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.backend.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "backend.serviceAccountName" -}}
{{- if .Values.backend.serviceAccount.create }}
{{- default (include "backend.fullname" .) .Values.backend.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.backend.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Set's the affinity for pod placement
*/}}
{{- define "backend.affinity" -}}
  {{- if .Values.backend.affinity }}
      affinity:
        {{ $tp := typeOf .Values.backend.affinity }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.backend.affinity . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.backend.affinity | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}

{{/*
Sets the toleration for pod placement
*/}}
{{- define "backend.tolerations" -}}
  {{- if .Values.backend.tolerations }}
      tolerations:
      {{- $tp := typeOf .Values.backend.tolerations }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.backend.tolerations . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.backend.tolerations | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{/*
Set's the node selector for pod placement
*/}}
{{- define "backend.nodeselector" -}}
  {{- if .Values.backend.nodeSelector }}
      nodeSelector:
      {{- $tp := typeOf .Values.backend.nodeSelector }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.backend.nodeSelector . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.backend.nodeSelector | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{/*
Iterates over any
extra volumes the user may have specified.
*/}}
{{- define "backend.volumes" -}}
  {{- if .Values.backend.volumes }}
      volumes:
        {{- toYaml .Values.backend.volumes | nindent 8 }}
  {{- end }}
{{- end -}}

{{/*
Set's which additional volumes should be mounted to the container.
*/}}
{{- define "backend.mounts" -}}
  {{- if .Values.backend.volumeMounts }}
          volumeMounts:
            {{- toYaml .Values.backend.volumeMounts | nindent 12 }}
  {{- end }}
{{- end -}}

{{/*
Return the Backend Secret Name
*/}}
{{- define "backend.backendSecretName" -}}
{{ printf "%s" (include "backend.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Iterates over any
extra volumes the user may have specified.
*/}}
{{- define "backend.cronjob.volumes" -}}
  {{- if .Values.backend.volumes }}
          volumes:
            {{- toYaml .Values.backend.volumes | nindent 12 }}
  {{- end }}
{{- end -}}

{{/*
Set's which additional volumes should be mounted to the container.
*/}}
{{- define "backend.cronjob.mounts" -}}
  {{- if .Values.backend.volumeMounts }}
              volumeMounts:
                {{- toYaml .Values.backend.volumeMounts | nindent 16 }}
  {{- end }}
{{- end -}}


{{/*
========
Frontend
========
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "frontend.name" -}}
{{- default .Chart.Name .Values.frontend.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "frontend.fullname" -}}
{{- if .Values.frontend.fullnameOverride }}
{{- .Values.frontend.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.frontend.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "frontend.serviceAccountName" -}}
{{- if .Values.frontend.serviceAccount.create }}
{{- default (include "frontend.fullname" .) .Values.frontend.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.frontend.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Set's the affinity for pod placement
*/}}
{{- define "frontend.affinity" -}}
  {{- if .Values.frontend.affinity }}
      affinity:
        {{ $tp := typeOf .Values.frontend.affinity }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.frontend.affinity . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.frontend.affinity | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}

{{/*
Sets the toleration for pod placement
*/}}
{{- define "frontend.tolerations" -}}
  {{- if .Values.frontend.tolerations }}
      tolerations:
      {{- $tp := typeOf .Values.frontend.tolerations }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.frontend.tolerations . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.frontend.tolerations | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{/*
Set's the node selector for pod placement
*/}}
{{- define "frontend.nodeselector" -}}
  {{- if .Values.frontend.nodeSelector }}
      nodeSelector:
      {{- $tp := typeOf .Values.frontend.nodeSelector }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.frontend.nodeSelector . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.frontend.nodeSelector | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{/*
Inject extra environment vars in the format key:value, if populated
*/}}
{{- define "frontend.extraEnvVars" -}}
{{- if .extraEnvVars -}}
{{- range $key, $value := .extraEnvVars }}
- name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Inject extra environment populated by secrets, if populated
*/}}
{{- define "frontend.extraSecretEnvVars" -}}
{{- if .extraSecretEnvVars -}}
{{- range .extraSecretEnvVars }}
- name: {{ .envName }}
  valueFrom:
   secretKeyRef:
     name: {{ .secretName }}
     key: {{ .secretKey }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Inject extra environment populated by configmaps, if populated
*/}}
{{- define "frontend.extraConfigMapEnvVars" -}}
{{- if .extraConfigMapEnvVars -}}
{{- range .extraConfigMapEnvVars }}
- name: {{ .envName }}
  valueFrom:
   configMapKeyRef:
     name: {{ .configMapName }}
     key: {{ .configMapKey }}
{{- end -}}
{{- end -}}
{{- end -}}
