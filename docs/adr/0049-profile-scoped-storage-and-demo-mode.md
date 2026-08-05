# ADR 0049: Profile-scoped storage and the demo-mode sync boundary

Date: 2026-08-05
Status: accepted

## Context

Demo mode needs a play world with complete isolation from real data: its own
root path, databases, settings, and sync identity, with zero possibility of
cross-contamination. Before this change the app had two independent root
resolution mechanisms (the getIt `Directory` singleton for file I/O, and a
fresh `findDocumentsDirectory()` call inside every database open), several
device-global stores (SharedPreferences, keychain, TTS model cache), and a
sync stack whose `enable_matrix` flag gated only outbox *sends* — enqueues,
the inbound pipeline, backfill timers, and a startup node-profile broadcast
all ran unconditionally.

## Decision

**One path authority.** The getIt `Directory` singleton is registered to the
active profile root; `openDbConnection` falls back to it and never re-derives
the OS path once a root is registered. Guest worlds nest under
`<realRoot>/guest_profiles/<uuid>/`; the real world stays at the existing
root, unmoved (backward compatible).

**Per-profile (inside the profile root):** all Drift databases including
`settings.sqlite` (hence the sync host ID `VC_HOST`, minted fresh per world),
entity JSON sidecars, media, waveform caches, agent files, logs, backups,
embeddings, and — real world only — the `matrix/` session store.

**Global (device):**

| Store | Scope rationale |
|-------|-----------------|
| SharedPreferences (whats-new seen, `seen_` hints, recording style, backfill toggle) | Device-level UX memory; not path-scopable; leaking "seen hint X" into a demo is desirable, carries no user data. |
| Keychain `MATRIX_CONFIG` (Matrix credentials) | OS keychains are app-scoped. Stays global and real-only: guest worlds never construct a reader (see below), and keeping it global preserves a future "promote demo to synced" without re-login. |
| Window geometry | Device/hardware state — moved from SettingsDb to SharedPreferences (with one-time migration) so a switch doesn't snap the window. |
| TTS model cache (`tts_models/`) | Content-addressable blobs, no user data; hundreds of MB not worth duplicating. |
| OS temp dir / `sqlite3.tempDirectory` | Anonymous transient spill files, process-global property. |
| `profiles.json` | The registry lists worlds; by definition it cannot live inside one. |

**Sync is structurally absent in guest worlds, not disabled.** Registration
branches on `ProfileCapabilities.syncEnabled`: guests get an
`InertOutboxService` (all enqueues are counted no-ops) and none of the Matrix
stack — no client, no inbound queue, no backfill timers, no broadcasts, no
VC-burn handlers. This is stronger than any flag: a guest world produces zero
outbox rows and has no code path that reads the keychain credentials.

## Sync-config sharing analysis (requirement 9)

Sharing the Matrix *credentials* store between worlds is safe **only**
because guest worlds have no reader. Sharing sync *state* (room id, host id,
sequence log) would be catastrophic — a demo world writing into the real
outbox or claiming counters in the real sequence space corrupts the real
device's sync history. Hence: credentials global-but-unread, all sync state
per-profile. Should a guest world ever be promoted to a synced world, it
must (a) keep its own host ID, (b) create or join a **new** room — never the
real room — and (c) opt into the full stack via capabilities. That promotion
is explicitly out of scope here and recorded as an open question.

## Consequences

- Existing installs see no change: no registry file means "real world,
  active"; the first mutation writes `profiles.json`.
- Every database or store added in the future MUST resolve its path through
  the registered root (or an explicit provider) and be added to
  `ServiceDisposer` + `WorldHandle`; the audit tests fail on OS-path
  re-derivation.
- The demo world's logs, backups, and slow-query captures land inside the
  guest directory and are deleted with it.
- In-app switching tears down the whole service generation; anything holding
  a getIt singleton across generations is a bug (the generation-keyed
  ProviderScope is the enforcement mechanism for widgets).

## Open questions

- Promoting a guest world to a synced world (new room, existing credentials)
  — deliberately unimplemented.
- Multiple concurrent guest worlds are supported by the registry; the UI
  exposes a single demo world for now.
