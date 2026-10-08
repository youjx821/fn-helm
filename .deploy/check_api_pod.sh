#!/usr/bin/env bash
kubectl get pod -n fn fn-fn-6db4dc5479-lwnhp -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state}{"\n"}{end}'
echo '--- runner-lb logs ---'
kubectl logs -n fn fn-fn-6db4dc5479-lwnhp -c runner-lb --tail=15 2>&1
echo '--- api logs ---'
kubectl logs -n fn fn-fn-6db4dc5479-lwnhp -c api --tail=10 2>&1
