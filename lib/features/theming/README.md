# Theming

Theming decides how Lotti looks: light, dark, or following the system. There is
exactly one theme — the design system's — built for each brightness.

## What it does for the user

- **Light, dark, or follow the system.**
- **Follows the user across devices.** Picking a mode on the laptop changes it on
  the phone too.

Device-local preferences — pane widths, AI concurrency, day-planning exclusions —
deliberately do **not** sync; the theme does, because a look is a personal
preference rather than a machine setting.

## What it owns

The theme-mode state and construction of the light and dark `ThemeData` — both
`withOverrides(DesignSystemTheme…)` — plus the sync of the mode selection.

The theming settings **page** lives here too (`ui/theming_page.dart`);
[settings](../settings/README.md) only routes to it at `/settings/theming`. The
design tokens it builds on come from [design_system](../design_system/README.md).

## Where the code lives

```text
lib/features/theming/
```

## How it works

The sync boundary and how the design-system tokens reach the app theme are
documented in the knowledge bundle:

**→ [knowledge/features/theming.md](../../../knowledge/features/theming.md)**
