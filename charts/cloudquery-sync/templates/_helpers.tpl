{{/*
Expand the name of the chart.
*/}}
{{- define "cloudquery-sync.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully-qualified app name.
*/}}
{{- define "cloudquery-sync.fullname" -}}
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
Create chart label value.
*/}}
{{- define "cloudquery-sync.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "cloudquery-sync.labels" -}}
helm.sh/chart: {{ include "cloudquery-sync.chart" . }}
{{ include "cloudquery-sync.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "cloudquery-sync.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloudquery-sync.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "cloudquery-sync.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cloudquery-sync.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the destination credentials Secret (either user-supplied or chart-managed).
*/}}
{{- define "cloudquery-sync.destinationSecretName" -}}
{{- if .Values.destination.existingSecret.name }}
{{- .Values.destination.existingSecret.name }}
{{- else if .Values.externalSecret.targetSecretName }}
{{- .Values.externalSecret.targetSecretName }}
{{- else }}
{{- printf "%s-destination-credentials" (include "cloudquery-sync.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Name of the ConfigMap holding the rendered CloudQuery config.
*/}}
{{- define "cloudquery-sync.configMapName" -}}
{{- printf "%s-config" (include "cloudquery-sync.fullname" .) }}
{{- end }}

{{/*
CloudQuery sync command.
When destination.existingSecret or destination.existingConfigMap is set, the
user-managed destination config is mounted at /etc/cloudquery/destination.yaml
and both files are passed to `cloudquery sync`.
*/}}
{{- define "cloudquery-sync.command" -}}
{{- if or .Values.destination.existingSecret.name .Values.destination.existingConfigMap.name }}
- cloudquery
- sync
- /etc/cloudquery/source-config.yaml
- /etc/cloudquery/destination.yaml
- --log-level={{ .Values.cloudquery.logLevel }}
- --log-format={{ .Values.cloudquery.logFormat }}
{{- else }}
- cloudquery
- sync
- /etc/cloudquery/source-config.yaml
- /etc/cloudquery/destination-config.yaml
- --log-level={{ .Values.cloudquery.logLevel }}
- --log-format={{ .Values.cloudquery.logFormat }}
{{- end }}
{{- end }}

{{/*
Shared pod template spec used by both CronJob and Deployment.
*/}}
{{- define "cloudquery-sync.podSpec" -}}
serviceAccountName: {{ include "cloudquery-sync.serviceAccountName" . }}
{{- with .Values.podSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
volumes:
  - name: cq-config
    configMap:
      name: {{ include "cloudquery-sync.configMapName" . }}
  - name: tmp
    emptyDir: {}
  {{- if .Values.destination.existingSecret.name }}
  - name: destination-config
    secret:
      secretName: {{ .Values.destination.existingSecret.name }}
      items:
        - key: {{ .Values.destination.existingSecret.key }}
          path: destination.yaml
  {{- else if .Values.destination.existingConfigMap.name }}
  - name: destination-config
    configMap:
      name: {{ .Values.destination.existingConfigMap.name }}
      items:
        - key: {{ .Values.destination.existingConfigMap.key }}
          path: destination.yaml
  {{- end }}
  {{- with .Values.extraVolumes }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
containers:
  - name: cloudquery
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    command:
      {{- include "cloudquery-sync.command" . | nindent 6 }}
    {{- with .Values.containerSecurityContext }}
    securityContext:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.resources }}
    resources:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.extraEnv }}
    env:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    volumeMounts:
      - name: cq-config
        mountPath: /etc/cloudquery
        readOnly: true
      - name: tmp
        mountPath: /tmp
      {{- if or .Values.destination.existingSecret.name .Values.destination.existingConfigMap.name }}
      - name: destination-config
        mountPath: /etc/cloudquery/destination.yaml
        subPath: destination.yaml
        readOnly: true
      {{- end }}
      {{- with .Values.extraVolumeMounts }}
      {{- toYaml . | nindent 6 }}
      {{- end }}

{{- end }}

{{/*
Validate that at most one destination spec source is active.
*/}}
{{- define "cloudquery-sync.validateDestination" -}}
{{- $hasSpec := not (empty .Values.destination.spec) }}
{{- $hasSecret := not (empty .Values.destination.existingSecret.name) }}
{{- $hasConfigMap := not (empty .Values.destination.existingConfigMap.name) }}
{{- $count := 0 }}
{{- if $hasSpec }}{{- $count = add $count 1 }}{{- end }}
{{- if $hasSecret }}{{- $count = add $count 1 }}{{- end }}
{{- if $hasConfigMap }}{{- $count = add $count 1 }}{{- end }}
{{- if gt $count 1 }}
{{- fail "Only one of destination.spec, destination.existingSecret, or destination.existingConfigMap may be set at a time." }}
{{- end }}
{{- end }}
