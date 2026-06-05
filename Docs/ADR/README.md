# Architecture Decision Records

Use this folder for significant product or architecture decisions that future maintainers should not need to rediscover from chat history.

Do not create an ADR for every implementation detail. Prefer an ADR when a decision:

- Sets a durable product direction.
- Chooses one architecture over another with meaningful tradeoffs.
- Rejects a tempting option that future work may reconsider.
- Depends on Home Assistant API risk, platform constraints, or performance evidence.

## Template

```md
# ADR N: Title

## Status

Accepted | Proposed | Superseded

## Context

What problem or decision pressure led to this?

## Decision

What are we doing?

## Consequences

What tradeoffs, follow-up work, or constraints come from this?
```
