#!/usr/bin/env bash
docker run --rm --entrypoint sh fnproject/fnserver:latest -c 'grep -aoE "/tmp/[a-z0-9]*iofs[a-z0-9/]*|FN_IOFS[A-Z_]*|iofs[a-z]*mount[a-z]*" /app/fnserver 2>/dev/null | sort -u | head -10' 2>/dev/null || \
docker run --rm --entrypoint sh fn.1ms/fnserver:latest -c true
