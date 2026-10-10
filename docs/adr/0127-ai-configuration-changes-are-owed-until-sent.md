# ADR 0127: AI Configuration Changes Are Owed Until Sent

- Status: Accepted — implemented
- Date: 2026-10-10

## Context

An AI configuration — an inference provider, a model, a prompt, a profile or
a skill — is written to `AiConfigDb` and then handed to the outbox as a
`SyncMessage.aiConfig` or `SyncMessage.aiConfigDelete`, stamped with the
version the write took (ADR 0094). The write commits first; the outbox's
ordinary `enqueueMessage` logs and swallows its own failure. So a change
whose row the outbox could not stage — a database error in the sync store, a
profile torn down between the two steps, a crash in between — was durable on
the device that made it and unknown everywhere else, and nothing recorded
that.

For an edit the gap closed at the next edit of the same row, or when the user
ran *Send settings*, which re-sends every stored row with its stamp. For a
hard deletion it never closed: the deletion leaves no row, only its stamp in
`ai_config_versions`, and *Send settings* read rows. A deleted prompt, skill
or provider could stay on the other devices for good. The orphan cleanup had
the same shape in reverse: it sent each orphaned model's deletion before
storing it and relied on the message being delivered again to resume, which a
swallowed failure never caused.

`specs/tla/AiConfigReplication.tla` took a write and its enqueue as one step
and listed the enqueue as outside the model. Saved task filters had already
closed the same gap with a durable ledger of owed ids (#4506).

Two neighbouring rules were open in the same model. A model edited after its
provider's deletion on a device that had not heard of it is kept by the
receive, because an undo's restore looks the same, and was then listed under
a provider that no longer existed. And a provider synced without a key kept
the receiver's key, because an empty key on the wire usually meant the
sender's keychain read came back empty, so a key the user removed on purpose
stayed on every other device.

## Decision

1. **Every AI configuration write owes its message until the outbox accepts
   it.** `AiConfigRepository` records the id in `AiConfigSyncLedger`, one
   `SettingsDb` key holding the owed ids, *before* staging the message with
   `enqueueMessageOrThrow`, and settles it once the row is staged. A failed
   enqueue leaves the id owed; the failure is logged, never thrown, since
   the write it follows has committed. `flushPending` sends what the device
   holds for each owed id — the stored row with its stamp, or the hard
   deletion its stamp alone records, or nothing for an id it holds neither
   for — at startup, a minute after a failure, and whenever a later write of
   the same id succeeds. What is sent is derived at flush time, never the
   message that failed, so a newer write supersedes an older owed one.
2. **The orphan cleanup stores each deletion, then sends it owed.** A send
   that fails leaves the deletion recorded and its id owed; the message is
   processed once. Delivering it again changes nothing.
3. ***Send settings* re-sends hard deletions.** The pass reads every stamp in
   `ai_config_versions` that has no row (`hardDeletionStamps`) and re-sends
   each as the deletion it records, beside the rows and tombstones.
4. **A model under a deleted or missing provider is hidden, not deleted.**
   `getConfigsByType` and `watchConfigsByType` leave it out of the model
   lists; `includeDeleted` reads, which the seeding passes and the cleanup
   use, still see it. A restore of the provider lists it again.
5. **A key removed on purpose says so.** `AiConfigInferenceProvider` gains
   `apiKeyCleared`, which the provider form sets when a key that was loaded
   is emptied, and which any version written with a key clears. A receiver
   keeps its own key for an incoming empty key only when the marker is not
   set.

The model gains `owed`, an `OwedSends` switch, the failing writes
(`LostEdit`, `LostCascade`, the owing `Interrupted`) and `Flush`;
`AiConfigReplicationOwed` checks them. With `OwedSends` off, a cascade whose
deletions the outbox refuses leaves the devices apart for good.

## Consequences

- A deletion or edit that could not be queued reaches the other devices at
  the next start or within a minute, without the user noticing anything
  went wrong; a hard deletion that a peer missed is repaired by *Send
  settings*.
- The ledger is one settings key, written twice per change. An unreadable
  value reads as empty: the cost is a change that is not resent until its
  next write, which *Send settings* repairs.
- A repository built without settings storage has no ledger and sends
  best-effort, as before; only tests build one that way.
- Orphaned models stay in the database with their stamp, so the undo of a
  provider deletion still brings them back; they are simply not offered
  anywhere.
- A provider edited on an older build carries no marker, so an older
  device's empty key is still taken for a failed keychain read.
