# ADR 0115: The Last Wake's Outcome Is Two Watermarks

- Status: Accepted — model-checked in `specs/tla/AgentWakeOutcome.tla` and
  implemented; the relationship conformance trace replays the model against
  the real stamp, join and card on two devices
- Date: 2026-10-02

## Context

Every relationship wake records its outcome on the agent's state row, and
the person page's agent card reads the row to show *failed* — the last wake
failed and nothing newer succeeded — with the reason and the fix. The row
is one synced register: concurrent versions are decided by `updatedAt`,
whole row, except for the fields `mergeAgentStateCounters` joins (the
G-counters and the report watermarks).

The outcome was `lastWakeAt`, stamped either way, and
`consecutiveFailureCount`, reset or bumped, both decided with the row. The
stamp was the `now` the wake read when it began. The card compared that
stamp with the briefing's `createdAt`, which another device may have
written.

`AgentWakeOutcome.tla` models two devices running wakes that start, run and
end, other writers of the row, and sync. Against the code at `1399ee934`,
TLC finds:

- **A short failure that began after a long success began outranks it**
  (`FailedFaceAgreed`, 7 states). Stamped by their starts, the failure is
  the newer, and once the writes meet both devices say *failed* beside the
  briefing the success wrote.
- **A later unrelated write of the row carries an older outcome over a
  newer one** (`FailedFaceAgreed`, 5 states). A failure ends on one device
  after a success began on the other, so its stamp is newer than the
  briefing's, and the success ends; then the device that failed moves the
  row's `updatedAt` for another reason — a watermark, the throttle — and
  that version wins last-writer-wins on every device, with its stale
  count. A failure that ended before the success began is history to the
  card either way, older than the briefing.

The failure count itself cannot be exact across devices: two devices that
fail concurrently each bump the same base, and "failures since the last
success" has no meaning without an order between devices.

## Decision

- **The outcome is two watermarks.** `lastWakeAt` names when the last wake
  completed; a new field, `lastWakeFailedAt`, names when the last wake
  failed. `mergeAgentStateCounters` joins both by latest instant, on a
  concurrent merge and when the incoming version dominates, as it joins the
  report watermarks. The last wake failed exactly when the failed stamp is
  the newer (`AgentStateWakeOutcome.lastWakeFailed`), on every device alike.
- **A wake is stamped when it ends**, with the instant it ends
  (`relationshipWakeOutcome`, through `updateAgentState`): in UTC, as the
  briefing is, and a microsecond past the stamps the row already holds
  (`decisionStampAfter`), so an outcome written with knowledge of an earlier
  one outranks it even when another device's clock ran ahead.
- **The failure count stays last-writer-wins and decides no face.** It
  feeds the configuration backoff and the Stats tab. The card reads
  `lastWakeFailed`. The maintenance pass (`_resumeConfiguredEscalations`)
  and the sync handler's re-offer read `lastWakeMayHaveFailed`: the same,
  except that a row no failed wake has stamped since the watermark existed
  counts as failed while its count is above zero. They only shorten a
  retry's deadline, where a stale count is harmless, and 1.1.35 shipped
  rows that carry a count but no stamp.
- **A failure older than the briefing is history.** The card keeps that
  guard: a success whose state write was lost still wrote its briefing.

Other agent kinds keep bumping the count on failure and stamping
`lastWakeAt` on success; the join of `lastWakeAt` by latest instant is what
their projection already does from the `wakeCompleted` markers, and a field
they never write is null on their rows.

## Consequences

- Every device shows the same face once the writes have met: a failure
  counts while nothing newer completed, whatever device ran either and in
  whatever order the rows arrived.
- A device whose clock runs behind and fails without having received a
  newer success stamps its failure earlier than that success; its face is
  then *current* until its next wake. That is the residual of wall clocks
  (`AgentWakeOutcomeSkew`, `FailedFaceAgreedWhenInformed`); a device that
  has received the success cannot misorder it.
- A row written before the watermark existed carries a count but no
  failed stamp: the card shows no failure until its next wake, while a
  config repair still brings its backed-off retry forward, by the count.
- An interactive wake that fails — a chat turn, *Brief me* — stamps a
  failure like any other: the agent could not run, and the card says so.
- The maintenance pass brings a backed-off retry forward only while the
  last outcome was a failure. A success elsewhere clears that, and the
  retry runs at its own deadline.

## Verification

- `specs/tla/AgentWakeOutcome.tla`, run with `specs/tla/tlc.sh`:
  `AgentWakeOutcome` (two devices, three wakes, one unrelated write, 30,022
  distinct states) and `AgentWakeOutcomeSkew` (device 1 three ticks ahead,
  55,646). Each switch set to the old code's value, in a temporary
  configuration, fails `FailedFaceAgreed`: `StampAtEnd` in 7 states,
  `OutcomeWatermarks` in 5, both in 5. `Converged` holds under either.
- `test/features/relationships/runtime/relationship_cadence_model_conformance.dart`
  replays the model beside `RelationshipCadence`: wakes that start, finish
  or fail on either device, writes of the row, deliveries, the real
  `updateAgentState`, `relationshipWakeOutcome`, `mergeAgentStateCounters`
  and `relationshipAgentCardStateOf`; 120 generated traces, two pinned ones
  for the counterexamples. Reverting the join or the card's read fails the
  trace; reverting the stamp to the wake's start fails the workflow suite.
- Unit regressions: the resolver's join; the entity's getters and round
  trip; the workflow's stamps, including a clock that advances during
  inference and a stamp bumped past a peer's; the card's table; the
  maintenance pass with a stale count beside a newer success, and with a
  row written before the watermark existed; the sync handler's re-offer on
  either.
