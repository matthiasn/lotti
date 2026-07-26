# Theming

Theming decides how Lotti looks: light or dark, and which theme within that.

## What it does for the user

- **Light, dark, or follow the system.**
- **Choice of themes** within each mode.
- **Follows the user across devices.** Picking a theme on the laptop changes it on
  the phone too.

Device-local preferences — pane widths, AI concurrency, day-planning exclusions —
deliberately do **not** sync; the theme does, because a look is a personal
preference rather than a machine setting.

## What it owns

Theme selection state and construction of the light and dark `ThemeData`, plus the
sync of the selection.

The theming settings **page** lives under [settings](../settings/README.md); the
design tokens it builds on come from
[design_system](../design_system/README.md).

## Where the code lives

```text
lib/features/theming/
```

## How it works

The sync boundary and how the design-system tokens reach the app theme are
documented in the knowledge bundle:

**→ [knowledge/features/theming.md](../../../knowledge/features/theming.md)**
