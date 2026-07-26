# ADR 0045: Exclude Unverified Devices from Key Sharing

## Status

Accepted

## Date

2026-07-26

## Context

### One ghost device could halt all sync

Sync replicates one user's data across their devices over end-to-end
encrypted Matrix. The app never bootstraps cross-signing, so the Matrix SDK's
default key-sharing policy (`ShareKeysWith.crossVerifiedIfEnabled`) degrades
to *share megolm keys with every non-blocked device*. Emoji (SAS)
verification therefore did not gate the cryptography at all — the only
confidentiality backstop was an app-level tripwire in
`MatrixMessageSender.sendMatrixMessage`, which refused to send **anything**
while `unverifiedDevices()` was non-empty.

That conflated two very different goals:

- *Confidentiality*: an unverified device must not receive key material.
- *Availability*: trusted devices should keep syncing.

The tripwire bought the first by destroying the second. A single unverified
device — typically a session left behind by an uninstalled app that never
logged out — silently stopped outbound sync on **every** device, and because
the dead session could never complete a verification, the outage was
permanent until the device was deleted (the support case that produced the
device-management roster, PRs #3609/#3614).

### Why flipping the policy is migration-safe

`ShareKeysWith.directlyVerifiedOnly` requires each *sender* to have
SAS-verified every device it shares keys with. The old tripwire already
enforced exactly that, more brutally: a device could not send at all until
its own unverified list was empty. So any install that has ever successfully
sent had already verified its full mesh — for such installs the policy flip
excludes nobody and changes nothing. For wedged installs (the ghost-device
case) it restores sync among the trusted devices. The newly-excluded case —
sender shares with a device it never verified — previously meant "sender
halts entirely", so availability strictly improves and confidentiality never
weakens.

Legacy rooms paired under the old one-user-per-device model verify
cross-user via SAS; `directlyVerifiedOnly` honours direct verification
regardless of which user owns the device, so those rooms keep working under
the same full-mesh requirement the tripwire already imposed.

## Decision

1. Construct the sync `Client` with
   `shareKeysWith: ShareKeysWith.directlyVerifiedOnly`
   (`lib/features/sync/matrix/client.dart`, shared by the default and actor
   paths). The SDK now withholds megolm keys from any device the sending
   session has not directly verified: an unverified device receives
   ciphertext it can never decrypt.
2. Demote the sender tripwire from a halt to a log line. Sends proceed while
   unverified devices exist; the device roster's warning banner
   (`SyncDevicesList`) remains the user-facing signal and names the remedy
   (verify or delete).
3. Keep the banner and roster semantics: an unverified device with published
   keys is now *excluded from new entries* rather than *blocking everyone*,
   and the copy says so.

Deliberately **not** done here:

- Cross-signing bootstrap. It would let a user verify once per device instead
  of per pair, but it is a larger lift (SSSS, recovery keys, migration) and
  orthogonal to removing the outage. `directlyVerifiedOnly` remains correct
  if cross-signing is added later.
- Blocking (`DeviceKeys.setBlocked`). A blocked device is by definition
  unverified, so blocking alone would have made the old outage permanent; it
  buys nothing over exclusion.

## Consequences

- A dead session can no longer wedge sync. Removal (or verification) is
  hygiene and roster clarity, not an unblock step.
- A freshly paired device syncs with each peer as soon as that peer has
  verified it — the pairing flow's auto-launched ceremony per device pair is
  now load-bearing for coverage, exactly as the old tripwire made it.
- If a pair is never verified, entries sent by one side are permanently
  unreadable by the other (no key backup exists). The roster banner is the
  guard rail; the sequence-log/backfill layer treats such gaps like any
  other missing counters.
- The verification state is per-install local trust. A reinstalling device
  starts unverified everywhere and must re-verify with each live peer —
  unchanged from before, but now the cost is scoped to that device instead
  of the whole mesh.
