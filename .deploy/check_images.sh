#!/usr/bin/env bash
for img in fnproject/hello fnproject/fn-test-utils; do
  echo "== $img =="
  curl -s --max-time 15 "https://docker.1ms.run/v2/$img/tags/list" 2>/dev/null | head -c 300
  echo
done
