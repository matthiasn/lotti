# ADR 0050: Multi-tenant worlds

## Status

Proposed

## Date

2026-08-05

## Context

[ADR 0049](./0049-profile-scoped-storage-and-demo-mode.md) built a profile
system to isolate one demo world from real data. It generalises further than
the feature that motivated it: a **profile is a complete world**, and the demo
is simply the first non-real one. The obvious next question — repeatedly
raised — is whether a user could keep *work* and *private* as separate worlds
on the same device, each with its own data and its own sync.

Nothing in the codebase decides this today. ADR 0049 gestures at it under
"Open questions" ("promoting a guest world to a synced world", "multiple
concurrent guest worlds") but records no position on peer tenants. This ADR
exists to hold that position explicitly rather than leaving it implied by
what the code happens to permit.

Nothing here is scheduled. The value is in recording what already
generalises, what does not, and which of the blockers is load-bearing — so
that the next person to touch profiles does not discover it by trial.

## What already generalises

The switching machinery is tenant-shaped, not demo-shaped:

- `ProfileRegistry` stores a list of profiles with an active-profile marker;
  `setActiveProfile` and `rootFor` are id-generic and type-blind.
- `ProfileSwitcher.switchTo(id)` tears down and rebuilds an entire service
  generation for **any** profile id — quiesce, `ServiceDisposer.disposeAll()`,
  `getIt.reset()`, re-bootstrap, bump the `ProviderScope` generation key. It
  contains no demo-specific logic.
- `WorldHandle.open(root)` opens a full, non-active database set with explicit
  documents-directory providers — the mechanism for touching a world you are
  not currently living in.
- Per-world storage is complete: every Drift database including
  `settings.sqlite`, and therefore the sync host ID (`VC_HOST`) and the Matrix
  room id (`MATRIX_ROOM`, `lib/features/sync/matrix/consts.dart`), plus
  sidecars, media, logs, backups and embeddings.

A second tenant would inherit all of that unchanged. The gap is not the
switch; it is the model, the capability derivation, and one device-global
store.

## Blockers

Four, in the code as it stands:

1. **Exactly one real profile is representable by construction.**
   `Profile.tryFromJson` rejects `type == ProfileType.real` with a non-empty
   `dirName`, and rejects any guest whose `dirName` does not start with
   `guest_profiles/` (`lib/features/profiles/model/profile.dart`). The real
   world *is* the root. A peer tenant needs its own directory, which the model
   currently refuses to parse.

2. **Only guests can be created.** `ProfileRegistry.createGuestProfile` is the
   sole creation API and hard-codes the type and the `guest_profiles/` prefix.

3. **Capabilities are derived from the type, not carried.**
   `ProfileContext.forProfile` maps `isGuest` onto the frozen
   `ProfileCapabilities.guest` / `.real` presets, so sync and health import are
   on if and only if the world is the real one. Peer tenants need capabilities
   decoupled from `ProfileType` — a second synced world is `real`-capable
   without being *the* real world.

4. **The Matrix credential store has no world dimension — and this is the
   load-bearing one.** `matrixConfigKey = 'MATRIX_CONFIG'`
   (`lib/features/sync/matrix/consts.dart`) is a single device-global keychain
   entry. ADR 0049 permits that sharing *only* because guest worlds never
   construct a reader. Two sync-enabled worlds break that premise directly:
   both would read the same credentials and sync as the same account. Room ids
   are already per-world, so the rooms would differ — but the account, the
   device keys, and the key-sharing decisions would not.

Two further consequences, softer but real:

- **Layout.** Guests nest *inside* the real root, which is correct for a
  disposable play world and wrong for a peer: deleting or relocating the real
  world would take the other tenant with it. Peers want siblings under a
  container root — which means moving the existing real world, precisely the
  migration ADR 0049 avoided in order to stay backward compatible.
- **Device-global surfaces beyond storage.** OS notifications are scheduled
  against a single plugin instance with ids derived per entity
  (`NotificationScheduler.notificationIdFor`) plus fixed constants such as the
  day-plan and conflict notification ids. Two tenants would overwrite each
  other on the fixed ids, and a notification tapped while the *other* tenant is
  active deep-links into a world that is not loaded. Background wake
  scheduling has the same shape.

## Decision

**Multi-tenancy is the intended generalisation of profiles, and demo mode is
one tenant class within it — but it is not implemented, and no code should be
shaped speculatively for it.** Concretely:

- `ProfileType` stays `real | guest` until a peer-tenant feature is actually
  scheduled. Adding a third value now would spread unexercised branches
  through registration.
- The isolation invariants in ADR 0049 are the durable part and hold for any
  future tenant: one path authority, per-world sync state, capability-gated
  registration, nothing device-global that carries user data.
- Any work that touches profiles must not deepen the four blockers — in
  particular, no new code may assume "guest" and "not the real world" are the
  same predicate, or that capabilities can be re-derived from `ProfileType` at
  the point of use rather than read from `ProfileContext.capabilities`.

When peer tenants are scheduled, the recommended shape is:

| Blocker | Recommended resolution |
|---------|------------------------|
| Model | Keep `dirName` as the discriminator, drop the type↔dirName coupling in favour of a `container/<uuid>` prefix validated for the same traversal safety. The real world keeps its empty `dirName` forever. |
| Creation | Generalise to `createProfile({type, name})`; `createGuestProfile` becomes a thin caller. |
| Capabilities | Persist capabilities on the `Profile` (defaulting from type on read), so a synced peer is expressible without a new type. |
| Credentials | Per-profile keychain key `MATRIX_CONFIG:<profileId>`, with a one-time migration of the existing entry to `MATRIX_CONFIG:real`. Each tenant creates or joins its **own** room; no tenant may ever join another's. |
| Layout | Leave the real world at the root. Peers go under a sibling container, not under `guest_profiles/`. Do not migrate the real root. |
| Notifications | Tenant-qualify the fixed notification ids and record the owning profile id in the payload, so a tap either switches worlds deliberately or is dropped. |

## Consequences

- The demo feature ships without waiting on any of this, and the machinery it
  introduced is reusable rather than throwaway.
- The credential-scoping migration is the single largest piece of work behind
  peer tenants, and it lands in the security-sensitive part of the codebase —
  it should not be attempted incidentally alongside a UI feature.
- Until this ADR moves to Accepted, "can I have work and private worlds?" has
  a documented answer: not yet, and here is exactly what it costs.

## Related

- [ADR 0049: Profile-scoped storage and the demo-mode sync boundary](./0049-profile-scoped-storage-and-demo-mode.md)
- [Profiles and demo mode](../../knowledge/architecture/profiles-and-demo-mode.md)
- [ADR 0045: Exclude unverified devices from key sharing](./0045-exclude-unverified-devices-from-key-sharing.md)
  — the key-sharing rules a second synced tenant would have to satisfy
  independently.
