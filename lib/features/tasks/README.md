# Tasks Feature

The `tasks` feature is the task-specific layer on top of Lotti's shared journal substrate.

A task is still a `JournalEntity`, but this feature is where it becomes a proper task with its own specific behaviors.

It owns the task-specific experience:

- detail surfaces
- checklist management
- linked-task management
- task progress calculation
- task-specific filter UI hooks
- priority, due-date, labels, project, and cover-art presentation

## What This Feature Owns

At runtime, the feature owns:

1. task detail page composition
2. checklist CRUD and reorder behavior
3. linked-task UI and manage mode
4. task progress aggregation and display
5. task-specific filter widgets and display toggles that plug into the shared journal page controller
6. task detail controls for status, category, priority, project, due date, labels, estimate, and language

It does not own raw task persistence by itself. Task entities still live in the journal/persistence layer, and many write operations flow through shared controllers or repositories there.

## Directory Shape

```text
lib/features/tasks/
├── model/
├── repository/
├── services/
├── state/
├── ui/
│   ├── checklists/
│   ├── filtering/
│   ├── header/
│   ├── labels/
│   ├── linked_tasks/
│   ├── pages/
│   └── widgets/
├── util/
└── widgetbook/
```

## Architecture

```mermaid
flowchart LR
  Task["Task entity (JournalEntity variant)"] --> Detail["TaskDetailsPage"]
  Detail --> EntryCtl["EntryController (journal feature)"]
  Detail --> AppBarCtl["TaskAppBarController"]
  Detail --> FocusCtl["TaskFocusController"]

  Detail --> Checklists["Checklist widgets + controllers"]
  Detail --> LinkedTasks["LinkedTasks widgets + controller"]
  Detail --> Progress["TaskProgressController"]
  Detail --> Header["Header wrappers"]

  Checklists --> ChecklistRepo["ChecklistRepository"]
  Progress --> ProgressRepo["TaskProgressRepository"]
  LinkedTasks --> LinkedEntries["Linked entry providers"]

  Filters["Task filter UI"] --> PageCtl["JournalPageController(showTasks=true)"]
  PageCtl --> DB["JournalDb / FTS / vector search"]
```

The important boundary here is that the tasks feature owns task behavior and task presentation, but it intentionally reuses the shared journal controllers and persistence paths where possible.

## Tasks Tab Browse Page

The redesigned tasks tab is an in-place browse-page migration, not a new query stack.

`TasksTabPage` still reads from `JournalPageController(showTasks: true)` and still uses the journal feature's existing infinite paging path. The redesign only swaps the browse presentation layer on top of that controller.

In desktop split-pane mode, `TasksRootPage` keeps the list pane mounted while
the detail pane is keyed by the selected task ID. That gives each task detail
surface its own state lifetime instead of reusing the previous task's
stateful page internals across selection changes.

At runtime the browse page does three specific things:

1. it converts paged `JournalEntity` results into `TaskBrowseEntry` rows via `buildTaskBrowseEntries`
2. it derives section headers from the active sort mode
3. it reuses the same grouped-card interaction model as the projects tab so hover and selection backgrounds can suppress adjacent dividers cleanly

```mermaid
flowchart TD
  Page["TasksTabPage"] --> PageCtl["JournalPageController(showTasks=true)"]
  PageCtl --> Paging["PagingController / infinite_scroll_pagination"]
  Paging --> Entries["buildTaskBrowseEntries(items, sortOption, now)"]
  Entries --> Rows["TaskBrowseListItem rows"]
  Rows --> Surface["GroupedCardRowSurface"]
  Rows --> RowInteractions["buildTaskBrowseRowInteractions(...)"]
  RowInteractions --> SharedInteractions["buildGroupedCardRowInteractions(...)"]
  SharedInteractions --> Projects["Projects grouped rows use the same adjacency logic"]
```

The section semantics are intentionally sort-dependent:

- due-date sort groups into `Today`, `Tomorrow`, `Yesterday`, exact due dates, or `No due date`
- created-date sort groups by the task creation day
- priority sort groups by priority buckets

That is why the browse model carries section metadata separately from the row widget. The card does not guess how to group tasks; it receives that decision from the browse-entry model.

## Core Data Model

Tasks are represented by the `Task` journal entity variant with `TaskData`.

Important task concerns represented directly in `TaskData` include:

- title
- status
- priority
- estimate
- due date
- checklist IDs
- cover-art ID
- language preference
- inference profile ID
- AI-suppressed label IDs

Two important boundaries:

- label assignments live on entry metadata (`meta.labelIds`), not in `TaskData`
- project membership is resolved through the `projects` feature, not embedded as a task field

Checklist content is modeled separately through checklist entities and linked checklist-item entities. That split matters because the UI allows drag, drop, reorder, export, and cross-checklist movement without flattening everything into one giant task row.

## Task Detail Composition

`TaskDetailsPage` is the main task surface. It composes:

- `TaskSliverAppBar`
- `TaskForm` (which begins with the `DesktopTaskHeaderConnector`)
- linked entries with timer-aware highlighting
- reverse linked-from entries
- AI-running animation overlay

```mermaid
flowchart TD
  Open["Open task detail page"] --> Load["entryControllerProvider(taskId)"]
  Load --> AppBar["TaskSliverAppBar (cover image + back / AI / overflow)"]
  Load --> Form["TaskForm"]
  Form --> Header["DesktopTaskHeaderConnector → DesktopTaskHeader"]
  Form --> Agents["AgentSuggestionsPanel + TaskAgentReportSection"]
  Form --> Linked["LinkedTasksWidget"]
  Form --> Checklists["ChecklistsWidget"]
  Load --> Focus["HighlightScrollMixin + TaskFocusController"]
  Open --> Drop["Desktop drag-and-drop media import"]
  Drop --> ImageAnalysis["Optional automatic image analysis trigger"]
```

This page is not just "show task fields." It is the task workspace where task metadata, linked content, time tracking, and AI-adjacent affordances meet.

Inside `TaskForm`, the composition is also fairly opinionated:

- `DesktopTaskHeaderConnector` for the interactive header: inline multi-line title edit, priority badge, project reference (with a "No project" placeholder when none is linked), work-category chip (or "unassigned" placeholder), due-date chip (or "No due date" placeholder), estimate chip (with progress bar when set), assigned label chips (or "Add Label" placeholder), and status dropdown. Extended actions (share, speech modal, etc.) are owned by the pinned app bar's `more_vert` button, not the header itself. The connector watches `entryControllerProvider`, `projectForTaskProvider` and the labels stream, maps the task to an immutable `DesktopTaskHeaderData` plus a Riverpod-aware `estimateSlot`, and forwards callbacks to the existing modal pickers (`TaskStatusModalContent`, `showDueDatePicker`, `showEstimatePicker`, `CategorySelectionModalContent`, `ProjectSelectionModalContent`, `LabelSelectionModalUtils`) plus `EntryController.save / updateTaskStatus / updateTaskPriority / updateCategoryId`
- an `EditorWidget` only for legacy tasks that already have non-empty entry text
- `AgentSuggestionsPanel` which embeds `TaskAgentReportSection` plus the unified open-proposal list
- `LinkedTasksWidget`
- `ChecklistsWidget`

### Visual surface

Section cards on the task detail page (AI Task Summary, Task description, Linked Tasks, Checklists, expanded activity) render on `TaskDetailSectionCard` — solid `background.level02`, `radii.l`, subtle `decorative.level01` border, no gradient, no drop shadow. This matches the `task_browse_list_item` surface in the task list, so the detail page reads as part of the same system. The section is encapsulated by `TaskShowcasePalette` and the design-system tokens — no ad-hoc hex values.

### DesktopTaskHeader visual states

The header has three interactive title states driven by `MouseRegion` + local editing state, all sharing the same 28px capsule (`surface.hover` fill, `radii.s` corners):

```mermaid
stateDiagram-v2
  [*] --> ReadOnly
  ReadOnly --> Editing: tap title
  Editing --> ReadOnly: check button / ⌘+Enter → onTitleSaved
  Editing --> ReadOnly: close button / Esc → revert
```

- ReadOnly: the title renders as plain `Text` in Heading 3 Bold, wrapping onto multiple lines for long strings.
- Editing: the title becomes a capsule-shaped inline `TextField` with a teal `interactive.enabled` border and external check (save) and close (cancel) buttons. Enter inserts a newline; ⌘/Ctrl+Enter or tapping the check saves.

The header body is three explicit lines:

1. **Title** — tap to edit.
2. **Classification** — `Wrap` of `[category | unassigned placeholder] → [project | No project placeholder] → [label chips | Add Label placeholder]`.
3. **Metadata** — `Wrap` of `[due date | No due date placeholder] → [estimate chip] → [priority badge] → [status dropdown]`.

There is no ellipsis inside the header — entry actions live on the pinned app bar. `TaskCompactAppBar` and `TaskExpandableAppBar` also surface the task title in `subtitle2` once the detail scroll offset passes a threshold, so the title stays visible as the header scrolls out of view.

The header is exercised in isolation under Widgetbook → Tasks → Desktop task header with Default / Editing / Long title / Empty classification + metadata / Playground use cases. The Playground drives priority, status, category, due date, labels and the editing initial flag via in-page controls — no Riverpod is needed because the presentational `DesktopTaskHeader` takes a plain `DesktopTaskHeaderData` and emits callbacks.

## Checklist Subsystem

Checklists are one of the main reasons the tasks feature exists as its own feature instead of being a loose set of task helper widgets.

### Checklist runtime model

`ChecklistController`:

- loads a checklist entity
- subscribes to the checklist and all linked checklist-item IDs
- updates title and item order
- handles dropping existing items into a checklist
- handles dropping a new item into a checklist
- unlinks and relinks items
- deletes the checklist and removes its ID from the parent task when possible

```mermaid
flowchart TD
  Checklist["ChecklistWidget"] --> Ctl["ChecklistController"]
  Ctl --> DB["JournalDb"]
  Ctl --> Repo["ChecklistRepository"]
  Ctl --> Notify["UpdateNotifications"]

  Drag["Drag/drop item"] --> Ctl
  Ctl --> Reorder["Reorder within checklist"]
  Ctl --> Move["Move item across checklists"]
  Ctl --> Create["Create new checklist item from drop payload"]
```

### Checklist sorting state machine

This one is real. `ChecklistsSortingController` owns a small but explicit state machine:

```mermaid
stateDiagram-v2
  [*] --> Normal
  Normal --> Sorting: enterSortingMode(preExpansionStates)
  Sorting --> Normal: exitSortingMode()
  Normal --> Normal: clearPreExpansionStates()
```

What actually happens in sorting mode:

- checklist cards collapse
- large drag handles appear
- pre-sort expansion states are stored
- widgets can restore their previous expansion states when sorting ends

That is not complex enough to deserve a PhD thesis, but it is absolutely worth documenting because it drives a visible UI mode change.

## Linked Tasks

The linked-task UI is intentionally separate from the generic linked-entry UI.

The feature distinguishes between:

- outgoing task links
- incoming task links
- generic linked entries that are not tasks

`LinkedTasksController` owns the small UI state for this section.

### Linked-task manage-mode state machine

```mermaid
stateDiagram-v2
  [*] --> Browse
  Browse --> Manage: toggleManageMode()
  Manage --> Browse: toggleManageMode()
  Manage --> Browse: exitManageMode()
```

When manage mode is active:

- unlink buttons are shown
- the section behaves like an editor, not just a viewer

This is one of those tiny state machines that users feel immediately even if they never see the code.

### Linked-task flow

```mermaid
flowchart LR
  Header["LinkedTasksHeader"] --> Modal["LinkTaskModal"]
  Header --> Manage["Manage mode toggle"]
  Modal --> Search["Search eligible tasks"]
  Search --> Link["Create link"]
  Link --> Outgoing["Outgoing linked tasks provider"]
  Link --> Incoming["Incoming linked-from tasks"]
```

The modal explicitly excludes:

- the current task
- already-linked tasks

which is a good example of the feature preferring guardrails over polite chaos.

## Task Progress Calculation

Task progress is calculated from linked work, not from optimism.

`TaskProgressRepository` batches progress requests across tasks and calculates:

- estimate
- time ranges of linked work
- union duration of meaningful work spans

It deliberately excludes:

- `Task`
- `AiResponseEntry`
- `JournalAudio`

from counted work duration.

That last exclusion is especially important. Otherwise a one-hour audio recording of a meeting could count as one hour of work even when it is just a recording artifact, which would be mathematically neat and practically wrong.

```mermaid
flowchart TD
  TaskId["Task ID"] --> Batch["TaskProgressRepository batch queue"]
  Batch --> DB["JournalDb.getTaskEstimatesByIds + getBulkLinkedTimeSpans"]
  DB --> Ranges["Build time ranges"]
  Ranges --> Union["Calculate union duration"]
  Union --> State["TaskProgressState(progress, estimate)"]
  State --> UI["Compact progress / detail widgets"]
```

## Filter and List Model

The `/tasks` route resolves through `TasksRootPage`, which renders `TasksTabPage`.

`TasksTabPage` is backed by `JournalPageController(showTasks: true)` and its `PagingController`. The tasks tab must continue to handle thousands of rows without replacing the existing infinite-scroll mechanics.

```mermaid
flowchart TD
  Route["/tasks"] --> Root["TasksRootPage"]
  Root --> Redesign["TasksTabPage"]

  Redesign --> PageCtl["JournalPageController(showTasks: true)"]
  PageCtl --> Paging["PagingController + PagedSliverList"]
  PageCtl --> Filters["Task filter model + persistence"]
  PageCtl --> Search["Search / sort / vector mode / quick labels"]
```

`TasksTabPage` intentionally does not own pagination, query execution, or filter semantics. It reads the already-loaded task slice from the shared paging state and only transforms that visible slice into section presentation metadata.

Current grouping behavior is sort-dependent:

- due-date sort: `Due Today`, `Due Tomorrow`, `Due Yesterday`, dated due buckets, and `No due date`
- priority sort: priority buckets (`P0` .. `P3`)
- creation-date sort: creation-day buckets

The filter button opens the task filter modal. Filter semantics, persistence keys, and controller methods are shared with the journal tab via `JournalPageController`.

Task-specific persisted filter concerns include:

- selected task statuses
- selected priorities
- selected labels
- selected categories
- selected projects
- sort option
- due-date display
- creation-date display
- cover-art display
- projects-header display
- distance display
- agent-assignment filter

Persistence uses:

- `TASKS_CATEGORY_FILTERS` for the tasks tab

which keeps tasks-tab filter state separate from the journal tab. One subtle boundary here: project filtering is persisted in the same controller state, but the visible project filter controls are rendered by shared/project widgets rather than `lib/features/tasks/ui/filtering/`.

### Saved Filters

The tasks tab also supports user-saved filters surfaced as a treeview under the Tasks destination in the desktop sidebar. The model lives in `lib/features/tasks/state/saved_filters/`:

- `SavedTaskFilter` (`{id, name, filter: TasksFilter}`) is a Freezed JSON-serializable model. The ephemeral `query` / `match` field on `JournalPageState` is intentionally NOT part of the saved payload — it stays on the live page state and is preserved across saved-filter activations.
- `SavedTaskFiltersPersistence` writes the ordered list as a single JSON blob to `SettingsDb` under the `SAVED_TASK_FILTERS` key. Position in the list IS the sort order. Mirrors the dedup-on-write pattern of `JournalFilterPersistence`.
- `savedTaskFiltersControllerProvider` (Riverpod `keepAlive: true` async notifier) exposes `create`, `rename`, `updateFilter`, `delete`, `reorder`. Each mutation persists.
- `SavedTaskFilterActivator` applies a `SavedTaskFilter` to the live `JournalPageController` via `applyBatchFilterUpdate`.

Three derived providers wire the UI to the live page state:

- `currentSavedTaskFilterIdProvider` — id of the saved filter whose persisted shape matches the live filter (display-only fields like `showCoverArt`/`showProjectsHeader`/`showDistances` are ignored when matching), or `null` when nothing matches.
- `tasksFilterHasUnsavedClausesProvider` — `true` when the live filter has clauses but doesn't match any saved filter; gates the sidebar `+` and modal Save button.
- `liveTasksFilterProvider` — snapshot of the live `TasksFilter` shape; used by the Save flow to capture exactly what the user sees.

Surfaces:

1. Sidebar treeview (`TasksSavedFiltersTree` → `SavedTaskFiltersSection` + `SavedTaskFilterRow`) — rendered via `DesktopSidebarDestination.expandedChildBuilder` only when the Tasks destination is active and the sidebar is expanded. Hover-trash with two-tap confirm delete, double-click rename, drag-to-reorder via `ReorderableListView.builder`. Empty state is a dashed pill instructing the user to adjust the filter and tap Save.
2. Filter modal Save flow — `DesignSystemTaskFilterActionBar` gained an optional Save button next to Apply. Tapping it opens an inline name popup (`MenuAnchor`-anchored) with autofocus, Enter-to-commit, Escape-to-cancel, click-outside dismiss. The name is passed to `showTaskFilterModal`'s `onSavePressed` handler, which calls `create()` for new saves and `updateFilter()` when the user edits and re-saves the currently active filter under the same name.
3. Tasks pane named-filter indicator — `TabSectionHeader.titleSuffix` renders `· {savedFilterName}` next to "Tasks" when a saved filter is active.
4. Save / update / delete confirmation toasts via `SnackBar` (`saved_task_filter_toast.dart`).

```mermaid
stateDiagram-v2
  [*] --> NoMatch
  NoMatch: live filter has no saved match
  Saved: live filter matches saved view
  NoMatch --> Saved: activate saved row\n· filter applies\n· currentSavedId set
  Saved --> NoMatch: user edits any field\n· currentSavedId clears
  NoMatch --> Saved: user re-edits into\nan existing saved shape
  NoMatch --> NoMatch: Save button →\nname popup → create
  Saved --> Saved: Save with same name →\nupdateFilter (no rename)
```

Counts in the saved-filter rows are surfaced through the optional `counts: Map<String, int>?` parameter on `SavedTaskFiltersSection`. The current desktop wiring leaves this null pending a per-saved-filter task-count provider — the row hides the count when none is supplied.

The redesigned browse page also preserves the existing non-filter runtime behavior:

- pull-to-refresh
- full-text vs vector search toggle
- quick-label strip
- optional project health header
- create-task FAB and auto-assign flow
- `/tasks/:taskId` navigation on row selection

## Header Controls and Metadata

The task detail metadata band is concentrated entirely inside `DesktopTaskHeaderConnector`. It provides interactive controls for:

- title (inline capsule edit)
- status
- priority
- category (work)
- project
- due date
- estimate
- labels
- ellipsis actions (share, extended actions, speech modal) via `ExtendedHeaderModal`

Notable behavior already implemented:

- `TaskSliverAppBar` switches between compact and expandable variants based on whether the task has `coverArtId`
- the header is desktop-first and the same component serves mobile — chips wrap onto the next line on narrow widths
- due dates on the detail page use urgency styling, while relative/absolute date display is a list-level concern owned by the shared page state
- labels are category-aware, but still allow out-of-scope assigned labels to be removed
- project selection integrates with the project health layer without making the task feature own project analysis itself
- language is not surfaced in the new header itself — it is reachable through the pinned app bar's triple-dot menu, which shows a "Set language" action (`ModernSetTaskLanguageItem`). The action renders the currently selected language's flag inline when one is set, falls back to `Icons.language` otherwise, and opens the same `LanguageSelectionModalContent` modal used by the category editor. Selection is persisted via `journalRepositoryProvider.updateJournalEntity` with `ChangeSource.user` on `TaskData.languageSource`.

## AI and Media Integrations

The tasks feature consumes AI-adjacent capabilities rather than owning them.

Examples:

- AI-running animation wrapper at the bottom of the detail page
- automatic image-analysis trigger on dropped media
- linked entries can include AI-generated content or transcriptions
- agent reports and pending change sets are displayed on task pages, but generated elsewhere

That separation is deliberate. The task feature owns the task experience; it should not become a secret duplicate of the AI feature.

## Current Constraints

- task persistence still flows through shared journal/persistence machinery
- task list filtering is powered by the shared journal page controller, so some list-state logic lives outside this feature directory
- checklists are modular and flexible, but that means the feature spans several controllers and widget clusters
- linked-task UI is task-specific, while generic linked-entry rendering still lives in the journal feature

## Relationship to Other Features

- `journal` owns the shared entry substrate and paging/filter controller
- `projects` adds project grouping and project-agent summaries around tasks
- `labels` supplies label entities and category scoping
- `speech` can create task-linked audio entries
- `ai` and `agents` provide reports, change sets, prompts, and automation around task content

If you want to understand why tasks feel like the app's operational center rather than just another entry type, this feature is the answer.
