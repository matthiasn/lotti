---
type: Feature Module
title: User activity gate
description: "A tiny coordination feature with outsized effect: the idle gate background work waits on."
resource: ../../../lib/features/user_activity
tags: [user-activity, idle, gating, background-work]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:00:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: ../../../lib/features/user_activity
    title: User activity gate source
    last_modified: 2026-07-25
---

The user-activity feature tracks whether the user was active recently and exposes
a **gate** background work waits on before doing potentially disruptive
processing.

It is what lets other parts of the app ask two questions: *is the user actively
doing things right now*, and *wait until they have been idle for a bit*.

# Who waits on it

Every consumer today is in [sync](../sync/):

| Consumer | Behaviour |
|----------|-----------|
| [Outbox send passes](../sync/send-path.md) | Wait for idle before draining, so a send burst does not compete with typing |
| [The inbound queue worker](../sync/receive-path.md) | Calls `activityGate.waitUntilIdle` at the top of every tick |
| `MatrixService`, `QueuePipelineCoordinator` | Hold the gate for their own scheduling |

**Daily OS processing does *not* use this gate.** `DayProcessingRuntime` drains
on startup, outbox changes, retries and connectivity events without waiting for
idle, so day transcription and agent wakes can compete with active interaction.
That is a real difference from sync, not an omission in this document — wiring
the gate in would be a behaviour change, not a docs fix.

The idle threshold is a single tuning constant
(`SyncTuning.outboxIdleThreshold`), wired at registration time in
[bootstrap](../../architecture/bootstrap-and-di.md).

# Why a gate rather than a check

A boolean "is idle" read would race: work would sample it, find idle, and start
just as the user resumed. **The gate is awaited**, so a caller parks until the
condition holds and resumes as one continuation — which is why heavy sync work
does not stutter the UI even under a large catch-up.
