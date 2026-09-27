# ADR 0104: One Task Agent Per Task

- Status: Accepted
- Date: 2026-09-27
- Builds on: [ADR 0075](./0075-idempotent-change-set-tools.md),
  [ADR 0099](./0099-agent-link-slots-rank-every-assignment.md)

## Context

A task agent is an agent identity plus an `agent_task` link from it to the
task. `TaskAgentService.createTaskAgent` writes both under fresh random ids,
and it refuses a task that already has a link. That check sees only what the
device holds. Two devices that assign the same task before either has the
other's agent both create one:

- **The follow-up tool.** A follow-up task confirmed on two devices gets one
  derived id (ADR 0075), and each device's `FollowUpTaskHandler` then
  auto-assigns the category's default agent to it.
- **Two manual assignments**, or any mix of the creation paths
  (`assignCategoryDefaultTaskAgent`, onboarding, the project tools).

Once both agents have synced, the task's card shows the agent of the primary
link (`AgentLinkSelection.selectPrimary`, the newest `createdAt`, then id).
The other agent is alive and invisible. It keeps its subscription, wakes on
task changes, and writes reports, token usage and proposals. Nothing ever
removed it. `AgentWakeCoordination.tla` coordinates wakes per agent id, so
the two agents were not coordinated either.

Two ways to make the task's agent unique were considered:

1. **A derived agent id**, like ADR 0075's derived effect ids: both devices
   would write the same entity, and `AgentReplication` would merge it. This
   is unworkable, because the task's agent is not a register. Deleting an
   agent is local: `AgentService.deleteAgent` hard-deletes the rows and syncs
   only the `destroyed` lifecycle. A reassignment after a delete would reuse
   the id that other devices still hold, destroyed and carrying the old
   agent's history, and the two versions would then race on their clocks.
   It also does nothing for the tasks that already have two agents.
2. **A rank every device applies the same way**, retiring the agents that
   lose. This is ADR 0099's approach for template slots. There a loser can be
   hidden, because a slot only selects a link. Here the loser is a running
   agent, so it has to stop.

## Decision

**Rank, and retire the losers (option 2).** `TaskAgentRetirement` holds the
rule.

1. **The rank is the card's.** The task's agent is the first of the task's
   live `agent_task` links by `orderedPrimaryFirst`, among the links whose
   agent identity the device holds. Destroyed agents rank too, so the agent
   that stays is always the one the card shows. When the card shows a
   destroyed agent, no other agent of the task keeps working unseen. A link
   whose identity has not arrived yet does not rank. The pass that the
   identity's arrival triggers ranks it.
2. **A loser is retired, which is a destroy.** The pass writes the loser's
   identity as `destroyed`, through `AgentSyncService`, so every device
   learns of it once and the drain engine never runs it again. The loser's
   history (reports, messages, the link) stays, as it does for any destroyed
   agent. The rank read and the writes share one transaction.
3. **The pass runs wherever a duplicate can first appear or first act:**
   - when sync applies an `agent_task` link, or a task agent's identity
     (`SyncEventProcessor.retireSupersededTaskAgents`), in its own
     transaction after the receive;
   - at startup (`TaskAgentService.restoreSubscriptions`), over every task
     with links from more than one agent. This covers a process that died
     between a receive and its pass, and the duplicates that older builds
     left;
   - before a task agent's wake (`wireWakeExecutor`'s gate). A loser whose
     pass has not run yet on this device is retired there instead of
     running.
4. **Nothing changes at creation.** `createTaskAgent` still refuses a task
   that has any link on this device. Transient duplicates cannot be avoided
   without coordination: two offline devices each assign. They are resolved
   when the devices meet.

`specs/tla/TaskAgentAssignment.tla` models one task on two devices, covering
auto-assignment, manual assignment, destroy, delete, every arrival order, a
crash between a receive and its pass, and wakes. The invariants are
`AtMostOneLive`, `LiveAgreed`, `KeepsAgent`, `KeepsAgentUndestroyed` and
`NoSupersededWake`. The switches `RetireLosers`, `RetireOnReceive`,
`StartupRetire`, `WakeGate` and `SharedRank` each reproduce a hole when set
to `FALSE`. The counterexamples are in `specs/tla/README.md`.

## Consequences

- After sync, a task has at most one live task agent, and every device agrees
  which one. When the follow-up tool fires on two devices, the later agent
  stays and the earlier one is destroyed.
- The loser may already have run a wake before its device saw the winner.
  Its reports and proposals from that wake stay. A proposal can still be
  confirmed or rejected, but the retired agent does not act again.
- **Clock skew can cost a reassignment.** Destroyed agents rank. So when a
  device assigns the task on a clock running behind a concurrent agent that
  another device created and destroyed, that device retires the new
  assignment in favour of the destroyed one. TLC finds this in 12 steps under
  `Skew`. The skew has to exceed the time between the other device's
  assignment and this one. The user assigns again, and the new agent then
  ranks first. Without skew, an agent assigned after the last destroy always
  leaves the task an agent (`KeepsAgent`). Under any skew, a task whose
  agents nobody destroyed always keeps one (`KeepsAgentUndestroyed`).
- **Hard delete is local and leaves no tombstone.** A device that receives
  a destroyed agent's final version before its creation, and deletes it in
  between, re-inserts it as live when the late creation arrives. This is not
  new, and it affects every agent kind. The model constrains the delete to
  come after every write about the agent has arrived, and the README records
  the counterexample.

## Related

- `lib/features/agents/service/task_agent_retirement.dart`
- `specs/tla/TaskAgentAssignment.tla`, `specs/tla/README.md`
- [Task agents](../../knowledge/features/agents/task-agents.md)
