# Projects Feature

Projects provide a grouping layer between categories and tasks. Each project belongs to a category and can have multiple tasks linked to it. When a matching `projectAgent` template is available, project creation provisions a project agent for analysis and reporting. If no agent exists yet, the detail page lets the user create one later.

## Feature Flag

The entire projects UI is gated behind the `enableProjects` config flag (default: `false`). When disabled, no project-related UI is visible. Toggle it in Settings > Feature Flags.

Gated integration points:
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
Project agents maintain a daily digest cadence via `scheduledWakeAt`, rolling
forward to 06:00 local time on the next day after creation or after a due
digest completes. Local project-linked activity no longer triggers an
immediate report wake; instead it marks the current summary as stale and the
next scheduled digest decides whether a refresh is needed.

## Module Structure

```
lib/features/projects/
├── repository/
│   └── project_repository.dart      # CRUD, task linking, query methods
├── state/
│   ├── project_health_metrics.dart   # Parsing for agent-authored health band/rationale
│   ├── project_providers.dart        # projectsForCategoryProvider, projectForTaskProvider, projectTaskCountProvider
│   └── project_detail_controller.dart # Detail page state (form tracking, save)
├── widgetbook/
│   ├── project_list_detail_mock_controller.dart # Widgetbook-only mock controller for the list/detail showcase
│   ├── project_list_detail_mock_data.dart       # Factory building ProjectListData with realistic mock records
│   └── project_widgetbook.dart                  # Widgetbook registration for project showcase use cases
└── ui/
    ├── model/
    │   ├── project_list_detail_models.dart       # Production presentation models (ProjectRecord, TaskSummary, ReviewSession, etc.)
    │   └── project_list_detail_state.dart        # UI state with search/filter/selection logic
    ├── pages/
    │   ├── project_create_page.dart   # New project form
    │   └── project_detail_page.dart   # View/edit existing project
    └── widgets/
        ├── category_projects_section.dart       # Projects list in category detail
        ├── health_panel.dart                     # Health score panel with progress bar and legends
        ├── project_agent_report_card.dart        # Agent report display
        ├── project_detail_pane.dart              # Right-hand detail pane (header, health, report, tasks, reviews)
        ├── project_health_header.dart            # Expandable project overview on tasks page
        ├── project_health_indicator.dart         # Compact health band chip with reason text
        ├── project_linked_tasks_section.dart     # Linked tasks list in project detail
        ├── project_list_detail_showcase.dart     # Thin Widgetbook wrapper composing production widgets with mock data
        ├── project_list_pane.dart                # Left-hand pane with search and grouped project rows
        ├── project_selection_modal_content.dart  # Project picker modal
        ├── project_status_attributes.dart        # Shared status→(label,color,icon) mapping
        ├── project_status_chip.dart              # Status badge with icon/color
        ├── project_status_picker.dart            # Interactive status selection bottom sheet
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
- `projectForTaskProvider(taskId)` — `FutureProvider.autoDispose.family` fetching the project a task belongs to.

### Detail Controller (`project_detail_controller.dart`)

`ProjectDetailController` is a `Notifier` with original/pending pattern for change tracking:

- Watches the repository update stream for live reload.
- Tracks `hasChanges` by comparing pending vs original project data.
- Methods: `updateTitle`, `updateTargetDate`, `updateStatus`, `saveChanges`.

## Routing

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

- **Category detail page**: `CategoryProjectsSection` shows projects and a "New Project" button (gated by `enableProjects` flag).
- **Task header**: `TaskProjectWrapper` adds a project chip to the task metadata row (gated by `enableProjects` flag).
- **Tasks page**: `ProjectHealthHeader` shows an expandable overview of projects for the selected category and provides inline project filtering through its expandable rows.
- **Agent system**: Project agents are managed through `ProjectAgentService`,
  `ProjectActivityMonitor`, and the agent workflow system. Local task/project
  changes mark pending activity, and only the next 06:00 scheduled digest
  spends tokens on a refreshed report.
- **Deferred agent proposals**: Project detail pages now surface project-agent
  change sets so users can confirm or reject proposed status changes, task
  creation, and other reviewed actions in place. Confirmed
  `recommend_next_steps` proposals are persisted as active project
  recommendations instead of being replayed from raw decision history.

## Task-Project Linking

Each task can belong to at most one project. Linking is done via the project picker modal (`ProjectSelectionModalContent`) accessible from the task header. The repository methods `linkTaskToProject` and `unlinkTaskFromProject` manage the `EntryLink` records, enforcing the single-project constraint.
