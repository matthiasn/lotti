# Sync

Sync keeps one person's Lotti data identical across their own devices — phone,
laptop, desktop — without any of it passing through a server that can read it.

It is **single-user, multi-device replication**. It is not a collaboration
feature: there is no sharing with other people, no permissions model, and no
merge of two users' work.

## What it does for the user

- **Keeps devices in step.** An entry written on the phone shows up on the
  desktop, and the reverse, with no manual export or import.
- **Works offline.** Changes made with no connection are queued on the device
  and sent when it reconnects. Nothing is lost while offline.
- **Uses the user's own Matrix account.** Self-hosted or any public homeserver —
  Lotti runs no sync server of its own, and the homeserver only ever relays
  content it cannot decrypt.
- **Repairs itself.** If a device misses something — it was off for a week, or a
  message never arrived — it notices the hole and asks the other devices for the
  missing piece rather than silently diverging.
- **Asks when it genuinely cannot decide.** If the same entry was edited on two
  devices while both were offline, sync raises a conflict, notifies the user, and
  offers a side-by-side field comparison with the option to keep either version
  or combine them. It never silently picks a winner for journal content.
- **Can hand AI work to a capable device.** Audio recorded on a phone can be
  transcribed automatically on a pinned desktop that has local models
  installed — and the path is built so that audio can never be handed to a cloud
  provider by accident.
- **Never hands keys to unverified devices.** Encryption keys are shared only
  with devices this session has emoji-verified (ADR 0045). An unverified
  device — a fresh install awaiting its ceremony, or a dead session left by
  an uninstalled app — receives ciphertext it cannot read, while every
  verified device keeps syncing. Nothing ever halts.
- **Adds a device from any device already syncing.** "Add device" sits on the
  device roster and mints a handover code on demand — a phone that outlives its
  desktop can onboard the replacement. The code is shown only when asked for,
  and it says plainly that it unlocks the account — it can also be copied as
  text, so it is treated as a credential throughout: let your own new device
  scan it, but never keep a screenshot or send it through chat or email. The
  joining device opens straight into the camera, with manual entry as the
  fallback, and finishes on a screen naming what is still outstanding: the
  emoji ceremony, plus the settings and message-history pushes that only the
  other device can send. Both transfers stay beside the pairing code and remain
  disabled until that exact new device's Matrix verification ceremony succeeds
  (roster order never chooses the target): message history
  defaults to everything, with 30-day and custom ranges available, and shows
  progress until the messages are queued. During that full initial transfer,
  the new device holds off asking for history that is already on its way; a
  failed or disconnected transfer releases that hold automatically.
- **Gives both devices something a person can actually compare.** Before
  anything is configured, the joining device shows which account it is about to
  join and a six-character check code that the inviting device derives
  independently and displays too — so a wrong or stale code is something to back
  out of rather than discover afterwards. A code from a different Lotti release
  says so instead of calling itself invalid.
- **Lets the user manage the device roster.** The sync status page lists every
  session on the account — verified or not, with when the server last saw it —
  and any of this account's sessions except the current one can be removed.
  (Devices from the legacy one-user-per-device pairing model appear too while
  unverified, but they can only be verified, not removed.) The roster warns
  while any device is excluded from sync and names the remedy; removal is
  hygiene, not an unblock step, and a bounded, best-effort key refresh tidies
  the cache right away — or on a later sync cycle if it cannot complete. A
  removal the server refuses because the saved account password has gone stale
  asks for the current one and finishes on the spot, and verification against
  a device that has been silent for weeks says the peer must be awake before
  opening a ceremony that would otherwise wait forever.

## What it owns

Outbound queueing and retries, Matrix session and room lifecycle, inbound
ingestion and ordered application, causal accounting over what each device has
seen, gap repair between peers, and the sync-facing settings, diagnostics,
provisioning and maintenance screens.

It does not own what gets synced. Journal, agents, AI configuration, tasks,
theming and notifications each decide what to enqueue; sync moves it.

## Where the code lives

```text
lib/features/sync/
├── outbox/      # outbound queue and send loop
├── matrix/      # session, rooms, sending, verification
├── gateway/     # Matrix SDK wrapper
├── queue/       # inbound queue, catch-up bridge, worker
├── sequence/    # (hostId, counter) accounting
├── backfill/    # gap requests and responses
├── onboarding/  # bounded initial-history suppression protocol
├── media/       # self-healing fetch for missing image/audio blobs
├── model/       # SyncMessage and node profiles
├── state/       # Riverpod controllers
└── ui/          # settings, stats, conflicts, outbox monitor
```

## How it works

For failure history, log-backed investigations and tuning context, see
[docs/architecture/sync_current_architecture.md](../../../docs/architecture/sync_current_architecture.md).

The runtime architecture — the outbox and its bundling, the inbound queue
pipeline, vector clocks and conflict detection, the sequence log and backfill,
and the synced-audio auto-trigger — is documented in the knowledge bundle:

**→ [knowledge/features/sync/](../../../knowledge/features/sync/)**
