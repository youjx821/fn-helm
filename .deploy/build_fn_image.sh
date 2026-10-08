#!/usr/bin/env bash
# Build a proper FDK-based function image (fn hot protocol).
set -e
mkdir -p /tmp/fnhello && cd /tmp/fnhello

cat > func.py <<'EOF'
import fdk
import json


def handler(ctx, data=None, loop=None):
    body = ""
    if data and len(data) > 0:
        body = data.decode("utf-8")
    return {"message": "Hello from Fn on Kubernetes!", "input": body}


if __name__ == "__main__":
    fdk.handle(handler)
EOF

cat > Dockerfile <<'EOF'
FROM docker.io/python:3.11-slim
RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple fdk
WORKDIR /function
COPY func.py func.py
ENTRYPOINT ["python", "func.py"]
EOF

docker build -t fn-hello:fdk .
echo "=== smoke test (as fn runs it) ==="
echo '{"smoke":1}' | docker run --rm -i -u 1000:1000 --cap-drop=all fn-hello:fdk
