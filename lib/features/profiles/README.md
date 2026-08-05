# Profiles

Profiles make one running Lotti able to host several complete, mutually
isolated worlds. A profile is a root directory holding *everything* — every
database, media file, log, and setting. The **real** profile is the existing
documents root (existing installs never move a byte); **guest** profiles
(today: the demo workspace) live under `guest_profiles/<uuid>/` beneath it.

## What it does for the user

- **Separation by default.** A guest world cannot read or write the real
  journal: it has its own databases, files, and settings, a fresh sync
  identity, and no sync stack at all — the Matrix pipeline is never even
  constructed there, so real credentials are never read.
- **Crossing over is explicit.** The one sanctioned crossing is the demo
  exit flow: on leaving, the user can choose to copy their own demo-created
  work (tasks, entries, media, connected AI setup) into the real journal.
  Seeded demo content is excluded and never travels; nothing is copied
  without the user picking it.
- **Seamless switching.** Entering or leaving a guest world happens in-app,
  behind a brief splash, without restarting the app. A crash mid-demo reopens
  the same world on the next launch.
- **Nothing surprising survives the switch.** Device-level state (window
  geometry, hint flags) is deliberately shared; everything content-shaped is
  per-world.

## Module map

```text
lib/features/profiles/
├── model/        Profile + registry state, ProfileContext + capabilities
├── repository/   ProfileRegistry — profiles.json at the real root
├── service/      ProfileSwitcher (the in-app switch),
│                 WorldHandle (writes into a non-active world),
│                 DemoWorldCreator (create → seed → activate ordering)
├── state/        profile/capability Riverpod providers
└── profile_paths.dart   directory-name constants + guest-root guard
```

`ProfileRegistry` and `ProfileSwitcher` deliberately live *outside* getIt:
getIt is reset on every switch, and these two are what drive and survive it.
Capabilities (`syncEnabled`, `healthImportEnabled`) are how guest worlds
exclude whole stacks structurally instead of toggling them off.

## What it delegates

Profiles provide the worlds; they do not decide what goes in them. Seeding,
the demo banner and entry points, exit copy-over, and everything else
demo-flavoured belongs to [`lib/features/demo/`](../demo/README.md).

## How it works

The registry format, the isolation contract and its audit tests, the
switch's quiesce → teardown → bootstrap sequence, and the
populate-first-then-migrate rule are documented in the knowledge bundle:

**→ [knowledge/architecture/profiles-and-demo-mode.md](../../../knowledge/architecture/profiles-and-demo-mode.md)**
