#!/usr/bin/env bash
# Configure containerd docker.io mirror via certs.d hosts.toml on node72.
set -e
if grep -q 'config_path' /etc/containerd/config.toml; then
  echo "config_path present"
else
  echo "WARNING: no config_path in config.toml"
fi

mkdir -p /etc/containerd/certs.d/docker.io
cat > /etc/containerd/certs.d/docker.io/hosts.toml <<'EOF'
server = "https://registry-1.docker.io"

[host."https://docker.1ms.run"]
  capabilities = ["pull", "resolve"]

[host."https://dockerproxy.net"]
  capabilities = ["pull", "resolve"]
EOF
echo "hosts.toml written"

systemctl restart containerd
sleep 2
systemctl is-active containerd
crictl pull bitnamilegacy/postgresql:17.6.0-debian-12-r4 > /dev/null 2>&1 && echo "crictl pull: OK" || echo "crictl pull: FAIL"
