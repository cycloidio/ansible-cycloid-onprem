{{/*
We don't want to loop over custom labels appending them to the selector
since it's very likely that it will break deployments, services, etc.
However, it's important to overwrite the standard labels if the user
overwrote them on metadata.labels fields.
*/}}
{{- define "mysql.selectorLabels" -}}
app.kubernetes.io/name: mysql
app.kubernetes.io/component: primary
app.kubernetes.io/part-of: primary
{{- end -}}

{{/*
Return the proper MySQL image name
*/}}
{{- define "mysql.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mysql.primary.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- $releaseName := regexReplaceAll "(-?[^a-z\\d\\-])+-?" (lower .Release.Name) "-" -}}
{{- if contains $name $releaseName -}}
{{- $releaseName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $releaseName $name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end }}
{{- end }}



{{- define "mysql.labels" -}}
app.kubernetes.io/name: mysql
app.kubernetes.io/component: primary
{{- with .Values.commonLabels }}
{{ toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Get secret passwords.
*/}}
{{- define "mysql.password" -}}
  {{- printf "%s" .Values.auth.password  -}}
{{- end -}}

{{- define "mysql.rootPassword" -}}
  {{- printf "%s" .Values.auth.rootPassword  -}}
{{- end -}}

{{- define "mysql.storage.class" -}}
{{- $storageClass := .Values.primary.persistence.storageClass | default "" -}}
{{- if $storageClass -}}
  {{- if (eq "-" $storageClass) -}}
      {{- printf "storageClassName: \"\"" -}}
  {{- else -}}
      {{- printf "storageClassName: %s" $storageClass -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return the secret with MySQL credentials
*/}}
{{- define "mysql.secretName" -}}
    {{- if .Values.auth.existingSecret -}}
        {{- printf "%s" (tpl .Values.auth.existingSecret $) -}}
    {{- else -}}
        {{- printf "%s" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- end -}}