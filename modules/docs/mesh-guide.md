# Mesh System Guide

The mesh is the multi-LLM routing layer at the core of OpenClaw. It routes requests to the optimal provider based on task type, cost constraints, and provider health.

## How Routing Works

When a request enters the mesh, the router evaluates it against several factors to select the best provider.

### Routing Decision Flow

```
Incoming Request
    |
    v
Task Classification
    |  (what kind of work is this?)
    v
Provider Scoring
    |  (which providers can handle it?)
    v
Cost/Quality Tradeoff
    |  (balance budget vs. quality needs)
    v
Health Check
    |  (is the selected provider healthy?)
    v
Dispatch to Provider
```

### Task Classification

The router categorizes requests into task types:

- **Coding** -- Code generation, completion, refactoring, debugging
- **Analysis** -- Code review, architecture analysis, security audit
- **Creative** -- Writing, brainstorming, content generation
- **Factual** -- Documentation, Q&A, lookups
- **Reasoning** -- Complex multi-step logic, planning, math

Each provider has different strengths across these categories. The router maintains a performance matrix that maps task types to provider capabilities.

### Provider Scoring

For each request, every available provider receives a score based on:

| Factor | Weight | Description |
|--------|--------|-------------|
| Capability match | 40% | How well the provider handles this task type |
| Cost efficiency | 25% | Token cost relative to budget constraints |
| Current latency | 15% | Recent response time measurements |
| Health score | 10% | Uptime and error rate over the last hour |
| Historical success | 10% | Past outcomes for similar requests |

The provider with the highest composite score is selected.

### Fallback Behavior

If the primary provider fails or times out:

1. The request is retried once with the same provider
2. On second failure, the request is routed to the next-highest-scoring provider
3. If all providers fail, the request is queued for retry with a backoff

## Cost Optimization

### Budget Controls

The mesh supports several budget mechanisms:

- **Daily spend limit** -- Hard cap on total daily spend across all providers
- **Per-provider limits** -- Maximum daily spend per individual provider
- **Per-request ceiling** -- Maximum token budget for a single request
- **Cost tier routing** -- Prefer cheaper providers for simple tasks, reserve expensive providers for complex work

### Cost Tier Strategy

```
Simple tasks (completions, formatting, lookups)
    --> Route to cheapest available provider

Medium tasks (code generation, standard analysis)
    --> Route to mid-tier provider with best capability match

Complex tasks (architecture design, deep debugging)
    --> Route to highest-capability provider regardless of cost
```

### Monitoring Spend

The cost tracker maintains running totals accessible via:

```bash
python3 ~/.openclaw/workspace/mesh/cost_tracker.py --report
```

This shows:
- Today's total spend
- Per-provider breakdown
- Remaining budget
- Projected daily total based on current rate

## Adding New LLM Providers

### 1. Create a provider configuration

Add a new entry to the mesh config:

```json
{
  "providers": {
    "new-provider": {
      "endpoint": "https://api.new-provider.com/v1/chat",
      "api_key_env": "NEW_PROVIDER_API_KEY",
      "model": "new-provider-latest",
      "max_tokens": 8192,
      "cost_per_1k_input": 0.003,
      "cost_per_1k_output": 0.015,
      "capabilities": {
        "coding": 0.8,
        "analysis": 0.7,
        "creative": 0.9,
        "factual": 0.8,
        "reasoning": 0.7
      }
    }
  }
}
```

### 2. Set the API key

```bash
export NEW_PROVIDER_API_KEY="your-key-here"
```

### 3. Register the provider

```bash
python3 ~/.openclaw/workspace/mesh/register_provider.py --name new-provider
```

### 4. Run a health check

```bash
python3 ~/.openclaw/workspace/mesh/health_check.py --provider new-provider
```

The learning system will automatically calibrate capability scores as the new provider handles real requests.

## Health Monitoring

### Health Metrics

The health monitor tracks per-provider:

- **Uptime** -- Percentage of successful requests over time windows (1h, 24h, 7d)
- **Latency** -- p50, p90, p99 response times
- **Error rate** -- Percentage of failed requests
- **Throughput** -- Requests per minute capacity
- **Token rate** -- Tokens per second generation speed

### Health States

Each provider is assigned a health state:

| State | Criteria | Routing Impact |
|-------|----------|----------------|
| Healthy | Error rate < 1%, latency nominal | Full routing weight |
| Degraded | Error rate 1-5% or elevated latency | Reduced routing weight |
| Unhealthy | Error rate > 5% or timeout spike | Minimal routing (fallback only) |
| Down | No successful requests in 5 minutes | Excluded from routing |

### Status Dashboard

View current provider health:

```bash
python3 ~/.openclaw/workspace/mesh/health_monitor.py --status
```

The mesh status is also written to `~/.openclaw/workspace/shared/MESH-STATUS.md` on each health check cycle.

## Learning System

The mesh improves its routing decisions over time through a feedback loop.

### How Learning Works

1. **Record** -- Every routed request logs the provider used, task type, latency, token count, and outcome
2. **Evaluate** -- Outcomes are scored (success, partial success, failure, timeout)
3. **Update** -- Provider capability scores are adjusted based on accumulated outcomes
4. **Decay** -- Old data decays over time so the system adapts to changing provider performance

### Capability Score Updates

Scores adjust gradually to avoid overreacting to individual results:

- Successful completion: score += 0.01 (capped at 1.0)
- Partial success: no change
- Failure: score -= 0.02 (floored at 0.1)
- Timeout: score -= 0.03 (floored at 0.1)

### Resetting Learning Data

To reset a provider's learned scores back to the configured baseline:

```bash
python3 ~/.openclaw/workspace/mesh/learning.py --reset --provider provider-name
```

To reset all providers:

```bash
python3 ~/.openclaw/workspace/mesh/learning.py --reset-all
```
