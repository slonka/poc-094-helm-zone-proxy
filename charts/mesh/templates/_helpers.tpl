{{/*
mesh.name — canonical resource name: <release>-<meshName>-<role>
Expects a dict with: Release, meshName, role
*/}}
{{- define "mesh.name" -}}
{{- printf "%s-%s-%s" .Release.Name .meshName .role | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
mesh.serviceName — service name with override support.
Expects a dict with: Release, meshName, role, roleConfig
Uses roleConfig.service.name if set, otherwise falls back to mesh.name.
*/}}
{{- define "mesh.serviceName" -}}
{{- if and .roleConfig .roleConfig.service .roleConfig.service.name -}}
{{- .roleConfig.service.name -}}
{{- else -}}
{{- include "mesh.name" . -}}
{{- end -}}
{{- end -}}

{{/*
mesh.serviceNameValidation — fail if the service name exceeds 63 characters.
Expects the same context as mesh.serviceName.
*/}}
{{- define "mesh.serviceNameValidation" -}}
{{- $svcName := include "mesh.serviceName" . -}}
{{- if gt (len $svcName) 63 -}}
{{- fail (printf "Service name %q is %d characters, exceeds the 63-character limit. Use service.name to set a shorter override." $svcName (len $svcName)) -}}
{{- end -}}
{{- end -}}

{{/*
mesh.labels — standard Helm labels plus kuma.io/mesh and app.
Expects a dict with: Release, meshName, role, Chart
*/}}
{{- define "mesh.labels" -}}
app: {{ include "mesh.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: zone-proxy
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
kuma.io/mesh: {{ .meshName | quote }}
{{- end -}}

{{/*
mesh.selectorLabels — minimal labels for selector matching.
Expects a dict with: Release, meshName, role
*/}}
{{- define "mesh.selectorLabels" -}}
app: {{ include "mesh.name" . }}
{{- end -}}

{{/*
mesh.validateExclusive — fail if both ingress/egress AND combinedProxies are enabled.
Expects a mesh entry from .Values.meshes.
*/}}
{{- define "mesh.validateExclusive" -}}
{{- $hasIngress := and .ingress .ingress.enabled -}}
{{- $hasEgress := and .egress .egress.enabled -}}
{{- $hasCombined := and .combinedProxies .combinedProxies.enabled -}}
{{- if and (or $hasIngress $hasEgress) $hasCombined -}}
{{- fail (printf "Mesh %q: cannot enable both ingress/egress and combinedProxies — they are mutually exclusive." .name) -}}
{{- end -}}
{{- end -}}
