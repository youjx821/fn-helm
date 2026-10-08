#!/usr/bin/env bash
# Pull the stalling images via the host docker daemon (mirrors work there),
# then import them into containerd so kubelet can use them (IfNotPresent).
set -e
for img in docker.io/bitnamilegacy/redis:latest docker.io/fnproject/flow:ui; do
  echo "== pulling $img via docker =="
  timeout 600 docker pull "$img"
  echo "== importing into containerd =="
  docker save "$img" | ctr -n k8s.io images import -
done
echo "== containerd images now =="
ctr -n k8s.io images ls | grep -E 'redis|flow' | head -6
