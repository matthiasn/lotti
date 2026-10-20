---
type: Feature Module
title: Inference backfill suggestions
description: How a task's images and recordings that never got their analysis, transcript or summary are found mechanically and offered as one suggestion each.
resource: ../../../lib/features/ai/backfill
tags: [ai, backfill, image-analysis, transcription, audio-summary, suggestions, agents]
status: draft
generated: { by: claude-code/opus-5.5, at: 2026-10-20T12:00:00Z }
stale_after: 2026-12-26
sources:
  - id: rule
    resource: ../../../lib/features/ai/backfill/inference_backfill.dart
    title: The missing-inference rule
    last_modified: 2026-10-07
  - id: detector
    resource: ../../../lib/features/ai/backfill/inference_backfill_detector.dart
    title: InferenceBackfillDetector
    last_modified: 2026-10-06
  - id: queue
    resource: ../../../lib/features/ai/backfill/inference_backfill_queue.dart
    title: InferenceBackfillQueue
    last_modified: 2026-10-06
  - id: providers
    resource: ../../../lib/features/ai/backfill/inference_backfill_providers.dart
    title: Scan, dismissals and the suggestion list
    last_modified: 2026-10-07
  - id: suggestion-list
    resource: ../../../lib/features/agents/state/unified_suggestion_providers.dart
    title: unifiedSuggestionListProvider
    last_modified: 2026-10-06
  - id: card
    resource: ../../../lib/features/agents/ui/ai_summary_card.dart
    title: AiSummaryCard Confirm all
    last_modified: 2026-10-19
  - id: backfill-actions
    resource: ../../../lib/features/agents/ui/ai_summary_card/backfill_actions.dart
    title: confirmBackfillSuggestion and dismissBackfillSuggestion
    last_modified: 2026-10-06
  - id: gate
    resource: ../../../lib/features/ai/services/profile_automation_service.dart
    title: hasAutomatedSkillType, the try* resolvers and the transcription fallback
    last_modified: 2026-10-08
  - id: runner
    resource: ../../../lib/features/ai/services/skill_inference_runner.dart
    title: EntryRuns, and the runs a backfill dispatches to
    last_modified: 2026-10-08
---

# What it is for

An image whose analysis never ran, or a recording with no transcript or no
summary, is a hole in what the task's agent can read — and on the collapsed
audio card, a missing summary leaves a one-line transcript fragment where the
summary belongs. Inference can be missing because a run failed, because the
category's automatic inference was switched on after the entry was captured,
or because the capability did not exist yet.

Backfill finds those entries and offers **one suggestion per entry** in the
task's *Proposed changes* list. Accepting one runs that entry's inference and
nothing else; *Confirm all* runs every one of them.

**It is mechanical.** Nothing here is an agent tool: no model decides what is
missing, the agent's tool list and wake context are unchanged, and no
suggestion is written to a change set. The rows are derived from stored data
every time the list is built.

# What counts as missing

`missingInferenceFor` decides, per entry, from the entry and the AI responses
linked *from* it. At most one kind per entry:

| Entry | Missing | Not missing |
|-------|---------|-------------|
| Image | no `imageAnalysis` response | an analysis response, **or** the image has text of its own |
| Audio | no transcript **and** no text → *transcription* | the user typed text but there is no transcript: a transcription run would overwrite it |
| Audio with content | no `audioSummary` response and the content passes `hasSummarizableContent` → *summary* | content under the summary run's 200-character floor |

Three of these rules exist to avoid offering something that cannot finish or
would do harm:

- **An image with its own text counts as analysed.** The legacy analysis path
  appended its result to the image's text instead of linking a response;
  analysing those again would pay twice for the same picture.
- **A recording without a transcript is offered transcription, never a
  summary.** An automated transcription runs the profile's summary straight
  after it ([audio summaries](execution-paths.md#audio-summaries)), so a separate
  summary suggestion would either race the transcript or summarise twice.
- **The summary floor is the run's own.** `hasSummarizableContent` reads the
  same content `runAudioSummary` reads (an edit before the transcript) against
  the same minimum. A suggestion the run would skip would never go away.

Deleted entries and deleted responses count for nothing.

# The consent gate

A kind is offered only when automation would run it for the task:
`ProfileAutomationService.hasAutomatedSkillType` for that skill type. That
check opens with the [category consent gate](execution-paths.md#the-category-consent-gate)
— the category's automatic inference switch — and then needs a profile the task
resolves to that automates the skill with its model slot set. Transcription has
one more way through, the same one automatic transcription has: with no such
profile, a configured speech-to-text model whose provider is usable passes on
its own. Backfill offers what the automatic triggers would have done, not more. A category with the
switch off gets no suggestions at all.

The gate is asked once per kind present, not once per entry.

# Detection and refresh

```mermaid
flowchart LR
  Scan["InferenceBackfillDetector.scan(taskId)"] --> Links["getLinkedEntities(task)<br/>images + audio"]
  Links --> Bulk["getBulkLinkedEntities(media ids)<br/>AI responses"]
  Bulk --> Rule["findMissingInference"]
  Rule --> Gate["hasAutomatedSkillType<br/>per kind"]
  Gate --> ScanProvider["inferenceBackfillScanProvider"]
  Config["watchConfigsByType<br/>profile, skill, model, provider"] --> ScanProvider
  ScanProvider --> List["inferenceBackfillSuggestionsProvider"]
  Queue["InferenceBackfillQueue state"] --> List
  Status["inferenceStatusControllerProvider<br/>per entry and type"] --> List
  Dismissed["InferenceBackfillDismissals"] --> List
  List --> Unified["unifiedSuggestionListProvider"]
  Unified --> Card["AiSummaryCard"]
```

`inferenceBackfillScanProvider` rescans when an update notification names the
task, one of its media entries, or `categoriesNotification` (the switch lives on
the category), and when the AI configuration the gate reads changes — profiles,
skills, models and providers arrive through `AiConfigRepository.watchConfigsByType`,
not through journal notifications. Each of those streams replays its snapshot on
subscribe; that first event is skipped, since the initial scan already read it.

Scans overlap, because every notification starts one. Each takes a generation
number and only the latest may publish: a slow scan that read the database
before an analysis landed would otherwise overwrite a faster, later one and
resurrect the suggestion. A background rescan that fails keeps the last list.

`inferenceBackfillSuggestionsProvider` then drops, on every rebuild:

- **entries whose inference is running** — from any trigger: an automatic run,
  the AI popup, another backfill. It watches each candidate's
  `inferenceStatusController`, so a row disappears the moment a run starts and
  returns if that run fails. An audio entry counts as busy while *either*
  transcription or summary runs;
- **entries still settling** — created less than `inferenceBackfillGrace`
  (ten minutes) ago, by `meta.createdAt` on whichever device created them,
  unless a run of theirs failed on this device. A fresh recording is still
  being transcribed, corrected and summarized, here or on the device that
  recorded it, and that work is invisible to this device's status; offering
  it would offer work already under way. The provider arms a timer for the
  earliest window still open and re-evaluates when it closes;
- entries already queued;
- entries dismissed on this device.

It returns nothing until both the scan and the dismissals have loaded, so a
dismissed row never flashes in first.

**A transcript without text** is a recording whose
[composite step](../speech/dictionary.md#correcting-a-speech-to-text-transcript) never finished: the summary run is
what writes its text. It misses its summary at any length unless a summary
already exists, in which case the empty text is the user's.

`unifiedSuggestionListProvider` appends the rows after the agent's own
proposals. A task without an agent shows neither.

# The suggestion lifecycle

```mermaid
stateDiagram-v2
  [*] --> Settling: scan finds it, gate allows, entry is fresh
  [*] --> Offered: scan finds it, gate allows, entry has settled
  Settling --> Offered: its window closes, or its run failed here
  Settling --> [*]: its own inference lands
  Offered --> Hidden: its inference starts running
  Hidden --> Offered: run ends, still missing
  Hidden --> [*]: run lands
  Offered --> Dismissed: reject
  Offered --> Queued: accept or Confirm all
  Offered --> [*]: rescan finds it landed, or the gate now declines
  Queued --> Skipped: running, landed, or gate declines
  Queued --> Dispatched: re-check passes
  Skipped --> Offered: still missing and not running
  Skipped --> [*]: no longer missing
  Dispatched --> [*]: inference lands
  Dispatched --> Offered: run fails
  Dismissed --> [*]
```

# Acceptance and the queue

A backfill row is a `PendingSuggestion` built by `PendingSuggestion.backfill`:
a `ChangeItem` with the kind's tool name (`backfill_image_analysis`,
`backfill_transcription`, `backfill_audio_summary`) and the entry's id and
capture time, wrapped in a stand-in change set that is **never persisted,
synced or shown to the agent**. It exists so the row renders, animates and
counts like every other proposal. `PendingSuggestion.backfill` carries the
candidate, and that is what routes the row:

- **Confirm** → `confirmBackfillSuggestion` → `InferenceBackfillQueue.enqueue`.
  Never `ChangeSetConfirmationService`.
- **Reject** → `dismissBackfillSuggestion` → `InferenceBackfillDismissals`, a
  device-local list in `SettingsDb`. A dismissal is a reading preference, not a
  change to the entry, so it rides on no synced entity.
- **Confirm all** → every backfill row is enqueued; the persisted change sets
  beside them go to `confirmAll` as before. The button appears once the list
  holds more than one row.

`InferenceBackfillQueue` runs jobs **one at a time, in acceptance order** — fifteen
photos must not become fifteen concurrent vision calls — and its state is the
set of queued or running keys, which is what hides a row the instant it is
accepted and makes a second accept of the same row a no-op.

**Every decision is taken when the job runs, not when it was accepted:**

1. If the entry's inference is running, skip it — the run in flight will land it.
2. If `InferenceBackfillDetector.isStillMissing` says it landed meanwhile —
   another device's result synced, an automatic run finished — skip it.
3. Resolve the profile **now** with `tryAnalyzeImage`, `tryTranscribe` or
   `trySummarizeAudio`; a transcription no profile automates falls back to a
   configured speech-to-text model, as automatic transcription does. A profile
   switched while the job waited is the one that runs; a category whose switch
   was turned off runs nothing.
4. Dispatch to `SkillInferenceRunner.runImageAnalysis`, `runTranscription` or
   `runAudioSummary` with the task as `linkedTaskId` — the same task context the
   automatic triggers pass.

A failing job is logged and the next one runs. The run reports through the
entry's own inference status like any other run, and a failed one returns to the
list as soon as the queue lets go of it: the stored data still lacks it.

# Gotchas

- **The running check is check-then-act; the runner closes the gap for
  transcriptions and image analyses.** The queue reads the entry's status, then
  awaits the database and the profile walk before it dispatches, so another
  trigger can start inside that window. For a transcription or an image
  analysis that is harmless on one device: the runner keeps one run per entry
  (`EntryRuns` — `transcriptionRunsProvider` and `imageAnalysisRunsProvider`),
  registered before its first await, and a second request joins the run in
  flight (`SingleFlight` in
  [`TranscriptionRun.tla`](../../../specs/tla/TranscriptionRun.tla)). A summary
  has no such registry: two summary requests inside the window both run and
  both store a summary, and readers take the newest. The queue's own check only
  spares the profile walk.
- **The status controllers are in-memory.** `inferenceStatusController` is
  autoDispose with a two-minute cache, so "running" is per device and per
  process. Another device's run is invisible until its result syncs — at which
  point the entry is no longer missing and the job is skipped.
- **Dismissals do not travel.** Rejecting on the phone leaves the row on the
  desktop.

# Related

* [Execution paths](execution-paths.md) — the runs a backfill dispatches to.
* [Profile resolution](profile-resolution.md) — which profile a task resolves to.
* [Agent UI surfaces](../agents/ui-surfaces.md) — the card that hosts the rows.
