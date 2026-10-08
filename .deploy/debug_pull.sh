#!/usr/bin/env bash
crictl pull bitnamilegacy/postgresql:17.6.0-debian-12-r4 2>&1 | tail -3
echo "--- mirror config ---"
containerd config dump | grep -A3 'mirrors."docker.io"'
echo "--- nodes ---"
kubectl get nodes
