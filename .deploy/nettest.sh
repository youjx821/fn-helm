#!/usr/bin/env bash
docker rm -f fntest > /dev/null 2>&1
docker run -d --name fntest fn-hello:local > /dev/null
sleep 2
IP=$(docker inspect fntest --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "container IP: $IP"
echo "=== iptables FORWARD policy / rules ==="
iptables -L FORWARD -n | head -5
