#!/usr/bin/env bash
# Replace the inline mirrors block with the certs.d hosts.toml mechanism.
set -e
CFG=/etc/containerd/config.toml

# 1. remove the appended inline-mirror block (from marker line to EOF)
if grep -q 'docker.io registry mirror (added by fn-helm deployment)' "$CFG"; then
  sed -i '/docker.io registry mirror (added by fn-helm deployment)/,$d' "$CFG"
  # trim trailing blank lines left behind
  sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$CFG"
  echo "inline mirror block removed"
else
  echo "no inline block present"
fi

# 2. write hosts.toml for docker.io (requires existing config_path in config.toml)
mkdir -p /etc/containerd/certs.d/docker.io
cat > /etc/containerd/certs.d/docker.io/hosts.toml <<'EOF'
server = "https://registry-1.docker.io"

[host."https://docker.1ms.run"]
  capabilities = ["pull", "resolve"]

[host."https://dockerproxy.net"]
  capabilities = ["pull", "resolve"]
EOF
echo "hosts.toml written"

# 3. restart and verify
systemctl restart containerd
sleep 2
systemctl is-active containerd
journalctl -u containerd --since "-1m" --no-pager | grep -i "failed to load plugin" && echo "CRI PLUGIN STILL BROKEN" || echo "cri plugin ok"
crictl pull bitnamilegacy/postgresql:17.6.0-debian-12-r4 > /dev/null 2>&1 && echo "crictl pull: OK" || echo "crictl pull: FAIL"
kubectl get nodes
