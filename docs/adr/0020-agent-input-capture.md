# ADR 0020: Agent Input Capture — Per-Source Content-Addressed Snapshots

- Status: Proposed
- Date: 2026-05-30

## Context

The agent is a log, and its derived state is a projection of that log (ADR
0016). For the projection to be a *pure function of the log* — and therefore for
deterministic replay, replay-from-summary equivalence (ADR 0017), and
cross-device convergence (ADR 0018) to hold — the inputs the agent reasoned over
must live **in the log**, not be re-read from mutable external state at fold
time.

User-generated content the agent needs to know about — task titles,
descriptions, checklist items, comments, audio transcripts, image-analysis
results — lives in the **journal domain**, which has its own convergence model
and a user-facing `Conflict`-row resolution path (losing user-authored content
silently is unacceptable). The agent **references** that content; it does not
own it.

If an agent's log event only *references* a journal entity (by id), replay
re-reads whatever that entity says *now* — which may have been edited or deleted
since the wake. The fold then depends on mutable external state and stops being
pure: replay can diverge from history, provenance is lost ("what text actually
produced this proposal?"), the on-device prompt-prefix cache is busted by every
cosmetic edit, and the agent's *input* becomes coupled to the journal domain's
conflict resolution.

The codebase already snapshots in one place — the Daily OS capture flow stores
the transcript in a `CaptureEntity` — and the schema already has the right
primitive: `AgentMessagePayloadEntity` (a normalized large-content payload),
referenced via the `messagePayload` link, with `contentEntryId` pointing back at
the originating journal entity. The open decision is whether to generalize
snapshotting to all agent inputs (notably **task and project agents** reading
task content), and at what granularity: reference-only vs. a whole-rendered
context blob vs. per-source payloads.

## Decision

1. **Capture inputs into the log; never reason from a live reference at replay.**
   When an agent consumes user content during a wake, the exact text it fed the
   model is recorded as append-only payloads in the agent log. The projection
   folds the log alone; it never re-reads the journal domain to reconstruct what
   an agent saw.

2. **Per-source, content-addressed payloads — provenance on the reference, not
   the payload.** Each distinct source — a task description, each comment, each
   transcript, each image-analysis result — is stored once as an
   `AgentMessagePayloadEntity` keyed purely by its `contentDigest` (the
   canonical-form content hash defined in ADR 0017 / §6: sorted keys, RFC 3339
   UTC, normalized numbers, canonical JSON, versioned tag). The payload holds
   **content only — no originating-entity identity** — so identical content
   dedupes to a single row across wakes *and* across agents. **Provenance lives
   on the reference**: the consuming message (and its `messagePayload` link)
   carries `contentEntryId` → the originating journal entity. The same shared
   payload is therefore pointed at by many links, each with its own provenance,
   so multi-entity provenance is preserved — a single `contentEntryId` field on
   the shared payload could not, and is deliberately *not* where it lives.
   Storage grows with the number of *distinct content versions observed*, not
   with wakes or agents.

3. **Per-wake input frontier.** Each wake records the **ordered set** of source
   payload hashes it consumed (the `messagePayload` references on that wake's
   message). This frontier is what makes the model context reconstructible
   byte-for-byte for both replay and the prefix cache.

4. **Canonical assembly order — from in-log metadata.** The rendered prompt
   context is assembled from the frontier in a fixed, replica-independent order —
   never insertion or arrival order — so two devices and a replay produce
   byte-identical prompts and the stable prefix keeps cache-hitting. The sort key
   is the source's `createdAt` then `id` **captured into the log at capture
   time** (snapshotted onto the `messagePayload` link / message), **not** a live
   read of the journal entity — which could be edited or deleted. Like the
   content itself, the ordering is thus a pure function of the log (Decision 1).

5. **Capture the rendered context, not unbounded raw history.** The agent
   captures the derived text it actually fed the model (a transcript, an
   analysis result, the task's rendered section). Heavy raw artifacts (long
   audio, large images) stay *referenced + hashed* in the journal domain; only
   their derived text enters the agent log. This bounds capture by the prompt
   budget and records the true provenance (what produced the output).

6. **Retention and coverage are shared with compaction.** A per-source payload
   is retained while any non-compacted event references it; a summary records
   the source payloads it covers as part of its frontier coverage. This reuses
   ADR 0017's frontier/coverage machinery rather than introducing a new one.

## Consequences

- **Deterministic replay & provenance.** The fold is a pure function of the log;
  "why did the agent propose X" is answerable from the exact captured text, and
  the sources/versions behind a decision are explicit and diffable between
  wakes.
- **Convergence with no LWW on inputs.** Captured payloads are append-only,
  content-addressed events → they converge via the projection kernel (ADR 0018
  rule 1). The agent never last-writer-wins user content; the journal domain
  keeps its own convergence and `Conflict` UI, and the agent only references +
  snapshots it.
- **Storage is bounded** by distinct-versions × edits (not wakes), with
  compaction folding old payloads away — which is what makes "full capture"
  affordable. Per-source dedup is strictly better here than a per-wake blob,
  which would re-store the entire context on any single-byte edit.
- **Stable prompt prefix** for KV-cache reuse follows from canonical assembly
  order (rule 4), independent of storage granularity.
- **Cost:** per-wake input-frontier bookkeeping, canonical-assembly discipline,
  and retention coupling with compaction — all built on the existing
  payload/link + frontier primitives, so no new mechanism.

### Rejected alternatives

- **Reference-only.** Breaks replay purity, loses point-in-time provenance,
  couples agent inputs to journal-domain conflict resolution, and busts the
  prefix cache on every edit.
- **Whole rendered-context blob per wake.** Any single-byte change to any source
  yields a new blob hash → re-stores the entire context, defeating dedup at the
  granularity edits actually occur, and collapses per-source provenance into an
  opaque lump. The per-wake input frontier (rule 3) already gives deterministic
  reassembly, so the blob has no remaining advantage.

## Related

- ADR 0016 (agent state as log projection) — this extends the projection thesis
  from derived *state* to the agent's *inputs*.
- ADR 0017 (deterministic log compaction) — shares the `contentDigest` /
  frontier / coverage machinery.
- ADR 0018 (convergent multi-device execution) — captured inputs are append-only
  and converge via the kernel; user content itself stays on the `Conflict` path.
- Roadmap: [PR 4 plan — state-as-projection](../implementation_plans/2026-05-30_state_as_projection_plan.md)
  (covers derived *state*; this ADR is its input-side companion) and PR 5
  (compaction) are where this lands; generalizes the existing Daily OS
  `CaptureEntity.transcript` snapshot to task and project agents.
