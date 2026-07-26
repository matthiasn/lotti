# Settings

Settings is where the user configures Lotti: what AI it uses, how it syncs, what
categories and labels exist, how it looks, and which optional features are turned
on.

It is deliberately thin. Most settings *pages* live with the feature they
configure — Settings provides the structure, the navigation, and the shared form
and list scaffolding they all sit in.

## What it does for the user

- **One organized place to configure everything.** A single menu covering AI,
  agents, sync, definitions (categories, labels, habits, dashboards,
  measurables), theming, and advanced options.
- **Adapts to the window.** On a wide screen, a navigation tree beside the
  selected page; on a phone, a drill-down where Back walks up one level at a
  time. Both are generated from the same structure, so they can never disagree.
- **Shows only what applies.** Sections gated behind feature flags simply are not
  there when the flag is off.
- **Consistent editors.** Every definition editor looks and behaves the same:
  search and create on the list, grouped form sections, a sticky Save that is
  only enabled when something changed, Primary+S to save, and delete behind a
  confirmation.
- **Safe destructive actions.** Long-running and irreversible operations go
  through a two-step confirm-then-progress modal rather than a bare button.
- **Fully translated, including the corners.** Every label — even debug and
  maintenance rows — comes from the translation catalogs, so no screen becomes an
  English island in another language.

## What it owns

The desktop/mobile layout fork; route composition for `/settings/**`; the shared
settings presentation widgets; the shared list and detail scaffolding every
definition editor reuses; the confirm-then-progress modal; and its own utility
pages — theming, flags, logging domains, manual language, maintenance, about,
health import and recording style.

It does **not** own the AI, agents, categories, labels, projects or sync settings
pages — those live in their features and Settings only routes into them. The menu
structure itself lives in [settings_v2](../settings_v2/README.md).

## Where the code lives

```text
lib/features/settings/
└── ui/
    ├── pages/          # utility pages + shared list/detail scaffolding
    │   └── advanced/
    └── widgets/
```

## How it works

The declarative settings tree, route assembly on each platform, the ownership
boundaries, and the shared list/detail kit are documented in the knowledge bundle:

**→ [knowledge/features/settings.md](../../../knowledge/features/settings.md)**
