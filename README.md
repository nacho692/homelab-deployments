# homelab-deployments

Every folder in `apps/` is an app running on the homelab k3s cluster.

## One-time setup

You need Docker and push access to this repo. Then:

```bash
sudo ./setup-docker.sh
```

This lets Docker push to the cluster registry (`registry.k3s.internal`,
plain HTTP on the internal network).

## Add or update an app

1. Create `apps/<name>/` with a `Dockerfile` and an `app.yaml`:

   ```yaml
   port: 8080        # port your container listens on
   ```

2. Commit, then run:

   ```bash
   ./deploy.sh <name>
   ```

It builds the image, pushes it to the registry, records the new tag in
`app.yaml`, and pushes to git. Within ~3 minutes it's live at
`http://<name>.k3s.internal`.

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
