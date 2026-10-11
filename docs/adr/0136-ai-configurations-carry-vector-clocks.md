# ADR 0136: AI Configurations Carry Vector Clocks for Repair, and Their Stamps Keep the Order

- Status: Accepted
- Date: 2026-10-11

## Context

AI configurations — inference providers, models, prompts, inference profiles
and skills — replicate as whole rows. Each version carries `AiConfigDb`'s
durable stamp, and a receiver keeps the greater one (ADR 0094). Every write is
owed until the outbox accepts it (ADR 0127), and a current device answers an
older copy with the version it holds (ADR 0131).

That makes the send side durable, but nothing notices a message lost after it
left. The payload carries no sequence counter, so a receiver cannot see a gap,
and backfill cannot ask for it. A device that misses a provider edit, a model's
deletion or a key that was cleared keeps the old version until the row changes
again or the user presses "Send settings". Entity definitions had the same gap
and closed it with vector clocks (ADR 0125). A periodic digest exchange was
considered and rejected: it adds traffic on the room for something the
counters already detect.

## Decision

- **Every sent write spends this host's next counter** on top of the clock
  held for the id, reserved for that payload (`SyncSequencePayloadType.aiConfig`,
  appended to the persisted enum). That covers a save, a soft or hard
  deletion, a provider cascade and its undo, and the deletion a receiver
  derives for a model left under a deleted provider. The message carries the
  clock (`SyncMessage.aiConfig.vectorClock`, `aiConfigDelete.vectorClock`) and
  `originatingHostId`; the outbox binds the counter at enqueue. A local write
  that is never sent (seeding, the orphaned-seed prune) spends none.
- **The clock never orders versions.** The stamp does, as before (ADR 0094).
  A local stamp always passes the held one, so the stamp order already agrees
  with causality on every device. A second order would only add another way
  for devices to disagree.
- **The held clock is the join of every copy met, kept or not.** It is stored
  in `ai_config_versions.vector_clock` (AI config schema 3), next to the stamp,
  so a hard deletion keeps it too. A copy that loses on its stamp still joins
  its clock, so the version held answers for the counters of every version it
  superseded.
- **A device sends only the version it holds.** A derived write that would
  lose locally is not sent: the orphan cleanup skips a model newer than the
  provider's deletion, and a model that would lose at its provider's stamp
  takes the next local stamp. Otherwise its clock would cover a version it
  does not supersede, and a peer answering from it could close another
  device's gap with an older version.
- **Backfill answers with the version held now.** A request for a counter of
  an AI configuration is answered with the held row (a provider with its key
  from this device's keychain) or its hard deletion, under the held clock,
  plus a hint naming the counter. Deep backfill reads `ai_config_versions`
  as its store, deletions included. "Send settings", the ADR 0131 answer and
  the owed flush send the held version too, with its clock. A sync database
  restore re-records the versions held (ADR 0135).
- **Rows from before this change are not migrated.** They hold no clock until
  their next write. Their counters were never sent, so there is nothing to
  repair; a receiver records nothing for a copy without a clock.
- `specs/tla/AiConfigClocks.tla` checks the counters against the stamp order:
  every learned counter is eventually received, a held clock answers only for
  versions the held one supersedes, no device goes back, and all end on the
  newest version, under lossy delivery. Each rule above has a switch whose
  counterexample is in the specs README.

## Consequences

- A lost AI configuration message is detected from the next counter of its
  sender, or a head announcement, and backfilled like any tracked payload.
  "Send settings" stays as the manual repair; it is no longer the only one.
- Counters are spent per sent write: a provider cascade spends one per model
  and one for the provider.
- Builds before this change ignore the new fields and keep applying by stamp,
  as before; they do not record or answer AI configuration counters.
- The order between concurrent edits does not change: the greater stamp wins,
  and a device whose clock runs far ahead can still win over a later edit from
  one whose clock is behind (ADR 0094).
