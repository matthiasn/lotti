# ADR 0128: Deletions Stick Across Purges, Retypes, Restores and Backfill

- Status: Accepted
- Date: 2026-10-10

## Context

ADR 0095 made a purge keep a journal entry's deletion as a tombstone, and
ADR 0096 gave each entry link one identity per `(from, to, type)`. Four
paths still let a deletion or a lost version come back, or cost work
every round:

- **A purge hard-deleted dashboards and measurable types.** Since ADR 0125
  their rows carry the clock that refuses an older copy, so removing the
  deleted row let any late copy write the definition back. Categories,
  labels and habits were never purged and kept their deletions.
- **A link version that lost its triple left no trace.** When a retype
  (`JournalRepository.updateLinkType`) moved a link's id onto a triple
  another id held with a newer version, the moved version lost and its old
  row went too. A late copy of that id from before the retype then found
  no row and was inserted again at the triple it had left. A holder
  displaced by a newer version had the same gap once the winner moved on.
- **The relationship dispatcher could not restore its own task.** It
  derives a task's id from the commitment, so a retried or synced
  confirmation meets the same row. It read that row with a lookup that
  hides deleted rows, so the restore branch for a task undo had deleted
  was unreachable, and a create under the id replaced the tombstone with a
  clock that did not cover it. Once a purge compacted the task to a plain
  tombstone, restoring "the task" under that id was a re-creation under a
  reused id, which every peer shows as an edit concurrent with the
  deletion.
- **Deep backfill asked for agent records the requester would refuse.** A
  device that recorded an agent's deletion (ADR 0108) refuses every record
  of that agent, so it requested the same records again every round.

## Decision

- **A purge removes no row.** It compacts deleted journal rows to their
  tombstones, as before, and leaves deleted definitions as the rows their
  deletion wrote. Its progress is one step.
- **A version that loses its triple is remembered under its id** in
  `entry_link_losses` (journal schema 53), whether it is the incoming
  version or the holder it would have displaced. An incoming version for
  an id with no row is refused unless it is newer than the remembered
  loser; a newer one (the user linking again) clears the memory and takes
  a row.
- **The dispatcher reads deleted rows when it derives a task id, and
  passes over any deleted row** — the task undo removed, or the tombstone a
  purge compacted it to — for the next generation of the id (the seed plus
  a generation number), as it does a row that is no task. The choice rests
  on whether the row is deleted, which replicates, never on its shape,
  which a purge changes on one device only: a replica that restored the
  deleted task while another, having purged it, moved on would keep two
  live tasks for one proposal. The task is a plain creation everywhere.
  After sixteen generations the proposal fails permanently.
- **Inventories name the agents of agent records.** `DeepBackfillRecord`
  gains an optional `agentIds`: an agent entity lists its agent, an agent
  link both ends. The requester drops a missing or older record whose
  agents include one it holds a deletion of. The field is left out of the
  JSON when absent, and a peer that predates it is requested from as
  before.

## Consequences

- A deleted dashboard or measurable type keeps a row for good, as every
  other definition already did. They are few and small.
- `entry_link_losses` grows by one row per lost triple, and shrinks when a
  newer version of the id arrives.
- A relationship task undo removed is never brought back under its old
  id; a new confirmation creates a sibling id that every device derives
  the same way.
- Older builds still send records of deleted agents and request them;
  only the requester's side changed, which is the side that pays.
