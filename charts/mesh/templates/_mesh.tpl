{{/*
mesh.meshResource — renders a Mesh CR and optional policies.

Only renders if mesh.createMesh is true (unfederated zone use case).

Expects a dict with:
  - mesh: the mesh entry from .Values.meshes
  - meshName: mesh name string
  - Release: $.Release
  - Chart: $.Chart
*/}}
{{- define "mesh.meshResource" -}}
{{- if .mesh.createMesh -}}
---
apiVersion: kuma.io/v1alpha1
kind: Mesh
metadata:
  name: {{ .meshName }}
  labels:
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    app.kubernetes.io/instance: {{ .Release.Name }}
spec: {}
{{- /* createPolicies: when implemented, default mesh policies (MeshTrafficPermission,
       MeshCircuitBreaker, MeshRetry, MeshTimeout, etc.) would be rendered here.
       Each policy would be a separate resource using the mesh name as a scope. */ -}}
{{- if .mesh.createPolicies }}
  {{- /* Placeholder: iterate over default policy templates */ -}}
{{- end }}
{{- end }}
{{ end -}}
