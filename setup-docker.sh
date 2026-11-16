#!/usr/bin/env bash
# One-time setup so this machine can push to the cluster registry.
# The registry is plain HTTP on the internal network, which Docker refuses
# unless it's listed under insecure-registries. Run with sudo.
#
#   sudo ./setup-docker.sh            # DNS already resolves *.k3s.internal
#   sudo ./setup-docker.sh <node-ip>  # no DNS yet: also add /etc/hosts entries
set -euo pipefail

REGISTRY=registry.k3s.internal
CONF=/etc/docker/daemon.json

[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }

if [ -n "${1:-}" ]; then
  sed -i '/k3s\.internal/d' /etc/hosts
  echo "$1 $REGISTRY argocd.k3s.internal hello.k3s.internal" >> /etc/hosts
  echo "Added /etc/hosts entries for $1"
fi

mkdir -p /etc/docker
[ -s "$CONF" ] || echo '{}' > "$CONF"
python3 -I - "$CONF" "$REGISTRY" <<'EOF'
import json, sys
path, registry = sys.argv[1], sys.argv[2]
with open(path) as f:
    conf = json.load(f)
regs = conf.setdefault("insecure-registries", [])
if registry not in regs:
    regs.append(registry)
with open(path, "w") as f:
    json.dump(conf, f, indent=2)
    f.write("\n")
EOF
echo "Added $REGISTRY to $CONF; restarting Docker"
systemctl restart docker
