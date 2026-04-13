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
    {{- $clusterDomain := "cluster.local" }}
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
Return the Redis schema
*/}}
{{- define "cycloid.redisSchema" -}}
{{- if or .Values.redis.tls.enabled .Values.externalRedis.tls.enabled -}}
  rediss
{{- else -}}
  redis
{{- end -}}
{{- end -}}


{{/*
Return the Redis username and password for authentication
*/}}
{{- define "cycloid.redisUserAuth" -}}
  {{- if .Values.redis.auth.enabled -}}
    :$(REDIS_PASSWORD)@
  {{- else if .Values.externalRedis.auth.enabled -}}
      {{ .Values.externalRedis.auth.username }}:$(REDIS_PASSWORD)@
  {{- end -}}
{{- end -}}

{{/*
Return the Redis URI
*/}}
{{- define "cycloid.redisUri" -}}
{{- $redisSchema := include "cycloid.redisSchema" . -}}
{{- $redisAuth := include "cycloid.redisUserAuth" . -}}
{{- if or .Values.redis.enabled .Values.externalRedis.enabled -}}
        {{- printf "%s://%s$(REDIS_HOST):$(REDIS_PORT)/$(REDIS_DB)" $redisSchema $redisAuth -}}
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

{{- define "backendTaskManager.selectorLabels" -}}
app.kubernetes.io/name: {{ printf "%s-task-manager" (include "backend.name" .) }}
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
  {{- if or .Values.backend.volumes (and .Values.extraCaCertificates.enabled .Values.extraCaCertificates.certs) }}
      volumes:
      {{- if .Values.backend.volumes }}
        {{- toYaml .Values.backend.volumes | nindent 8 }}
      {{- end }}

      {{- if and .Values.extraCaCertificates.enabled .Values.extraCaCertificates.certs }}
        - name: extra-ca-certificates
          configMap:
            name: {{ printf "%s-extra-ca" (include "cycloid.name" .) | trunc 63 | trimSuffix "-" }}
      {{- end }}
      {{- end }}
{{- end -}}

{{/*
Set's which additional volumes should be mounted to the container.
*/}}
{{- define "backend.mounts" -}}
  {{- if or .Values.backend.volumeMounts (and .Values.extraCaCertificates.enabled .Values.extraCaCertificates.certs) }}
          volumeMounts:
          {{- if .Values.backend.volumeMounts }}
          {{- toYaml .Values.backend.volumeMounts | nindent 12 }}
          {{- end }}

          {{- if and .Values.extraCaCertificates.enabled .Values.extraCaCertificates.certs }}
            - name: extra-ca-certificates
              mountPath: /usr/local/share/ca-certificates
              readOnly: true
          {{- end }}
  {{- end }}
{{- end -}}

{{/*
Return the Vault AppRole Secret Name
*/}}
{{- define "cycloid.vaultApproleSecretName" -}}
{{- printf "%s-vault-approle" (include "cycloid.fullname" .) -}}
{{- end -}}

{{/*
Return the Vault Init Data PVC Name
*/}}
{{- define "cycloid.vaultInitDataPvcName" -}}
{{- printf "%s-vault-init-data" (include "cycloid.fullname" .) -}}
{{- end -}}

{{/*
Return the Vault Init Script ConfigMap Name
*/}}
{{- define "cycloid.vaultInitScriptConfigMapName" -}}
{{- printf "%s-vault-init-script" (include "cycloid.fullname" .) -}}
{{- end -}}

{{/*
Vault env vars injected into every backend container/cronjob.
When vault.enabled=true  → reads from the auto-generated vault-approle-secret (role-id / secret-id).
When vault.enabled=false → reads from the backend secret (vault-role-id / vault-secret-id),
                           which is populated from values.backend.vault.roleId/secretId.
This helper is the single place to maintain; all backend templates call it.
*/}}
{{- define "backend.vaultEnvVars" -}}
- name: "VAULT_URL"
  value: {{ .Values.backend.vault.url | quote }}
- name: "VAULT_ROLE_ID"
  valueFrom:
    secretKeyRef:
      name: {{ if .Values.vault.enabled }}{{ include "cycloid.vaultApproleSecretName" . }}{{ else }}{{ template "backend.backendSecretName" . }}{{ end }}
      key: {{ if .Values.vault.enabled }}role-id{{ else }}vault-role-id{{ end }}
- name: "VAULT_SECRET_ID"
  valueFrom:
    secretKeyRef:
      name: {{ if .Values.vault.enabled }}{{ include "cycloid.vaultApproleSecretName" . }}{{ else }}{{ template "backend.backendSecretName" . }}{{ end }}
      key: {{ if .Values.vault.enabled }}secret-id{{ else }}vault-secret-id{{ end }}
{{- end -}}

{{/*
Vault init shell script — rendered into the vault-init-script ConfigMap.
Uses vault CLI + busybox tools only (no jq, no extra images).
*/}}
{{- define "cycloid.vaultInitScript" -}}
#!/bin/sh
set -e
INIT_DATA=/vault/init-data/init.txt

# Wait for vault listener to be ready
until vault status 2>/dev/null; do sleep 1; done

# ── UPGRADE GUARD ─────────────────────────────────────────────────────
# On upgrades from pre-auto-init installations, vault is already
# initialised but init data does not exist on the new PVC yet.
# Exit cleanly so the vault pod starts normally; the cluster operator
# must unseal vault manually (same behaviour as before this chart change)
# and can seed /vault/init-data/init.txt to enable auto-unseal going forward.
if vault status 2>/dev/null | grep -q "Initialized.*true" && [ ! -f "$INIT_DATA" ]; then
  echo "INFO: Vault already initialised but no init data found on PVC."
  echo "INFO: Skipping auto-configuration. Seed $INIT_DATA to enable auto-unseal."
  exit 0
fi

# ── INIT (idempotent) ─────────────────────────────────────────────────
if vault status 2>/dev/null | grep -q "Initialized.*false"; then
  vault operator init -key-shares=5 -key-threshold=3 | tee "$INIT_DATA"
fi

# ── UNSEAL (idempotent) ───────────────────────────────────────────────
if vault status 2>/dev/null | grep -q "Sealed.*true"; then
  grep "Unseal Key [1-3]:" "$INIT_DATA" | awk '{print $NF}' | \
    while read -r key; do vault operator unseal "$key"; done
fi

# ── CONFIGURE (idempotent) ────────────────────────────────────────────
ROOT_TOKEN=$(grep "Initial Root Token:" "$INIT_DATA" | awk '{print $NF}')
vault login "$ROOT_TOKEN"

vault auth list 2>/dev/null | grep -q approle \
  || vault auth enable approle
vault secrets list 2>/dev/null | grep -q "^cycloid" \
  || vault secrets enable -path cycloid kv

vault policy write cycloid-ro - <<'POLICYEOF'
path "cycloid/*" { policy = "read" }
path "auth/token/create" { policy = "write" }
path "auth/token/renew-self" { policy = "write" }
POLICYEOF

vault policy write cycloid - <<'POLICYEOF'
path "cycloid/*" { capabilities = ["create","read","update","delete","list"] }
path "sys/policy/cycloid/*" { capabilities = ["create","read","update","delete","list"] }
path "auth/approle/role/cycloid-*" { capabilities = ["create","read","update","delete","list"] }
path "auth/token/create" { capabilities = ["create"] }
path "auth/token/renew-self" { capabilities = ["create"] }
POLICYEOF

vault read auth/approle/role/cycloid >/dev/null 2>&1 \
  || vault write auth/approle/role/cycloid \
       token_max_ttl=1h policies=cycloid token_ttl=20m
vault write auth/approle/role/cycloid/role-id   role_id="$VAULT_ROLE_ID"
vault write auth/approle/role/cycloid/secret-id secret_id="$VAULT_SECRET_ID"

vault read auth/approle/role/cycloid-ro >/dev/null 2>&1 \
  || vault write auth/approle/role/cycloid-ro \
       period=30m policies=cycloid-ro token_ttl=30m
vault write auth/approle/role/cycloid-ro/role-id   role_id="$VAULT_ROLE_ID_RO"
vault write auth/approle/role/cycloid-ro/secret-id secret_id="$VAULT_SECRET_ID_RO"
{{ if .Values.vaultInitSecret.enabled }}
# ── BACKUP INIT DATA TO K8S SECRET (optional, requires RBAC) ─────────
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
INIT_CONTENT=$(base64 < "$INIT_DATA" | tr -d '\n')

curl -sSk \
  -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/apply-patch+yaml" \
  "https://kubernetes.default.svc/api/v1/namespaces/${NAMESPACE}/secrets/{{ .Values.vaultInitSecret.secretName }}?fieldManager=vault-init&force=true" \
  -d @- <<CURLEOF \
  && echo "Init data stored in secret {{ .Values.vaultInitSecret.secretName }}" \
  || echo "WARNING: Failed to write K8s secret — check vaultInitSecret RBAC"
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.vaultInitSecret.secretName }}
  namespace: ${NAMESPACE}
data:
  init.txt: ${INIT_CONTENT}
CURLEOF
{{- end }}
{{- end }}

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


{{/*
========
Plugins
========
*/}}

{{/*
Return the Plugins Docker Registry fullname
*/}}
{{- define "plugins.dockerRegistry.fullname" -}}
{{- printf "%s-docker-registry" (include "cycloid.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Return the Plugins Registry fullname
*/}}
{{- define "plugins.pluginRegistry.fullname" -}}
{{- printf "%s-plugin-registry" (include "cycloid.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Return the Plugins Manager fullname
*/}}
{{- define "plugins.pluginManager.fullname" -}}
{{- printf "%s-plugin-manager" (include "cycloid.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Return the Plugins Secret name
*/}}
{{- define "plugins.secretName" -}}
{{- printf "%s-plugin-registry" (include "cycloid.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Docker Registry selector labels
*/}}
{{- define "plugins.dockerRegistry.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugins.dockerRegistry.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Plugin Registry selector labels
*/}}
{{- define "plugins.pluginRegistry.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugins.pluginRegistry.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Plugin Manager selector labels
*/}}
{{- define "plugins.pluginManager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugins.pluginManager.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}