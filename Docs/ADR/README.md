# Architecture Decision Records

Use this folder for significant product or architecture decisions that future maintainers should not need to rediscover from chat history.

Current decisions:

- [ADR 1: Unified Setup, Discovery, And iCloud Bootstrap](001-unified-setup-discovery-and-icloud-bootstrap.md)
- [ADR 2: Capability-Driven Entity Detail Grammar](002-capability-driven-entity-detail-grammar.md)
- [ADR 3: Homestead+ StoreKit Entitlements](003-homestead-plus-storekit-entitlements.md)

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
