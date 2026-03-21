# Design System

This feature contains the standalone Widgetbook-first design system work.

## Scope

- Import Figma design tokens from `assets/design_system/tokens.json`
- Generate typed Flutter token classes under `theme/generated/`
- Build a standalone Widgetbook-only theme
- Build new design-system components without retrofitting existing app widgets
- Render design-system typography with the bundled local `Inter` variable font

## Accessibility Conventions

- Interactive controls require either a visible label or a `semanticsLabel`
- Split buttons use `mainSemanticsLabel` for the primary action when the
  visible label is omitted, and the dropdown action derives its fallback label
  from that same accessible name unless explicitly overridden
- Decorative trailing info icons must use a real tooltip message
- Disabled states should block interaction and keep semantics in sync

## Implemented Components

- Typography showcase
- Buttons
- Badges
- Chips
- Dropdowns
- Split buttons
- Tabs
- Calendar picker
- Progress bar
- Toggles
- Radio buttons
- Checkboxes

## Usage

Import all components and theme via the barrel file:

```dart
import 'package:lotti/features/design_system/design_system.dart';
```

## Shared Utilities

- `utils/disabled_overlay.dart` — `Widget.withDisabledOpacity()` extension used
  by all interactive components for consistent disabled treatment.

## Import Workflow

Run:

```sh
make design_system_import
```

This regenerates:

- `lib/features/design_system/theme/generated/design_tokens.g.dart`

The import currently targets the consolidated token export we have today. If the
Figma export later splits into manifests, foundations, use cases, and styles,
the importer can be extended without touching component code.
