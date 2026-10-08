#!/usr/bin/env bash
# Bitnami charts hardcode registry-1.docker.io as image registry domain;
# containerd matches mirrors by domain, so it needs its own hosts.toml entry.
set -e
mkdir -p /etc/containerd/certs.d/registry-1.docker.io
cat > /etc/containerd/certs.d/registry-1.docker.io/hosts.toml <<'EOF'
server = "https://registry-1.docker.io"

[host."https://docker.1ms.run"]
  capabilities = ["pull", "resolve"]

[host."https://dockerproxy.net"]
  capabilities = ["pull", "resolve"]
EOF
echo "hosts.toml for registry-1.docker.io written on $(hostname)"
# hosts.toml changes are picked up by containerd without restart,
# but the currently-stuck pull must be cancelled so kubelet retries.
crictl rmp $(crictl pods -q --state Ready --label io.kubernetes.pod.name=fn-redis-master-0 2>/dev/null) 2>/dev/null || true
