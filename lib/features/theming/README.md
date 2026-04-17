# Theming Feature

The `theming` feature owns app theme selection and theme construction.

It takes stored user preferences and turns them into actual `ThemeData` objects for:

- light theme
- dark theme
- theme mode

It also syncs theme selection across devices through the sync feature.

## What This Feature Owns

At runtime, the feature owns:

1. the current theming state (`lightTheme`, `darkTheme`, names, mode)
2. building `ThemeData` from theme definitions
3. persistence of theme selection to `SettingsDb`
4. enqueueing theme-selection sync messages
5. live reload when synced settings changes arrive

## Directory Shape

```text
lib/features/theming/
├── model/
├── state/
└── README.md
```

## Architecture

```mermaid
flowchart LR
  UI["Settings / app shell"] --> Ctl["ThemingController"]
  Ctl --> Themes["theme_definitions.dart"]
  Ctl --> Settings["SettingsDb"]
  Ctl --> Notify["UpdateNotifications"]
  Ctl --> Sync["OutboxService"]
  Themes --> ThemeData["ThemeData builders"]
  ThemeData --> App["MaterialApp theming"]
```

The feature is conceptually simple, but the runtime path matters because theme changes can come from:

- the local user
- synced settings updates from another device

## Theme Construction Model

`ThemingController` builds theme data from:

- the selected light theme name
- the selected dark theme name
- the selected `ThemeMode`

Theme definitions come from standard `FlexScheme` mappings.

The build path also applies:

- shared overrides
- Linux emoji font fallback

## Theming State Machine

The explicit runtime lifecycle looks like this:

```mermaid
stateDiagram-v2
  [*] --> DefaultTheme: build()
  DefaultTheme --> LoadedPrefs: _loadSelectedSchemes()
  LoadedPrefs --> LocalUpdate: setLightTheme / setDarkTheme / onThemeSelectionChanged
  LocalUpdate --> LoadedPrefs: settings saved + sync message enqueued
  LoadedPrefs --> SyncedReload: settings notification from sync
  SyncedReload --> LoadedPrefs: _loadSelectedSchemes()
```

That split between local update and synced reload is important. The controller explicitly avoids enqueuing a new sync message while it is applying synced changes, which prevents theme ping-pong between devices.

## Theme Selection Flow

```mermaid
sequenceDiagram
  participant User as "User"
  participant Ctl as "ThemingController"
  participant Settings as "SettingsDb"
  participant Sync as "OutboxService"

  User->>Ctl: choose light/dark theme or theme mode
  Ctl->>Ctl: validate theme name and build ThemeData
  Ctl->>Settings: save selected names / mode
  Ctl->>Sync: enqueue themingSelection sync message
  Ctl-->>User: updated theme state
```

## Theme Definitions

`theme_definitions.dart` provides:

- the map of standard theme names to `FlexScheme`
- validation helpers
- the default theme name
- light-mode surface constants

## Sync Semantics

Theme changes are synced via `SyncMessage.themingSelection`.

Theming therefore behaves like a user preference with cross-device propagation, not like a purely local UI tweak. That is the right choice for an app where users generally expect "my chosen theme" to follow them.

## Relationship to Other Features

- `settings` exposes the user-facing theme controls
- `sync` transports theme-selection changes across devices

This feature is small, but it is one of the cleanest examples in the codebase of a focused controller doing one job well: build theme state, persist it, and keep it in sync.
