---
type: Feature Module
title: AI consumption and attribution
description: "Two small facts per piece of AI work — who initiated it and what the calls cost — linked by one id, with no extra tables."
resource: ../../lib/features/ai_consumption
tags: [ai-consumption, attribution, cost, impact]
status: stable
generated: { by: codex/gpt-5, at: 2026-08-11T01:43:18Z }
stale_after: 2027-02-22
sources:
  - id: src
    resource: ../../lib/features/ai_consumption
    title: AI consumption and attribution source
    last_modified: 2026-08-11
---

This feature records two related facts: **which creator initiated a logical piece
of AI work**, and **which provider calls, usage, reported cost and environmental
impact produced it**.

The implementation deliberately keeps those facts small:

- A completed output embeds **one** `AiWorkAttribution`.
- Every provider call remains **one** `AiConsumptionEvent`.
- Both are linked by `attributionId`.

**There are no extra cost, payload, link or recovery tables.** That constraint is
what keeps the ledger cheap to write on every call and cheap to query for a
per-task or per-model total.

Lifetime projections stay ledger-derived rather than introducing summary rows.
`ConsumptionDatabase.sumConsumptionByTask` and `sumConsumptionByAgent`
aggregate every retained event for the owner id with no rolling-window cutoff,
including calls, tokens, provider-reported credits, energy, carbon, water and
invocation duration. Task Details and Goal Agent Details render the same
`ConsumptionSummaryPill`; goal agents add a separate compute-time pill from the
summed duration. Providers without measured impact fall back to token display,
and no pricing lookup fabricates cost.

# Why the carrier is authoritative

The attribution is embedded in the output it describes — the AI response, the
image, the transcript — rather than only living in a side table. A projection can
therefore be rebuilt from the carriers, and a projection that falls behind is a
performance problem rather than a data-loss one.

`ConsumptionSyncService` replicates events as their own sequence-tracked
[sync message family](sync/message-model.md), so per-device AI spend converges
without a separate reconciliation pass.

See [AI work attribution](ai/attribution.md) for the producing side and
[agent persistence](agents/persistence-and-sync.md) for how a wake groups its
calls into one attribution.
