# AGENTS.md

GitOps configuration for a single k3s cluster, written with [nixidy](https://nixidy.dev).
Nix modules in `modules/` are rendered to plain YAML in `manifests/`, which Argo CD syncs
from the `main` branch of `https://github.com/arnarg/cluster.git`.

There is one environment: `.#prod` (`flake.nix` → `nixidyEnvs.prod`).

## Running nixidy

Always invoke the CLI through the flake so the version matches `flake.lock`:

```sh
nix run .#nixidy -- <command> .#prod [options]
```

Do not rely on a globally installed `nixidy`.

| Task | Command |
| --- | --- |
| Show target repo/branch | `nix run .#nixidy -- info .#prod` |
| Build to `./result` (no repo changes) | `nix run .#nixidy -- build .#prod` |
| Diff build against committed manifests | `nix run .#nixidy -- diff .#prod --path manifests` |
| Diff against manifests on a git branch | `nix run .#nixidy -- diff .#prod --branch main --path manifests` |
| Regenerate `manifests/` | `nix run .#nixidy -- switch .#prod` |
| List typed resource attribute names | `nix run .#nixidy -- resources .#prod` |
| Inspect options of a resource type | `nix run .#nixidy -- resources .#prod deployments.spec.template.spec` |

Never run `nix run .#nixidy -- apply` or `bootstrap` against the cluster; deployment is done
by Argo CD from git.

Other flake apps:

- `nix run .#staticCheck` — statix lint (also run in CI). Fix warnings before finishing.
- `nix run .#updateCharts` — bump the local charts in `charts/`.
- `nix run .#updateCiliumSrc` — regenerate `modules/cilium/source.json` (Cilium CRD source)
  from the nixhelm Cilium chart's `appVersion`.

Nix files are formatted with `nixfmt` (RFC style). Keep that style.

## Workflow

1. Edit Nix under `modules/` (or `configuration.nix`).
2. Verify with `nix run .#nixidy -- diff .#prod --path manifests` and check the diff is what you
   intended and nothing else changed.
3. Run `nix run .#staticCheck`.
4. Optionally run `nix run .#nixidy -- switch .#prod` to update `manifests/`.

**Never hand-edit files in `manifests/`.** They are generated. On every push to `main`
that touches non-manifest files, CI (`.github/workflows/generate-manifests.yaml`) runs `switch` and opens a
`promote/env/prod` PR with the rendered result. A weekly workflow bumps `nixhelm` (and
the Cilium source) the same way.

New files must be `git add`ed before nix evaluation sees them (flakes only read tracked files).

## Repository layout

- `flake.nix` — inputs (nixpkgs, nixidy, nixhelm), the `prod` env and helper apps.
- `configuration.nix` — prod-specific settings (domain, NFS server, target branch/rootPath).
- `modules/default.nix` — imports every app module, sets nixidy defaults. **A new module
  must be added to `imports` here.**
- `modules/templates.nix` — `webApplication` template (Deployment + Service + Ingress).
- `modules/<app>/default.nix` — one Argo CD application each.
- `charts/` — Helm charts not in nixhelm (`nixidy.chartsDir`), each a `default.nix` with
  `repo`, `chart`, `version`, `chartHash`.
- `manifests/` — generated output: `manifests/<app>/<Kind>-<name>.yaml`, Argo CD
  Applications in `manifests/apps/Application-<app>.yaml`.

## nixidy conventions used here

- **Applications**: `applications.<name> = { namespace; createNamespace; helm.releases.<r>; resources; templates; }`.
  Some apps use `syncPolicy.syncOptions.createNamespace = true` (Argo-managed namespace) instead
  of `createNamespace = true`.
- **Helm charts** come from nixhelm via the `charts` module argument, e.g.
  `chart = charts.traefik.traefik;`. Local charts appear under the same `charts` arg.
- **Patching Helm output**: set fields under `applications.<app>.resources.<type>.<name>`; use
  `lib.mkForce` to override chart-provided values (see `k8s-gateway` ClusterRole).
- **Typed resources** use plural camelCase names (`deployments`, `networkPolicies`,
  `ciliumNetworkPolicies`, `onePasswordItems`, `proxyClasses`). Keyed lists such as
  `containers`, `ports`, `env`, `volumes`, `volumeMounts` are written as attrsets keyed by
  name (or mount path); true lists like Ingress `rules` stay lists. Use `nix run .#nixidy -- resources`
  when unsure.
- **CRD types** are added with `nixidy.applicationImports` using the `generators` module arg
  (`generators.fromCRDModule` for Cilium, `generators.fromChartCRDModule` for 1Password and
  Tailscale). Add a kind to `kindFilter` before using a new CRD kind from those charts.
- **Label stripping**: `nixidy.defaults.helm.transformer` removes `app.kubernetes.io/version`,
  `app.kubernetes.io/managed-by` and `helm.sh/chart` from all Helm output to keep diffs small.
- **Module options** shared between apps: `networking.domain`, `networking.traefik.ingressClassName`,
  `storage.csi.nfs.storageClassName`, plus `services.argocd.values`, `networking.cilium.values`,
  `networking.traefik.values`, `networking.tailscale-operator.values` for cross-module value overrides.
- Other nixidy features available if needed: `objectTransforms` (match/update/replace rules on
  rendered objects), `assertions`/`warnings`, `extraRawYamls` (unparsed passthrough YAML).
  See https://nixidy.dev.

## Cluster specifics to respect

- **Cilium enforces policy everywhere** (`policyEnforcementMode = "always"`). Every new
  workload needs explicit network policies or it will be cut off. Typical set:
  - Ingress from Traefik: `networkPolicies.allow-traefik-ingress` selecting namespace
    `traefik` / pod `app.kubernetes.io/name = traefik` on the container port.
  - kube-apiserver access: `ciliumNetworkPolicies` with `toEntities = [ "kube-apiserver" ]`, port `6443`.
  - FQDN egress: a DNS-proxy rule to `kube-system`/`kube-dns` port 53 with `rules.dns`, then `toFQDNs`.
  - PostgreSQL and other lab services run on the same host as the API server, so Cilium matches
    them as entity `kube-apiserver`, not a CIDR (see miniflux/shiori).
- **Ingress**: Traefik is the default ingress class, exposed only on the tailnet through
  tailscale-operator; k8s-gateway resolves Ingress hosts. Hosts are `<sub>.${config.networking.domain}`.
  TLS is handled by Traefik (Let's Encrypt via Cloudflare DNS), so backends serve plain HTTP.
- **Secrets** come from 1Password: use the `opSecret` template
  (`applications.<app>.templates.opSecret.<secret-name>.itemName = "<1password item>";`), which
  renders a `OnePasswordItem` that the operator turns into a Secret. Never put secret values in Nix.
- **Storage**: NFS CSI storage class `config.storage.csi.nfs.storageClassName` (`nfs-csi`, `Retain`).
- All Argo CD apps auto-sync with `prune` and `selfHeal`, so removing a resource from Nix deletes it
  from the cluster once merged. Be careful when removing CRDs, PVCs or namespaces.
