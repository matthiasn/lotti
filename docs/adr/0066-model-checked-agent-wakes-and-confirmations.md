# ADR 0066: Model-Checked Agent Wakes and Confirmations

- Status: Accepted
- Date: 2026-09-24

## Context

After the sync sequence log ([ADR 0065](./0065-model-checked-sync-sequence-reservations.md)),
the agent runtime was the next protocol whose correctness rested on prose: a
wake queue, per-agent runner leases, executors that an abort cannot cancel
(Dart futures run on), and a confirmation flow in which a double tap, a
"Confirm all" and a retry can race over one persisted change set.

We wrote both down in TLA+ as the code stood — `specs/tla/WakeRuntime.tla`
and `specs/tla/ChangeSetConfirm.tla` — and model-checked them with TLC. Four
holes came back as concrete traces:

1. **Overlapping runs after an abort.** A cancel, the ten-minute run cap or a
   stale-drain reset released the agent's lease while its executor kept
   running, and the next wake for that agent started beside it.
2. **Lost wakes on a crash.** Queued jobs lived only in memory, and a run
   the crash interrupted was never retried: whatever triggered them was gone.
3. **A concurrent confirm applied a change twice.** Both callers read the item
   as `pending` before either wrote, and both dispatched the tool.
4. **A throwing post-confirm hook applied a change twice.** The failure
   reverted an item whose change had already landed to `pending`, and a retry
   applied it again.

## Decision

1. **Single flight covers detached executors.** The drain does not dispatch an
   agent while an earlier executor of it is still live, whether or not it
   still holds its lease. An executor still running after
   `WakeOrchestrator.hungExecutorAfter` (30 minutes, three run caps) is
   reported once as hung and stops blocking, so a future that never settles
   cannot wedge its agent until the next launch — the model's `DeclareHung`.
2. **Every queued wake is a durable intent until its run settles.**
   `WakeIntentStore` records one intent per queued job, keyed by its run key,
   in the device-local settings database; merged tokens join the job's intent.
   The intent is settled when the job's run settles, or when the job is
   dropped for good — gated, cancelled or superseded — and startup restores
   whatever is left, one job per agent and workspace, at most twice without a
   settled run.
3. **A confirm claims the item before it dispatches.**
   `ChangeSetResolutionStore.claimChangeSetItem` moves the item from `pending`
   to `confirmed` and returns nothing when it is no longer pending; the
   decision is written in the same transaction, so a failed decision write
   rolls the claim back. The loser of a race stops without dispatching, and
   without recording a decision.
4. **A successful dispatch is final.** When the post-confirm hook throws after
   the change landed, the failure is logged and the item stays `confirmed`.
5. **The models gate the code**, as in ADR 0065: the specs live in
   `specs/tla/`, CI model-checks them whenever they or the code they describe
   change, and Glados traces in the wake and confirmation suites drive the real
   Dart code through generated interleavings and check the same properties.

## Consequences

- `SingleFlight`, `HungOnlyWhenDetached` and `NoLostWake` hold with two
  agents, up to two aborts, and one crash at any point; `AtMostOnceApply` and
  `ConfirmedMeansApplied` hold for two concurrent confirmers with dispatch
  failures and throwing hooks, and `AtMostOnceApply` also across a crash.
- The wake-intent trace earned its place before the change merged: settling
  intents per agent with a sequence cutoff — the first implementation — lost a
  trigger queued in a second job of the same agent. The model, which settles
  exactly the triggers a run covered, was right; the code was not a faithful
  refinement of it. The model now also lets a run cover only some of an
  agent's queued triggers, as the real queue does, and TLC rejects the cutoff
  design.
- A follow-up wake for an agent whose aborted executor is still running now
  waits for it, up to 30 minutes, instead of overlapping it.
- A wake restored after a crash runs as a manual wake of its agent and
  workspace; one whose run crashes the process twice is dropped with an error
  log.
- Two confirmation cases stay open and are documented in `specs/tla/README.md`:
  a tool that throws after its effect landed is reverted to `pending` and can
  apply again on retry, and a crash between the claim and the dispatch leaves
  an item `confirmed` without its effect. Closing them needs either an
  `applying` status that sync and the UI understand, or tools that are
  idempotent per decision id.

## Related

- `specs/tla/WakeRuntime.tla`, `specs/tla/ChangeSetConfirm.tla`,
  `specs/tla/README.md`
- [Wake orchestration](../../knowledge/features/agents/wake-orchestration.md)
- [Task agents](../../knowledge/features/agents/task-agents.md)
- [ADR 0006: Change-set deferred tool confirmation](./0006-change-set-deferred-tool-confirmation.md)
