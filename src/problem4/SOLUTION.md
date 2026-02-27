SOLUTION:

default.conf — fixed port from 3001 to 3000

docker-compose.yml — added healthchecks to all services, changed depends_on to wait on health conditions, added restart: unless-stopped to all services

index.js — moved db.release() into a finally block so it always runs even on error

init.sql — removed the max_connections = 20 line which was dangerously low and ineffective without a restart

RUN:

docker compose up --build

jellyfish@luffy:~/khengyang/99devops-challenge/src/problem4$ curl http://localhost:8080
Welcome to the platform

jellyfish@luffy:~/khengyang/99devops-challenge/src/problem4$ curl http://localhost:8080/api/users
{"ok":true,"time":{"now":"2026-02-27T08:56:52.683Z"}}


jellyfish@luffy:~/khengyang/99devops-challenge/src/problem4$ curl http://localhost:8080/status
{"status":"ok"}