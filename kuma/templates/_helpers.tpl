{{/* Parent chart helpers — minimal, most logic lives in the mesh library chart. */}}
{{- define "kuma.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
