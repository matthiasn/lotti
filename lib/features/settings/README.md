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
  measurables), preferences, and advanced options.
- **Adapts to the window.** On a wide screen, a navigation tree beside the
  selected page, with a breadcrumb naming where you are; on a phone, a
  drill-down where Back walks up exactly one level at a time. Both are built
  from the same structure, so they can never disagree.
- **Shows only what applies.** Parts of the app gated behind feature flags simply
  are not there when the flag is off.
- **Every settings page has a link.** Each page and editor has a URL, so a deep
  link, a restored session or the manual opens it directly — on a phone with the
  pages above it already in place to go back through.
- **One page for turning the app's parts on.** *Sections*, second from the top of
  Settings, is where Daily OS, Projects, Goals, Habits, Dashboards, People and
  Events are switched on or off — the switches that reveal a feature sit where
  someone looking for that feature will actually find them, not three levels down
  under Advanced. Config Flags keeps the preferences and the diagnostics, grouped
  so the two are told apart.
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

The settings tree (what exists, how it is grouped, which flags gate it); the
route registry that says where each entry leads; the desktop tree-and-detail
page and the mobile drill-down; the shared presentation widgets and list/detail
scaffolding every definition editor reuses; the confirm-then-progress modal; and
the pages that belong to no other feature — sections, config flags, logging,
manual language, maintenance, about, completion animations, health import, and
the measurable editor.

It does **not** own the pages that configure another feature. AI, agents,
categories, labels, projects and sync settings live in their features, and so do
the dashboard definitions (`dashboards`), the habit list (`habits`), theming
(`theming`), notification settings (`notifications`), recording style
(`onboarding`), speech (`tts`), keyboard shortcuts (`keyboard`), system health
(`system_health`) and GitHub (`github`). Settings only references them from its
route registry.

## Where the code lives

```text
lib/features/settings/
├── domain/     # the tree, its index, flag placement, shared URLs
├── state/      # tree selection, tree width, settings-owned controllers
├── routing/    # settingsRoutes — every destination, declared once
└── ui/
    ├── pages/      # desktop page, settings-owned pages, list shell
    ├── detail/     # desktop detail pane and panel host
    ├── labels/     # localized title and description per tree node
    ├── mobile/     # drill-down root, branch hubs, shell
    ├── tree/       # tree rows and nodes
    ├── url_sync/   # tree path ↔ URL
    └── widgets/    # breadcrumb, resize handle, form and list widgets
```

## How it works

The tree and the registry, how a URL becomes a page stack or a desktop panel,
why every page names its pop target, flag placement, and the editor kit are
documented in the knowledge bundle:

**→ [knowledge/features/settings.md](../../../knowledge/features/settings.md)**
