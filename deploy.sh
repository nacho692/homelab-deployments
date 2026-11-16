#!/usr/bin/env bash
# Build an image from any folder, push it to the cluster registry, and deploy
# it by committing the new tag into apps/<app>/app.yaml. Argo CD does the rest.
# Source code and Dockerfiles live wherever you like; this repo is config only.
#
#   ./deploy.sh <app> <build-dir>
#   PUSH_REGISTRY=<node-ip>:30500 ./deploy.sh <app> <build-dir>   # no DNS for the registry
#
# Pushes with crane (--insecure, the registry is plain HTTP), so Docker
# needs no insecure-registries config; Docker is only used to build.
set -euo pipefail

REGISTRY=registry.k3s.internal
PUSH_REGISTRY="${PUSH_REGISTRY:-$REGISTRY}"

usage="usage: ./deploy.sh <app> <build-dir>"
app="${1:?$usage}"
src="$(realpath "${2:?$usage}")"
cd "$(dirname "$0")"
conf="apps/$app/app.yaml"

[ -f "$src/Dockerfile" ] || { echo "no Dockerfile in $src"; exit 1; }

if command -v crane >/dev/null; then
  crane() { command crane "$@"; }
elif command -v nix >/dev/null; then
  crane() { nix run nixpkgs#crane -- "$@"; }
else
  echo "need crane (https://github.com/google/go-containerregistry) or nix"; exit 1
fi

# Tag = last commit touching the build dir (+ suffix if it has uncommitted
# changes), or a timestamp if it isn't a git repo.
if git -C "$src" rev-parse --git-dir >/dev/null 2>&1; then
  tag=$(git -C "$src" log -1 --format=%h -- .)
  [ -n "$(git -C "$src" status --porcelain -- .)" ] && tag="$tag-dirty-$(date +%s)"
else
  tag="build-$(date +%Y%m%d-%H%M%S)"
fi
image="$REGISTRY/$app:$tag"

docker build -t "$image" "$src"
tarball=$(mktemp --suffix=.tar)
trap 'rm -f "$tarball"' EXIT
docker save "$image" -o "$tarball"
crane push --insecure "$tarball" "$PUSH_REGISTRY/$app:$tag"

# Rewrite only the tag line under `image:`; keeps the rest of app.yaml as-is.
mkdir -p "apps/$app"
if [ ! -f "$conf" ]; then
  printf 'image:\n  tag: %s\n' "$tag" > "$conf"
  echo "Created $conf (port defaults to 8080; see chart/values.yaml)"
elif grep -q '^image:' "$conf"; then
  sed -i "/^image:/,/^[^ ]/ s/^\(  tag:\).*/\1 $tag/" "$conf"
else
  printf 'image:\n  tag: %s\n' "$tag" >> "$conf"
fi

git add "$conf"
git commit -m "deploy: $app @ $tag"
git push

echo "Pushed $image; Argo CD will roll it out within ~3 minutes."
