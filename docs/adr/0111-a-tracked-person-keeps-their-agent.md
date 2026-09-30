# ADR 0111: A Tracked Person Keeps Their Agent

- Status: Accepted — model-checked in
  `specs/tla/RelationshipAgentLifecycle.tla` and implemented; a conformance
  trace replays the model against the real services
- Date: 2026-09-29

## Context

A person marked important gets a relationship agent (ADR 0059 Decision 2).
Its id is derived from the person's (`relationshipAgentIdFor`), and an
`agentRelationship` link names the person it watches. The agent's lifecycle
is set in several places:

- the background ensure after a mark or an edit
  (`ensureAgentForRelationship`);
- the delete cascade from the person page (`handleRelationshipDeleted`);
- the reaper in `RelationshipRuntimeMaintenance`, before every
  scheduled-wake scan;
- the agent controls (pause, resume, destroy, delete).

The person and the agent sync on different paths. The person is a journal
row: a concurrent pair becomes a conflict for the user. The agent is an
agent entity: a concurrent pair is decided as a whole row by `updatedAt`.
Nothing orders the two paths against each other.

`RelationshipAgentLifecycle.tla` models these writers on two devices, with
every arrival order. Against the code at `9f1fec4e5`, TLC finds these
failures:

- **A person not yet synced is reaped.** The reaper reads the person through
  `journalEntityById`, which returns no row both for a tombstone and for a
  row that has not arrived. A device that receives the agent and its link
  before the person destroys the agent, and the destroy syncs everywhere
  (`NoReapOfLivePerson`, 6 states). `ensureAgentForRelationship` keeps an
  existing identity whatever its lifecycle, and the wake engine refuses a
  destroyed one. So marking the person important again does nothing, and
  the person never gets another reminder or briefing.
- **A destroyed agent never comes back.** The same holds after a delete that
  raced an edit and was resolved in favour of the live person, and after a
  crash that lost the background ensure (`Tracked`).
- **A rename overturns a destroy.** An edit's ensure rewrites the identity
  to change `displayName`, and it carries the lifecycle it read. A rename
  that is concurrent with a destroy and later by `updatedAt` makes the
  agent live again on every device.
- **A hard delete stays on one device.** A user who deletes a destroyed
  agent is refused its later writes on that device only
  (ADR 0108), while another device can bring the agent back.

## Decision

- **Reap only over a tombstone.** The reaper reads the person including
  deleted rows and destroys the agent only when the person is deleted.
  Missing means not yet arrived.
- **Intent is recorded as stamps.**
  - The person records when `important` was last switched on.
  - The identity records three things: when the user last stopped it, and
    how (destroy, pause or delete); when the user last resumed it; and
    when its lifecycle last changed.
  - Every stamp is the time of the write that sets it, so along any causal
    chain it only grows.
- **Identities merge field by field.** For two concurrent identity versions:
  - the lifecycle with the later lifecycle stamp wins;
  - the stop with the later stop stamp wins, and so does the resume;
  - the result carries the joined clock.

  Each field is a join, so the merge is commutative and associative, and
  every device reaches the same version whatever the arrival order. A rename
  no longer touches the lifecycle. The code keeps the winner's clock, as
  every agent merge does, and joins these fields on every receive — a
  dominating one too — which is what the model's joined clock achieves: a
  successor of one side never drops the other side's decision
  (`joinIdentityDecisions`).
- **The maintenance pass reconciles a live person's agent** to what the
  user asked for last:
  - the stop, if it is newer than the last mark and the last resume;
  - otherwise active, if the person is important.

  The pass creates a missing agent (a lost background ensure, a peer's
  creation not yet arrived, a delete older than the last mark). It writes
  the target over whatever the merge, the reaper or the cascade left. While
  the person has an open conflict it only ever stops the agent, judging the
  newest mark among the versions it holds. Every device eventually holds the
  same stamps, so every device computes the same target, and the writes
  converge.
- **A hard delete tells the other devices.** `deleteAgent` first writes the
  user's stop, which syncs, then removes the rows here. The background
  ensure never recreates an agent this device deleted. Only the maintenance
  pass does, for a mark newer than the delete, and it clears the
  `deleted_agents` entry.

The user's latest word wins. A mark or resume newer than a stop brings the
agent back, and a stop newer than both keeps it stopped. Whether a newer mark
should also resume an agent the user *paused* is a product choice. This ADR
says yes, because `important` is the single consent switch.

An earlier draft stamped a revive's lifecycle with the time of the mark it
acts on, so that a later stop would win a plain lifecycle merge. TLC showed
this breaks convergence. A revive written after a destroy then carries an
older lifecycle stamp than the destroy it supersedes, so the merge's order
disagrees with causal order, and two devices settle on different lifecycles
under the same clock. Keeping every stamp monotonic, and deciding "who asked
last" in the reconcile pass rather than in the merge, removes that failure.

## Consequences

- A person marked important is tracked on every device once sync settles:
  whatever the arrival order, a lost background job, a mis-resolved delete,
  or a rename racing a destroy.
- A deleted person has no active agent anywhere once devices agree on the
  person. While a delete/edit conflict is open, each device follows the
  person it holds.
- The identity gains three fields, and the person gains one. The field-level
  merge applies to every agent kind's identity. That also closes the
  residual `TaskAgentAssignment` records, where a concurrent config edit
  could revive a retired task agent.
- An agent destroyed by a build from before this decision carries no stop,
  so the pass cannot tell a reap that went wrong from a user's destroy. For a
  person still marked important it brings the agent back on the first scan.
  That repairs every person the old reaper lost; a user who destroyed the
  agent by hand while keeping reminders on turns reminders off instead.
- The pass writes on a device's own view. A device that holds a stale
  person can briefly write a lifecycle that a later delivery then corrects.
  The model checks that every quiescent state is correct.

## Verification

`specs/tla/RelationshipAgentLifecycle.tla` checks this design in six
configurations, which run in CI: base, crash, conflict, stop, pause and hard
delete. Together they reach 55,713,551 distinct states, and every one passes.
With every switch off (the code at `9f1fec4e5`) TLC breaks
`NoReapOfLivePerson` in 6 states.

Each decision is a switch, and each switch set back breaks a named property.
The spec's README section lists the traces:

- reaping over a missing person: `NoReapOfLivePerson`, 6 states;
- no reconcile pass: `Tracked`, crash configuration, 5 states;
- the whole-row merge: `StopSticks`, stop configuration, 12 states;
- a local-only hard delete: `StopSticks`, hard-delete configuration,
  14 states;
- the ensure recreating over `deleted_agents`: `StopSticks`, hard-delete
  configuration, 15 states.

The conformance trace
(`test/features/relationships/runtime/relationship_agent_lifecycle_model_conformance.dart`)
drives the real agent stack on two devices through generated traces of the
model's actions, checks every property, and pins the counterexamples. With
any one of the five decisions reverted, it fails.
