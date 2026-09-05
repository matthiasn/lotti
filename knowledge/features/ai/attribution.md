---
type: Feature Module
title: AI work attribution
description: How every inference call becomes an auditable, costed record attached to the output it produced.
resource: ../../../lib/features/ai_consumption
tags: [ai, attribution, consumption, cost, provenance]
status: stable
generated: { by: codex/gpt-6, at: 2026-09-05T16:00:00Z }
stale_after: 2026-10-19
sources:
  - id: consumption
    resource: ../../../lib/features/ai_consumption
    title: AI consumption feature — audit model and ledger
    last_modified: 2026-07-26
  - id: runner
    resource: ../../../lib/features/ai/services/skill_inference_runner.dart
    title: SkillInferenceRunner attribution sessions
    last_modified: 2026-09-05
---

# The boundary

The `ai` feature **creates output carriers**; `features/ai_consumption` owns
their **audit model and interaction ledger**. Neither reaches into the other's
job.

```mermaid
sequenceDiagram
  participant Runner as SkillInferenceRunner
  participant Attr as AiAttributionService
  participant Provider as Cloud/native provider
  participant Sync as ConsumptionSyncService
  participant Journal as Journal/PersistenceLogic
  Runner->>Attr: begin(work type, actor, trigger, intended output)
  Runner->>Provider: inference request
  alt complete response
    Provider-->>Runner: response + usage/reported impact
    Runner->>Attr: recordInteraction(digests + metadata)
    Attr->>Sync: persist, then enqueue best effort
    Runner->>Attr: prepareCompletion(output reference)
    Runner->>Journal: persist carrier with attribution
    Runner->>Attr: finalize local projection
  else transcription fails after completed segments
    Provider-->>Runner: error + incurred usage and impact
    Runner->>Attr: recordInteraction(completed segments only)
    Attr->>Sync: persist, then enqueue best effort
    Runner->>Attr: prepareCompletion(failed)
    Runner->>Attr: finalize failed local projection
  end
```

`SkillInferenceRunner` begins an in-memory attribution session **before**
transcription, image analysis, prompt generation or image generation. Each
logical call records usage, digests, and provider-reported cost/impact. The
completed output embeds the authoritative attribution, and only then is the local
query projection updated.

Segmented transcription aggregates its physical calls. If a later segment fails,
`TranscriptionException` carries the completed segments' usage and impact; the
runner records those incurred quantities once and finalizes a failed local
attribution. No partial transcript carrier is written. Its output reference is
an intended artifact, not evidence that an artifact exists. A canceled subscriber
cannot receive this exception; cancellation accounting needs a separate caller
lifecycle hook and is not captured by this failure path.

# Carrier mapping is uniform

| Output | Carrier field |
|--------|---------------|
| Generated text, authoritative image-analysis results | `AiResponseData.aiAttribution` |
| Generated images | `ImageData.aiAttribution` |
| Transcripts | `AudioTranscript.id` / `aiAttribution` |

`UnifiedAiInferenceRepository` begins before provider invocation, **reuses one
owner and output id across automatic language reruns**, and finalizes the local
projection after the carrier write.

Attributed image analysis is stored as the authoritative `AiResponseEntry`
instead of also duplicating the response into journal entry text.

# Rules that keep the ledger honest

- **No invented cost.** Embedding indexing records one interaction per chunk with
  digests only and no monetary figure, because none is reported.
- **The carrier is authoritative.** For agent reports the local attribution
  projection is updated *after* the report write, never before.
- **Carrier-less operations terminalize as partial.** Log-compaction inference is
  captured before each backend call and marked partial, because its checkpoint
  format has no attribution record.
- **Historical outputs are never backfilled with guesses.** Reports predating
  attribution get no invented creator or cost data.

For the agent-side view of the same mechanism — the deterministic wake run key
that groups initial calls, tool continuations and forced-report retries into one
attribution — see
[agent persistence and sync](../agents/persistence-and-sync.md).
