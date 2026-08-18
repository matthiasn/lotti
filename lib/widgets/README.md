# Shared widgets

This directory holds the reusable widgets that belong to no single feature: app-bar
chrome, modal presentation, selection primitives, the settings page scaffolding,
the entity picker, and the bottom-navigation shell.

Anything with a token-backed visual identity — buttons, inputs, chips, badges —
lives in the [design system](../features/design_system/README.md) instead. What
remains here is composition and app-shell chrome.

## Layout

```text
lib/widgets/
├── app_bar/     # back and glass actions, sliver settings header, title bars
├── modal/       # ModalUtils (the only export), confirmation modal, item animations
├── selection/   # selection-modal primitives and the unified toggle family
├── settings/    # settings page grid and detail scaffold
├── picker/      # EntityPickerSheet, shared by categories, labels and task links
├── nav_bar/     # bottom navigation shell and FAB clearance
├── media/       # full-screen image-viewer orientation lifecycle
├── timeline/    # the one vertical timeline rail, shared by events and goals
└── misc/        # sidebar activity summary and similar cross-feature pieces
```

## How it works

Why modal presentation is centralized, why the selection primitives were
extracted, and why the bottom-nav shell lives here rather than in the design
system are documented in the knowledge bundle:

**→ [knowledge/architecture/shared-widgets.md](../../knowledge/architecture/shared-widgets.md)**
