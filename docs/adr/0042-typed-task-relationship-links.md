# ADR 0042: Typed Task Relationship Links

## Status

Proposed

## Date

2026-07-23

## Context

### Tasks relate to each other, but the link model cannot say how

Lotti links journal entities through `EntryLink`
(`lib/classes/entry_link.dart`), a freezed union with three variants —
`basic`, `rating`, `project` — persisted in the `linked_entries` table.
`BasicLink` is deliberately semantics-free: it means "belongs with", and
that vagueness is load-bearing. Basic links attach time entries, audio,
images, and comments to tasks; recorded-time attribution
(`basicLinksForEntryIds` → `resolveTimeEntries`) walks them to credit
tracked time to tasks and categories; the task detail page renders them as
the linked-entries timeline; capture parsing attaches phrases to tasks
through them.

What the model cannot express is a *directed semantic relationship between
two tasks*: this task cannot start until that one finishes; this task is a
follow-up spawned by that one; these two are the same work filed twice;
this task fixes a defect that task tracks; this task replaces that obsolete
one. Every mainstream task system models some subset of these (Jira:
blocks / is blocked by, duplicates, causes, clones; Linear: blocks,
related, duplicate of; GitHub: fixes/closes; Beads: blocks/depends-on,
parent-child, relates-to, duplicates, supersedes). Without them:

- The planning agents' task corpus is a flat open/due list
  (`DayAgentCorpusService.buildTaskCorpusSnapshot`), so a day plan can
  schedule "Deploy release" before "Fix the blocker" — nothing in context
  says B waits on A (consumed by ADR 0043).
- The user has a manual `TaskStatus.blocked`, but it is a self-declared
  flag with no machine-readable cause: nothing identifies *what* blocks the
  task, nothing clears it when the blocker closes, and agents can only echo
  it back.
- Duplicate and superseded work accumulates silently; closing the canonical
  task does nothing visible to its twins.

### What already exists that typed links can reuse

The storage and sync substrate needs **no schema change**:

- `linked_entries` already has a `type TEXT NOT NULL` column, a
  `UNIQUE(from_id, to_id, type)` constraint, and indexes on `from_id`,
  `to_id`, `type`, and `(to_id, type)`. The type column is derived from the
  union variant on write (`linkedDbEntity`: `'BasicLink'`, `'RatingLink'`,
  `'ProjectLink'`), so precedent exists for multiple coexisting link types
  between the same pair.
- Consumers are already type-scoped: `basicLinksForEntryIds` filters
  `type = 'BasicLink'` at the SQL layer, so time attribution, the
  linked-entries timeline, and capture attribution are structurally
  invisible to any new type. Nothing leaks by construction.
- Creation, vector-clock stamping, outbox sync (`SyncMessage.entryLink`),
  and change notifications all run through `PersistenceLogic.createLink` /
  `JournalDb.upsertEntryLink`, which handle `EntryLink` generically.
- `EntryLink` is declared `@Freezed(fallbackUnion: 'basic')`: an older
  build receiving an unknown variant over sync deserializes it as a plain
  `BasicLink` instead of crashing — unknown semantics degrade to a visible
  generic link.

## Decision

### 1. New `EntryLink` union variants, not a field on `BasicLink`

Task relationships become first-class union variants:

| Variant      | Reading (from → to)              | Inverse rendering    |
| ------------ | -------------------------------- | -------------------- |
| `blocks`     | *from* blocks *to*               | *to* is blocked by *from* |
| `followsUp`  | *from* follows up on *to*        | *to* has follow-up *from* |
| `duplicates` | *from* duplicates *to* (canonical) | *to* is duplicated by *from* |
| `fixes`      | *from* fixes *to* (the defect)   | *to* is fixed by *from* |
| `supersedes` | *from* supersedes *to* (obsolete) | *to* is superseded by *from* |

Each variant carries the same shape as `BasicLink` (id, fromId, toId,
timestamps, vector clock, hidden/collapsed, deletedAt) — the semantics live
entirely in the type. Rationale for variants over a `linkType` field on
`BasicLink`:

- The `type` column derives from the union map, so every existing
  `type = 'BasicLink'` consumer stays correct without an audit — a field
  would put typed edges *inside* the basic result set and require touching
  every basic-link read (time attribution above all) defensively.
- `fallbackUnion: 'basic'` gives forward compatibility for free: an old
  build shows an unknown typed edge as a plain link (see Consequences for
  the write-back caveat).
- `UNIQUE(from_id, to_id, type)` naturally allows a pair to hold a basic
  link *and* a `blocks` edge simultaneously, and dedupes repeated
  assertions of the same relationship.

### 2. One stored edge per relationship; inverses are rendering

"Is blocked by", "has follow-up", "is duplicated by" etc. are **labels for
the reverse direction of the same row**, never separate rows. Both
directions are queryable through the existing `from_id` and `(to_id, type)`
indexes. The UI offers both phrasings when creating a link and simply swaps
`fromId`/`toId` before persisting the canonical direction.

### 3. `relates to` stays `BasicLink`; hierarchy stays out

- A generic "these are related" association is exactly what `BasicLink`
  already is between two tasks. No new `relatesTo` variant.
- **No cross-task parent/child variant.** Sub-structure inside a task is
  checklists; grouping across tasks is categories and `ProjectLink`. A
  parallel task-hierarchy edge would compete with both. Revisit only if
  projects prove insufficient.
- `causes`/`clones` (Jira) are deferred — no consumer in the app would read
  them today.

### 4. Ready semantics: derived, one hop, status-aware

A task is **ready** iff it has no live blocker:

> no non-deleted `blocks` link with `toId == task` whose `fromId` task is
> neither tombstoned (`deletedAt` set) nor closed (`DONE`/`REJECTED`, the
> `isClosedTask` predicate).

An **unresolvable blocker keeps blocking**: when the link row exists but
the `fromId` task cannot be loaded (typically a sync gap — the link
arrived before its task), the dependent stays blocked until the task
materializes or the link is deleted. Journal entities tombstone rather
than hard-delete, so a *deliberately* deleted blocker carries `deletedAt`
and releases its dependents; only a genuinely unresolved reference blocks
conservatively. The resolver tests must pin all three cases (closed →
released, tombstoned → released, unresolvable → blocked).

- Readiness is **derived at read time, never stored**. Closing a blocker
  "releases" its dependents implicitly on every device — no unlock write,
  nothing to converge, no sync race.
- One hop only: a task with an open blocker is blocked; transitive chains
  emerge naturally because the blocker itself stays unready until its own
  blockers close. (Chain *display* may traverse; readiness never needs to.)
- The `hidden` flag stays a pure UI affordance and does not affect
  readiness; `deletedAt` tombstones do.
- The manual `TaskStatus.blocked` **coexists and is never mutated by the
  link layer**. It remains the user's self-declared flag (blocked on
  something outside the system); link-derived blockedness is computed and
  names its cause. The two enrich each other without coupling: when the
  user sets the status to blocked, the UI *offers* to name the blocking
  task (which persists a `blocks` edge) — optional, never required, since
  many blocks are external (waiting on a person, a delivery, a decision).
  Conversely, creating a blocking link may *suggest* the status. No
  automation writes task status from links in either direction.

### 5. Cycles: guarded at creation, tolerated at read

Concurrent offline writes on two devices can always create a cycle
(A blocks B on one device, B blocks A on the other), so cycles cannot be
prevented — they must be survivable:

- **Creation-time guard (best effort, local):** creating a `blocks` edge
  runs a bounded local traversal and rejects the write if it would close a
  cycle visible on this device.
- **Read-time tolerance:** all traversals use a visited set and a depth
  cap. Members of a cycle each have an open blocker, so all of them are
  unready — the deadlock is made *visible* (surfaced in the UI as a mutual
  block), never hidden or "resolved" silently.

### 6. Lifecycle semantics are suggestions, not automation

- Closing a task that others `duplicate` → the UI offers to close the
  duplicates; nothing auto-closes.
- Creating a `supersedes` edge → the UI offers to close the superseded
  task; nothing auto-closes.
- `fixes`/`followsUp` carry no lifecycle coupling; they are navigation and
  context.

This keeps the user the only writer of task status (consistent with the
ChangeSet philosophy of ADR 0006: agents and derived systems propose, the
user disposes).

## Consequences

- **No migration.** Purely additive: new union variants, new type-column
  values, existing rows untouched, existing queries unaffected.
- **New read surface needed:** a type-scoped batch query (typed links for a
  set of task ids, both directions) mirroring `basicLinksForEntryIds`,
  served by the existing `(to_id, type)` and `from_id` indexes.
- **Old-build degradation is bounded but real.** An old build folds an
  unknown variant to `BasicLink` (fallback union) and *displays* it as a
  generic link — acceptable. If that old build then **mutates** the link
  (hide, collapse, delete), it re-serializes it as `basic`, permanently
  down-typing the edge for everyone. Links are rarely mutated after
  creation, and the same exposure already exists for every new
  `AgentDomainEntity` variant; accepted, documented here, mitigated by
  shipping the model variants at least one release before any UI writes
  them (standard rollout ordering).
- **The typed vocabulary is closed by design.** Five verbs cover the
  standard task-system semantics; anything fuzzier belongs in `BasicLink`
  or in text. Growing the vocabulary requires an amendment here, not an ad
  hoc string.
- Planning integration (ready frontier in the agent corpus, directive
  rules) is deliberately split into ADR 0043 — this ADR is complete without
  it, and the link layer must not depend on the agents feature.

## Related

- ADR 0003 — linked-context contract (the read pattern typed links extend).
- ADR 0006 — user-as-final-validator, mirrored by decision 6.
- ADR 0032 — hierarchical day-agent coordination (the consumer side's
  architecture).
- ADR 0043 — dependency-aware planning (the ready frontier consuming these
  edges).
- Implementation plan:
  `docs/implementation_plans/2026-07-23_task_dependency_links.md`.
- Prior art: Jira link types, Linear relations, Beads
  (github.com/steveyegge/beads) — the blocks/ready-frontier model for
  agent-facing task graphs.
