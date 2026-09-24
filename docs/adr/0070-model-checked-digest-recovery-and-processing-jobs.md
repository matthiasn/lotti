# ADR 0070: Model-Checked Digest Recovery and Processing Jobs

- Status: Accepted
- Date: 2026-09-24

## Context

Two Daily OS mechanisms promise to spend exactly one inference on one piece of
work, and both rested on prose:

- The coordinator's morning digest (ADR 0032, ADR 0048). A crash after the
  record flips to `consumed` used to lose the day's briefing; the consumed-record
  retry in `DayAgentService` fixed that, and it must never bill a second
  inference for a briefing the user already has. Since ADR 0066 a second
  recovery path existed beside it: the digest wake was also a `WakeIntentStore`
  intent, which startup replays.
- The durable `draftPlan` / `refinePlan` / `parseCapture` jobs (ADR 0044). Every
  claimed mutation is fenced by `claim_token`, and an artifact pre-check makes a
  re-claim after a crash safe. But the claim's lease is three minutes and never
  renewed, the executor waits three minutes for its wake, and the wake can sit
  behind its agent's single flight, or run on after the ten-minute cap, for up
  to 30 minutes.

We modelled both as the code stood — `specs/tla/DigestRecovery.tla` and
`specs/tla/DayProcessingJob.tla` — and TLC returned these holes as traces:

1. **A completed digest ran again after a crash.** The run settled its wake
   intent, but the settle is a coalesced write; the process died first, and
   startup replayed the intent: a second inference after the briefing existed
   (`NoInferenceAfterBriefing`).
2. **Both recovery paths ran after a crash mid-digest.** Startup's
   `restoreSubscriptions` saw the consumed record with no live work (the intent
   is restored later, in `restoreWakeIntents`) and re-armed it; the record
   fired and completed; then the restored intent ran the digest again.
3. **The live-work probe missed a job the drain had taken.** Between leaving
   the queue and taking the runner lock the drain awaits the agent's policy,
   and a job it holds back sits in a local list. `hasPendingOrActiveWake` saw
   neither, so the pre-scan repair re-armed a digest whose run was about to
   start, and the day was digested twice — no crash needed.
4. **A backward clock step hid a finished digest.** When the run commits its
   milestone and re-arm before the wake manager's consume write lands, that
   write replaces the re-armed row. The retry check then looks for the
   milestone in `[consumedAt, now]`, and a run whose clock stepped back stamped
   it just before `consumedAt`.
5. **A processing job ran two inferences for one request.** Three shortest
   traces, one per path: the lease lapsed while the attempt waited and another
   lane (a provider rebuild leaves the old runtime's drain running) re-claimed
   and enqueued a second wake; the wait timed out and the retry enqueued
   another; a `retryNow` tap re-queued a running job. A refine produced two
   ChangeSets (`AtMostOneLiveWake`, `NoInferenceAfterArtifact`,
   `AtMostOneArtifact`).

Two suspected gaps did **not** hold up. A crash between `enqueueWake` and
`recordRunKey` cannot leave a restored wake intent that runs under a run key
the job never recorded: processing wakes are never intents. And the claim
fence holds — no stale claimant's write lands (`Fenced`).

## Decision

1. **The digest record is the digest's only crash recovery.** Wakes carrying
   a `digest:` token are never `WakeIntentStore` intents, exactly like
   outbox-owned processing jobs; startup discards legacy copies.
2. **Pending-work probes see drain-held jobs.** `hasPendingOrActiveWake`
   counts a job a drain pass has taken out of the queue and not yet started,
   or holds back until it requeues it, beside queued, locked and detached work.
3. **The digest watermark window starts at the local day** of `consumedAt`,
   not at `consumedAt`: any digest of the day is the day's briefing. The upper
   bound stays `now`, which is what guards against a future-dated peer
   milestone.
4. **A processing job attaches to its request's live wake.** Before enqueueing,
   the executor asks `WakeOrchestrator.liveRunKeyWithToken` for a wake carrying
   the job's `processing_job:<jobId>@<requestedAt>` token that is queued,
   drain-held, running, or running on after an abort, and awaits that wake.
   It asks before its reads and again after them, with nothing awaited
   between that second answer and the enqueue, so two attempts racing
   after a retry tap cannot both enqueue (found in review, then by TLC
   with `RecheckBeforeEnqueue = FALSE`). A
   wait that times out while the wake is still live defers without counting an
   attempt; a timeout on a wake no longer live counts and is capped by
   `maxAttempts` like any other retryable failure.
5. **The models gate the code**, as in ADR 0065 and ADR 0066. A Glados trace in
   the executor suite drives the real outbox repository, processor and
   executor through generated interleavings of two lanes, lease lapses,
   timeouts, wake outcomes, retry taps and crashes, and checks the job model's
   invariants.

## Consequences

- `DigestRecovery` holds `AtMostOneDigest`, `NoInferenceAfterBriefing`,
  `InferencesBounded` and `EventuallyBriefed` with up to two crashes, with and
  without the lease, and with a backward clock step. `DayProcessingJob` holds
  `AtMostOneLiveWake`, `NoInferenceAfterArtifact`, `AtMostOneArtifact`, `Fenced`
  and `EventuallySettled` for a refine and a draft job with two lanes, a crash
  and a user tap.
- A crash mid-digest is recovered by the record retry alone, which waits out
  the lease's claim and settle. A briefing interrupted by a crash arrives a few
  minutes after the next start rather than immediately.
- A request whose wake is stuck behind other work waits for it instead of
  paying for another, up to `hungExecutorAfter` (30 minutes); the job stays
  queued, retrying with backoff, and its attempt count does not grow.
- Residuals, recorded in `specs/tla/README.md`:
  - An executor past `hungExecutorAfter` stops counting as live, so its request
    can run a second inference — the same boundary `WakeRuntime.tla` accepts
    for single flight.
  - A wake that commits its artifact before its attempt's `recordRunKey` lands,
    followed by a crash, leaves a never-attempted refine without provenance, so
    the re-claim runs it again (`ProvenanceRace`). The window is one local
    write against a model call; closing it needs the artifact to carry the
    processing-intent id rather than the run key.
  - The claim lease is still never renewed. That is harmless now — whoever
    re-claims attaches to the live wake — and renewing it would add a timer per
    attempt for no model-visible gain.
  - Tool calls a digest commits before a crash are not rolled back, so the
    retried digest can revise directives the interrupted one already wrote;
    the directive register converges, which ADR 0048 relies on too.

## Related

- `specs/tla/DigestRecovery.tla`, `specs/tla/DayProcessingJob.tla`,
  `specs/tla/README.md`
- [Coordinator and day-agent protocol](../../knowledge/features/daily_os_next/coordination-protocol.md)
- [Day processing outbox](../../knowledge/features/daily_os_next/processing-outbox.md)
- [Wake orchestration](../../knowledge/features/agents/wake-orchestration.md)
- [ADR 0032: Hierarchical day-agent coordination](./0032-hierarchical-day-agent-coordination.md)
- [ADR 0044: Day processing outbox storage](./0044-day-processing-outbox-storage.md)
- [ADR 0048: One device runs the coordinator digest](./0048-one-device-runs-the-coordinator-digest.md)
- [ADR 0066: Model-checked agent wakes and confirmations](./0066-model-checked-agent-wakes-and-confirmations.md)
