---
type: Feature Module
title: AI consumption and attribution
description: "Two small facts per piece of AI work — who initiated it and what the calls cost — linked by one id, with no extra tables."
resource: ../../lib/features/ai_consumption
tags: [ai-consumption, attribution, cost, impact]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-28T22:00:00Z }
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
`ConsumptionSummaryPill`. Goal-agent invocation duration remains available in
the ledger and attribution detail, but is not repeated as a second user-facing
lifetime pill. Providers without measured impact fall back to token display,
and no pricing lookup fabricates cost.

**A Melious speech-to-text transcription records no cost.** Chat, vision
and image calls carry `billing_cost` and `environment_impact` in their
non-streaming response, which `MeliousCallImpact.fromResponseJson` parses.
`/audio/transcriptions` carries neither, nor `usage`, for any Whisper model
(probed 2026-10-10 with
[`melious_transcription_probe.py`](../../tool/melious_transcription_probe.py)).
The transcription's event is still written with its duration, so it counts as
a call, but its credits stay null. The post-processing that follows is a chat
call, so its cost is reported, lands on the same task, and shows on the
summary's own caption. Only the transcription itself is missing from a task's
total.

**The caption says who did the work, quietly, and what it cost only when
known.** On an entry, `AiAttributionSummary` (with `asCaption`) and
`AiAttributionSummaryGroup` render one line of small, low-emphasis caption
text — no pill, no icon — under every attributed output: a Whisper transcript
or a local model that bills nothing did the work all the same, and the caption
is how a reader finds out who, without it competing with the output itself.
The line leads with the model (or, for a group, the kind of work) and appends
cost and impact only when the provider reported them, so an unbilled output
does not carry "Cost unknown"; the full attribution row and the details sheet
still say so. Tapping it opens the details sheet. An AI response made before
attribution existed — the analysis or summary card and the generated-prompt
card alike — passes the model it recorded as `unrecordedModel`, and its caption
reads "<model> · Provenance not recorded" rather than vanishing; it opens
nothing, because there is no record to open.
The group renders nothing only without attributions, taking its `topSpacing`
along, so an audio card keeps an even rhythm without it.

# Why the carrier is authoritative

The attribution is embedded in the output it describes — the AI response, the
image, the transcript — rather than only living in a side table. A projection can
therefore be rebuilt from the carriers, and a projection that falls behind is a
performance problem rather than a data-loss one.

`ConsumptionSyncService` replicates events as their own sequence-tracked
[sync message family](sync/message-model.md), so per-device AI spend converges
without a separate reconciliation pass.

The attribution projection indexes both exact output references and the latest
attempt for an output artifact. The latter follows `(output type, output id,
completed at DESC, id DESC)`, matching the durable transcription-failure lookup
without a temporary sort.

See [AI work attribution](ai/attribution.md) for the producing side and
[agent persistence](agents/persistence-and-sync.md) for how a wake groups its
calls into one attribution.


`AiInteractionCapture.captureStream` directly owns the provider subscription so
cancellation can reach a provider that has not emitted yet. It closes its
intermediate stream to release the accounting generator, then lets that
generator finalize one cancelled interaction. Cancellation while attribution
is resolving prevents provider invocation. Normal completion and failure retain
their existing usage, digest and status accounting; no raw request or response
is persisted. Query cancellation can therefore abort the buffered Melious HTTP
request even when the accounting wrapper is installed.

Non-conversational text calls (one prompt in, one block of text out) go
through
[`OneShotTextGeneration.generateText`](../../lib/features/ai/repository/one_shot_text_generation.dart)
rather than wiring `captureStream` themselves. Its callers are:
- the agent log summarizer
- the goal check-in digest and compaction
- onboarding task structuring
- system-health findings
- the Daily OS tomorrow note

Each caller supplies only a `OneShotGenerationAttribution`: work type, trigger,
automation, captured context and, when it has them, category and task. The
helper supplies the usage mapping, the impact collector and the trimmed result.
It passes no impact collector when no capture is registered, because a collector
switches a Melious call to non-streaming.
