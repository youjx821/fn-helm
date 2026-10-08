#!/usr/bin/env bash
docker pull fnproject/fnserver:latest > /dev/null 2>&1
echo "=== cmd/entrypoint ==="
docker inspect fnproject/fnserver:latest | python3 -c "import sys,json; c=json.load(sys.stdin)[0]['Config']; print('Entrypoint:', c['Entrypoint']); print('Cmd:', c['Cmd'])"
echo "=== root files ==="
docker run --rm --entrypoint ls fnproject/fnserver:latest /app / 2>/dev/null | head -20
