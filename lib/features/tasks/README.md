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
- `TaskTitleHeader`
- `TaskForm`
- linked entries with timer-aware highlighting
- reverse linked-from entries
- AI-running animation overlay

```mermaid
flowchart TD
  Open["Open task detail page"] --> Load["entryControllerProvider(taskId)"]
  Load --> Header["Task app bar + title header"]
  Load --> Form["TaskForm"]
  Load --> Linked["LinkedEntriesWithTimer"]
  Load --> LinkedFrom["LinkedFromEntriesWidget"]
  Linked --> Focus["HighlightScrollMixin + TaskFocusController"]
  Form --> HeaderControls["Status / priority / labels / project / due date"]
  Open --> Drop["Desktop drag-and-drop media import"]
  Drop --> ImageAnalysis["Optional automatic image analysis trigger"]
```

This page is not just "show task fields." It is the task workspace where task metadata, linked content, time tracking, and AI-adjacent affordances meet.

Inside `TaskForm`, the composition is also fairly opinionated:

- `TaskHeaderMetaCard` for status/priority/category/project/language plus created-at and due-date chips
- `TaskLabelsWrapper` for label assignment and estimate editing/progress
- an `EditorWidget` only for legacy tasks that already have non-empty entry text
- `TaskAgentReportSection` and `ChangeSetSummaryCard` for agent output that belongs on the task page but is owned elsewhere
- `LinkedTasksWidget`
- `ChecklistsWidget`

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

The redesigned browse page also preserves the existing non-filter runtime behavior:

- pull-to-refresh
- full-text vs vector search toggle
- quick-label strip
- optional project health header
- create-task FAB and auto-assign flow
- `/tasks/:taskId` navigation on row selection

## Header Controls and Metadata

The task detail metadata band is split between `TaskHeaderMetaCard` and `TaskLabelsWrapper`. Together they provide interactive controls for:

- status
- category
- language
- priority
- project
- due date
- estimate
- labels

Notable behavior already implemented:

- `TaskSliverAppBar` switches between compact and expandable variants based on whether the task has `coverArtId`
- due dates on the detail page use urgency styling, while relative/absolute date display is a list-level concern owned by the shared page state
- labels are category-aware, but still allow out-of-scope assigned labels to be removed
- language changes are explicitly marked as user-originated
- project selection integrates with the project health layer without making the task feature own project analysis itself

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
