# Projects Feature

Projects provide a grouping layer between categories and tasks. Each project belongs to a category and can have multiple tasks linked to it. An optional AI agent is auto-created per project for analysis and reporting.

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
Project agents maintain two time-based cadences through `scheduledWakeAt`:
- a daily digest at 06:00 local
- a weekly review checkpoint on Monday at 10:00 local

`scheduledWakeAt` always points at whichever of those two cadences is due
next. Successful scheduled wakes update `lastDailyWakeAt`, and Monday review
wakes also update `lastWeeklyReviewAt` plus `weeklyReviewCount`.
Automatic project-agent wakes now use dedicated agent-only tokens for:
- direct project changes and task link/unlink operations
- linked task status transitions
- day-plan agreement events for the project's category

This avoids waking project agents on every linked-task text or checklist edit
while preserving the broader `projectId` notifications used by the UI.

## Module Structure

```
lib/features/projects/
├── repository/
│   └── project_repository.dart      # CRUD, task linking, query methods
├── state/
│   ├── project_providers.dart        # projectsForCategoryProvider, projectForTaskProvider, projectTaskCountProvider
│   └── project_detail_controller.dart # Detail page state (form tracking, save)
└── ui/
    ├── pages/
    │   ├── project_create_page.dart   # New project form
    │   └── project_detail_page.dart   # View/edit existing project
    └── widgets/
        ├── category_projects_section.dart       # Projects list in category detail
        ├── project_agent_report_card.dart        # Agent report display
        ├── project_health_header.dart            # Expandable project overview on tasks page
        ├── project_linked_tasks_section.dart     # Linked tasks list in project detail
        ├── project_selection_modal_content.dart  # Project picker modal
        ├── project_status_attributes.dart        # Shared status→(label,color,icon) mapping
        ├── project_status_chip.dart              # Status badge with icon/color
        └── project_status_picker.dart            # Interactive status selection bottom sheet
```

## State Management

### Providers (`project_providers.dart`)

- `projectsForCategoryProvider(categoryId)` — `FutureProvider.autoDispose.family` fetching projects for a category. Auto-invalidates on `projectNotification` updates.
- `projectTaskCountProvider(projectId)` — `FutureProvider.autoDispose.family` returning the number of tasks linked to a project.
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

## Key Widgets

### ProjectHealthHeader

Expandable header on the tasks page. Collapsed (default) shows a `ModernBaseCard` with a folder icon, "Projects" title, and a summary like "2 projects, 4 tasks". Tapping expands to reveal per-project rows with name, task count, target date, and status chip. Tapping a project row navigates to its detail page.

### ProjectStatusPicker

Interactive status selector on the project detail page. Shows the current status with color-coded icon and label. Tapping opens a bottom sheet with all five status options; selecting one calls `updateStatus` on the controller.

### ProjectDetailPage

Form page with the current project-management surface:
1. **Status** — `ProjectStatusPicker` for changing project status.
2. **Project Title** — text field and optional target date.
3. **Project Agent** — latest project-agent report, accepted next steps, and the provisioned agent identity.
4. **Reviewed Changes** — pending project-agent change sets that can be confirmed or rejected in place.
5. **Linked Tasks** — list of tasks in this project.

## Integration Points

- **Category detail page**: `CategoryProjectsSection` shows projects and a "New Project" button (gated by `enableProjects` flag).
- **Task header**: `TaskProjectWrapper` adds a project chip to the task metadata row (gated by `enableProjects` flag).
- **Tasks page**: `ProjectHealthHeader` shows an expandable overview of projects for the selected category and provides inline project filtering through its expandable rows.
- **Agent system**: Project agents are managed through `ProjectAgentService`
  and the agent workflow system, including the daily/weekly scheduled cadence,
  linked-task status-transition wakes, and category day-plan agreement wakes.
- **Deferred agent proposals**: Project detail pages now surface project-agent
  change sets so users can confirm or reject proposed status changes, task
  creation, and other reviewed actions in place.
- **Agent reporting**: Project detail pages now render the latest project-agent
  report alongside accepted `recommend_next_steps` recommendations, which are
  persisted as dedicated project recommendation records once confirmed.

## Task-Project Linking

Each task can belong to at most one project. Linking is done via the project picker modal (`ProjectSelectionModalContent`) accessible from the task header. The repository methods `linkTaskToProject` and `unlinkTaskFromProject` manage the `EntryLink` records, enforcing the single-project constraint.
