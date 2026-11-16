# homelab-deployments

Every folder in `apps/` is an app running on the homelab k3s cluster.

## Add an app

1. Create `apps/<name>/` with a `Dockerfile` and an `app.yaml`:

   ```yaml
   port: 8080        # port your container listens on
   ```

2. Push to `main`.

That's it. CI builds the image, and a minute or two later it's live at
`http://<name>.k3s.internal` on the internal network.

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
  tag: ...               # set by CI, don't edit
```

Defaults are in [`chart/values.yaml`](chart/values.yaml).

## Remove an app

Delete its folder and push.

## How it works

- `.github/workflows/build.yml` builds changed apps, pushes
  `ghcr.io/nacho692/<name>:<sha>`, and commits the new tag into `app.yaml`.
- Argo CD (in the cluster) watches this repo; every `apps/*` folder becomes an
  Argo CD Application rendered with `chart/` + that folder's `app.yaml`.
