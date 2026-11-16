# homelab-deployments

Every folder in `apps/` is an app running on the homelab k3s cluster.

## Requirements

Push access to this repo. To build images here you also need Docker and
[crane](https://github.com/google/go-containerregistry) (or Nix, which
`deploy.sh` uses to run crane). No Docker configuration needed.

## Use an existing image

Any public image works without building anything here:

```yaml
# apps/<name>/app.yaml
port: 8080
image:
  repository: ghcr.io/someone/myapp
  tag: v1.2
```

Commit and push; that's the whole deploy.

## Build and deploy your own image

1. Create `apps/<name>/` with a `Dockerfile` and an `app.yaml`:

   ```yaml
   port: 8080        # port your container listens on
   ```

2. Commit, then run:

   ```bash
   ./deploy.sh <name>
   ```

It builds the image, pushes it to the cluster registry
(`registry.k3s.internal`), records the new tag in `app.yaml`, and pushes to
git. Within ~3 minutes it's live at `http://<name>.k3s.internal`.

If `registry.k3s.internal` doesn't resolve on your machine, push by node IP:
`PUSH_REGISTRY=<node-ip>:30500 ./deploy.sh <name>`.

Changes to `app.yaml` alone (env, replicas, ...) only need a normal
commit and push, no `deploy.sh`.

## app.yaml options

```yaml
port: 8080
replicas: 1
env:
  GREETING: hello
ingress:
  enabled: true          # false = only reachable inside the cluster
  host: other.k3s.internal
resources:
  limits:
    memory: 512Mi
image:
  tag: ...               # set by deploy.sh, don't edit
```

Defaults are in [`chart/values.yaml`](chart/values.yaml).

## Remove an app

Delete its folder and push.

## How it works

- `deploy.sh` pushes `registry.k3s.internal/<name>:<git-sha>` and commits
  the tag into `app.yaml`.
- Argo CD (in the cluster) watches this repo; every `apps/*` folder becomes an
  Argo CD Application rendered with `chart/` + that folder's `app.yaml`.
