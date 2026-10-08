#!/usr/bin/env bash
echo "=== flow logs ==="
kubectl logs -n fn fn-fn-flow-depl-6c98b86567-rhnrm --tail=12 2>&1
echo "=== fn-fn pending reason ==="
kubectl describe pod -n fn fn-fn-5cdcd4dcc8-4ddbq 2>&1 | grep -A5 Events | tail -6
echo "=== node allocatable/requests ==="
kubectl describe node node72 2>&1 | grep -A9 "Allocated resources"
