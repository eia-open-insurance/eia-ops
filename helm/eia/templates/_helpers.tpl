{{/*
Common chart labels.
*/}}
{{- define "eia.labels" -}}
app.kubernetes.io/part-of: eia-open-insurance
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Image reference. The per-service tag wins; global.imageTag is the fallback.
Call with: (dict "root" $ "image" $service.image)
*/}}
{{- define "eia.image" -}}
{{- $image := .image -}}
{{- printf "%s:%s" $image.repository (default .root.Values.global.imageTag $image.tag) -}}
{{- end }}

{{/*
Database Secret name: an existing Secret wins, otherwise the chart-managed placeholder.
*/}}
{{- define "eia.dbSecretName" -}}
{{- default "eia-db" .Values.postgres.auth.existingSecret -}}
{{- end }}

{{/*
Event signing Secret name for the outbox HMAC secret.
*/}}
{{- define "eia.eventSigningSecretName" -}}
{{- default "eia-event-signing" .Values.eventSigning.existingSecret -}}
{{- end }}
