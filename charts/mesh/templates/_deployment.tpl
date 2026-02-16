{{/*
mesh.deployment — renders a Deployment for a given mesh + role.

Expects a context dict with:
  - mesh: the mesh entry from .Values.meshes
  - meshName: mesh name string
  - role: "ingress" | "egress" | "all"
  - roleConfig: the role-specific config block (ingress/egress/combinedProxies)
  - Release: $.Release
  - Chart: $.Chart
  - Values: $.Values (parent)
*/}}
{{- define "mesh.deployment" -}}
{{- $ctx := dict "Release" .Release "meshName" .meshName "role" .role "Chart" .Chart "roleConfig" .roleConfig -}}

{{- /* Determine ports based on role */ -}}
{{- $ports := list -}}
{{- if eq .role "ingress" -}}
{{- $ports = list (dict "name" "proxy" "containerPort" 10001) (dict "name" "admin" "containerPort" 9901) -}}
{{- else if eq .role "egress" -}}
{{- $ports = list (dict "name" "proxy" "containerPort" 10002) (dict "name" "admin" "containerPort" 9901) -}}
{{- else -}}
{{- /* combined: both ports */ -}}
{{- $ports = list (dict "name" "ingress" "containerPort" 10001) (dict "name" "egress" "containerPort" 10002) (dict "name" "admin" "containerPort" 9901) -}}
{{- end -}}

{{- /* Determine proxy type annotation */ -}}
{{- $proxyType := .role -}}
{{- if eq .role "all" -}}
{{- $proxyType = "combined" -}}
{{- end -}}

{{- /* Build default container */ -}}
{{- $defaultContainer := dict
  "name" "zone-proxy"
  "image" "docker.io/kumahq/kuma-dp:latest"
  "imagePullPolicy" "IfNotPresent"
  "ports" $ports
  "args" (list "run" (printf "--proxy-type=%s" $proxyType))
  "readinessProbe" (dict
    "httpGet" (dict "path" "/ready" "port" 9901)
    "initialDelaySeconds" 1
    "periodSeconds" 5
  )
  "livenessProbe" (dict
    "httpGet" (dict "path" "/ready" "port" 9901)
    "initialDelaySeconds" 60
    "periodSeconds" 5
  )
-}}

{{- /* Merge resources as a first-class field into the default container */ -}}
{{- if .roleConfig.resources -}}
{{- $_ := set $defaultContainer "resources" .roleConfig.resources -}}
{{- end -}}

{{- /* Build user container overrides from podSpec.containers[0] if present,
       but primarily the passthrough is via podSpec at the pod level */ -}}
{{- $container := $defaultContainer -}}

{{- /* Build default pod spec */ -}}
{{- $defaultPodSpec := dict
  "serviceAccountName" (include "mesh.name" $ctx)
  "containers" (list $container)
-}}

{{- /* Merge roleConfig.podSpec on top — raw passthrough for any PodSpec field */ -}}
{{- $podSpec := $defaultPodSpec -}}
{{- if .roleConfig.podSpec -}}
{{- $podSpec = merge .roleConfig.podSpec $defaultPodSpec -}}
{{- end -}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mesh.name" $ctx }}
  labels:
    {{- include "mesh.labels" $ctx | nindent 4 }}
spec:
  replicas: {{ .roleConfig.replicas | default 1 }}
  selector:
    matchLabels:
      {{- include "mesh.selectorLabels" $ctx | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "mesh.labels" $ctx | nindent 8 }}
      annotations:
        kuma.io/proxy-type: {{ $proxyType }}
    spec:
{{ $podSpec | toYaml | indent 6 }}
{{ end -}}
