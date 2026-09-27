# ADR 0094: AI Configuration Versions Are Stamped, and the Receiver Keeps the Newest

- Status: Accepted
- Date: 2026-09-27
- Resolves: [ADR 0085](./0085-model-checked-outbox.md)'s residual 1 (a
  timed-out send can land after a newer one), kept by
  [ADR 0086](./0086-append-only-outbox.md)

## Context

The outbox processor abandons a Matrix send after `sendTimeout` and retries
its rows, but the SDK's send keeps running and can still land — after the
retry, and after a newer version of the same entity. `specs/tla/Outbox.tla`
allows this in `OutboxGhost`; with `NewestLandsLast` claimed it fails in ten
steps: v1 is claimed, v2 is enqueued, v1's send times out and is retried, v2
goes out, and the abandoned v1 lands last.

Whether that loses anything depends on the receiver. On `main` before this
change, every payload with more than one version was already ordered by
something other than arrival:

| Payload | Receiver order |
|---|---|
| journal entities, entry links, agent entities and links, notifications | vector clock |
| entity definitions (categories, habits, dashboards, measurables, labels) | `updatedAt` and vector clock (`_upsertDefinitionIfNotOlder`) |
| config flags | durable stamp in `config_flag_versions` (#4517) |
| theme selection, Daily OS name | settings-group stamp (`saveSettingsItemsIfNewer`) |
| saved task filters, node profiles | `updatedAt` last-write-wins |
| consumption events | immutable, one per inference |
| **AI configurations (`aiConfig`, `aiConfigDelete`)** | **arrival order** |

So the residual's remaining victim was the AI configuration: a provider,
model, prompt, inference profile or skill. `AiConfigRepository.saveConfig`
upserted whatever arrived, and `aiConfigDelete` hard-deleted whatever it
named. A late copy of an older edit overwrote the newer one on the peer, and
a late copy of a config sent before a hard delete brought the row back.
(`_isStaleReplayOfTombstone` guards only an active copy against a local
soft-delete tombstone.) AI config rows are not collapsed
(`collapseKeyOf` gives them no key), so each version is its own send and a
retried older row can land after a newer one even without a timeout.

ADR 0085 named three options, each a wire or protocol change: a stable Matrix
transaction id per outbox row, a clock or stamp on those payloads, or no
timeout while the SDK still retries. The first two need no decision about
the SDK's behaviour; only the second is receiver-side, so an old receiver
keeps working and an old sender's messages still decode.

## Decision

Give every AI configuration version a durable, monotonic per-entity stamp,
send it, and have the receiver keep only a newer one — the shape #4517 gave
config flags.

- **Storage.** AI config schema 2 adds `ai_config_versions (id, stamp)`: the
  stamp of the version each config last took. It is not a foreign key of
  `ai_configs`: a row with no config is a *deletion*, and it outlives the
  hard delete so a late copy of the deleted config cannot bring it back. The
  migration stamps every existing row with the time this device last wrote
  it (`COALESCE(updated_at, created_at)`, in milliseconds), so a resend of a
  pre-upgrade row is ordered too.
- **Local writes.** `AiConfigDb.saveConfig` and `deleteConfig` stamp the
  version with the current time in milliseconds, or one past the stamp held
  when the clock has not moved beyond it, in the same transaction as the
  write, and return the stamp. The repository sends it:
  `SyncMessage.aiConfig.versionStamp` and `SyncMessage.aiConfigDelete.versionStamp`,
  both optional. The maintenance resend (`SyncStep.aiSettings`) carries the
  stored stamp, so a peer holding a newer version drops the resend.
- **Receive.** `AiConfigDb.applyConfigVersion` writes a received version only
  if its stamp is greater than the one held. On a tie a held deletion wins,
  and two configs are ordered by their payload JSON without the credential,
  so every device keeps the same one; an identical copy is a no-op.
  `applyConfigDeletion` applies unless the device holds a newer stamp, and
  wins a tie. Nothing is written for a dropped version — not even the
  provider credential, whose keychain write follows the decision.
- **Old senders.** A message without a stamp is ordered by the Matrix event's
  server timestamp, as config flags do. Among old senders that is arrival
  order, as before. Such a copy still passes the `updatedAt` tombstone
  screen first; a stamped version does not, because its stamp already says
  whether it is newer than the tombstone, and a restore's `updatedAt` can
  trail the tombstone's when the restoring device's clock runs behind. A
  legacy deletion of an id this device never held, with no bundled template
  to tombstone, still records its stamp. Old receivers ignore the new field and keep applying in
  arrival order, so the guarantee needs updated receivers, not updated
  senders.
- **Local-only removal.** The orphaned-seed prune
  (`removeOrphanedDefaultSeeds`) hard-deletes without sending. It now also
  forgets the version it held (`forgetConfig`): it sent no deletion, so it
  must not outrank the version peers still hold, and a peer's next copy of
  the profile applies again, as it did before.

The model gains a switch and a property. `StampedReceiver` makes the receiver
a stamped register; `PeerHoldsNewest` says the version a peer holds, after
applying the room in arrival order, is the newest the room carries.
`RowKeys` marks keys whose rows never collapse, and the new configuration
`OutboxGhostRows` checks one: an AI configuration with ghosts, a failed send,
marks that throw, a crash or teardown, and the monitor's Retry and Remove.
Every Outbox configuration claims `PeerHoldsNewest`. With
`StampedReceiver = FALSE`, `OutboxGhost` and `OutboxGhostRows` both fail it
in ten steps: the counterexample of the residual.

## Consequences

- A timed-out AI configuration send that lands late, a monitor Retry of an
  older row, and a replay of an older version are dropped on every updated
  receiver. A hard-deleted configuration is not brought back by a copy sent
  before the deletion.
- One small table and one integer per configuration. The deletion marker
  holds only the id and a stamp, none of the deleted content.
- Stamps are wall-clock milliseconds. As with config flags and the settings
  groups, a device whose clock is far ahead can win over a later edit from a
  device whose clock is behind; per-entity monotonicity only guarantees that
  one device's own versions stay in order.
- `NewestLandsLast` — the room's own order — still fails under ghosts; it is
  no longer what any receiver depends on.
- An old build receiving from a new one still applies AI configurations in
  arrival order, so the overwrite stays possible on devices that have not
  updated.
