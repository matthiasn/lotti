# ADR 0133: Removals and Repairs Reach Every Device

- Status: Accepted
- Date: 2026-10-11

## Context

A sweep of the sync code after #4760 found six paths where something one
device decided — a removal, a repair, a disconnection — never reached the
others, or kept being undone by them.

- **A lost destroy was never repaired.** `hardDeleteAgent` removes every row
  of a destroyed agent, including its identity, and records the agent in
  `deleted_agents` (ADR 0108). A peer that missed the `destroyed` identity
  update and asked for it was answered `deleted`, which only settles the
  counter. Deep backfill found no rows to offer. The peer kept the agent
  running, and kept paying for its inference.
- **Repair vector clocks stamped a stale snapshot.** The manual repair, and
  the historical re-sync's stamp of a clockless agent row, stamped the copy
  read when the list was built. An edit made, or a copy received, in
  between was overwritten by an older version carrying a newer clock, and
  that older version then won on every device.
- **A retried identity skipped its runtime.** When a received task agent
  identity committed and a later step failed, the queue retried the event.
  The retry found the identity stored and took the duplicate branch, which
  mirrors no runtime. A resumed agent stayed without subscriptions until the
  next restart.
- **Deep backfill undid retention.** Retention hard-deletes old status events
  and observations without a tombstone. A peer that had not swept yet still
  listed those rows, so the device that pruned them asked for them and stored
  them again every round.
- **Deep backfill kept asking for a lost link version.** A link version that
  lost its triple to another id (ADR 0128) lives only in
  `entry_link_losses`, which the inventory did not list. The device lacked
  the id, asked a peer for it every round, and refused the answer.
- **A lost GitHub disconnection was never repaired.** The account message has
  no sequence counter. "Send settings" re-sent preferences but not the
  account, and the account's own resend only sends a connected token.

## Decision

- **A deleted agent's destroyed identity is kept.** `deleted_agents` gains an
  `identity` column (agent schema v25), written by `hardDeleteAgent` in the
  transaction that deletes the rows. The backfill responder answers a request
  for an agent entity it has no row of with that identity, not `deleted`. Deep
  backfill sends it to an advertiser that still lists the agent's identity
  with an older clock (`DeepBackfillStore.resendDestroyedAgents`). No row
  comes back: the record is not an entity, and writes about the agent are
  still refused.
- **Agent clocks are stamped from the stored row.** `AgentClockStamper` reads
  the row again inside the agent database transaction that writes the stamp,
  stamps it only while it is still clockless, and enqueues it in the same
  transaction. Repair vector clocks and the historical re-sync both use it.
- **The runtime is mirrored for the identity that stands.** The mirroring of a
  task agent's subscriptions, cadence and automatic updates is idempotent,
  and the duplicate branch runs it for the stored identity.
- **Retention remembers what it pruned, locally.** Each pruned id is recorded
  in `pruned_agent_entities` (v25) in the transaction that deletes it. A
  received copy of a pruned id is refused, and deep backfill does not ask for
  one. The record does not sync: every device applies the same rule.
- **Link losses are inventoried.** The entry link inventory lists the losing
  version of each id that holds no row, under its own clock, and resends it on
  request.
- **"Send settings" re-sends the GitHub account**, connected or not, with its
  own stamp. Features above sync add such records through
  `preferenceResendExtrasProvider`, which the composition root binds.

## Consequences

- Agents deleted, and rows pruned, before this build keep no record: a peer
  that missed their destroy stays unrepaired, and a pruned row may be fetched
  once more before the next sweep removes it.
- A peer that keeps a deleted agent's rows while holding its destroyed
  identity still lists them, and the deleting device refuses them on receipt.
- Repair vector clocks may now find an entity already stamped by the time it
  reaches it; such an entity is left as it stands.
