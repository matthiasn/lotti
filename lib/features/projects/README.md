# Projects Feature

Projects provide a grouping layer between categories and tasks. Each project belongs to a category and can have multiple tasks linked to it. When a matching `projectAgent` template is available, project creation provisions a project agent for analysis and reporting. If no agent exists yet, the detail page lets the user create one later.

## Feature Flag

The entire projects UI is gated behind the `enableProjects` config flag (default: `false`). When disabled, no project-related UI is visible. Toggle it in Settings > Feature Flags.

Gated integration points:
- **Top-level navigation**: the `Projects` tab is hidden unless the flag is enabled.
- **Tasks page**: `ProjectHealthHeader` is hidden.
- **Category details**: `CategoryProjectsSection` is hidden.
- **Task metadata row**: `TaskProjectWrapper` chip is hidden.

Routes remain registered but are unreachable when all navigation entry points are hidden.

## Data Model

Projects are stored as `ProjectEntry` — a variant of the `JournalEntity` sealed class. The project-specific data lives in `ProjectData` (Freezed):

- **title**: project name (required)
- **status**: `ProjectStatus` sealed class with five variants: `open`, `active`, `onHold`, `completed`, `archived`. Each carries a timestamp, UTC offset, and the `onHold` variant adds a `reason`.
- **statusHistory**: chronological list of prior statuses.
- **targetDate**: optional deadline.
- **dateFrom** / **dateTo**: time range.

Task-to-project linking is a 1:1 relationship stored via `EntryLink` records in the journal database.
The journal table also keeps a denormalized `project_id` column in sync for
tasks so the top-level projects tab can batch task rollups without repeated
link-table joins.
Project agents maintain a daily digest cadence via `scheduledWakeAt`, rolling
forward to 06:00 local time on the next day after creation or after a due
digest completes. Direct project edits and task linking changes coalesce into a
short deferred refresh, while other task-level activity marks the current
summary as stale and defers the automatic refresh to the next scheduled digest.

## Module Structure

```
lib/features/projects/
├── model/
│   └── projects_overview_models.dart  # Tab overview DTOs and filter/query state
├── repository/
│   └── project_repository.dart      # CRUD, task linking, and batch overview methods
├── state/
│   ├── project_health_metrics.dart   # Parsing for agent-authored health band/rationale
│   ├── project_providers.dart        # Detail providers plus projects-tab overview/filter providers
│   └── project_detail_controller.dart # Detail page state (form tracking, save)
├── widgetbook/
│   ├── project_list_detail_mock_controller.dart # Widgetbook-only mock controller for the list/detail showcase
│   ├── project_list_detail_mock_data.dart       # Factory building ProjectListData with realistic mock records
│   └── project_widgetbook.dart                  # Widgetbook registration for desktop + mobile project showcase use cases
└── ui/
    ├── model/
    │   ├── project_list_detail_models.dart       # Widgetbook list/detail records plus bridge getters into ProjectListItemData
    │   └── project_list_detail_state.dart        # Widgetbook search/filter/selection state built on ProjectCategoryGroup
    ├── pages/
    │   ├── project_create_page.dart   # New project form
    │   ├── project_detail_page.dart   # View/edit existing project
    │   └── projects_tab_page.dart     # Top-level grouped projects list page
    └── widgets/
        ├── category_projects_section.dart       # Projects list in category detail
        ├── health_panel.dart                     # Health score panel with progress bar and legends
        ├── project_agent_report_card.dart        # Agent report display
        ├── project_detail_pane.dart              # Right-hand detail pane (header, health, report, tasks, reviews)
        ├── project_health_header.dart            # Expandable project overview on tasks page
        ├── project_health_indicator.dart         # Compact health band chip with reason text
        ├── projects_header.dart                  # Shared DS header used by the production tab and Widgetbook mobile list
        ├── project_linked_tasks_section.dart     # Linked tasks list in project detail
        ├── project_list_detail_showcase.dart     # Thin Widgetbook wrapper composing production widgets with mock data
        ├── project_list_pane.dart                # Desktop Widgetbook/search pane wrapper around the shared project list widgets
        ├── project_list_shared.dart              # Neutral shared group header, grouped section, and project row widgets
        ├── project_mobile_list_detail_showcase.dart # Mobile list/detail showcase with shared mock selection state and adaptive split/stack layout
        ├── project_selection_modal_content.dart  # Project picker modal
        ├── project_status_attributes.dart        # Shared status→(label,color,icon) mapping
        ├── project_status_chip.dart              # Status badge with icon/color
        ├── project_status_picker.dart            # Interactive status selection bottom sheet
        ├── projects_overview_list.dart           # Production lazy sliver wrapper around the shared DS project rows
        ├── project_tasks_panel.dart              # Highlighted tasks panel with duration totals
        ├── review_sessions_panel.dart            # Review sessions panel with expandable metric rows
        ├── shared_widgets.dart                   # Reusable widgets: CategoryTag, StatusPill, CountDotBadge, etc.
        ├── sidebar.dart                          # Desktop sidebar navigation and top bar
        └── showcase/
            ├── showcase_palette.dart             # Design-token colour mapping for the desktop layout
            └── showcase_status_helpers.dart       # Status label/icon/colour helpers and duration formatting
```

## State Management

### Providers (`project_providers.dart`)

- `projectsForCategoryProvider(categoryId)` — `FutureProvider.autoDispose.family` fetching projects for a category. Auto-invalidates on `projectNotification` updates.
- `projectTaskCountProvider(projectId)` — `FutureProvider.autoDispose.family` returning the number of tasks linked to a project.
- `projectHealthMetricsProvider(projectId)` — `FutureProvider.autoDispose.family` reading the latest persisted project-agent report and exposing its agent-authored health band and rationale. If the latest report has no health payload yet, the provider returns `null` and the UI shows no health state.
- `projectHealthSnapshotProvider(projectId)` — aggregates the latest health band, stale-summary state, and active `ProjectRecommendationEntity` records for a single project so dashboard UI can consume one project-scoped state object.
- `projectHealthOverviewEntriesProvider(categoryId)` — prepares category-scoped project health entries, already sorted worst-band-first for future health dashboard list surfaces.
- `projectForTaskProvider(taskId)` — `FutureProvider.autoDispose.family` fetching the project a task belongs to.
- `projectsFilterControllerProvider` — keep-alive `NotifierProvider` storing selected category IDs, text query, and search mode for the top-level tab rollout.
- `projectsOverviewProvider` — `StreamProvider.autoDispose` exposing the batched grouped snapshot for the top-level projects tab via `ProjectRepository.watchProjectsOverview()`.
- `visibleProjectGroupsProvider` — derived provider that applies provider-layer filtering to the raw grouped snapshot. Local text filtering only activates when `searchMode == ProjectsSearchMode.localText`; the live tab currently keeps the search field disabled while vector search is pending.

### Detail Controller (`project_detail_controller.dart`)

`ProjectDetailController` is a `Notifier` with original/pending pattern for change tracking:

- Watches the repository update stream for live reload.
- Tracks `hasChanges` by comparing pending vs original project data.
- Methods: `updateTitle`, `updateTargetDate`, `updateStatus`, `saveChanges`.

## Routing

Top-level route:
- `/projects` — grouped list tab, inserted into the main bottom navigation after `Tasks`

Project routes live under the settings location:
- `/settings/projects/create?categoryId=X` — create page
- `/settings/projects/:projectId` — detail page
- `/settings/projects/:projectId?categoryId=X` — detail page with category
  return context preserved for back navigation

## Key Widgets

### ProjectHealthHeader

Expandable header on the tasks page. Collapsed (default) shows a `ModernBaseCard` with a folder icon, "Projects" title, and a summary like "2 projects, 4 tasks". Tapping expands to reveal per-project rows with name, task count, target date, and status chip. Tapping a project row navigates to its detail page.

Each expanded row also renders a compact project health band (`Surviving`, `On Track`, `Watch`, `At Risk`, `Blocked`) taken from the latest project-agent report. The app does not synthesize a fallback band from local heuristics; if the agent has not published health yet, no band is shown.

### ProjectListDetailShowcase

Widgetbook-only thin wrapper that composes the production desktop layout widgets (`Sidebar`, `MainTopBar`, `ProjectListPane`, `ProjectDetailPane`) with mock data from `project_list_detail_mock_data.dart`. The production widgets live under `ui/widgets/` and consume `ProjectListDetailState` and `ProjectRecord` presentation models from `ui/model/`. A dedicated mock controller in `widgetbook/` drives search and selection without depending on the live repository.

### ProjectMobileListDetailShowcase

Widgetbook-only mobile showcase that uses the same mock controller/provider as the desktop showcase. On wide canvases it renders list and detail phone frames side by side; on narrow canvases it navigates between the list screen and the selected detail screen while preserving selection state. The mobile screens reuse the shared `ProjectsHeader`, `ProjectGroupSection`, and `ProjectRow` implementations so the Widgetbook list UI and the production projects tab stay visually aligned instead of drifting apart.

### ProjectsTabPage

The top-level projects tab uses the same design-system list primitives as the Widgetbook mobile list, but renders them through a lazy sliver pipeline (`ProjectsOverviewSliverList`) for production scalability. The header is a shared `ProjectsHeader` with the left-aligned title, notification icon, disabled search field, and filter icon shown in the Widgetbook mobile reference.

### Shared List Components

`ProjectCategoryGroup` and `ProjectListItemData` are the production list contracts. The shared UI components that render them are:

- `ProjectsHeader` — shared top section for the Widgetbook mobile list and the live tab.
- `ProjectGroupHeader` — neutral category header row shared across production and Widgetbook.
- `ProjectGroupSection` — grouped card list used by the desktop/mobile Widgetbook list.
- `ProjectRow` — shared DS project row with progress ring, task count, due/ongoing label, and compact status label.
- `ProjectsOverviewSliverList` — production wrapper that keeps the same row visuals but renders lazily with slivers.

These shared list widgets live in `project_list_shared.dart`, so production and Widgetbook depend on the same neutral module instead of importing showcase-specific pane code.

### ProjectStatusPicker

Interactive status selector on the project detail page. Shows the current status with color-coded icon and label. Tapping opens a bottom sheet with all five status options; selecting one calls `updateStatus` on the controller.

### ProjectDetailPage

Form page with three sections:
1. **Status** — `ProjectStatusPicker` for changing project status.
2. **Project Title** — text field and optional target date.
3. **Project Health** — compact health band chip plus the project agent's user-facing rationale from the latest report. If the latest report has no health payload yet, this section stays hidden.
4. **Agent** — current project-agent report, active project
   recommendations, manual refresh action, and an explicit empty state when
   no project agent has been provisioned. Confirmed
   `recommend_next_steps` proposals become first-class recommendation records
   that supersede any older active set and can be resolved or dismissed from
   this section.
5. **Linked Tasks** — list of tasks in this project.

## Integration Points

- **Main app shell**: a top-level `Projects` tab now appears immediately after `Tasks` when the feature flag is enabled. The tab uses the existing bottom navigation and opens the production grouped list page.
- **Category detail page**: `CategoryProjectsSection` shows projects and a "New Project" button (gated by `enableProjects` flag).
- **Task header**: `TaskProjectWrapper` adds a project chip to the task metadata row (gated by `enableProjects` flag).
- **Tasks page**: `ProjectHealthHeader` shows an expandable overview of projects for the selected category and provides inline project filtering through its expandable rows.
- **Agent system**: Project agents are managed through `ProjectAgentService`,
  `ProjectActivityMonitor`, and the agent workflow system. Local task/project
  changes mark pending activity, including task-linked updates such as new or
  refreshed task summaries. Direct edits to the project and task linking
  changes also schedule a short deferred refresh through the wake orchestrator.
  Other task-driven staleness still rolls into the next 06:00 scheduled digest
  unless the user refreshes manually sooner.
- **Deferred agent proposals**: Project detail pages now surface project-agent
  change sets so users can confirm or reject proposed status changes, task
  creation, and other reviewed actions in place. Confirmed
  `recommend_next_steps` proposals are persisted as active project
  recommendations instead of being replayed from raw decision history.

## Task-Project Linking

Each task can belong to at most one project. Linking is done via the project picker modal (`ProjectSelectionModalContent`) accessible from the task header. The repository methods `linkTaskToProject` and `unlinkTaskFromProject` manage the `EntryLink` records, enforcing the single-project constraint.

## Top-Level Tab Data Path

The top-level projects tab does **not** render through per-project providers such as `projectTaskCountProvider` or by looping `projectsForCategoryProvider` over categories.

Instead it uses one batched overview path:

1. `JournalDb.getVisibleProjects()` fetches all visible `ProjectEntry` rows in one query.
2. `JournalDb.getProjectTaskRollups(projectIds)` fetches task counts for all visible projects in one aggregate query keyed by the denormalized `journal.project_id`.
3. `ProjectRepository.getProjectsOverview()` resolves category metadata once, groups the result in memory, and returns a `ProjectsOverviewSnapshot`.
4. `ProjectRepository.watchProjectsOverview()` subscribes to `UpdateNotifications`, refreshing on broad project/task/category/private tokens and on concrete project/category IDs already present in the current snapshot so status changes cannot leave the list stale.
5. `projectsOverviewProvider` exposes that snapshot stream to the tab, while `visibleProjectGroupsProvider` applies the local filtering model without re-querying per project.
