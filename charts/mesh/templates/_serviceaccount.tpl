{{/*
mesh.serviceaccount — renders a ServiceAccount for a given mesh + role.

Expects the same context dict as mesh.deployment.
*/}}
{{- define "mesh.serviceaccount" -}}
{{- $ctx := dict "Release" .Release "meshName" .meshName "role" .role "Chart" .Chart "roleConfig" .roleConfig -}}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "mesh.name" $ctx }}
  labels:
    {{- include "mesh.labels" $ctx | nindent 4 }}
{{ end -}}
