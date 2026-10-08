#!/usr/bin/env bash
kubectl delete pod -n fn fn-fn-runner-8574759775-2fg6h fn-fn-runner-8574759775-v26jq fn-fn-ui-56fbbcfb66-fq77v fn-fn-ui-55b57797d4-plcnz --force --grace-period=0 2>&1 | tail -1
echo "=== redis pull progress on node72 ==="
journalctl -u containerd --since "-10m" --no-pager | grep -i "redis" | tail -5
