#!/usr/bin/env bash
# Configure containerd to mirror docker.io through public mirrors, then verify.
set -e
CFG=/etc/containerd/config.toml

if grep -q 'docker.1ms.run' "$CFG"; then
  echo "mirror already configured on $(hostname)"
else
  cp "$CFG" "${CFG}.bak.$(date +%s)"
  cat >> "$CFG" <<'EOF'

# --- docker.io registry mirror (added by fn-helm deployment) ---
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
  endpoint = ["https://docker.1ms.run", "https://dockerproxy.net"]
EOF
  # validate config syntax before restarting
  containerd config dump > /dev/null
  systemctl restart containerd
  echo "mirror configured and containerd restarted on $(hostname)"
fi

sleep 2
systemctl is-active containerd
# verify: pull the postgres image through the mirror via CRI
if crictl pull bitnamilegacy/postgresql:17.6.0-debian-12-r4 > /dev/null 2>&1; then
  echo "crictl pull test: OK"
else
  echo "crictl pull test: FAIL"
fi
