---
type: Feature Module
title: Theming
description: Stored preferences turned into ThemeData, and the one selection that syncs across devices.
resource: ../../lib/features/theming
tags: [theming, themes, sync]
status: stable
generated: { by: codex/gpt-6, at: 2026-09-26T10:14:00Z }
stale_after: 2027-03-08
sources:
  - id: settings-db
    resource: ../../lib/database/settings_db.dart
    title: Atomic versioned settings groups
    last_modified: 2026-09-26
  - id: sync-apply
    resource: ../../lib/features/sync/matrix/sync_event_processor_apply.dart
    title: Normalize and atomically apply received preferences
    last_modified: 2026-09-26
  - id: src
    resource: ../../lib/features/theming
    title: Theming source
    last_modified: 2026-07-28
---

The theming feature builds the app's one theme — `withOverrides(DesignSystemTheme)`
for each brightness — and turns the stored light/dark/system preference into
what `MaterialApp` renders. The old scheme picker is gone, but sync still
round-trips legacy scheme names stored by older devices, using the legacy
default only when a stored name is absent.

# The sync boundary

A local mode selection uses the
[local settings group contract](../architecture/persistence.md#settings-groups)
to commit its value, retained legacy names and version before scheduling sync.
The debounce captures that committed snapshot; a remote reload during the wait
cannot substitute a different mode into its envelope. Failed saves are logged
and publish nothing. The screen still updates optimistically when the user picks.

There is no durable theme-publication marker: disposal can cancel a pending
debounce, and a failed or unavailable outbox does not automatically republish it.
These source-publication windows remain outside the convergence guarantee.

Inbound application normalizes an unknown mode to `system`, then uses the
[versioned settings group contract](../architecture/persistence.md#settings-groups)
to choose and commit a complete preference. A losing version changes nothing and
emits no settings notification. A successful commit notifies with `fromSync`,
which reloads the theme without enqueuing an echo.

```mermaid
flowchart TD
  Pick["Local mode pick"] --> Save["Commit local settings group"]
  Save -->|success| Debounce["Debounce 250 ms"]
  Debounce --> Enqueue["Enqueue committed snapshot"]
  Save -->|failure| Log["Log error; do not enqueue"]
  Message["Incoming theme selection"] --> Normalize["Normalize mode"]
  Normalize --> Compare["Atomically compare stamp and payload"]
  Compare -->|loses| Ignore["Keep current settings"]
  Compare -->|wins or identical| Commit["Commit names, mode and stamp"]
  Commit --> Notify["Notify fromSync and reload"]
```

The [sync message model](sync/message-model.md#settings-without-sequence-recovery)
documents the delivery and retry boundary shared with other preference messages.
Local-only preferences such as pane widths and Daily OS category exclusions do
not use this protocol.

# Where the theme comes from

`ThemingController._buildTheme` composes
`withOverrides(DesignSystemTheme.dark()/light())`: the
[design system](design_system/) supplies the token-derived `ColorScheme`
(surfaces, container ramp, accents), `TextTheme` (including the platform-aware
color-emoji font fallback) and the `DsTokens` extension behind
`context.designTokens`; `withOverrides` layers the Material-level extras on
top — wolt sheet motion, markdown theme, input/card shapes — without touching
the scheme or the text theme. The screenshot harness's `screenshotTheme`
builds the identical composition, which is what keeps design verdicts made on
captures transferable to the running app.

The theming **UI** lives under [settings](settings.md); the state machine lives
here.
