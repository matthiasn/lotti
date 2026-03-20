# Design System

This feature contains the standalone Widgetbook-first design system work.

## Scope

- Import Figma design tokens from `assets/design_system/tokens.json`
- Generate typed Flutter token classes under `theme/generated/`
- Build a standalone Widgetbook-only theme
- Build new design-system components without retrofitting existing app widgets

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
