# ADR 0134: Sessions, Rooms and Trust Recover

- Status: Accepted
- Date: 2026-10-11

## Context

A sweep of the sync code after #4760 found three places where setting up or
starting sync left a device permanently out of step, with nothing to recover
it short of a restart or a reset.

- **Trusted later, dropped for good.** The inbound trust gate (rule F8)
  dropped every payload not encrypted by a device this one shares its keys
  with. That covers forgeries, and also a peer whose verification had only
  completed on one side, or whose device keys had not arrived yet. Such an
  event never entered the queue, so the applied marker moved past it, and
  verifying the device afterwards brought nothing back. Settings sent in
  that window were lost.
- **Offline at start, offline all session.** `MatrixService.init` connected
  once. Without network the homeserver check threw before the stored
  session was loaded, and nothing tried again: connectivity coming back only
  recorded a metric, so sync stayed off until the next launch.
- **Manual sign-in split the fleet.** Signing in with a homeserver, user and
  password always created a new sync room. A second device set up that way
  never met the account's existing devices, and nothing reported the split.

## Decision

- **An event from a device not trusted yet is held, not dropped.** The gate
  keeps dropping forgeries. A payload whose verdict is `untrustedDevice` or
  `unknownDevice` is stored as an abandoned queue row under
  `untrustedReason`. `InboundQueue.readmitUntrusted` checks each held event
  again against the current device keys and re-arms the ones now trusted. It
  runs when a verification completes or the device set changes
  (`refreshDeviceKeysAndResumeSync`), and at every queue start. No other
  resurrection path touches a held row: "Retry all" and an attachment
  landing cannot apply an event without a fresh trust check.
- **A failed start keeps connecting.** When the first connect fails and a
  configuration exists, `MatrixService` tries again after 30 seconds,
  doubling the wait up to five minutes, and at once when connectivity
  returns. It stops once the client is logged in by any path, or on dispose.
- **Manual sign-in joins the existing room.** `configureFromCredentials` uses
  the account's existing sync room when it has one: among the joined rooms
  carrying the `m.lotti.sync_room` marker, the one whose latest event is
  newest (`MatrixSyncGateway.findSyncRoom`). It creates a room only when the
  account has none.

## Consequences

- Held events stay in the queue ledger until their device is trusted; a
  device that never is keeps its rows there, terminal and visible as skipped.
- An account that already has several sync rooms from earlier manual
  sign-ins converges on the most recently used one; the others are left as
  they are.
- A device that can never reach its homeserver keeps trying every five
  minutes for the session.
