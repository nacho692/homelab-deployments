#!/usr/bin/env bash
# Build apps/<app>, push it to the cluster registry, and deploy it by
# committing the new tag into apps/<app>/app.yaml. Argo CD does the rest.
#
#   ./deploy.sh <app>
#   PUSH_REGISTRY=<node-ip>:30500 ./deploy.sh <app>   # no DNS for the registry
#
# Pushes with crane (--insecure, the registry is plain HTTP), so Docker
# needs no insecure-registries config; Docker is only used to build.
set -euo pipefail

REGISTRY=registry.k3s.internal
PUSH_REGISTRY="${PUSH_REGISTRY:-$REGISTRY}"

if command -v crane >/dev/null; then
  crane() { command crane "$@"; }
elif command -v nix >/dev/null; then
  crane() { nix run nixpkgs#crane -- "$@"; }
else
  echo "need crane (https://github.com/google/go-containerregistry) or nix"; exit 1
fi

app="${1:?usage: ./deploy.sh <app>}"
dir="apps/$app"
cd "$(dirname "$0")"

[ -f "$dir/Dockerfile" ] || { echo "no $dir/Dockerfile"; exit 1; }
[ -f "$dir/app.yaml" ] || { echo "no $dir/app.yaml"; exit 1; }

# Tag = commit of the app folder, plus a suffix if it has uncommitted changes.
tag=$(git log -1 --format=%h -- "$dir")
[ -n "$(git status --porcelain -- "$dir")" ] && tag="$tag-dirty-$(date +%s)"
image="$REGISTRY/$app:$tag"

docker build -t "$image" "$dir"
tarball=$(mktemp --suffix=.tar)
trap 'rm -f "$tarball"' EXIT
docker save "$image" -o "$tarball"
crane push --insecure "$tarball" "$PUSH_REGISTRY/$app:$tag"

# Rewrite only the tag line under `image:`; keeps the rest of app.yaml as-is.
if grep -q '^image:' "$dir/app.yaml"; then
  sed -i "/^image:/,/^[^ ]/ s/^\(  tag:\).*/\1 $tag/" "$dir/app.yaml"
else
  printf 'image:\n  tag: %s\n' "$tag" >> "$dir/app.yaml"
fi

git add "$dir"
git commit -m "deploy: $app @ $tag"
git push

echo "Pushed $image; Argo CD will roll it out within ~3 minutes."
