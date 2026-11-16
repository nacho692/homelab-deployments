# homelab-deployments

Every folder in `apps/` is an app running on the homelab k3s cluster. This
repo is config only: each app is just an `app.yaml` saying which image to run
and how. Source code and Dockerfiles live in your own repos.

## Use an existing image

Any public image works:

```yaml
# apps/<name>/app.yaml
port: 8080
image:
  repository: ghcr.io/someone/myapp
  tag: v1.2
```

Commit and push. Within ~3 minutes it's live at `http://<name>.k3s.internal`.

## Build and deploy your own image

Requires Docker and [crane](https://github.com/google/go-containerregistry)
(or Nix, which `deploy.sh` uses to run crane). No Docker configuration needed.

```bash
./deploy.sh <name> ~/code/myapp     # folder with your Dockerfile
```

It builds the image, pushes it to the cluster registry
(`registry.k3s.internal`), records the new tag in `apps/<name>/app.yaml`
(creating it if needed), and pushes to git.

If `registry.k3s.internal` doesn't resolve on your machine, push by node IP:
`PUSH_REGISTRY=<node-ip>:30500 ./deploy.sh <name> <dir>`.

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
  repository: ...        # default: registry.k3s.internal/<name>
  tag: ...               # set by deploy.sh for registry images
```

Defaults are in [`chart/values.yaml`](chart/values.yaml). Changes to
`app.yaml` only need a normal commit and push.

## Remove an app

Delete its folder and push.

## How it works

Argo CD (in the cluster) watches this repo; every `apps/*` folder becomes an
Argo CD Application rendered with `chart/` + that folder's `app.yaml`.
