# ADR 0106: The Task Link Graph Across Devices

- Status: Accepted
- Date: 2026-09-27

## Context

[ADR 0096](./0096-an-entry-link-is-its-natural-key.md) settles one link:
every device keeps the same version of each `(fromId, toId, type)`, and a
removal sticks. It says nothing about what the links mean together. Two
kinds of task link carry a rule about the whole graph.

**`blocks` links** must not form a cycle.
[ADR 0042 §5](./0042-typed-task-relationship-links.md) guards creation with a
local traversal and accepts that two offline devices can close a cycle
anyway: each writes one direction, and both arrive everywhere. It promised
that such a cycle is then *visible*, "surfaced in the UI as a mutual block".
Three things fell short of it:

1. **The check and the write were two steps.** `PersistenceLogic.createLink`
   ran `wouldCreateBlocksCycle` and then, several awaits later, wrote the
   link, outside any transaction. The user and the task agent's link tool
   write on the same device at the same time; each check passed before the
   other's write, and together they closed a cycle on one device.
   `JournalRepository.updateLinkType`, which retypes or turns a link around,
   had the same gap, and built the new version from the link as it read it:
   a link removed in between came back, retyped.
2. **The check stopped after 64 hops.** A cycle closed through a longer
   chain was not seen.
3. **Nothing reported a cycle.** Each task on it showed "Blocked by 1 task",
   and the day agent was told to schedule a task's blocker first — which was
   blocked by that task.

**Project links** give a task at most one project. `linkTaskToProject`
removes the task's link to its old project in the transaction that writes
the new one, but two devices that file the task under different projects
while offline each write a link, and both arrive. Every device then shows
the same one — `_projectIdSubquery` and `projectLinkForTask` pick the live
link with the latest `updatedAt`, then the greatest id, a function of the
stored rows — and the other stays live underneath it. The writes read only
the one shown:

4. **An unfile removed the link shown and let the other take its place.**
   The task left one project and appeared in the other.
5. **Filing the task under the project underneath did nothing.**
   `_newProjectLink` found that link live and returned null, so the move
   wrote nothing and reported failure.
6. **A move could lose to the link underneath.** The new link is stamped
   with this device's clock; a link underneath stamped later by a device
   whose clock runs ahead still outranks it, so the task stayed where it
   was.
7. **Privacy cleanup** (`unlinkTaskFromProject(onlyIfPrivacyMismatched:)`)
   checked only the link shown, and left a mismatched link underneath.

`specs/tla/TaskLinkGraph.tla` models three tasks and their projects on two
devices, the user and the agent writing at once on one of them, tasks
closing, and every version delivered in any order. With the old behaviour
TLC finds each of the first six in three to six steps (README).

## Decision

1. **A cycle is kept and reported, not broken.** A cycle that two devices
   close is two decisions a person made, each sound where it was made. The
   alternative — a deterministic rule that treats one link of each cycle as
   inactive, the same on every device — would show a task as ready while its
   Linked Tasks card still says it is blocked, and would pick the link to
   ignore by an order that means nothing to the user. Keeping both follows
   ADR 0042 §5: every task on the cycle stays blocked, closing or deleting
   any of them releases the task it blocks, and the readers say why.
   `findBlockersInCycle` follows live `blocks` links forward from each
   blocked task through tasks that still block — open, or not synced yet —
   and marks a blocker the task reaches back. It reads only stored links and
   statuses, so every device that holds the same rows reports the same
   cycles. `TaskBlockersController` carries the marked blockers as
   `cycleBlockerIds`, and the task header's chip reads "Blocked in a cycle";
   `TaskDependencyResolver` serializes `"cycle": true` on the blocker, and
   the day agent's blocked-work rules say that neither task can go first.
   Blockedness itself stays one hop (ADR 0042 §4).
2. **The cycle check runs again inside the write's transaction.**
   `createLink` checks once before it reserves a clock, as a fast path, and
   again in the transaction that upserts the link. `updateLinkType` checks
   the occupant and the cycle the same way, and requires the link to be
   stored as it read it; `JournalRepository.updateLink` takes that
   `precondition`. Drift runs one transaction at a time, so a second writer
   on the device sees the first one's link and writes nothing.
3. **The cycle check follows every path.** The visited set bounds the
   traversal by the tasks the chain reaches; the depth cap is gone.
4. **A project write takes out every live link it replaces.**
   `linkTaskToProject` retires every live link of the task to another
   project in the transaction that files it, and when a live link to the
   target is among them, keeps that one instead of writing a second. An
   unfile retires every live link; privacy cleanup every link whose project
   differs in privacy from the task. The transaction first checks the task's
   live links are still the ones read (`getLiveProjectLinksForTask`), and
   writes nothing if they moved. Which link shows is unchanged: the latest
   `updatedAt`, then the greatest id.

## Consequences

- One device never writes a `blocks` link that closes a cycle it holds
  (`NoLocalCycle`); once every version has arrived, a cycle needs links from
  two devices (`OneWriterAcyclic`).
- A cycle is reported the same way on every device, and closing any task on
  it releases the task after it (`CycleSurfaced`, `ReleaseOnClose`). Nothing
  is written to break it; the user closes a task or removes a link.
- Reading a task's blockers reads further when the task has any: the cycle
  report follows the links one batch per hop. The task page watches every
  task that search read, so closing one on the cycle refreshes it.
- Tasks already in two projects, and cycles already stored, need no
  migration: the reads were already the same on every device, and the next
  move or unfile of such a task takes out every link. Existing cycles show as
  cycles.
- Once every version has arrived, every device shows a task in the same
  project or in none (`AtMostOneProject`), never through a link a move or
  unfile of it had seen (`ProjectWriteSticks`), and the device that files a
  task shows it there (`FilingShows`).
- Residual: two devices that file the task under different projects
  concurrently still both write, and the later `updatedAt` shows. That is
  the order of concurrent writes elsewhere in sync, and the next move
  removes the other.

## Model

`specs/tla/TaskLinkGraph.tla`: `TaskLinkGraph` (blocks links, 9,213,523
distinct states), `TaskLinkGraphProjects` (163,378) and
`TaskLinkGraphProjectsThree` (1,384,808).

| Switch | FALSE restores | Counterexample |
|---|---|---|
| `AtomicCheck` | the check outside the write | `NoLocalCycle`, three steps: the agent's check of t2 → t1 passes, the user creates t1 → t2, the agent writes |
| `Uncapped` | a depth cap (one hop in the model, 64 in the code) | `NoLocalCycle`: t1 → t2, t2 → t3, then t3 → t1 passes the check |
| `DetectCycle` | no cycle report | `CycleSurfaced`: one device writes t2 → t1, the other t1 → t2, one delivery |
| `RetireAll` | a move or unfile takes out only the link shown | `ProjectWriteSticks`, five steps: the devices file the task under p1 and p2, one receives the other's link and unfiles, the other's link shows everywhere. `FilingShows`, four steps: filing under the project underneath does nothing; and with three projects, a move shows the old project when the link underneath is stamped later |

`ReleaseByStatus` and `DeterministicWinner` are not fixes; FALSE shows their
properties can fail. The Dart conformance trace (`blocks_cycles_test.dart`)
runs the real writers against two in-memory databases, and each fix reverted
fails it.

## Related

- [ADR 0042](./0042-typed-task-relationship-links.md): typed links, one-hop
  readiness, and the cycle policy this implements
- [ADR 0043](./0043-dependency-aware-planning.md): the day agent's
  blocked-work rules
- [ADR 0096](./0096-an-entry-link-is-its-natural-key.md): one link's
  identity, which this builds on
- `specs/tla/TaskLinkGraph.tla`, `specs/tla/README.md`
- [Typed relationships and blockedness](../../knowledge/features/tasks/relationships.md),
  [Projects](../../knowledge/features/projects.md)
