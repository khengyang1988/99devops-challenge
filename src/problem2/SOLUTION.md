# Problem 2: Building Castle In The Cloud

## Overview

A highly available trading platform with similar features to Binance, hosted on AWS. Rather than rebuilding exchange infrastructure from scratch, the system consumes existing market data APIs (Binance Public API / CoinGecko) and focuses on hosting the application layer reliably and cost-effectively.

The system targets 500 RPS with p99 response time under 100ms.

---

## Features Covered

The following Binance-like features are supported by this architecture:

**Spot Trading** — users can place market and limit orders against live price feeds. Order state (open, filled, cancelled) is stored in Aurora and updated in real-time.

**Order Types** — market orders (execute immediately at current price) and limit orders (execute when price reaches target) are handled by the backend API. Stop-loss orders can be implemented as a background job polling open limit orders against cached prices.

**Real-time Price Feeds and Candlestick Charts** — market data is fetched from the Binance Public API and cached in Redis. WebSocket connections push live price updates to connected clients via Redis pub/sub. Candlestick/OHLCV data is fetched from the external API and served directly.

**Wallet and Balance Management** — user balances are stored in Aurora. On order placement the backend validates and reserves the balance, updating it on fill or cancellation.

**Trade History** — all executed trades are persisted in Aurora and queryable by the user. Older records can be archived to S3 via a nightly job.

**User Authentication** — JWT-based auth with tokens cached in Redis for fast validation on every request.

---

## Architecture

```
Users
  │
  ▼
Route 53 (DNS)
  │
  ▼
CloudFront (CDN — serves frontend, caches API responses where appropriate)
  │
  ├──► S3 (static frontend — React/Next.js build)
  │
  └──► ALB (routes /api/* to backend)
            │
            ▼
       ECS Fargate (backend API — multiple tasks across 2 AZs)
            │
            ├──► ElastiCache Redis
            │    - session/token cache
            │    - market data response cache
            │    - WebSocket pub/sub for real-time price updates
            │
            └──► RDS Aurora PostgreSQL (Multi-AZ)
                 - user accounts
                 - wallet balances
                 - open and filled orders
                 - trade history

External Dependencies:
  Binance Public API / CoinGecko ──► backend fetches and caches in Redis
```

---

## Services and Rationale

**Route 53** — DNS with health checks. Automatically removes unhealthy endpoints. Native AWS integration. Alternative: Cloudflare DNS, but adds a vendor outside the stack.

**CloudFront + S3** — the frontend is a static build (React/Next.js) deployed to S3 and served via CloudFront. Extremely cheap at this scale and globally fast. CloudFront also caches non-personalised API responses like market prices, reducing backend load. Alternative: serve frontend from ECS, but static hosting on S3 is simpler and cheaper.

**ALB** — distributes traffic across Fargate tasks, handles SSL termination, routes `/api/*` to the backend. Multi-AZ by default. Alternative: API Gateway, but adds cost and latency without meaningful benefit at 500 RPS.

**ECS Fargate** — runs the backend API. No servers to manage. Auto-scales based on CPU/memory. Tasks run across 2 AZs so one AZ going down doesn't take the service down. Alternative: EC2 — cheaper at sustained load but requires managing instances, patching, and scaling groups.

**ElastiCache Redis** — three jobs: caching session tokens so auth doesn't hit the DB on every request, caching market data responses from the external API (prices cached for 1-2 seconds to avoid hammering the external API on every user request), and pub/sub for pushing real-time price updates to connected WebSocket clients. Alternative: Memcached — simpler but no pub/sub or persistence.

**RDS Aurora PostgreSQL (Multi-AZ)** — stores user accounts, wallet balances, orders, and trade history. Aurora gives automatic failover under 30 seconds and higher throughput than standard RDS PostgreSQL. Multi-AZ means a standby replica is always ready. Alternative: DynamoDB — better at extreme scale but relational queries (balance calculations, order matching, trade history) are better served by PostgreSQL.

**Binance Public API / CoinGecko** — market data source. No need to build or maintain a matching engine or price feed infrastructure. The backend fetches prices, order book data, and candlestick data from these APIs and caches responses in Redis. Alternative: build your own — unnecessary cost and complexity at this scale.

Note: This introduces an external dependency outside our control and is a known single point of failure. To mitigate this, market data responses are cached in Redis so a short outage does not immediately impact users. In a later stage, this would be replaced by an internal price feed service aggregating from multiple sources for redundancy.

---

## High Availability

- ALB, ECS Fargate, Aurora, and Redis all span multiple AZs
- Aurora automatic failover under 30 seconds
- ECS maintains minimum healthy task count during deployments — zero downtime deploys
- Route 53 health checks pull unhealthy endpoints from DNS automatically
- Redis caching means external API outages don't immediately break the user experience — cached market data continues serving users while the external API recovers
- Wallet balance updates use database transactions to prevent inconsistency during failures

---

## Meeting 500 RPS / p99 < 100ms

- Static frontend served from CloudFront edge — zero backend requests for page loads
- Redis token cache eliminates DB calls for auth on every request
- Redis market data cache means price feed requests resolve in under 1ms
- Aurora handles only writes and uncached reads, keeping it well within throughput limits
- ECS auto-scaling pre-warms at 60% CPU before saturation hits

---

## Cost Profile

- S3 + CloudFront for frontend: near zero
- ECS Fargate: pay per task, scale down outside peak hours
- Aurora: db.t3.medium is sufficient at this scale
- Redis: cache.t3.micro sufficient to start
- No Kafka, no SQS, no API Gateway, no dedicated matching engine

Estimated AWS cost at this scale: **~$150-300/month** depending on traffic patterns.

---

## Scaling Plan

**Current setup handles up to ~5,000 RPS** by simply increasing Fargate task count and Aurora read replicas — no architectural changes needed.

**Beyond 5,000 RPS:**
- Introduce SQS to decouple order placement from processing
- Add Aurora read replicas for portfolio and history queries
- Extract the order service into its own Fargate service with independent scaling

**Beyond 50,000 RPS:**
- Multi-region with Route 53 latency routing
- Replace external market data dependency with a dedicated internal price feed service
- Introduce Kafka for event-driven architecture between services
- Consider a dedicated matching engine on compute-optimised EC2

---

## Alternatives Summary

| Component | Chosen | Alternative | Reason not chosen |
|---|---|---|---|
| Frontend hosting | S3 + CloudFront | ECS / Vercel | Cheapest and simplest for static assets |
| Compute | ECS Fargate | EC2 / EKS | No servers to manage, scales easily |
| Database | Aurora PostgreSQL | DynamoDB | Relational queries needed |
| Cache | ElastiCache Redis | Memcached | Need pub/sub for WebSocket |
| Market data | Binance Public API | Build own | Unnecessary complexity at this scale |
| Load balancer | ALB | API Gateway | Simpler, lower cost at this scale |