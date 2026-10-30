# ADR 0145: A Goal Holding an Unknown Criterion Is Fenced, Not Judged

- Status: Accepted
- Date: 2026-10-30
- Builds on: [ADR 0053](./0053-goal-driven-agents-per-goal-producers.md)
  (the `GoalCriterion` tree), [ADR 0054](./0054-deterministic-first-two-tier-wakes.md)
  (Phase A on every device)

## Context

A goal's criteria sync as a JSON tree of `GoalCriterion` variants. A device
running an older build receives a goal written by a newer one, and a new
criterion kind is exactly what a newer build adds. Before this decision the
sealed union had no fallback: the spec failed to decode, the whole agent
entity was dropped as `unknown`, and the goal vanished from that device.

Decoding it leniently is not enough on its own. Phase A runs on every device
and writes the shared `goalProgress` register; Phase B is lease-elected and
may land on the old device. A build that cannot evaluate one leaf would
either fail the goal or score it as unmet, and its register write or report
would then sync over the correct one from the newer device. A revision
applied there would rewrite a tree the device only half understands.

## Decision

1. **An unknown kind decodes as `GoalCriterion.unsupported`**
   (`@Freezed(fallbackUnion: 'unsupported')`), carrying its `criterionId`,
   title and, under `unsupportedSource`, the whole node as it arrived. The
   inbound sync persists the decoded entity, so without that the stored row
   would keep a stub an updated build could not decode. `GoalCriterion.fromJson`
   decodes a stored `unsupportedSource` instead of the stub around it — on an
   updated build, as the criterion it always was. The goal stays visible and
   its other criteria keep their meaning.
2. **Such a goal is fenced on the device that cannot read it.** Phase A
   re-arms the cadence and stops — no register write, no escalation, no
   deferred refresh. Phase B does not run its automatic wake, and a chat turn
   fails with a reason instead of answering from half the facts. A revision is
   rejected with "update the app on this device to change it", and
   `GoalSpecValidator.authoringIssues` refuses such a tree on every authoring
   route, not only the page that hides Edit. The detail page hides editing and says once, at the top, that this version cannot
   read part of the goal.
3. **Every other switch treats the leaf as unreadable, not as failed**: the
   evaluator returns no samples and no attainment, validators raise nothing,
   collectors skip it, and FACTS render it as `{"criterionId", "unsupported":
   true}`. These are reachable only off the fenced paths, but must not throw.

## Consequences

- A goal written on a newer device survives sync to an older one, and the
  newer device stays the only writer of its register and reports.
- An old device shows the goal's last synced report and register, possibly
  stale, until it is updated. That is the price of not overwriting them.
- Adding a criterion kind needs no migration: older builds fence it by
  construction. A kind that should be readable everywhere still has to ship
  to every device before goals use it.

## Related

- [ADR 0053](./0053-goal-driven-agents-per-goal-producers.md)
- [ADR 0054](./0054-deterministic-first-two-tier-wakes.md)
