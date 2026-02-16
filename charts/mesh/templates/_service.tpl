{{/*
mesh.service — renders a Service for a given mesh + role.

Expects the same context dict as mesh.deployment.
*/}}
{{- define "mesh.service" -}}
{{- $ctx := dict "Release" .Release "meshName" .meshName "role" .role "Chart" .Chart "roleConfig" .roleConfig -}}

{{- /* Validate service name length */ -}}
{{- include "mesh.serviceNameValidation" $ctx -}}

{{- /* Determine default service type by role */ -}}
{{- $defaultType := "ClusterIP" -}}
{{- if eq .role "ingress" -}}
{{- $defaultType = "LoadBalancer" -}}
{{- end -}}

{{- /* Allow override via roleConfig.service.type */ -}}
{{- $svcType := $defaultType -}}
{{- if and .roleConfig.service .roleConfig.service.type -}}
{{- $svcType = .roleConfig.service.type -}}
{{- end -}}

{{- /* Determine port based on role */ -}}
{{- $ports := list -}}
{{- if eq .role "ingress" -}}
{{- $ports = list (dict "name" "proxy" "port" 10001 "targetPort" "proxy") -}}
{{- else if eq .role "egress" -}}
{{- $ports = list (dict "name" "proxy" "port" 10002 "targetPort" "proxy") -}}
{{- else -}}
{{- $ports = list (dict "name" "ingress" "port" 10001 "targetPort" "ingress") (dict "name" "egress" "port" 10002 "targetPort" "egress") -}}
{{- end -}}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mesh.serviceName" $ctx }}
  labels:
    {{- include "mesh.labels" $ctx | nindent 4 }}
spec:
  type: {{ $svcType }}
  selector:
    {{- include "mesh.selectorLabels" $ctx | nindent 4 }}
  ports:
    {{- $ports | toYaml | nindent 4 }}
{{ end -}}
