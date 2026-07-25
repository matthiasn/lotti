---
type: Feature Module
title: Wake orchestration
description: How a local change becomes an agent wake — subscription matching, run-key dedupe, workspace partitioning, bounded concurrency — and the three failure modes the design defends against.
resource: ../../../lib/features/agents/wake
tags: [agents, wake, scheduling, concurrency]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T23:30:00Z }
stale_after: 2027-01-31
sources:
  - id: wake
    resource: ../../../lib/features/agents/wake
    title: WakeOrchestrator, WakeQueue, WakeRunner, drain engine
    last_modified: 2026-07-25
  - id: enums
    resource: ../../../lib/features/agents/model/agent_enums.dart
    title: WakeReason
    last_modified: 2026-07-25
  - id: runtime-settings
    resource: ../../../lib/features/ai/model/ai_runtime_settings.dart
    title: Concurrency bounds
    last_modified: 2026-07-25
  - id: adr-0002
    resource: ../../../docs/adr/0002-wake-scheduling-and-throttling-policy.md
    title: ADR 0002 — Wake scheduling and throttling policy
    last_modified: 2026-07-24
  - id: adr-0022
    resource: ../../../docs/adr/0022-long-lived-daily-os-planner.md
    title: ADR 0022 — Long-lived Daily OS planner
    last_modified: 2026-07-24
---

# Why the design is this defensive

`WakeOrchestrator` is shaped around three specific background-agent failure
modes. Reading it as over-engineering misses that each mitigation exists because
the corresponding failure is easy to reach:

1. **Wake storms** after rapid local edits.
2. **Self-trigger loops** after an agent writes to the entities it watches.
3. **Duplicate execution** when an agent is already running.

# The path from change to wake

```mermaid
flowchart TD
  Update["localUpdateStream batch"] --> Match["Match AgentSubscription tokens"]
  Match --> Suppress{"Suppressed by vector-clock tracking?"}
  Suppress -->|yes| Drop["Drop wake"]
  Suppress -->|no| Merge{"Queued job for same agent + workspace?"}
  Merge -->|yes| Coalesce["Merge trigger tokens"]
  Merge -->|no| Queue["WakeQueue.enqueue(runKey)"]
  Queue --> Drain["Single bounded queue scheduler"]
  Drain --> Capacity{"Active wakes below AI setting?"}
  Capacity -->|no| WaitSlot["Wait for a wake to finish or a new drain signal"]
  WaitSlot --> Capacity
  Capacity -->|yes| Busy{"Agent already running?"}
  Busy -->|yes| KeepQueued["Keep same-agent follow-up visible in FIFO queue"]
  KeepQueued --> Capacity
  Busy -->|no| Content{"awaitingContent gate?"}
  Content -->|skip| Wait["Leave agent dormant until content exists"]
  Content -->|run| Persist["Persist wake_run_log row"]
  Persist --> Exec["Dispatch workflow by agent kind in a capacity slot"]
  Exec --> Capacity
```

Note the input: **`localUpdateStream`, not `updateStream`**. A synced change must
not wake an agent on the receiving device for work the originating device
already did. See [persistence](../../architecture/persistence.md).

# Suppression is pre-registered

Suppression state is registered **before** execution starts, then replaced with
the actual mutated-entity vector clocks afterwards.

That ordering closes the race between "the agent already wrote to the database"
and "the suppression tracker recorded the write". Register afterwards and the
agent's own write can slip through as a fresh notification and re-wake it.

# Workspace partitioning

`WakeJob.workspaceKey` partitions merging, superseding and cancellation by
`(agentId, workspaceKey)` — required by ADR 0022, where the Daily OS planner is
**one identity handling many day workspaces** (`day:<dayId>`).

Without it, a day-B capture wake would merge into — or cancel — a day-A draft
wake, because both belong to the same agent id.

The key is asymmetric across run-key factories, deliberately:

| Factory | Includes `workspaceKey`? | Why |
|---------|--------------------------|-----|
| `RunKeyFactory.forSubscription` | **No** | Subscription matches for one agent should still coalesce |
| `RunKeyFactory.forManual` | **Yes** | Two day-scoped manual wakes enqueued in the same tick must get distinct run keys instead of the second being deduped away |

A null workspace (task, project, improver agents) only partitions with other
null workspaces, so their behaviour is unchanged.

# Wake reasons

`WakeReason` has five values: `subscription`, `creation`, `reanalysis`,
`scheduled`, `transcriptionComplete`.

**`transcriptionComplete` bypasses the throttle**, so a user who just finished
speaking does not wait out the 120-second coalescing window. Both transcript
paths — the local `AutomaticPromptTrigger` and the synced
`SyncedAudioInferenceDispatcher` — route through
`WakeOrchestrator.requestContentWake`, which honours the automatic-updates
opt-in: with automation off, the transcript only persists the stale watermark
(surfacing the manual *Update now* CTA) instead of enqueuing inference. The
enqueued wake carries `WakeInitiator.automation`, so toggling automation off
sweeps a still-queued transcript wake from the queue.

**Image analyses deliberately have no analogous reason.** A stored analysis is an
`AiResponseEntry` linked *from the image*, so its creation notifies only the
image and response ids — never the tasks, since notification propagation is one
hop. Instead, `SkillInferenceRunner.runImageAnalysis` emits the standard
child-changed pairs (`taskId` + `PROPAGATED::taskId`) after persisting, for
**every parent task of the image** (an image can be linked from several tasks;
non-task parents are skipped since only task contexts render analyses), unioned
with the resolved `linkedTaskId`. Each parent agent's normal `subscription` wake
picks it up on the 120-second coalesced path, so it merges with the image-add
wake instead of racing it.

# Throttling

Subscription-driven wakes are throttled with a **120-second** window.

A subscription can opt into daily-digest deferral for propagated-only matches.
Project-agent subscriptions use that path, so linked-task churn waits for the
scheduled project digest; task-agent subscriptions opt out, so child-entry and
task-context updates refresh on the normal coalesced path.

Manual wakes — `creation`, `reanalysis`, and scheduled jobs enqueued by
`ScheduledWakeManager` — bypass subscription matching and the throttle.

# The content gate

Task agents auto-provisioned from category defaults can start with
`awaitingContent = true`. The orchestrator skips the wake until the task or one
of its linked entries has meaningful text, then clears the flag and lets the wake
proceed. Event agents use the same shared gate with their own checker.

Without it, auto-provisioning would burn an inference run on a bare title.

# Concurrency

Two independent limits apply:

- **Global**: up to the device-local AI concurrency setting — range **1–8**,
  default **3** (`AiRuntimeSettings`). It lives in AI Settings and the scheduler
  re-reads it whenever capacity frees up, so tuning takes effect without a
  restart. Setting it to 1 restores the former globally sequential behaviour.
- **Per agent**: `WakeRunner` enforces single-flight, so two wakes for the same
  agent never overlap even when global capacity is free.

Only the scheduler mutates `WakeQueue`, suppression state, throttle state and
run-key history. Concurrent work begins only after a job has acquired its
`WakeRunner` agent lock. Workflows and conversation managers are created per
wake; agent sync transaction buffers are zone-local; Drift serialises database
work on its connection.

The bounded limit also keeps provider, API and database pressure finite. A
downstream provider rate-limit or connection failure continues through the
per-wake failure path and does not cancel other active wakes.

# Completion signalling

`runCompletions` is a broadcast `Stream<WakeRunCompletion>` — one event per
finished wake (`completed` / `failed` / `aborted`, carrying the error object for
failures), keyed by the run key `enqueueManualWake` returns.

It is **in-process only, never persisted**. Callers that enqueued a wake and
need its precise outcome without polling — the Daily OS durable
`draftPlan`/`refinePlan` job executor (ADR 0032 phase 1) — subscribe *before*
enqueueing and filter on the returned run key. The durable record of the same
outcome remains the `wake_run_log` row.

# Deferred deadlines are device-local

All three scheduling fields — `nextWakeAt`, `sleepUntil`, `scheduledWakeAt` —
are device-local. Each device schedules its own wakes, so the sync apply path
preserves the local row's scheduling rather than letting a peer's
`AgentStateEntity` overwrite it (`_preserveLocalScheduling`).
