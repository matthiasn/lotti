# ADR 0108: A Deleted Agent Stays Deleted

- Status: Accepted
- Date: 2026-09-27

## Context

Deleting an agent is two steps. `AgentService.destroyAgent` sets its
lifecycle to `destroyed`, a version that syncs to every device.
`AgentService.deleteAgent` then removes the agent's data on this device —
`AgentRepository.hardDeleteAgent` deletes its entities, links, wake runs and
saga ops, and the sidecar reclaimer removes their JSON files. The hard
delete is local; nothing about it syncs.

Once the rows are gone, nothing on the device remembers the deletion. A
write about the agent that sync delivers afterwards — its creation or its
link delivered late, a backfill answer, a message from a run that was still
going on another device — is resolved against no stored row and inserted as
new. The agent comes back, live if the late version was its creation.

[ADR 0104](./0104-one-task-agent-per-task.md) recorded this as a residual:
its model's `HardDelete` waited for every write about the agent to arrive,
and with that relaxed TLC broke `LiveAgreed`. `specs/tla/TaskAgentAssignment.tla`
now lets the delete run early (`EarlyHardDelete`) and checks
`DeletedStaysDeleted`: a device that deleted an agent never holds its
identity or its link again. Without a tombstone TLC breaks it in six states —
A creates an agent and destroys it; B receives the destroy first, deletes the
agent, and the late link brings it back.

## Decision

- **A deletion is recorded.** The agent database gains `deleted_agents`
  (schema v23): `hardDeleteAgent` inserts the agent id in the transaction
  that deletes its rows. Agent ids are never reused, so the record is
  permanent; one row per deleted agent.
- **Sync refuses writes about a deleted agent.** The agent entity and agent
  link receive paths (`SyncEventProcessor`) ask
  `refusesWriteAboutDeletedAgent` — an entity by its `agentId`, a link by
  both ends — inside the transaction that would write, so no write can land
  between the check and a deletion. A refused message is recorded as
  received, like a version that loses, and the JSON it brought is removed:
  the deletion already reclaimed the agent's files.
- **Only the device that deleted refuses.** Other devices hold the agent as
  destroyed until the user deletes it there too; their receive is unchanged.

`DeletedTombstone` is the design switch; the conformance trace receives
through the same function and pins the six-state trace.

## Consequences

- A deleted agent no longer reappears, whatever order sync delivers its
  writes in.
- Agents deleted before this build were not recorded; their late writes
  still insert rows, as before.
- A link between two of a deleted agent's own entities names neither end as
  the agent and is written, pointing at two entities that were refused.
