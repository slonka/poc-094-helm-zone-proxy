{{/*
mesh.hpa — renders an HPA for a given mesh + role.

Only renders if roleConfig.hpa is non-empty.
Auto-fills scaleTargetRef; remaining fields come from the raw hpa passthrough.

Expects the same context dict as mesh.deployment.
*/}}
{{- define "mesh.hpa" -}}
{{- if .roleConfig.hpa -}}
{{- $ctx := dict "Release" .Release "meshName" .meshName "role" .role "Chart" .Chart "roleConfig" .roleConfig -}}
{{- $deployName := include "mesh.name" $ctx -}}

{{- /* Build default HPA spec with scaleTargetRef */ -}}
{{- $defaultSpec := dict
  "scaleTargetRef" (dict
    "apiVersion" "apps/v1"
    "kind" "Deployment"
    "name" $deployName
  )
-}}

{{- /* Merge user HPA fields on top */ -}}
{{- $hpaSpec := merge .roleConfig.hpa $defaultSpec -}}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "mesh.name" $ctx }}
  labels:
    {{- include "mesh.labels" $ctx | nindent 4 }}
spec:
  {{- $hpaSpec | toYaml | nindent 2 }}
{{- end }}
{{ end -}}
