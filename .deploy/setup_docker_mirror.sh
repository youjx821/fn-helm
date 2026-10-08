#!/usr/bin/env bash
# Fn runners execute function containers through the HOST docker daemon,
# so the daemon itself needs mirrors for docker.io.
set -e
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": ["https://docker.1ms.run", "https://dockerproxy.net"]
}
EOF
systemctl restart docker
sleep 2
systemctl is-active docker
docker info 2>/dev/null | grep -A3 "Registry Mirrors"
