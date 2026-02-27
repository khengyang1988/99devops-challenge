## Requirements Coverage

**1. Highly Available Trading System**
- Multi-AZ ALB, ECS Fargate, Aurora, and Redis. Automatic failover, health checks, and zero-downtime deployments in place.

**2. Similar Features to Binance**
- Spot trading (market and limit orders)
- Order types (market, limit, stop-loss)
- Real-time price feeds and candlestick/chart data
- Wallet and balance management
- Trade history
- User authentication and account management

**3. Resilient to Failures, Scalable, and Cost-Effective**
- Resilience: Multi-AZ across all services, Aurora automatic failover under 30 seconds, Redis cache absorbs external API outages
- Scalable: Fargate auto-scaling handles traffic spikes, scaling path documented from 500 RPS to 50,000+ RPS with no re-architecture needed until 5,000 RPS
- Cost-effective: Static frontend on S3+CloudFront, no over-engineered services (no Kafka, SQS, or API Gateway until needed), estimated $150-300/month at target scale

**4. Architecture Design, Technology Choices, HA and Scalability Explanation**
- Architecture diagram and service breakdown provided
- Each technology choice includes rationale and alternatives considered
- High availability approach documented per service
- Scaling plan covers three growth stages with specific trigger points