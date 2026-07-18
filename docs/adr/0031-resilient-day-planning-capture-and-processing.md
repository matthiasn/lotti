# ADR 0031: Resilient Day-Planning Capture and Durable Processing

## Status

Accepted

## Date

2026-07-18

## Expert review gate

The user-required independent architecture, reliability, and product/testing
panel produced:

| Round | Architecture | Reliability | Product/testing | Average | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| 1 | 6.0 | 6.5 | 7.4 | 6.63 | Rejected |
| 2 | 7.6 | 7.8 | 7.9 | 7.77 | Rejected |
| 3 (first 9/10 attempt) | 8.1 | 8.9 | 7.8 | 8.27 | Rejected; critical blockers |
| 4 (final 9/10 attempt, after targeted blocker closure) | 9.2 | 9.6 | 9.4 | 9.40 | Accepted; no critical blockers |

## Context

Daily OS voice capture currently makes network-dependent transcription part of
the path to durable day data.

In `CaptureController`'s batch path, the recorder finalizes an `.m4a`, calls
`AudioTranscriptionService.transcribe`, and only creates `JournalAudio` after
transcription succeeds. A transcription failure clears the controller's
recording note and leaves a stopped file without a journal row. In the realtime
path, `JournalAudio` is created only after `RealtimeTranscriptionService.stop`
returns an artifact. That service buffers PCM in memory, drops old PCM after
its cap, and writes the artifact only at stop. A provider or process failure can
therefore prevent any recoverable day recording.

The day-scoped `CaptureEntity` is later still: the UI creates it only after a
non-empty transcript reaches Review and the user continues. The resulting
capture is durable and synced, but its parse wake is placed in `WakeQueue`,
which is intentionally in-memory. Manual draft and refine wakes use the same
queue. An app exit can preserve source text while losing pending processing
intent.

The standard file-backed task recording path has the correct post-stop order:
it persists a task-linked `JournalAudio` before invoking optional automatic
transcription. Its journal row and attachment survive inference failure and can
be rediscovered by a later task wake. The task realtime path still shares the
RAM-buffer/stop-time weakness and is not the reference for artifact ownership.

The failure violates the product's primary capture guarantee: a user who speaks
about a day must not lose that account because assistance is unavailable.

Three existing mechanisms have deliberately different ownership:

- `JournalDb` and the asset directory own user-created audio.
- The Matrix sync outbox transports already-durable journal/agent entities; it
  does not represent pending inference.
- `WakeQueue` owns bounded in-process agent execution and coalescing; manual
  jobs are not generally restart-safe.

Conflating them would make sync, processing, and execution state impossible to
reason about independently.

ADR 0020 also requires the exact text consumed by an agent to be immutable,
append-only captured input. `CaptureEntity` is currently that submitted
transcript. It must not become a mutable automatic-transcription register.

The task-agent pattern is reused only where its guarantees are real:

| Concern | Reuse from task/journal architecture | Daily-OS/shared work required |
| --- | --- | --- |
| Source ownership | Journal asset directory, `JournalAudio`, playback, deletion, attachment sync | Explicit day/session/intent context and day indexes |
| Journal durability | Vector clocks, sidecars, sequence binding, Matrix gap/backfill repair | One source-plus-transcribe-job transaction and deterministic recovery IDs |
| Later discovery | Durable source/reference lookup | Day Activity projection and planner day-entry index |
| Realtime capture | None: the existing path buffers before stop | Shared write-before-send PCM spool and process-death recovery |
| Pending inference | None: `WakeQueue` is in-memory | Device-local semantic processing outbox, claims, receipts, and reconciler |
| Generated plans | Existing mutable day plan and edit APIs, after every mutation participates in the new head-version guard | Operation-addressed revisions and divergent-head conflict semantics |

No task-agent API is copied merely because its UI appears resilient. Shared
speech and journal primitives are strengthened once and then consumed by Daily
OS; day-workspace and planner semantics remain in the Daily-OS boundary.

## Decision

### 1. Local source persistence precedes every network-dependent operation

A successful day-recording stop is defined by a local durable commit, not by a
transcription or planner result.

Before the UI reports **Saved**, the application must have:

1. a stable playback artifact;
2. a `JournalAudio` row that identifies the artifact and selected day
   workspace; and
3. a durable local `transcribe` processing row.

No transcription provider, realtime socket, or planner wake may be the sole
owner of bytes already acknowledged to the user. Derived-work failure never
deletes or hides the source.

If the application retains a spool but cannot complete steps 1–3 (for example,
database full), the UI says **Recovery retained**, not **Saved**. Startup
recovery continues the commit.

### 2. Capture session context is immutable before microphone start

Every voice flow constructs:

```text
CaptureSessionContext {
  sessionId
  dayId
  planDate
  intent: capture | refine | checkIn
  activityEntryId
  timezone
  utcOffset
  originHostId
  continuationOperationId?  // required for refine
  baselineRevisionId?       // required for refine
}
```

`sessionId` is a UUID created before microphone access. `activityEntryId` is
derived from it. `dayId` comes from the selected Day workspace, never from the wall
clock at stop. The context is passed to a family/scoped capture controller and
snapshotted in the spool manifest before the first audio frame.
Refine sessions also preallocate their continuation operation and snapshot the
exact current plan revision; capture/check-in sessions keep both fields null.

Changing the selected calendar date while recording does not rebind the
session. Crossing midnight does not move it to another day. Create, Refine, and
check-in flows provide their explicit intent when constructing the context.

Lifecycle rules are phase-specific:

| Phase | Explicit discard | Route close / auto-dispose / app background |
| --- | --- | --- |
| Before first frame | Remove empty manifest | Remove empty manifest |
| Recording, before stop | Stop and delete spool only after discard confirmation | Stop/checkpoint; keep recovery manifest |
| Finalizing/commit | Do not delete; cancellation only suppresses derived work after commit | Continue or recover on startup |
| Saved or later | Cancel processing only; audio remains | Audio and jobs remain durable |

`reset()` clears UI/controller state only. It never deletes a committed source.

### 3. A shared durable spool owns PCM before realtime consumers

The recorder starts the local spool before connecting realtime transcription.
PCM frames are written locally before being forwarded to any remote or local
realtime consumer. A realtime disconnect degrades live transcript feedback only.

The spool is a shared speech-layer component, not a permanent Daily-OS-only
recorder. Daily OS adopts it first for the P1. Task/chat realtime capture moves
to the same owner in the same implementation if it calls the changed shared
service; no second RAM-only implementation is introduced.

#### Spool format and publication protocol

- Root: `<documents>/audio_spool/<sessionId>/`.
- Audio: PCM signed 16-bit little-endian, 16 kHz, mono.
- Chunks: monotonically numbered two-second files.
- Active chunk: `<sequence>.part`. Flush at least once per second. A recovery
  scan trims any trailing byte that does not form a complete 16-bit sample.
- Published chunk: flush/fsync file, rename `.part` to `.pcm`, then sync the
  containing directory where the platform supports it. A process kill can lose
  at most the unflushed interval; it cannot invalidate prior published chunks.
- Manifest: versioned/checksummed JSON containing immutable session context,
  format, published chunk lengths/digests, active sequence, and state
  (`recording`, `finalizing`, `published`, `committed`, `discarded`). Write a
  new generation to a temporary file, flush, atomically rename, and sync the
  directory where supported. Recovery chooses the newest valid generation.
- Final artifact: assemble a valid WAV at the final asset directory as
  `<file>.wav.part`, flush/fsync, atomically rename to `<file>.wav`, then publish
  manifest state `published`. `JournalAudio` never points at a system-temp path
  or `.part` file. M4A conversion is optional derived optimization, not the
  source commit.

If WAV publication fails, complete chunks and the manifest remain the recovery
source. The UI exposes a recovery item; it does not create a broken
`JournalAudio` path. Startup validates checksums/lengths, republishes WAV, then
continues the journal commit.

Recovery reconciles the directory as well as the manifest. It enumerates
numeric `.pcm` files and adopts every contiguous, format-valid published chunk
not yet listed in the newest manifest, recomputing its length and digest. A
contiguous `.part` is trimmed to a complete sample, flushed, published, and
adopted. Gaps, duplicate sequence numbers, checksum mismatches, and
non-contiguous extras are retained in a quarantined recovery state with a
visible error; they are never silently ignored or deleted. The service writes a
repaired manifest generation before WAV assembly.

No ring buffer may evict old audio from the durable owner. A realtime consumer
may keep its own bounded analysis buffer only after the spool has accepted the
frame. The mic callback feeds one bounded writer channel whose capacity is
fixed in the implementation plan. If disk cannot accept data before that bound
fills, capture stops/checkpoints and reports partial recovery; it never grows an
unbounded memory queue or drops frames while claiming a complete save.

Recovered duration is derived from accepted PCM sample count, never wall time.
WAV recovery validates format, header/data length, sample-derived duration, and
digest before journal publication.

### 4. `JournalAudio` owns automatic transcription and repairable day scope

`AudioData` gains optional `DayAudioContext`:

```text
DayAudioContext {
  sessionId
  dayId
  activityEntryId
  intent
  originHostId
  planDate
  timezone
  utcOffset
  continuationOperationId?
  baselineRevisionId?
  reviewOperationId?
  reviewedAt?
}
```

Older/non-Daily-OS rows deserialize with no context. The journal table gains a
nullable denormalized/indexed `day_id` and `recording_session_id` populated from
this context. `recording_session_id` has a partial unique index for non-null
values, so one session cannot produce two journal rows.

Identifiers are normative:

```text
journalAudioId = UUIDv5(dailyOsAudioNamespace, "day-audio:" + sessionId)
initialTranscribeOperationId = UUIDv5(dailyOsOperationNamespace,
  "transcribe:" + sessionId)
transcribeJobId = "day_transcribe:" + transcribeOperationId
transcribeDedupeKey = "transcribe:" + journalAudioId
activityEntryId = "day_audio:" + sessionId
captureId = UUIDv5(dailyOsCaptureNamespace,
                   "review:" + reviewOperationId)
initialParseOperationId = UUIDv5(dailyOsOperationNamespace,
  "parse:" + captureId)
parseJobId = "day_parse:" + parseOperationId
refineJobId = "day_refine:" + continuationOperationId
draftJobId = "day_draft:" + operationId
conflictResolutionJobId = "day_plan_resolve:" + operationId
```

Every user intent preallocates a UUID `operationId` before its durable boundary.
A retry keeps the same job ID. Changing immutable input, provider/configuration,
or a resolved decision creates a new operation/job ID and records
`supersedesJobId`; it never reuses a receipt identity. Initial automatic
transcribe/parse operation IDs are deterministically derived from
session/capture. A replacement preallocates a UUID operation ID while retaining
the same `rootSemanticId` chain.

Repair inserts by the deterministic ID/session constraint and reuses an
existing row/VC. On conflict it validates `dayId`, session context, artifact
path, duration, and artifact digest. A mismatch is corruption requiring visible
recovery; repair never reserves a replacement VC or creates a second row.

Automatic provider output remains `JournalAudio.data.transcripts` and gains an
optional `sourceProcessingJobId` for idempotency. Until review,
`JournalAudio.entryText` may show the selected automatic transcript for journal
search/UI, but it is not planner input.

On review, the user-confirmed text becomes `JournalAudio.entryText`, and
`DayAudioContext.reviewOperationId/reviewedAt` are stamped in the same journal
update. Journal conflict handling remains authoritative for concurrent user
edits. A deterministic repair can recreate missing downstream work from the
review operation ID.

### 5. `CaptureEntity` remains immutable reviewed planner input

Do not create a `CaptureEntity` for pending audio or an automatic transcript.

For JSON and sync compatibility, `CaptureEntity` gains one nullable versioned
field rather than several new required top-level fields. When the user
reviews/submits new-format text, create one immutable `CaptureEntity` with
non-null provenance:

```text
CaptureEntity {
  id: captureId
  agentId
  dayId
  transcript: reviewed text
  capturedAt
  createdAt
  audioRef?
  dailyOsProvenance?: DailyOsCaptureProvenance
  supersedesCaptureId?
  vectorClock
}

DailyOsCaptureProvenance {
  schemaVersion: 1
  reviewOperationId
  sourceIntent: capture | refine | checkIn
  sessionId
  activityEntryId
  planDate
  timezone
  utcOffset
  originHostId
  continuationOperationId?  // required for refine
  baselineRevisionId?       // required for refine
}
```

This preserves existing ADR 0020 semantics. A later correction creates another
immutable capture that supersedes the prior capture; it does not mutate
consumed history. Only reviewed captures enter the capture-event/day-log
substrate. The user's reviewed text is therefore canonical for Activity and
planner input, while automatic transcript provenance remains on `JournalAudio`.
The immutable intent/provenance fields make restart repair choose the correct
continuation for voice and typed capture/refine flows without re-reading route
state. A capture/check-in continuation uses `parseJobId`; a refine continuation
requires its baseline and preallocated continuation operation. A conflicting
row under any deterministic ID is validated field-by-field and surfaced as
corruption rather than overwritten.

Legacy JSON with no provenance continues to deserialize. It is immutable
historical planner input and is **not** eligible for automatic job repair.
Legacy IDs prefixed `refine_capture:` are classified as historical refine input
with unknown baseline; they are never parsed or automatically continued.
Other legacy captures remain historical reviewed capture input. Existing
parsed outputs/history remain visible, but only an explicit new user action may
create new processing intent from a legacy capture. New-peer/old-peer JSON
round trips must preserve the nullable extension.

A correction after review creates a new immutable capture with
`supersedesCaptureId`. For voice entries it also updates JournalAudio's latest
display text/review pointer under normal journal conflict handling, but never
mutates the superseded capture. Activity renders the newest non-superseded text
by default, labels it edited, and keeps prior reviewed versions navigable. The
planner frontier consumes both immutable historical input and the explicit
supersession relation; it never rewrites an input already captured by a wake.

### 6. Day Activity is a projection, not another synced source entity

A day remains the ADR 0022 workspace identified by
`dayPlanId(localDay(date))`. No mutable `Day` row or generic persisted
`DayEntryEntity` is introduced.

`DayActivityItem` is a local read model projected from authoritative sources:

- Daily-OS `JournalAudio` for voice entries;
- immutable `CaptureEntity` without audio for typed entries;
- existing `DaySummaryEntity` for planner check-ins;
- immutable `DayPlanRevisionEntity` plus `DayPlanConflictEntity` for generated
  plans/conflicts; and
- device-local processing/recovery rows for current status.

Each source type defines a stable projection ID. Temporary missing joins render
placeholders and repair state; they never remove a previously visible card. A
voice item is visible from the indexed journal source even if AgentDb is
unavailable.

A voice session is one Activity item keyed by its context `activityEntryId`;
the recovery manifest, JournalAudio, reviewed capture, processing rows, and
derived plan usage progressively enrich that item rather than creating
additional cards.
Typed entries use `day_typed:<captureId>`, summaries use their entity ID, plan
revisions use their revision ID, and conflicts use their conflict ID. Join
conflicts validate immutable day/session provenance and render corruption
instead of arbitrarily coalescing unrelated sources.

Canonical order is `(occurredAt, sourceTypeOrder, sourceId)`, oldest first.
`sourceTypeOrder` is fixed by Activity item kind: voice session `0`, typed
capture `1`, planner/day summary `2`, plan revision `3`, and plan conflict `4`.
A voice session retains kind `0` while enriching from spool-only to
JournalAudio-backed, so a timestamp tie cannot move the card.
Activity opens positioned at the latest item and preserves position on
navigation/refresh.

### 7. Every plan-head mutation is revision-addressed and conflicts converge

The deterministic `DayPlanEntity` remains the materialized mutable head and
gains `currentRevisionId` plus nullable `activeConflictId`. A processing job
carries its immutable `baselineRevisionId`.

Every mutation path writes an immutable revision, including generated draft or
refine output, accepted ChangeSet items, commit/uncommit, rename, edit,
reschedule, block-state change, undo, delete, and recreate:

```text
DayPlanRevisionEntity {
  id: day_plan_revision:<operationId>
  operationId
  sourceProcessingJobId?
  parentRevisionIds          // canonical sorted set
  mutationKind
  agentId
  dayId
  planDate
  data?                      // null only for a deletion tombstone
  outputDigest
  sourceCaptureIds
  resolvesConflictId?
  resolutionInputRevisionIds
  createdAt
  vectorClock
}
```

The operation ID, not content alone, is the revision identity. Retrying one
operation reuses one ID; two actions producing identical content remain two
revisions. `outputDigest` hashes canonical mutation kind plus plan bytes. An
undo is a new revision whose data matches an ancestor; it never moves the head
pointer backward.

All existing plan mutation APIs must accept a preallocated operation ID and
write revision plus head in one AgentDb transaction. Generated effects also
write their receipt there. A job updates the head only when its
`baselineRevisionId` still equals `currentRevisionId` and no unresolved active
conflict exists. Otherwise its revision is preserved as a branch.

Existing plans receive a deterministic `legacySnapshot` revision before any
new mutation:

```text
legacyRevisionId = UUIDv5(dayPlanRevisionNamespace,
  dayId + ":legacy:" + semanticDigest)

semanticDigest = SHA-256(day_plan_revision_semantic_v1(
  dayId, planDate, mutationKind: legacySnapshot, planData))
```

The versioned semantic canonicalizer is the existing
`content_digest.dart` mechanism extended with this schema. It excludes vector
clocks, host IDs, transport/update timestamps, and other envelope metadata.
Legacy `createdAt` is the deterministic UTC noon of `planDate`; new operations
persist their preallocated occurrence time in semantic input. UUIDv5 namespace
values and digest schema names are fixed persisted constants, never regenerated
per install. Concurrent different legacy payloads therefore remain distinct
candidates. A plan with no predecessor uses the canonical fork sentinel
`no_head`.

`DayPlanEntity` and plan conflicts use a type-specific sync resolver. Generic
LWW is forbidden when concurrent heads have different `currentRevisionId`
values. There is one lifetime conflict register per day, so partial ancestry or
arrival order cannot create overlapping conflict epochs. Such a merge preserves
all revisions and creates/merges:

```text
DayPlanConflictEntity {
  id: UUIDv5(dayPlanConflictNamespace, "day:" + dayId)
  dayId
  candidateRevisionClocks   // grow-only map revisionId -> canonical VC
  resolutionAttemptIds      // grow-only canonical sorted set
  vectorClock
}
```

A canonical vector clock is a host-ID-sorted map of non-negative counters. The
custom resolver unions the candidate map and resolution-attempt set; it never
stores mutable resolved status. Each resolution attempt is itself an immutable
`DayPlanRevisionEntity` naming the conflict and every frontier revision it
attempted to resolve. Its clock joins those inputs.

The same revision ID with the same versioned semantic bytes is one revision;
the resolver joins envelope/source clocks componentwise and uses that merged
clock in `candidateRevisionClocks`. Different transport timestamps do not
conflict. The same ID with a different semantic schema/payload/digest is sync
corruption and is quarantined; union never picks one by LWW. Missing revision
payloads render a recoverable placeholder until sync/backfill repairs them.

Conflict status is derived from the revision graph. It is resolved only when
exactly one resolution revision causally dominates every candidate clock and
every other resolution attempt. Concurrent resolutions remain an unresolved
fork. A late candidate not dominated by the prior resolution reopens the same
day register. Historical candidates remain but fall off the frontier once
dominated. The bounded implementation indexes the revision DAG; it does not
scan full history on every read.

A resolution clock is formed by componentwise-joining every current frontier
clock and then incrementing the resolving host counter. The conflict-register
and head envelopes written in the same transaction causally include that
revision clock and increment their own local counters. Concurrent attempts
therefore remain incomparable; a subsequent attempt joins both and dominates
them.

The deterministic provisional display is the lexicographically smallest
revision ID on the unresolved frontier. While unresolved, sync stores that
revision as an explicitly provisional raw-head cache and sets the day's fixed
`activeConflictId`; it never describes the cache as committed.
`DayPlanReadProjection` is authoritative
for every UI provider, planner wake, and tool: it resolves the provisional
revision and labels it unresolved. Direct feature reads of raw
`DayPlanEntity.data` are forbidden. Editing/committing is disabled until the
conflict is resolved.

`activeConflictId` is repairable derived cache, not authority. On every plan or
conflict sync event and at startup, the resolver recomputes the fixed day
register's frontier: unresolved sets the ID/provisional cache; one dominating
resolution clears it and installs that revision unless the cached head
causally descends from it, in which case the later descendant is preserved.
Concurrent later heads are first added as candidates and therefore remain
unresolved. Missing revisions show a sync-recovery placeholder and request
backfill. A stale linkage cannot indefinitely block mutations.

Choosing a candidate still creates a resolution revision (with identical plan
bytes) so its clock can dominate the full frontier. The resolution revision,
head, conflict linkage, owning claim, and receipt commit atomically. Activity
shows generated revisions and conflict resolutions; mechanical edit revisions
remain navigable from plan history/conflict UI without flooding the day feed.
Likewise, a stale generated job atomically commits its branch revision,
candidate clock, active conflict linkage, claim, and receipt without mutating
the prior head data.

### 8. Pending work lives in a device-local processing outbox

Add `day_processing_outbox` to `JournalDb`. It is separate from the Matrix
transport outbox and in-memory `WakeQueue`.

Each row stores:

```text
id / rootSemanticId / semanticDedupeKey / operation
supersedesJobId? / supersededByJobId? / pendingReplacementJobId?
dayId / originHostId / sessionId? / sourceEntityId / immutableInputRevisionId?
baselineRevisionId? / immutableInputDigest
providerSnapshotJson? / providerSnapshotDigest?
payloadDigest / payloadJson (IDs and decisions only)
priority / status / attemptCount
nextAttemptAt / retryNotBefore
leaseOwner / leaseToken / bootSessionId / leaseExpiresAtUtc
claimGeneration
lastErrorCode / lastErrorMessage
createdAt / updatedAt / completedAt
```

The provider snapshot contains provider/profile/model identifiers and inference
parameters required to replay the same operation, but never credentials or
secrets. Missing/removed credentials or model assets move the job to
`waitingForUser`; selecting a different configuration creates a replacement
job.

`retryNotBefore` is a hard provider/server boundary (for example
`Retry-After`). Connectivity/app-resume hints may advance `nextAttemptAt` but
never bypass `retryNotBefore`. Semantic dedupe keys include immutable source
revision, reviewed capture/review operation, decision digest, and plan baseline
as relevant. An input edit creates a new operation/job and explicitly cancels
or supersedes stale queued work.

Job ID is the primary key and `semanticDedupeKey` has a uniqueness constraint
within non-superseded work. Repair uses strict insert, then validates the
existing operation, immutable payload digest, source, baseline, and
supersession chain. It never mutates a conflicting row into the desired job.

There is no cardinality cap that evicts or rejects an old job in favor of a new
one; DB/disk exhaustion follows the Recovery-retained contract. Queue claims,
startup repair, and Activity reads are paged/bounded. Required indexes cover
`(status, retryNotBefore, nextAttemptAt, priority, createdAt)`, semantic chain,
`day_id`, and `recording_session_id`; exact page sizes and quotas are fixed in
the implementation plan.

Initial execution is source-device-only, identified by `originHostId`. Peers
sync/render source and derived entities but do not create automatic or manual
processing jobs in this P1. Cross-device executor takeover requires a separate
ADR defining claims and concurrent result selection. The UI on a peer explains
that pending processing will continue on the recording device. This constraint
removes unsupported claims that existing LWW makes nondeterministic inference
convergent.

### 9. Journal source commit has a precise vector-clock boundary

The implementation adds a dedicated `PersistenceLogic`/`JournalDb` operation;
it must not compose public `createDbEntity()` followed by a job insert.

The order is:

1. publish or validate the stable WAV/recoverable spool;
2. reserve/stamp the journal vector clock;
3. inside one `JournalDb.transaction`, strictly insert the `JournalAudio` row
   and the unique initial `transcribe` row;
4. commit the vector-clock scope iff both inserts commit; burn/release according
   to the existing vector-clock contract otherwise;
5. post-commit, record journal sequence binding and generate/repair the JSON
   sidecar;
6. post-commit, enqueue Matrix sync using existing failure-tolerant gap/backfill
   semantics;
7. notify the UI only after steps 1–4; and
8. mark the spool `committed` only after the DB transaction commits.

Startup repair handles these cases idempotently:

- published spool, no journal row: repeat steps 2–8;
- journal row and job committed, manifest not marked committed: mark it;
- journal row missing JSON/sequence binding/Matrix message: use existing
  sidecar regeneration and sync gap/backfill repair paths, with an explicit
  repair scan for Daily OS source rows;
- journal row exists but initial job is absent (legacy/partial pre-migration
  case): insert the deduped job if automatic transcript/reviewed capture does
  not already satisfy the next state.

### 10. Queue claims are fenced in the database that owns the effect

Status and a random token alone do not fence a cross-database effect. Claims
therefore have two explicit protocols.

For `transcribe`, whose expected output is in JournalDb, a JournalDb claim
increments `claimGeneration`, creates a random `leaseToken`, and records worker,
app `bootSessionId`, and expiry in one transaction. Every renew, output write,
success, retry, fail, or cancel compare-and-set includes job ID, running status,
generation, and token.

Transcription completion runs in a vector-clock scope and re-reads the latest
`JournalAudio` inside the owning transaction. It appends at most one transcript
with the job's `sourceProcessingJobId`, preserves any reviewed `entryText`,
review operation, and day context that won a concurrent review race, then marks
the job succeeded under the same generation/token. No-op duplicate completion
releases/burns the reservation under the existing VC contract. Sequence
binding, sidecar, and Matrix enqueue are post-commit and use the same explicit
repair scan as source creation.

For `parseCapture`, `draftPlan`, `refinePlan`, and conflict resolution, AgentDb
owns the claim because it owns the effect. Add device-local
`day_agent_effect_claims`, keyed by processing job ID:

```text
processingJobId / claimGeneration / leaseToken
leaseOwner / bootSessionId / leaseExpiresAtUtc
status: claimed | effectCommitted | abandoned
terminalReason?: cancelled | superseded
cancellationOperationId?
replacementJobId?
updatedAt
```

The authoritative claim transaction in AgentDb first verifies that no valid
receipt or cancellation tombstone exists and that the prior AgentDb lease is
absent or expired; it then monotonically increments `claimGeneration` and
writes the new token. The processor mirrors that exact generation/token into
the JournalDb outbox row with a CAS before invoking any provider. A crash
between those steps leaves an authoritative claim that startup either mirrors
and resumes or lets expire. It cannot authorize an older worker.

The AgentDb output transaction validates that the claim row is still `claimed`
with the exact generation and token, then strict-inserts outputs and receipt
and marks the claim `effectCommitted`. A zero-row validation or uniqueness
conflict is handled by reading and validating the winning receipt/output; it is
never overwritten by upsert. JournalDb acknowledgement happens afterward and
requires the mirrored generation/token. Thus worker B fences worker A at the
AgentDb claim increment, before A can publish an AgentDb effect, including the
crash/reclaim ABA case.

`bootSessionId` is diagnostic, not proof that another process is dead. Each
owning database has a transactional processor-owner lease; only its holder may
claim jobs. A second desktop process waits for expiry and never steals merely
because its boot ID differs. After process death, startup likewise waits for
the bounded owner/job lease unless the platform supplies positive termination
proof. The processor detects large wall-clock jumps and re-evaluates leases.
Provider calls have a hard timeout below lease duration. Heartbeat occurs at
most one third of the lease duration and before any output commit. Concrete
durations are operation-specific and fixed in the implementation plan/tests.

Cancellation linearizes in the database that owns the effect. Transcribe
cancellation fences and commits in JournalDb. Agent-effect cancellation first
transacts in AgentDb: a validated receipt/`effectCommitted` claim wins and is
reconciled as success; otherwise cancellation increments the generation and
writes an `abandoned` tombstone before JournalDb is mirrored to cancelled. The
first of effect-commit or cancellation-fence transactions wins. Future claims
reject the tombstone. Manual retry after cancellation is a new operation/job,
not resurrection of the cancelled ID.
Startup scans terminal AgentDb claims: an `abandoned` claim with no receipt CASes
the matching non-terminal Journal row to `cancelled` using cancellation
operation/generation; `effectCommitted` reconciles to success. This closes a
crash between the owning cancellation transaction and Journal mirror.

Supersession uses a recoverable prepare/fence/activate saga:

1. JournalDb strictly inserts the **complete** replacement row as non-claimable
   `preparing`, with all immutable input/provider/payload/retry fields and
   `supersedesJobId`; the old row records `pendingReplacementJobId` but remains
   semantically current.
2. The owning AgentDb transaction either observes a committed effect (old wins)
   or increments/fences the old claim as `abandoned` with terminal reason
   `superseded` and the replacement ID. Transcribe performs the equivalent
   fence in JournalDb.
3. JournalDb atomically CASes old to `superseded`, clears its pending marker,
   writes `supersededByJobId`, and changes the prepared replacement to `queued`.

While a pending replacement exists, no new worker may claim the old row;
already-running work races the owning fence normally. A prepared row is never
claimable/current. Startup validates the full prepared descriptor and repairs
every case idempotently: prepared/no fence retries the fence or explicitly
discards the preparation and clears the marker; fence+prepared activates it;
`effectCommitted` reconciles old success and cancels the preparation. Thus
there is exactly one claimable non-superseded job at every boundary, and no
opaque replacement ID must be reconstructed after a crash. There is at most
one claimable job and exactly one durable current-or-prepared continuation at
every boundary; the brief fenced/prepared state intentionally has no claimable
worker until activation repair.

### 11. Every nondeterministic effect has a job-addressed receipt

Add a device-local AgentDb `day_agent_effect_receipts` table with a strict
unique key on `processingJobId`. A receipt records operation, immutable
input/baseline IDs, output entity IDs/digest, committed claim generation, and
completion time.

Parse handlers write parsed items/links plus the receipt in one AgentDb
transaction. Draft handlers write revision/head-or-branch plus the receipt;
refine handlers write an immutable ChangeSet plus the receipt. Accepting a
ChangeSet is a separately preallocated plan-mutation operation that revalidates
its baseline and atomically writes revision plus head-or-branch. `WakeJob` and
wake-run logs carry optional `processingJobId`.

Before external inference, a retry queries the receipt. If it exists and its
output validates, the processor reconciles the JournalDb row to `succeeded`
without repeating inference. This receipt-reconciliation CAS is keyed by job
ID and receipt output digest and is permitted from any non-cancelled,
non-superseded, non-succeeded state; it does not claim authority to publish
another effect. A
receipt/output mismatch is visible corruption, not an invitation to overwrite.
The normal post-effect JournalDb acknowledgement still requires the exact
generation/token that committed the effect.

`reconcileReceipt` is an explicit legal state-machine edge from any
non-cancelled, non-superseded, non-succeeded state to `succeeded`. Effect claims and receipts
are retained until the associated source and Journal processing history are
eligible for the same explicit deletion flow; ordinary queue cleanup never
removes them independently.

This receipt, rather than a guessed content-addressed output ID, closes the
crash window between AgentDb output commit and JournalDb acknowledgement.

### 12. The durable workflow and continuation rules are normative

There is no implicit automatic chain. Each transition has a durable source,
expected output, and repair rule:

| Operation or gate | Durable prerequisite | Creation/intent boundary | Expected output / completion | Crash repair |
| --- | --- | --- | --- | --- |
| `transcribe` | Stable `JournalAudio` + audio artifact | Same JournalDb transaction as source | `AudioTranscript.sourceProcessingJobId == job.id` | Missing output keeps/retries same job |
| Voice capture/check-in review | Automatic transcript edited or accepted by the user | Journal update stamps reviewed text + `reviewOperationId`; deterministic capture and parse-job writes are attempted before navigation | Immutable capture with new-format capture/check-in provenance + `parseCapture` job | Reconciler scans reviewed day-audio rows, recreates the deterministic capture, then selects continuation from provenance intent |
| Voice refine review | Automatic transcript edited or accepted by the user | Journal update stamps reviewed text + `reviewOperationId`; deterministic capture and refine-job writes are attempted before navigation | Immutable refine-provenance capture with baseline + preallocated continuation operation + `refinePlan` job | Reconciler recreates capture and refine job; refine never falls through `parseCapture` |
| Typed capture/check-in | User submits text with a preallocated `reviewOperationId`/session context | Deterministic immutable capture is the first durable boundary; parse-job write is attempted before navigation | Capture with new-format capture/check-in provenance + `parseCapture` job | Reconciler scans eligible new-format captures and recreates the continuation selected by provenance intent |
| Typed refine | User submits text with explicit baseline | Deterministic immutable capture is the first durable boundary; refine-job write is attempted before navigation | Capture with new-format refine provenance + `refinePlan` job | Reconciler recreates refine job; no JournalAudio update or parse job is required |
| `parseCapture` | Immutable reviewed capture with capture/check-in intent | Dedupe includes capture ID | Parsed items/links + AgentDb effect receipt | Reconciler scans eligible captures with neither valid receipt/output nor retained parse row |
| Decision review | Parsed items or explicit empty decision set | User confirmation computes an immutable decision digest and preallocates an operation | Durable `draftPlan` job | The job insert is the intent commit; UI does not advance if it did not commit |
| `draftPlan` | Reviewed capture(s), decisions, baseline revision | User presses Build my day; job commits before busy UI | Plan revision + conditional head/branch + receipt | Receipt check avoids repeat inference |
| `refinePlan` | Reviewed refine capture, baseline revision | User submits reviewed refine text | Immutable pending ChangeSet + receipt | Receipt check avoids inference replay; acceptance revalidates baseline and becomes revision/head or branch/conflict |

Voice review data that crosses AgentDb and JournalDb uses deterministic IDs and a
`DayProcessingInvariantReconciler` on startup and relevant update streams. The
same reconciler derives typed-entry continuation directly from immutable
`CaptureEntity.dailyOsProvenance`. Captures with null/unsupported provenance are
never automatic-repair inputs. The UI does not report an intent as queued until
the enqueue attempt returns. A draft decision has no preceding cross-store commit: its processing-row
insert is the atomic intent boundary, and its immutable decision payload/digest
is stored in that row. If the insert does not commit, the UI stays on decisions.

Legal processing statuses are:

```text
preparing -> queued | cancelled
queued -> running | cancelled | superseded
running -> succeeded | retryScheduled | waitingForNetwork |
           waitingForUser | failed | cancelled | superseded
waitingForNetwork -> queued
waitingForUser -> queued | cancelled | superseded
retryScheduled -> queued | cancelled | superseded
failed -> queued (same-operation retry) | cancelled | superseded
any non-cancelled, non-superseded, non-succeeded -> succeeded (reconcileReceipt)
```

Every non-cancelled source has either its expected output or a retained durable
record in `preparing`, `queued`, `running`, `retryScheduled`, `waitingForNetwork`,
`waitingForUser`, `failed`, or a persisted user gate/decision state from which
the reconciler deterministically creates the next job.

Cancellation follows Decision 10's owning-database transaction and cancels
dependent jobs whose immutable input is no longer selected. It never deletes
the committed audio. Manual retry of a failed job resets `nextAttemptAt` but
never bypasses hard `retryNotBefore`, and retains attempt history. Retry after
cancellation, or choosing a different provider/configuration, creates a new
operation/job with `supersedesJobId` instead of weakening the old provider's
server boundary or receipt identity.

### 13. Retry, fairness, disk pressure, and deletion are explicit

Retryable network/provider failures use full-jitter exponential backoff:

```text
delay = random(0, min(base * 2^attempt, cap))
```

Operation-specific base/cap values are fixed in the implementation plan.
Attempts increment only after an external operation begins. Offline preflight
does not burn an attempt. Provider `Retry-After` sets `retryNotBefore`.

Interactive user jobs outrank automatic maintenance, but the processor reserves
periodic capacity for the oldest due lower-priority job to prevent starvation.
Pending/failed jobs are never pruned by age.

Before microphone start, reserve/check a configured minimum free-space budget.
On ENOSPC mid-recording, stop/checkpoint immediately and retain every published
chunk; UI distinguishes “partial recording recovered” from “not saved.” A DB
full failure cannot produce a Saved state. Spool cleanup has a quota but always
excludes uncommitted recoveries and sources referenced by non-terminal jobs.
After WAV digest verification, JournalAudio/job commit, and a configurable
grace period, committed PCM chunks are reclaimable; a small committed manifest
tombstone retaining session context, artifact path, digest, and cleanup time
remains for repair/audit. Cleanup never removes chunks before all three
conditions hold.

Deletion order is: fence/cancel non-terminal jobs, commit cancellation, soft
delete derived references, then enter the existing explicit journal deletion
flow. Physical audio/spool purge occurs only when no job/recovery/reference
remains, including an outstanding Matrix attachment transport reference unless
the explicit user deletion flow also cancels that transport. Inference failures
never initiate deletion.

### 14. Day Activity is a third local-first Day view

The Day header's `PlanView` becomes `agenda | schedule | activity`.

- A day with a current plan keeps the user's existing Agenda/Schedule choice;
  Activity is selected explicitly or via a deep link to an entry.
- A no-plan day with saved/pending/failed day entries opens Activity by default.
- A no-plan/no-entry day retains the current default surface (Schedule).
- Calendar day indicators distinguish plan days from entry-only days and make
  the latter navigable.
- Activity is oldest-first, initially positioned at the latest entry, and
  restores scroll/selected entry after Review/Drafting routes return.
- `CapturesPanel` remains until Activity has playback, transcript, and
  navigation parity, then is removed rather than duplicated.

Root-level plan loading adopts stale-while-revalidate: a previous Day shell is
never replaced by full loading/error during background invalidation. Every
Activity input (journal, agent, processing, recovery) follows the same rule.
A local error affects its card/section; it does not make the whole Activity view
disappear.

Cards expose state-derived actions, not ad hoc network dialogs:

| State | Required presentation/action |
| --- | --- |
| Recoverable spool | Recovery retained; Finish saving |
| Saved, offline/retrying | Audio playback; Saved on this device; retry status; Retry now when the hard provider boundary permits |
| Transcript unavailable/failed | Audio playback; Retry transcription; Add reviewed text manually |
| Automatic transcript | Review check-in |
| Reviewed, parsing | Reviewed text; processing status |
| Parsed decisions | Resume decisions / Use to build plan |
| Draft queued/running | Durable progress; leave safely |
| Waiting for setup | Audio/text retained; open setup |
| Failed draft/refine | Audio/text retained; Retry; Back to decisions |
| Plan revision | Open exact generated revision; open current plan if different |
| Plan conflict | Compare candidates; choose one or create a merged resolution |

“Add reviewed text manually” stamps the same durable review operation and enters
the same intent-specific continuation as accepting an automatic transcript.
Consequently, a provider is never required to recover a saved recording into a
later manual plan-build flow. A user can leave after recording, return from the
Activity card, review/add text, resume decisions, and durably enqueue plan
creation.

All user-visible strings use ARB localization. Styling and status treatments use
existing design-system tokens/components. Semantics announce time, entry type,
durability/processing state, and actions; status is not color-only. Responsive
and text-scale tests cover phone and desktop layouts. Desktop tests also cover
keyboard traversal/activation and focus restoration to the originating card.
Status announcements are debounced to meaningful state changes, reduced-motion
settings suppress nonessential progress motion, and retry-count churn is not
announced.

### 15. Planner context adds a compact day-entry index, not duplicate text

Reviewed capture text already enters the compacted `<day_log>` through the
existing capture-event substrate. ADR 0031 does not inject it again, but it
does make that substrate strictly workspace-scoped.

`CaptureEventMeta` gains `dayId`. Before inline capture resolution, compaction,
or day-log assembly, the planner filters capture events to the resolved wake
`dayId`. Raw capture compaction/frontier state is keyed by planner agent **and
day workspace**, rather than one global capture stream for the long-lived
planner. Non-capture global observations remain separate. A planner may learn
about another date only through the existing bounded `<recent_days>`,
`search_memory`, or durable-knowledge paths; a foreign day's capture body must
never appear in the current `<day_log>`.

Every compacted agent-log checkpoint/summary gains a persisted scope:

```text
CompactionScope = globalObservations | dayCaptures(dayId)
```

Repository selection is by `(plannerAgentId, scope)`. The compactor never folds
capture text into `globalObservations` and never folds two day scopes together.
Within `<day_log>`, assembly is deterministic: the capture-free global
observation checkpoint/events first, then the selected day's checkpoint and
remaining capture events; each subsection retains its canonical event order.

Legacy unscoped/global checkpoints are considered potentially mixed and are
excluded from every new day wake. Migration rebuilds day checkpoints from
immutable captures filtered by `dayId` and rebuilds the global checkpoint only
from surviving non-capture observation messages. Derived prose that exists only
inside a legacy mixed checkpoint is not guessed apart and is omitted; durable
knowledge remains unaffected. Legacy checkpoint rows remain for audit and old
prompt replay, not live selection.

Old prompt records replay their already frozen ADR 0020 input/prompt bytes and
never substitute a newly scoped checkpoint. A legacy record lacking a complete
captured payload is marked non-reconstructable for diagnostics and is never
used as context for a new wake.

ADR 0028 is amended with a `<day_entries>` **provenance/status index** containing
only stable IDs, kind, timestamp, review/processing state, supersession, and
plan-revision usage. It contains no transcript body or excerpt.

- Canonical order: `(occurredAt, sourceTypeOrder, sourceId)`.
- Inline cap: newest 32 items and 4 KiB canonical encoded bytes, whichever is
  smaller; deterministic overflow count/cursor.
- Placement: after `<week_ahead>` and before the per-wake mode section in ADR
  0028's canonical order. It does not move or duplicate the stable
  prompt-prefix/day-log sections.
- Sanitization: use the shared prompt-section tag sanitizer and canonical JSON
  encoding inside the tag.
- Paging: a read-only tool lists/resolves more metadata by stable cursor/ID.
- Snapshotting: the exact index consumed by a wake is captured in the ADR 0020
  input frontier/prompt record. Replay does not re-read live status.
- Day filter: only the resolved wake `dayId`; pending entries expose no text and
  cannot be inferred from.

The index lets a later invocation identify reviewed-but-unused captures and
pending recordings without paying for duplicate transcript tokens.

### 16. Source/derived state sync; processing state stays on the source device

`JournalAudio` and its attachment use existing journal sync.
`CaptureEntity`, parsed items, plan revisions/heads, and existing day summaries
use agent sync.

Processing rows and effect receipts are device-local. This P1 does not claim
cross-device job exclusivity or peer inference convergence. Concurrent synced
journal edits continue through the journal conflict UI. Immutable agent inputs
and revisions use stable operation IDs. Day-plan heads and
`DayPlanConflictEntity` use the type-specific union/causal resolution rule in
Decision 7; generic LWW is not used for divergent current revision IDs.

A peer may play/export a synced attachment and may submit reviewed text; that
review syncs as immutable provenance and the recording device's reconciler
creates the continuation. Peer cards do not offer nonfunctional Retry/Build
actions and state that processing continues on the recording device. If that
device is unavailable, playback/export and reviewed text remain accessible,
but P1 does not silently turn the peer into an executor.

Cross-device automatic/manual executor takeover is an explicit non-goal until a
separate ADR defines a synced claim epoch and canonical result selection.

### 17. Migration is proof-based

Older Daily OS audio is assigned a day only when an existing
`CaptureEntity.audioRef` proves the association. Generic unlinked audio is never
assigned heuristically. Proven links receive deterministic legacy session and
Activity IDs derived from journal ID; they do not automatically enqueue new
inference.

Existing captures deserialize with null `dailyOsProvenance` and follow Decision
5's legacy classification. The migration never fabricates review operations,
intent, baseline, timezone, or continuation jobs. Existing
`refine_capture:*` rows specifically remain non-repairable historical refine
inputs.

Before any mutation, each existing `DayPlanEntity` receives Decision 7's
deterministic `legacySnapshot` revision and head pointer. Migration is
idempotent on every peer; concurrent legacy payloads remain conflict
candidates instead of being silently selected.

This is also an ingest normalizer, not only a one-time migration. Any later
old-peer `DayPlanEntity` with null `currentRevisionId` is converted to its
versioned semantic legacy revision before head comparison. Same semantic
payloads merge envelope clocks; a changed old-peer payload becomes a distinct
candidate in the day's fixed conflict register. Mixed-version sync therefore
cannot bypass revisioning.

The pre-ADR batch failure may have left audio files with no journal row. A
device-local **Recovered recordings** inbox scans only supported application
audio asset roots, subtracts every referenced asset, and offers playback plus
explicit day assignment. It never guesses that an orphan is Daily OS data.
Assignment preallocates a session/day context and commits the existing file as
a deterministic JournalAudio/source job; Ignore merely hides the candidate
locally and does not delete it. Physical deletion remains an explicit user
action.

## Required invariants and verification contract

The implementation and tests must prove:

1. after a reported Saved state, a valid playback artifact, `JournalAudio`, day
   association, and transcribe job/output exist;
2. every non-cancelled source satisfies the durable continuation invariant in
   Decision 12;
3. at most one current owning-database claim generation can transition a job;
4. a worker that loses its generation/token cannot publish a new effect or
   transition a job based on stale ownership, including across reclaim and
   process death; idempotent reconciliation from a validated receipt is the
   only lease-free completion path;
5. replaying a completed job observes its effect receipt and never repeats
   nondeterministic inference;
6. separate operations remain separate plan revisions even with identical
   content, while retrying one operation does not duplicate history;
7. entries from one `dayId` never leak into another day wake;
8. automatic transcripts never enter planner input before review and never
   replace reviewed history;
9. Activity remains locally enumerable and last-data-preserving offline;
10. prune/delete cannot remove a source required by recovery or non-terminal
    work; and
11. cross-store repair converges to exactly one semantic job/output per
    operation ID;
12. every plan mutation advances `currentRevisionId`, so a job completing from
    any stale manual/generated baseline branches instead of overwriting it; and
13. concurrent conflict resolutions and late candidates converge under the
    append-only frontier rule; and
14. conflict/revision merge is commutative, associative, idempotent, and
    permutation-invariant, including missing-ancestor backfill.

The implementation plan requires meaningful coverage of every new production
branch, legal state transition, recovery outcome, and user action in addition
to these invariants. In particular, a two-day fixture must assert that the
foreign reviewed transcript is absent from both `<day_log>` and
`<day_entries>`, not merely that the selected day's entry is present.
Backward old-JSON/old-peer round trips, every legacy classification branch,
deterministic legacy plan snapshots, source ordering ties, and scoped-compaction
migration are part of this coverage contract.

Queue/state-machine and ID/repair invariants use Glados with the mandatory
`glados` tag and bounded run count. Orchestration uses fake clocks/jitter,
`fakeAsync`, scripted transports, temporary asset roots, and in-memory Journal
and Agent databases. No test uses real delays/timers or `DateTime.now`.

The deterministic crash harness injects failure after each flush/rename,
manifest publication, journal/job insert, VC commit, transcript update, review
write, owning-DB claim creation, Journal claim mirror, cancellation fence,
replacement prepare, owning-DB supersession fence, replacement activation,
AgentDb output/receipt commit, receipt reconciliation, JournalDb
acknowledgement, and plan-conflict resolution commit.
A small real-device integration layer covers OS process death and airplane/
shaped-network behavior. Widget tests use centralized mocks/fallbacks,
`makeTestableWidget`, meaningful state/action assertions, accessibility, and
phone/desktop text-scale coverage. Test paths mirror production sources.

Network scenarios explicitly cover fully offline, slow response, disconnect
after provider acceptance but before client acknowledgement, intermittent
flapping/repeated connectivity hints, `Retry-After`, provider timeout, and a
large paged queue with fairness. Resolver properties permute candidate arrival,
duplicate envelopes, same-payload/different-clock legacy migration, different
legacy payloads, concurrent resolutions, late candidates, and ancestor
backfill. Supersession crash cases inject after prepare, after the owning fence,
and before/after activation, asserting preservation of the immutable prepared
descriptor, at most one claimable job, and exactly one durable continuation.

One named end-to-end acceptance scenario is mandatory: record fully offline;
observe Saved plus playable audio; kill/restart; let transcription remain
unavailable; add reviewed text manually; repair the deterministic capture and
intent-specific continuation; resume decisions; enqueue draft; kill/restart;
then observe the revision/head while the original audio remains visible
throughout. Separate parameterized concurrency tests enqueue a job, apply each
plan mutation kind, complete the stale job, and assert conflict/branch with no
user edit overwritten.

## Consequences

### Positive

- Poor connectivity can delay assistance but cannot erase acknowledged audio.
- Recording, sync, processing, and execution have separate inspectable owners.
- Review keeps automatic text out of planner memory until the user confirms it.
- Owning-database claim generations and effect receipts close
  restart/ABA/nondeterministic retry gaps.
- Activity remains useful offline and makes entry-only days discoverable.
- Operation-addressed revisions provide navigable generated-plan history.

### Negative and trade-offs

- A shared durable PCM spool and recovery service are substantial speech-layer
  work.
- `JournalDb` gains source metadata/indexing, processing rows, migrations, and a
  specialized vector-clock-aware transaction.
- AgentDb gains plan revisions/conflicts plus local effect claims and receipts.
- Cross-store repair is required because journal and agent databases cannot
  transact together.
- The Day shell joins multiple local stores and must preserve partial data.
- Peer processing is intentionally deferred; a synced peer can view/play data
  but cannot take over inference in this P1.
- Legacy mixed-scope compaction prose that cannot be separated from raw source
  messages is intentionally omitted from new wakes to prevent cross-day leaks;
  old frozen prompt records remain auditable.
- Full deterministic crash/state-machine coverage is expensive and accepted
  because the input is irreplaceable.

## Rejected alternatives

### Persist only a file path in controller state

Route-scoped state is not durable, queryable, restart-safe, or synced.

### Keep current ordering and add Retry

Retry cannot recover audio that never received a source/day entity or an
in-memory wake lost at restart.

### Put inference jobs in the Matrix outbox

Transport acknowledgement is not inference completion. Mixing them would leak
device credentials/availability into sync semantics and make retries unsafe.

### Persist generic manual wakes only

A generic wake cannot prove source-specific expected output. The processing
outbox owns semantic completion and rehydrates a `WakeJob` only as execution.

### Create automatic/mutable `CaptureEntity` rows

That would turn immutable reviewed ADR 0020 input into an LWW register and risk
unreviewed text entering compaction/planner memory.

### Use content-only plan revision IDs

They collapse separate user actions that happen to return identical plans and
do not prevent nondeterministic retries from producing multiple results.

### Add one generic synced `DayEntryEntity`

Existing authoritative sources already carry voice, reviewed text, summaries,
and revisions. Duplicating them creates deletion/repair/convergence ambiguity.
Activity is a projection over those sources.

### Allow peer takeover now

Existing LWW rules do not make provider output converge. A safe takeover design
needs its own synced claim/result-selection decision.

### Duplicate transcript text in `<day_entries>`

Reviewed text is already in `<day_log>`. Duplication wastes prompt budget and
can present inconsistent versions.

## Related

- [ADR 0013: Outbox Priority Queue & Sync Observability](./0013-outbox-priority-queue.md)
- [ADR 0016: Agent State as Log Projection](./0016-agent-state-as-log-projection.md)
- [ADR 0018: Convergent Multi-Device Execution](./0018-convergent-multi-device-execution.md)
- [ADR 0020: Agent Input Capture](./0020-agent-input-capture.md)
- [ADR 0022: Long-Lived Daily OS Planner](./0022-long-lived-daily-os-planner.md)
- [ADR 0028: Tagged Plaintext Planner Payload and Day Summaries](./0028-tagged-plaintext-payload-and-day-summaries.md)
- [Implementation plan](../implementation_plans/2026-07-18_resilient_day_planning_capture_and_timeline.md)
