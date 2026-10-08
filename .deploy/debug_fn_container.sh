#!/usr/bin/env bash
docker rm -f fntest > /dev/null 2>&1
docker run -d --name fntest -p 18080:8080 fn-hello:local
sleep 3
echo "=== curl from node ==="
curl -s --max-time 5 -X POST http://localhost:18080/call -d '{"test":1}'
echo
docker logs fntest 2>&1 | tail -5
docker rm -f fntest > /dev/null 2>&1
