#!/usr/bin/env bash
# Tag imported images with the exact ref kubelet requests, and (re)import flow:ui.
set -e
ctr -n k8s.io images tag docker.io/bitnamilegacy/redis:latest registry-1.docker.io/bitnamilegacy/redis:latest || true

if ! ctr -n k8s.io images ls -q | grep -q 'fnproject/flow:ui'; then
  echo "== re-pulling flow:ui via docker =="
  timeout 600 docker pull docker.io/fnproject/flow:ui > /dev/null 2>&1
  docker save docker.io/fnproject/flow:ui | ctr -n k8s.io images import - > /dev/null 2>&1
  echo "flow:ui imported"
else
  echo "flow:ui already in containerd"
fi
ctr -n k8s.io images ls -q | grep -E 'redis:latest|flow:ui'
