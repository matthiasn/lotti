# ADR 0100: A Deleted Default Stays Deleted

- Status: Accepted
- Date: 2026-09-27
- Amends: [ADR 0081](0081-model-checked-evolution-sessions-and-agent-links.md) (addendum, "A row built afresh over a removed one always brings it back")

## Context

The app seeds seven default agent templates (Laura, Tom, Project Analyst,
Scribe, Shepherd and the two improvers), six default souls and three default
soul assignments under well-known ids, at every start
(`AgentTemplateSeeding.seedDefaults`, `SoulTemplateOps.seedDefaults`). A
seed asked the typed reads whether the default existed, and those reads hide
a tombstone. So:

1. **A default the user deleted came back at the next start.** The seed
   found no row and built the default afresh over its removal. Under ADR
   0081's addendum a row built afresh over a tombstone is a re-creation that
   succeeds the removal, so the default came back on every device.
2. **A soul the user unassigned or replaced was assigned again.** The
   assignment pass ran `assignSoulToTemplate` for every default pair at every
   start, which removes any other assignment of the template. Pointing Laura
   at the Max soul lasted until the next start.
3. **A device that had not yet received a deletion undid it.** A seed was
   stamped at the wall clock. A device that started after the deletion, but
   before the deletion reached it, wrote a version concurrent with it, and
   last-writer-wins gave the seed the later instant — the deletion lost on
   every device. The seed of a device whose clock ran ahead did the same to a
   rename made concurrently.

ADR 0081 left whether a deleted default should stay deleted to a product
decision; `specs/tla/README.md` listed it as a residual of
`AgentReplication`.

## Decision

The user's choice about a seeded default is respected on every device.

1. **A default is seeded only where no row for its id is stored — a removed
   one included.** The template and soul seeding read with
   `getEntityIncludingDeleted`. Any stored row under the id, of any variant,
   means the default was created here once and is not the seed's to touch. A
   default that a later release adds has no row yet and is seeded as before.
2. **A default assignment is made only for a template that has never had a
   soul assignment**, a removed one included (`AgentRepository.hasAnyLinkFrom`),
   and only while the template and the soul both exist. The seed no longer
   repairs or overwrites an assignment.
3. **A seed is stamped at `agentSeedInstant`, the epoch** — the template row,
   the soul document row and the assignment link, which are the rows under a
   well-known id. Every write a user makes carries a later instant, so a
   deletion, an edit, an unassignment or a reassignment concurrent with a
   seed wins over it on every device. The version and head rows of a seeded
   template or soul keep the current instant, which the version history
   shows.
4. **The seeded assignment has a deterministic id,**
   `seededSoulAssignmentLinkId(templateId)`. Every device seeds the same
   link, so one removal of it removes every device's seed; before, each
   device minted its own, and a removal covered only the ones its device had
   received.
5. **The seeded assignment yields to any other assignment of its template**
   (`AgentRepoLinks.upsertLink`). Devices on older builds hold their default
   assignment under a random id, so a user's reassignment or unassignment
   there is not a version of the seeded link and last-writer-wins never
   compares the two. A live seed that arrives where the template has another
   assignment row, live or removed, is not stored; any other assignment row
   written for the template retires a live seed, stamping the removal at
   `agentSeedInstant` so every device stores the same row.
6. **The check and the seed share one transaction.** Sync runs before
   seeding at startup; a peer's deletion received between a check that found
   nothing and the write would otherwise be overwritten by a row built
   afresh, which the local write resolution takes as a re-creation.

`specs/tla/AgentReplication.tla` gains a fourth kind, `"seeded"`: a row that
starts absent, is seeded by any replica, and is edited and deleted by the
user through the typed reads, and the `Seed` action. `SeedYieldsToRemoval`
says that a replica that has received a removal — its own included — never
holds a seeded version. The two switches are the two halves of the fix:

| Switch | FALSE is | Counterexample |
|--------|----------|----------------|
| `SeedSeesTombstones` | the seed asks the typed read, which reads a tombstone as no row | three steps: A seeds, A deletes, A seeds again |
| `SeedYields` | the seed is stamped at the wall clock | four steps: A and B seed at the same instant, B deletes, A receives the deletion and keeps its own seed, which wins the canonical tiebreak |

With both switches set, `AgentReplicationSeed` (three replicas, three writes,
one tick of skew, 1,843,077 distinct states) and `AgentReplicationSeedLossy`
(two replicas with any delivery lost and recovered by backfill, 339,219)
check `Converged`, `NoLostSuccessor` and `SeedYieldsToRemoval`. The other
configurations keep their state counts.

## Consequences

- A default the user deleted is never seeded again, on any device, and a
  default soul the user unassigned or replaced stays that way. There is no
  "restore defaults" action; bringing a deleted default back is not possible
  from the app. That is a deliberate, reversible choice: a restore action
  would re-create under the id, which ADR 0081's re-creation rule already
  makes win everywhere.
- The seeded rows under a well-known id sort as the oldest in the template
  and soul lists until the user edits them.
- A re-sync limited to a recent interval does not re-send a seeded row the
  user never edited. Every device seeds its own copy, so none is missing.
- A device that seeded a default before it received a peer's deletion keeps
  the version and head rows it wrote under fresh ids. They hang off a removed
  template or soul, and every read reaches them through it.
- A device on an older build still seeds at the wall clock over tombstones.
  Its seed can undo a deletion until it updates.
- Existing installs whose user deleted a default before this change have it
  back already; it stays until they delete it again.

## Related

- [ADR 0081](./0081-model-checked-evolution-sessions-and-agent-links.md):
  removals and re-creations of agent entities
- [ADR 0068](./0068-model-checked-agent-convergence.md): the entity resolver
  and last-writer-wins on `effectiveUpdatedAt`
- `specs/tla/AgentReplication.tla` (the seeded kind), `specs/tla/README.md`
- [Templates, souls and evolution](../../knowledge/features/agents/templates-souls-evolution.md)
- [Agent persistence and sync](../../knowledge/features/agents/persistence-and-sync.md)
