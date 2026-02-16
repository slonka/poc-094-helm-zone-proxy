{{/*
mesh.pdb — renders a PodDisruptionBudget for a given mesh + role.

Only renders if roleConfig.pdb is non-empty.
Auto-fills selector matching the Deployment labels.

Expects the same context dict as mesh.deployment.
*/}}
{{- define "mesh.pdb" -}}
{{- if .roleConfig.pdb -}}
{{- $ctx := dict "Release" .Release "meshName" .meshName "role" .role "Chart" .Chart "roleConfig" .roleConfig -}}

{{- /* Build default PDB spec with selector */ -}}
{{- $defaultSpec := dict
  "selector" (dict
    "matchLabels" (dict "app" (include "mesh.name" $ctx))
  )
-}}

{{- /* Merge user PDB fields on top */ -}}
{{- $pdbSpec := merge .roleConfig.pdb $defaultSpec -}}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "mesh.name" $ctx }}
  labels:
    {{- include "mesh.labels" $ctx | nindent 4 }}
spec:
  {{- $pdbSpec | toYaml | nindent 2 }}
{{- end }}
{{ end -}}
