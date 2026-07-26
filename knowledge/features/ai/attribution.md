---
type: Feature Module
title: AI work attribution
description: How every inference call becomes an auditable, costed record attached to the output it produced.
resource: ../../../lib/features/ai_consumption
tags: [ai, attribution, consumption, cost, provenance]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T00:00:00Z }
stale_after: 2026-10-19
sources:
  - id: consumption
    resource: ../../../lib/features/ai_consumption
    title: AI consumption feature — audit model and ledger
    last_modified: 2026-07-25
  - id: runner
    resource: ../../../lib/features/ai/services/skill_inference_runner.dart
    title: SkillInferenceRunner attribution sessions
    last_modified: 2026-07-25
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
  Provider-->>Runner: response + usage/reported impact
  Runner->>Attr: recordInteraction(digests + metadata)
  Attr->>Sync: persist, then enqueue best effort
  Runner->>Attr: prepareCompletion(output reference)
  Runner->>Journal: persist carrier with attribution
  Runner->>Attr: finalize local projection
```

`SkillInferenceRunner` begins an in-memory attribution session **before**
transcription, image analysis, prompt generation or image generation. Each
provider call records usage, digests, and provider-reported cost/impact. The
completed output embeds the authoritative attribution, and only then is the local
query projection updated.

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
