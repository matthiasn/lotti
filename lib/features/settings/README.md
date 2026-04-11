# Settings Feature

Settings is the app's control room. It mostly does not own the engines. It owns the switches, the route stack, the "are you sure?" moments, and a few utility pages that would otherwise be left wandering the halls.

If another feature needs a configuration surface, Settings is often where the user enters. That does not mean Settings owns the underlying domain. It usually means Settings owns the doorway and knows when to stop pretending it is the whole building.

## Core Job

In the current codebase, Settings does four concrete things:

1. Renders the `/settings` landing page and several section landing pages.
2. Assembles the Beamer stack for every `/settings/...` route in [`lib/beamer/locations/settings_location.dart`](../../beamer/locations/settings_location.dart).
3. Turns config flags into visible or hidden navigation.
4. Hosts a small set of actual settings-owned pages: theming, flags, advanced utilities, health import, about, and shared editor scaffolding for several definition types.

That last point matters. Settings is mostly a router, but not only a router.

## Ownership Boundaries

### Settings owns

- The landing page in [`ui/pages/settings_page.dart`](ui/pages/settings_page.dart)
- Route composition in [`lib/beamer/locations/settings_location.dart`](../../beamer/locations/settings_location.dart)
- Shared settings presentation widgets in [`ui/widgets/`](ui/widgets/)
- Shared list/detail scaffolding such as [`ui/pages/definitions_list_page.dart`](ui/pages/definitions_list_page.dart) and [`ui/widgets/entity_detail_card.dart`](ui/widgets/entity_detail_card.dart)
- Utility pages such as:
  - [`ui/pages/theming_page.dart`](ui/pages/theming_page.dart)
  - [`ui/pages/flags_page.dart`](ui/pages/flags_page.dart)
  - [`ui/pages/advanced_settings_page.dart`](ui/pages/advanced_settings_page.dart)
  - [`ui/pages/advanced/logging_settings_page.dart`](ui/pages/advanced/logging_settings_page.dart)
  - [`ui/pages/advanced/maintenance_page.dart`](ui/pages/advanced/maintenance_page.dart)
  - [`ui/pages/advanced/about_page.dart`](ui/pages/advanced/about_page.dart)
  - [`ui/pages/health_import_page.dart`](ui/pages/health_import_page.dart)
- The two-step destructive/long-running modal wrapper in [`ui/confirmation_progress_modal.dart`](ui/confirmation_progress_modal.dart)

### Settings routes into other features

- AI settings: [`lib/features/ai/ui/settings/ai_settings_page.dart`](../ai/ui/settings/ai_settings_page.dart)
- Agents: [`lib/features/agents/ui/`](../agents/ui/)
- Categories: [`lib/features/categories/ui/pages/`](../categories/ui/pages/)
- Labels: [`lib/features/labels/ui/pages/`](../labels/ui/pages/)
- Projects: [`lib/features/projects/ui/pages/`](../projects/ui/pages/)
- Sync: [`lib/features/sync/ui/`](../sync/ui/)

### Settings hosts pages that still depend on other feature logic

- Habit editing UI lives under Settings, but save/delete state comes from [`lib/features/habits/state/habit_settings_controller.dart`](../habits/state/habit_settings_controller.dart)
- Theming UI lives under Settings, but the real state machine is [`lib/features/theming/state/theming_controller.dart`](../theming/state/theming_controller.dart)
- Health import lives under Settings, but the implementation is [`lib/logic/health_import.dart`](../../logic/health_import.dart)

So yes, Settings is thin. Just not spiritually pure.

## Directory Shape

```text
lib/features/settings/
├── constants/
│   └── theming_settings_keys.dart
└── ui/
    ├── confirmation_progress_modal.dart
    ├── pages/
    │   ├── settings_page.dart
    │   ├── advanced/
    │   ├── dashboards/
    │   ├── habits/
    │   ├── measurables/
    │   ├── advanced_settings_page.dart
    │   ├── definitions_list_page.dart
    │   ├── flags_page.dart
    │   ├── health_import_page.dart
    │   ├── sliver_box_adapter_page.dart
    │   └── theming_page.dart
    └── widgets/
        ├── dashboards/
        ├── form/
        ├── habits/
        └── measurables/
```

The structure mirrors the actual role of the feature:

- `pages/` contains both landing pages and a few editors
- `widgets/` keeps the settings area visually coherent
- `constants/` is tiny and currently only exposes theming preference keys

## Route Assembly

The canonical route owner is [`lib/beamer/locations/settings_location.dart`](../../beamer/locations/settings_location.dart).

The important implementation detail is that Settings builds *stacks*, not single pages. Parent pages stay in the Beamer stack for many subroutes.

```mermaid
flowchart TD
  Route["Incoming /settings/... path"] --> Location["SettingsLocation"]
  Location --> Base["SettingsPage is always the first page"]
  Location --> Section["Optional section page stays in stack"]
  Section --> Leaf["Optional detail/editor page"]

  Base --> AI["AI / Agents / Labels / Categories / Sync / Theming / Flags / Advanced"]
  Section --> Editor["Dashboard, measurable, habit, project, category, agent, conflict, etc."]
```

Concrete examples from the current implementation:

```text
/settings
  -> [SettingsPage]

/settings/sync/stats
  -> [SettingsPage, SyncSettingsPage, SyncStatsPage]

/settings/advanced/about
  -> [SettingsPage, AdvancedSettingsPage, AboutPage]

/settings/dashboards/:dashboardId
  -> [SettingsPage, DashboardSettingsPage, EditDashboardPage]

/settings/categories/:categoryId
  -> [SettingsPage, CategoriesListPage, CategoryDetailsPage]
```

That stacked model is why detail pages can feel like descendants of a section instead of random teleports. Beamer is doing real work here, which is nice for once.

## Runtime Topology

```mermaid
flowchart LR
  Landing["/settings"] --> AI["AI settings"]
  Landing --> Agents["Agents settings"]
  Landing --> Habits["Habits"]
  Landing --> Categories["Categories"]
  Landing --> Labels["Labels"]
  Landing --> Sync["Sync"]
  Landing --> Dashboards["Dashboards"]
  Landing --> Measurables["Measurables"]
  Landing --> Theming["Theming"]
  Landing --> Flags["Flags"]
  Landing --> Advanced["Advanced"]

  Categories --> Projects["Project create/detail routes"]
  Sync --> MatrixMaint["Matrix maintenance"]
  Sync --> Outbox["Outbox monitor"]
  Sync --> Conflicts["Conflicts page via /settings/advanced/conflicts"]
  Sync --> Stats["Sync stats"]
  Sync --> Backfill["Backfill settings"]
  Advanced --> Logging["Logging domains"]
  Advanced --> Health["Health import (mobile only)"]
  Advanced --> Maint["Maintenance"]
  Advanced --> About["About"]
```

One slightly awkward but code-accurate detail: the Sync landing page links to conflicts through `/settings/advanced/conflicts`. The UI treats conflicts as sync-adjacent, the route still wears an Advanced nametag, and everyone is currently living with that arrangement.

## Landing Page Behavior

[`ui/pages/settings_page.dart`](ui/pages/settings_page.dart) is not a static list. It is assembled from live state:

- `configFlagProvider(...)` gates Habits, Dashboards, Agents, and What's New
- `JournalDb.watchConfigFlag(enableMatrixFlag)` decides whether Sync is shown
- the Agents tile overlays a pending ritual indicator
- the What's New feature appears both as an app-bar action and as a settings card when enabled

The landing page is therefore equal parts navigation and feature census.

## Flags, Navigation, and Cross-Feature Side Effects

Settings is where feature flags become visible to users, but the effects are larger than the Settings UI itself.

```mermaid
flowchart LR
  JournalDb["JournalDb config flags"] --> FlagProvider["configFlagProvider / watchConfigFlag"]
  FlagProvider --> SettingsLanding["Settings landing page"]
  FlagProvider --> FlagsPage["Flags page"]
  FlagsPage --> Persistence["PersistenceLogic.setConfigFlag(...)"]
  JournalDb --> NavService["NavService"]
  NavService --> Tabs["Top-level tab availability"]
```

This is why the flags page is not just a developer toy:

- toggling `enableHabitsPageFlag` or `enableDashboardsPageFlag` changes both Settings tiles and top-level navigation behavior
- toggling `enableMatrixFlag` changes visibility of Sync surfaces and also affects the Sync feature gate
- logging flags influence subdomain logging pages under Advanced

The control panel is wired to actual breakers, not cardboard cutouts.

## Shared List and Detail Pattern

Dashboards, habits, and measurables all reuse the same broad pattern:

1. A list page wraps [`DefinitionsListPage<T>`](ui/pages/definitions_list_page.dart).
2. The list is fed by `notificationDrivenStream(...)` from `JournalDb` plus `UpdateNotifications`.
3. Search happens locally in the generic scaffold.
4. Tapping an item opens a detail editor page.
5. Saving or deleting goes through shared persistence or a feature-specific controller.

The shared create affordance for those list pages is `FloatingAddIcon`, which
now includes the bottom-navigation clearance wrapper. Dashboards, habits, and
measurables therefore stay above the floating app-shell nav without each page
inventing its own bottom offset.

### List pages

- [`ui/pages/dashboards/dashboards_page.dart`](ui/pages/dashboards/dashboards_page.dart)
- [`ui/pages/habits/habits_page.dart`](ui/pages/habits/habits_page.dart)
- [`ui/pages/measurables/measurables_page.dart`](ui/pages/measurables/measurables_page.dart)

### Detail/editor pages

- [`ui/pages/dashboards/dashboard_definition_page.dart`](ui/pages/dashboards/dashboard_definition_page.dart)
- [`ui/pages/habits/habit_details_page.dart`](ui/pages/habits/habit_details_page.dart)
- [`ui/pages/measurables/measurable_details_page.dart`](ui/pages/measurables/measurable_details_page.dart)

### Persistence split

- Dashboards and measurables save through [`lib/logic/persistence_logic.dart`](../../logic/persistence_logic.dart)
- Habits save through [`lib/features/habits/state/habit_settings_controller.dart`](../habits/state/habit_settings_controller.dart), which also schedules notifications

This is one of the more useful boundaries in the feature. Settings owns the editing shell, but it does not insist on owning every write path.

## Settings-Owned Utility Pages

### Theming

[`ui/pages/theming_page.dart`](ui/pages/theming_page.dart) is a thin view over [`lib/features/theming/state/theming_controller.dart`](../theming/state/theming_controller.dart).

It does three concrete things:

- switches `ThemeMode`
- selects light and dark theme names
- adapts the card styling to the currently active theme family

Theme selection is persisted in `SettingsDb`, and the theming controller also watches settings notifications so synced preference changes can be applied back into live state.

### Flags

[`ui/pages/flags_page.dart`](ui/pages/flags_page.dart) renders a curated subset of config flags in a fixed order. It is intentionally not a raw dump of everything in the database.

Each visible flag has:

- a localized title
- a localized description
- a hand-picked icon
- a `Switch.adaptive` that writes back through `PersistenceLogic`

### Advanced

[`ui/pages/advanced_settings_page.dart`](ui/pages/advanced_settings_page.dart) is the non-sync maintenance hub.

It currently links to:

- logging domains
- health import on mobile only
- maintenance
- about

The tests enforce that sync-specific items no longer live here as cards, even if a few routes still pass through the Advanced namespace.

### Health import

[`ui/pages/health_import_page.dart`](ui/pages/health_import_page.dart) is a thin date-range launcher over [`lib/logic/health_import.dart`](../../logic/health_import.dart). In practice it is surfaced through the mobile-only Advanced entry point, even though the route itself still exists in the shared settings location.

### About

[`ui/pages/advanced/about_page.dart`](ui/pages/advanced/about_page.dart) is more than a static credits wall. It pulls:

- app version and build number from `PackageInfo`
- journal entry count from `JournalDb`
- flagged and task counts from shared widgets

## Sync Surfaces From Settings

Settings does not implement sync itself, but it does define how sync is entered and how sync pages behave inside the settings namespace.

Key facts:

- the `/settings` landing page only shows Sync when `enableMatrixFlag` is on
- [`lib/features/sync/ui/widgets/sync_feature_gate.dart`](../sync/ui/widgets/sync_feature_gate.dart) guards sync pages and redirects back to `/settings` if sync is disabled
- the sync landing page is [`lib/features/sync/ui/sync_settings_page.dart`](../sync/ui/sync_settings_page.dart)
- sync maintenance, outbox, stats, and backfill each get their own leaf routes

This split keeps app-wide maintenance in Advanced and sync-specific maintenance with Sync, which is the correct kind of boring.

## Destructive and Long-Running Operations

Settings is where many "please do not tap this casually" actions live.

There are two common interaction patterns:

```mermaid
flowchart LR
  Card["Settings card tap"] --> Confirm["showConfirmationModal(...)"]
  Confirm --> Action["Immediate destructive action"]

  Card --> MultiStep["ConfirmationProgressModal.show(...)"]
  MultiStep --> Progress["Progress/completion page"]
  Progress --> Service["Sync or maintenance operation"]
```

### Immediate confirmation flows

Used for actions such as:

- deleting editor, agent, or sync databases
- retrying or deleting outbox items
- habit and measurable delete actions

### Confirmation + progress flows

Used by modals such as:

- [`lib/features/sync/ui/purge_modal.dart`](../sync/ui/purge_modal.dart)
- [`lib/features/sync/ui/fts5_recreate_modal.dart`](../sync/ui/fts5_recreate_modal.dart)
- [`lib/features/sync/ui/sync_modal.dart`](../sync/ui/sync_modal.dart)
- [`lib/features/sync/ui/sequence_log_populate_modal.dart`](../sync/ui/sequence_log_populate_modal.dart)

The shared wrapper lives in [`ui/confirmation_progress_modal.dart`](ui/confirmation_progress_modal.dart), catches exceptions, and optionally closes itself on completion.

## Route Inventory

This is the route shape that currently matters in practice:

- `/settings`
- `/settings/ai`
- `/settings/ai/profiles`
- `/settings/agents/...`
- `/settings/categories/...`
- `/settings/projects/...`
- `/settings/labels/...`
- `/settings/habits/...`
- `/settings/dashboards/...`
- `/settings/measurables/...`
- `/settings/sync`
- `/settings/sync/matrix/maintenance`
- `/settings/sync/outbox`
- `/settings/sync/stats`
- `/settings/sync/backfill`
- `/settings/theming`
- `/settings/flags`
- `/settings/health_import`
- `/settings/advanced`
- `/settings/advanced/logging_domains`
- `/settings/advanced/about`
- `/settings/advanced/conflicts/...`
- `/settings/advanced/maintenance`

The notable oddball is `/settings/projects/...`: there is no top-level Settings tile for projects, but project create/detail routes still live under the settings namespace because category and project management meet there.

## Notes For Future Changes

- Add new settings routes in [`lib/beamer/locations/settings_location.dart`](../../beamer/locations/settings_location.dart), not just in a tile callback.
- Decide explicitly whether a new page is:
  - a Settings-owned utility
  - a list/detail shell over another feature's data
  - a pure handoff into another feature
- If a surface is feature-gated, gate both the entry point and any leaf pages that should not remain reachable.
- Keep sync-specific repair tools with Sync unless they are truly app-wide.
- Reuse [`DefinitionsListPage<T>`](ui/pages/definitions_list_page.dart) and the existing card widgets before inventing another one-off admin list. Settings already has enough ways to make a form look earnest.
