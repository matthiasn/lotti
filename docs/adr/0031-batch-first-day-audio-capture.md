# ADR 0031: Batch-First Day Audio Capture and Durable Processing

## Status

Accepted

## Date

2026-07-21

## Context

A Daily OS recording made on a degraded network could be lost entirely: the
capture controller finalized the audio file, ran transcription, and only
created the `JournalAudio` after transcription succeeded. A provider or
network failure left a stopped file with no journal row, no retry path, and
no way for a later planner invocation to rediscover what the user said.
Network-dependent inference sat on the source-data critical path.

Two mechanisms were evaluated and rejected on the way here:

- **Streaming/realtime transcription** (Mistral WebSocket, MLX realtime
  sessions) constrained provider choice to streaming ASR endpoints, accepted
  no dictionary/glossary context, produced reliably worse text for exactly
  the words that matter (proper nouns, domain terms), and its live
  transcript added distraction without value. Its deltas were also
  unreproducible: no stored input meant no re-transcription. Removed
  app-wide.
- **A crash-durable PCM spool with WAV finalization** (built in the closed,
  unmerged PR #3525). Its remaining justification after realtime removal was
  mid-recording crash durability, which is explicitly a non-goal: the
  observed failure mode is network failure after stop, not process death.
  AAC (`.m4a`) is the primary audio format — WAV is ~4x heavier for storage
  and Matrix attachment sync. The spool, PCM chunking, WAV pipeline, and
  spool-recovery surfaces were not ported.

## Decision

### 1. Local-first commit order defines a successful stop

The platform recorder writes a plain `.m4a`. Stop then, in order:

1. persists the `JournalAudio` with a `DayAudioContext` provenance payload;
2. enqueues and claims a durable transcription job in the device-local
   processing outbox; and
3. runs foreground batch transcription through that job's state machine.

A transcription, network, or provider failure after step 1 never loses the
recording: the journal entry stays, the job stays, and the background
runtime owns retries. The UI reports "saved, transcription pending" — never
a successful empty capture. Failure of step 1 itself surfaces as
`audioPersistFailed` and leaves the finished file on disk untouched.

The guarantee is **no recording lost after stop** — not "no audio lost
ever". Mid-recording process death is out of scope by design.

### 2. Session context is fixed before the microphone opens

Each voice session pre-computes: a recording-session id, a deterministic
UUIDv5 `activityEntryId` derived from it, the selected planning day's
`dayId`/`planDate` (the selected workspace, never the wall clock at stop),
the intent (`dayPlan` | `dayRefine`), and the origin host id. This
`DayAudioContext` is stamped onto the `JournalAudio` and denormalized into
indexed journal columns (`day_id`, unique `recording_session_id`), giving
Activity, outbox repair, and agent context bounded indexed lookups.

### 3. Pending transcription lives in a device-local outbox

A checksummed, file-backed job store (deterministic job id per recording
session) with lease/claim semantics, exponential jittered backoff, hard
`retryNotBefore` boundaries, and failure classification
(network/timeout/setup-required/deterministic/…). The runtime drains on
startup, on connectivity restoration, on every repository mutation, and via
periodic probes. Startup repair rebuilds lost jobs from persisted
`dayContext` provenance (skipping other hosts' recordings). Provider output
is persisted before the journal write-back so a local commit failure retries
without repeating inference. User-reviewed text fences the job to succeeded
so pending work never overwrites a human decision.

### 4. Day Activity is a local-first projection

The Day header exposes agenda | schedule | activity. Activity joins day
audio, outbox jobs, check-ins, the drafted plan, and day summaries on
activity ids; cards expose playback, retry, manual reviewed text, AI setup,
and use-to-plan/refine. A no-plan day with entries opens Activity so pending
recordings are the recovery path.

### 5. Recordings are agent-visible without user submission

`DayAudioEntryContextService` reads persisted transcript receipts straight
from journal provenance — deliberately independent of `CaptureEntity` — and
feeds the planner's `day_entries` prompt section, so a later wake discovers
completed offline check-ins immediately.

### 6. Batch transcription is the glossary integration point

`AudioTranscriptionService.transcribe` accepts speech-dictionary terms.
Correction-lexicon/glossary context (ADR 0024) attaches here; retained audio
plus replayable jobs make future re-transcription with a grown glossary
possible. (Follow-up work; not part of this change.)

## Consequences

### Positive

- Recordings survive offline/failed inference end-to-end; retries are
  durable and background.
- One transcription path; any batch-capable provider works; dictionary
  context applies uniformly.
- Deterministic ids make recovery idempotent joins, not heuristics.
- ~5k lines of streaming/spool machinery never enter the codebase.

### Negative and trade-offs

- No live transcript while speaking (measured as low-value; misspelled live
  text was worse than a few seconds' wait).
- A force-quit mid-recording loses that in-flight recording (accepted
  non-goal).
- An `.m4a` whose journal insert failed is on disk but invisible until the
  user re-records; there is no orphan-scan surface (accepted for now).

## Rejected alternatives

- **PCM spool + WAV finalization + crash recovery** — see Context; closed
  PR #3525 remains the reference implementation in git history.
- **Keeping realtime alongside batch** — double transcription stack for a
  preview feature; see Context.
- **Matrix sync outbox as the job queue** — the sync outbox transports
  already-durable entities; it does not represent pending inference.
- **In-memory wake/processing intent** — an app exit must not lose the
  user's request to have a recording transcribed.

## Related

- ADR 0024 (correction lexicon — the glossary integration point)
- ADR 0032 (hierarchical day agents — consumes this substrate; its phase 1
  extends the outbox to plan/parse jobs)
- Closed PR #3525 (spool-based predecessor, unmerged reference)
