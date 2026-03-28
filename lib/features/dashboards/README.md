# Dashboards Feature

The `dashboards` feature powers the app's dashboard/insights surface. It reads
stored `DashboardDefinition` entities, routes each `DashboardItem` to the right
chart widget, and keeps those charts refreshed from journal-backed data.

This is a view layer, not a separate analytics warehouse with grand ambitions.
The source data still lives in the journal database and neighboring features.
The dashboards feature mostly assembles and visualizes it. "Mostly" is doing a
bit of work here, because a few charts can also launch capture flows directly.

## Runtime Responsibilities

At runtime, this feature owns:

- listing active dashboards with `dashboardsProvider`
- locally filtering that list by category with
  `selectedCategoryIdsProvider`
- opening a single dashboard page and switching its visible time span
- routing dashboard items to measurement, health, workout, survey, and habit
  widgets
- keeping chart providers warm for 5 minutes via
  `cacheFor(dashboardCacheDuration)`
- tracking horizontal zoom scale for bar charts with `BarWidthController`

It does not own:

- dashboard authoring UI, which lives under
  `lib/features/settings/ui/pages/dashboards/`
- the underlying journal, survey, workout, or habit records
- a generic reporting/query engine

## What A Dashboard Actually Is

`DashboardDefinition` is a stored entity with metadata such as `name`,
`description`, `categoryId`, `active`, `private`, and `days`, plus a list of
`DashboardItem`s.

At render time, `DashboardWidget` currently supports exactly these item types:

- `DashboardMeasurementItem`
- `DashboardHealthItem`
- `DashboardWorkoutItem`
- `DashboardSurveyItem`
- `DashboardHabitItem`

So this feature is broader than "health charts". If an item lands in one of
those five switch cases, the page knows how to render it.

## Directory Shape

```text
lib/features/dashboards/
├── config/                      # Health/workout lookup maps
├── state/                       # Riverpod providers, fetchers, aggregators
├── ui/
│   ├── pages/                   # List page and single dashboard page
│   └── widgets/
│       ├── charts/              # Chart shells and chart-specific widgets
│       └── ...                  # App bar, filter, list, card widgets
└── README.md
```

Most of the real behavior lives in `state/` and `ui/widgets/charts/`. The page
widgets stay fairly thin on purpose.

## High-Level Architecture

```mermaid
flowchart LR
  ListPage["DashboardsListPage"] --> AppBar["DashboardsSliverAppBar"]
  AppBar --> Filter["DashboardsFilter"]
  Filter --> CategoryState["selectedCategoryIdsProvider"]
  ListPage --> Dashboards["dashboardsProvider"]
  Dashboards --> Filtered["filteredSortedDashboardsProvider"]
  CategoryState --> Filtered
  Filtered --> Cards["DashboardCard list"]

  Cards --> Page["DashboardPage"]
  Page --> Cache["EntitiesCacheService.getDashboardById()"]
  Page --> Span["TimeSpanSegmentedControl"]
  Page --> Scale["BarWidthController"]
  Page --> Widget["DashboardWidget"]

  Widget --> Measurement["MeasurablesBarChart"]
  Widget --> Health["DashboardHealthChart"]
  Widget --> Workout["DashboardWorkoutChart"]
  Widget --> Survey["DashboardSurveyChart"]
  Widget --> Habit["DashboardHabitsChart"]

  Measurement --> DB["JournalDb + related services"]
  Health --> DB
  Workout --> DB
  Survey --> DB
  Habit --> Habits["HabitCompletionCard / habits feature"]
```

The feature splits cleanly into two halves:

- dashboard discovery and filtering
- item-specific chart rendering for a selected dashboard

## Dashboard List Flow

The list page is a `CustomScrollView` with a pinned sliver app bar, a category
filter button, and a flat list of `DashboardCard`s.

```mermaid
flowchart TD
  Open["Open dashboards tab"] --> Stream["dashboardsProvider"]
  Stream --> Active["Keep only active dashboards"]
  Active --> Sort["Sort by lowercased name"]
  Sort --> Visible["filteredSortedDashboardsProvider"]

  FilterTap["Tap filter button"] --> BottomSheet["Category chip sheet"]
  BottomSheet --> Toggle["selectedCategoryIdsProvider.toggle(id)"]
  Toggle --> Visible
  Visible --> Cards["DashboardCard widgets"]
```

Code-backed details worth knowing:

- `dashboardsProvider` reads all dashboards from `JournalDb`, then filters to
  `active == true`
- category filtering is purely local UI state; no database query changes
- `DashboardsFilter` renders its icon as a tiny ring `PieChart` based on the
  currently visible dashboards and category colors
- `DashboardsListPage` wires its scroll controller into
  `UserActivityService.updateActivity`, so even scrolling quietly counts as user
  activity

That filter button does double duty as both control and tiny dashboard census.
Not flashy, but genuinely handy.

## Single Dashboard Page Lifecycle

`DashboardPage` is a `ConsumerStatefulWidget` with two pieces of local page
state:

- `timeSpanDays`, defaulting to `90`
- a `TransformationController` whose listener updates
  `barWidthControllerProvider`

```mermaid
sequenceDiagram
  participant User as "User"
  participant Page as "DashboardPage"
  participant Cache as "EntitiesCacheService"
  participant Widget as "DashboardWidget"
  participant Providers as "Chart providers"

  User->>Page: open /dashboards/:id
  Page->>Cache: getDashboardById(id)
  alt dashboard exists
    Page->>Widget: build with date range + transformation controller
    Widget->>Providers: watch item-specific providers
    Providers-->>Widget: entities or observations
    User->>Page: change segmented time span
    Page->>Widget: rebuild with new range
    User->>Page: pan or zoom chart
    Page->>Page: update BarWidthController scale
  else dashboard missing
    Page->>Page: beamToNamed('/dashboards')
  end
```

Important reality checks:

- the page title comes from `EntitiesCacheService.getDashboardById()`
- the visible date range is derived from `DateTime.now()` and midnight helpers
- `DashboardDefinition.days` exists on the entity, but `DashboardPage` does not
  currently use it; the UI always starts at 90 days until the user changes the
  segmented control

## Item Rendering Matrix

| Dashboard item | Widget | Data path | Notes |
| --- | --- | --- | --- |
| `DashboardMeasurementItem` | `MeasurablesBarChart` | `measurableDataTypeControllerProvider` -> `aggregationTypeControllerProvider` -> `measurableChartDataControllerProvider` -> `measurableObservationsControllerProvider` | Renders a line chart for `AggregationType.none`, otherwise a bar chart. The header can open `MeasurementDialog`. |
| `DashboardHealthItem` | `DashboardHealthChart` | `HealthChartDataController` -> `HealthObservationsController` | `BLOOD_PRESSURE` and `BODY_MASS_INDEX` branch to special widgets. Health refresh is nudged in the background via `HealthImport.fetchHealthDataDelta(...)`. |
| `DashboardWorkoutItem` | `DashboardWorkoutChart` | `WorkoutChartDataController` -> `WorkoutObservationsController` | Aggregates daily sums for the selected workout type/value kind. Also triggers `HealthImport.getWorkoutsHealthDataDelta()`. |
| `DashboardSurveyItem` | `DashboardSurveyChart` | `SurveyChartDataController` + `surveyLines(...)` | Multi-line chart. The `+` button only knows how to launch CFQ11, PANAS, and GHQ12 survey flows. |
| `DashboardHabitItem` | `DashboardHabitsChart` | delegates to `HabitCompletionCard` in the habits feature | No local dashboard-specific fetcher here; this is pragmatic reuse of habit UI. |

## Refresh And Caching Model

There are two refresh styles in play:

1. list-level streams for dashboards and categories
2. item-level providers for chart data and aggregated observations

```mermaid
flowchart LR
  Writes["DB writes elsewhere"] --> Updates["UpdateNotifications"]
  Updates --> ListStreams["notificationDrivenStream\n(dashboards/categories)"]
  Updates --> RawControllers["health/workout/survey/measurable raw-data providers"]
  RawControllers --> Aggregation["Aggregation helpers / observation providers"]
  Aggregation --> Charts["Dashboard chart widgets"]
  Charts --> Cache["Provider cacheFor(5 minutes)"]
```

In concrete terms:

- dashboard and category lists use `notificationDrivenStream(...)`
- measurement, health, workout, and survey controllers subscribe to
  `UpdateNotifications.updateStream` and refetch on matching keys
- most providers call `ref.cacheFor(dashboardCacheDuration)`, which currently
  means 5 minutes
- some health-related controllers opportunistically kick off background imports
  while building, so opening a dashboard can also serve as a polite "please go
  refresh that data" nudge

## Chart-Specific Notes

The chart widgets are not all built from one abstract chart super-engine, and
that is fine.

- measurement charts resolve aggregation from either the dashboard item or the
  measurable type definition
- health charts use the `healthTypes` config map for display names, units, and
  aggregation behavior
- workout charts always render as bars after aggregating daily totals
- survey charts build `LineChartBarData` locally from survey score keys
- habit charts intentionally reuse `HabitCompletionCard` rather than copying
  habit chart logic into this feature

This is a pragmatic switchboard, not a shrine to abstraction purity.

## Current Constraints And Quirks

- only active dashboards appear in the list
- category filters are client-side only
- `dashboardByIdProvider` watches `dashboardsProvider` for invalidation, but the
  actual lookup still comes from `EntitiesCacheService`
- the stored dashboard `days` value is currently ignored by the runtime page
- survey launch actions are hard-coded to a small known set of surveys
- health and workout chart configs still rely on local lookup maps rather than a
  more generic registry

None of that is mysterious. It is just the shape of the current code.

## Related Code Outside This Folder

- `lib/features/settings/ui/pages/dashboards/` edits dashboard definitions
- `lib/widgets/charts/habits/` provides the habit chart/card reused here
- `lib/features/surveys/tools/run_surveys.dart` backs the survey `+` actions
- `lib/services/entities_cache_service.dart` provides fast dashboard lookups for
  page routing/title rendering
- `lib/database/database.dart` remains the real source of dashboard data

If you want to change how dashboards look, start here. If you want to change
where the underlying numbers come from, this feature is mostly the messenger.
