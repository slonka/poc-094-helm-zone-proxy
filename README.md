# POC: Helm Chart for Per-Mesh Zone Proxy Deployment (MADR 094)

## What Changed Since the Original POC (Feb 9)

The original POC demonstrated a single `zone-proxy` subchart with flat values (`mesh`, `role`, `podSpec`, `containers`). MADR 094 has since evolved significantly:

| Original POC | Current MADR 094 |
|---|---|
| Flat `zoneProxy` config | **`meshes` list** with per-mesh entries |
| Single `role` field | Separate **`ingress`/`egress`/`combinedProxies`** per mesh |
| `zone-proxy` subchart | **`mesh` library subchart** (manages full mesh lifecycle) |
| No scaling support | **HPA** and **PDB** passthrough |
| No ServiceAccount | **Per-role ServiceAccount** |
| `containers` passthrough | **`resources`** as first-class field; `podSpec` for everything else |
| Single mesh only | **Multi-mesh** support |
| — | **`createMesh`** for unfederated zones |
| — | **Service naming** with 63-char validation and override |

The core innovation — raw K8s spec passthrough via `merge` — is preserved.

## Architecture: Library Subchart + Parent Iteration

Helm can't natively render a subchart N times for N list items. This POC uses a **library chart** pattern:

```
poc-094-helm-zone-proxy/
├── charts/
│   └── mesh/                        # Library subchart (type: library)
│       ├── Chart.yaml
│       └── templates/
│           ├── _helpers.tpl         # Naming, labels, 63-char validation
│           ├── _deployment.tpl      # Per-role Deployment (merge pattern)
│           ├── _service.tpl         # Per-role Service
│           ├── _hpa.tpl             # HPA (passthrough)
│           ├── _pdb.tpl             # PDB (passthrough)
│           ├── _serviceaccount.tpl  # ServiceAccount
│           └── _mesh.tpl           # Mesh CR + policy stub
└── kuma/
    ├── Chart.yaml                   # Depends on mesh library
    ├── values.yaml                  # meshes list (MADR schema)
    └── templates/
        ├── _helpers.tpl
        └── meshes.yaml              # range .Values.meshes → calls library
```

- `charts/mesh/` is a **library chart** — it only provides named templates, never renders directly
- `kuma/templates/meshes.yaml` iterates `.Values.meshes` and calls these templates for each role
- Users interact only with the `meshes` list in `kuma/values.yaml`

## The `meshes` List Pattern

```yaml
meshes:
  - name: default
    ingress:
      enabled: true
    egress:
      enabled: true

  - name: payments
    ingress:
      enabled: true
      resources:             # First-class field (most common override)
        requests:
          cpu: 100m
          memory: 64Mi
      podSpec:               # Raw passthrough — any PodSpec field
        nodeSelector:
          kubernetes.io/os: linux
      hpa:                   # Raw passthrough — any HPA spec field
        minReplicas: 2
        maxReplicas: 5
        metrics:
          - type: Resource
            resource:
              name: cpu
              target:
                type: Utilization
                averageUtilization: 80
    egress:
      enabled: true
```

Each mesh entry can have:
- **`ingress`** / **`egress`**: separate role configs (mutually exclusive with `combinedProxies`)
- **`combinedProxies`**: single deployment handling both roles
- **`createMesh`**: render a Mesh CR (for unfederated zones)
- **`createPolicies`**: stub for default mesh policies

Each role config supports:
- **`resources`**: container resources (first-class, merged into the container spec)
- **`podSpec`**: raw PodSpec passthrough (nodeSelector, tolerations, affinity, etc.)
- **`hpa`**: raw HPA spec passthrough (scaleTargetRef is auto-filled)
- **`pdb`**: raw PDB spec passthrough (selector is auto-filled)
- **`replicas`**: Deployment replicas (default 1)
- **`service.name`**: override the generated service name
- **`service.type`**: override the default type (LoadBalancer for ingress, ClusterIP for egress)

## Raw Spec Passthrough (Preserved)

The core `merge` pattern from the original POC is preserved:

```
defaultContainer  +  roleConfig.resources  →  container with resources
defaultPodSpec    +  roleConfig.podSpec     →  final pod spec
```

Any valid PodSpec field works without template changes:

```bash
helm template my-release . \
  --set 'meshes[0].name=default' \
  --set 'meshes[0].ingress.enabled=true' \
  --set 'meshes[0].ingress.podSpec.shareProcessNamespace=true'

helm template my-release . \
  --set 'meshes[0].name=default' \
  --set 'meshes[0].ingress.enabled=true' \
  --set 'meshes[0].ingress.podSpec.terminationGracePeriodSeconds=60'
```

HPA and PDB also use passthrough — any valid HPA/PDB spec field works, with `scaleTargetRef`/`selector` auto-filled.

## Service Naming

Services are named `<release>-<mesh>-<role>` by default (e.g., `my-release-default-ingress`). Names are validated to not exceed 63 characters. Override with:

```yaml
ingress:
  service:
    name: custom-svc
```

## Running the POC

```bash
cd kuma
helm dependency update .

# Multi-mesh rendering (default values: 2 meshes × 2 roles)
helm template my-release .
# → 4 Deployments, 4 Services, 4 ServiceAccounts, 1 HPA

# Raw passthrough — no template changes needed
helm template my-release . \
  --set 'meshes[0].name=default' \
  --set 'meshes[0].ingress.enabled=true' \
  --set 'meshes[0].ingress.podSpec.shareProcessNamespace=true'

# Service name override
helm template my-release . \
  --set 'meshes[0].name=default' \
  --set 'meshes[0].ingress.enabled=true' \
  --set 'meshes[0].ingress.service.name=custom-svc'

# Combined proxies mode
helm template my-release . \
  --set 'meshes[0].name=default' \
  --set 'meshes[0].combinedProxies.enabled=true'

# Create Mesh CR for unfederated zone
helm template my-release . \
  --set 'meshes[0].name=default' \
  --set 'meshes[0].ingress.enabled=true' \
  --set 'meshes[0].createMesh=true'

# Mutual exclusion validation (fails as expected)
helm template my-release . \
  --set 'meshes[0].name=default' \
  --set 'meshes[0].ingress.enabled=true' \
  --set 'meshes[0].combinedProxies.enabled=true'
```

## Comparison

### Current kuma chart (ingress only)

```
values.yaml            144 lines   Fixed set of fields
deployment template    148 lines   One {{- with }} block per field
────────────────────────────────
Total                  292 lines   Supports ~15 PodSpec/container fields
```

### This POC (all roles, multi-mesh)

```
values.yaml             31 lines   Open-ended meshes list
meshes.yaml             35 lines   Iterates meshes, calls library
_deployment.tpl         93 lines   Single merge, renders entire spec
_service.tpl            47 lines   Per-role Service with overrides
_hpa.tpl                35 lines   Passthrough with auto scaleTargetRef
_pdb.tpl                32 lines   Passthrough with auto selector
_serviceaccount.tpl     15 lines   Per-role SA
_mesh.tpl               30 lines   Mesh CR + policy stub
_helpers.tpl            62 lines   Naming, labels, validation
────────────────────────────────
Total                  380 lines   Supports ALL fields, ALL roles, multi-mesh
```

380 lines covers ingress + egress + combined proxies + HPA + PDB + ServiceAccount + Mesh CR across unlimited meshes. The current chart would need ~900+ lines for equivalent coverage (292 lines × 3 roles, plus HPA/PDB/SA).
