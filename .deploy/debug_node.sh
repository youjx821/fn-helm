#!/usr/bin/env bash
echo "=== containerd version/status ==="
systemctl is-active containerd kubelet
crictl version 2>&1 | head -6
echo "=== kubelet last logs ==="
journalctl -u kubelet --since "-5m" --no-pager | tail -8
echo "=== containerd last logs ==="
journalctl -u containerd --since "-5m" --no-pager | tail -8
