# ADR 0109: A Running Peer Wake Covers at Once

- Status: Accepted
- Date: 2026-09-27
- Amends: [ADR 0090](0090-cross-device-agent-wake-coordination.md),
  [ADR 0091](0091-wake-coordination-by-vector-clock-coverage.md)

## Context

Under ADR 0090 a device whose pending wake a peer's *live* claim covered held
the wake back until the peer's `done` cancelled it, or until the claim was
released or lapsed, which let it run. While it waited, the device kept
counting down, and its summary stayed outdated. Testing on two devices,
that was what the user saw: the phone started an update after a
transcription, the desktop received the phone's entry, and the desktop's
countdown went on as if nothing had happened.

Waiting bought one thing: a device ran the wake itself if the peer's run
failed. The user's call was that it need not. A started run is trusted to
finish, and when it does not, the report staying outdated is acceptable.

## Decision

A live peer claim that covers a pending wake **drops** it, as a covering
`done` does. The countdown and the job go at once.

- **Nothing is lost.** In `specs/tla/AgentWakeCoordination.tla` the new
  `ClaimCancels` switch lets `Cancel` fire on a live covering claim.
  `NoLostEdit` still holds in all four configurations, including those with
  a failed or crashed run: that run's own wake stays owed on its device
  (`Fail`, `Crash`), and its retry covers every edit it was handed.
  `HandoverCovered` checks that a wake is only ever handed to a run that
  started over a state covering it. `CancelCovered` still applies to `done`,
  and `Exclusive` is unchanged.
- **The report is marked fresh only by a covering `done`.** A claim cannot
  say whether its run will refresh the report. A wake handed over is
  remembered, and the next covering `done` marks the report fresh if its run
  refreshed it. That may be the retry's `done`, after a failure. A wake this
  device runs itself ends the hand-over too.
- **A peer's first claim is an event.** The coordinator used to notify the
  orchestrator only when a claim ended, lapsed or was replaced. It now
  notifies on every claim that is new or changes coverage, so a covered
  countdown is checked as soon as the peer starts. A heartbeat repeating the
  same claim is not an event.
- `WakeCoordinationDefer` is gone. A covering peer run, completed or not, is
  `WakeCoordinationCancel`, with `completed` saying which.

## Consequences

- The waiting device's countdown ends when the other device *starts* a
  covering update, not when it finishes. Its summary becomes fresh when that
  update's `done` arrives.
- If the other device's run fails, this device does not run the wake. The
  summary stays outdated until the other device's retry completes, or until
  this device wakes the agent for a new edit, or the user wakes it by hand.
- A claim that reaches a device late, after a disconnect, can still drop a
  covered wake for up to the two-minute timer. The claimer's run covers it
  either way.
