---
type: Feature Module
title: Projects
description: The middle layer between categories and tasks — a denormalized membership column, coalesced reads, and health that is agent-authored rather than locally guessed.
resource: ../../lib/features/projects
tags: [projects, grouping, health, agents]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T03:00:00Z }
stale_after: 2027-03-01
sources:
  - id: src
    resource: ../../lib/features/projects
    title: Projects feature source
    last_modified: 2026-08-15
  - id: queries
    resource: ../../lib/database/database_project_queries.dart
    title: Project queries and the coalescing wave
    last_modified: 2026-06-08
---

Projects group related tasks, power the projects tab, and integrate with the
agent system so a project accumulates health signals, recommendations and
update-driven reports instead of just acting as a nicer folder.

**The visible experience is gated by `enableProjectsFlag`.** With it off there is
no top-level tab, no category projects section and no task project chip. Routes
may still exist, but the normal ways in are hidden.

```mermaid
flowchart TD
  ProjectEntry["ProjectEntry"] --> Repo["ProjectRepository"]
  Repo --> Journal["JournalDb + PersistenceLogic"]
  Repo --> Links["EntryLink.project"]
  Links --> Tasks["Task membership"]

  Repo --> Overview["Projects overview snapshot"]
  Overview --> Filters["ProjectsFilterController"]
  Filters --> Tab["Projects tab UI"]

  Agent["Project agent"] --> Health["projectHealthMetricsProvider"]
```

# The data model

A project is a `JournalEntity.project` variant. `ProjectData` carries `title`,
`status`, `statusHistory`, `targetDate`, `dateFrom` and `dateTo`, plus free-form
body text through `entryText` — which the detail page uses as fallback when no
project-agent TL;DR exists yet.

**`ProjectStatus` has six variants**: `open`, `active`, `monitoring`, `onHold`
(with a **required reason**), `completed`, `archived`.

`monitoring` marks a project that is not closed but has **no time actively
scheduled** — touched only when something comes up before it can be declared
done. Day planning tiers by status: `active` forms the scheduled pool;
`open`/`monitoring`/`onHold` stay available at lower priority so something
noticed along the way can still be planned; `completed`/`archived` are
unavailable.

## Membership is denormalized

Tasks link to projects through `EntryLink.project`, **and** the database keeps a
denormalized `project_id` on tasks.

That column is the read path for "project of a task":
`JournalDb.getProjectForTask` resolves through `journal.project_id` (indexed)
rather than joining `linked_entries` and sorting. **It is kept in lock-step with
the latest non-hidden `ProjectLink` on every link and entity write**, so the
result is identical to the old join without its
`USE TEMP B-TREE FOR ORDER BY` sort.

## Membership is scoped to a category — from the task's side

`linkTaskToProject` refuses a link whose two sides disagree on category, which
covers the moment the link is created. But a category can move afterwards, and
that write is nowhere near the link, so the rule has to be re-checked there too.

**`EntryController.updateCategoryId` does that for the task side**: it drops the
project link of every task it moves when the new category is not the project's
own.

```mermaid
stateDiagram-v2
  [*] --> Unlinked
  Unlinked --> Linked: linkTaskToProject (same category only)
  Linked --> Linked: task category re-picked unchanged
  Linked --> Unlinked: task category changed or cleared
  Linked --> Mismatched: project moved to another category
  note right of Mismatched
    Not reconciled — see below
  end note
```

The comparison is against **the project's** category, not the task's previous
one — re-picking the category the task is already in leaves the two in
agreement, so there is nothing to drop. It stays a comparison when the category
is cleared: a project that carries a category is dropped, and an uncategorized
project is kept, since `null == null` is exactly the pairing
`linkTaskToProject` would still accept. Uncategorized projects are real —
`createProject` takes a nullable category, and `createTask(projectId:)` copies
the project's category onto the new task, `null` included.

The lookup deliberately does **not** go through `getProjectForTask`. That read
honors the private gate, so a private project resolves to null while private
entries are hidden; a cleanup reading that as "no link" would skip the stale row
and let it reappear the moment they are shown. `getLinkedProjectForTask`
resolves the live `ProjectLink` and its project entity directly, neither of
which is privacy-filtered.

A task whose category write did not land is not swept. A failed write means the
entity was not found — deleted since it was read, or never there — so it keeps
the category it had, and its project is still correct for it.

The sweep covers the entries the same call re-categorized, not just the edited
one. `getLinkedEntities` is **not filtered by link type**, so the propagation
loop rewrites the category of linked *tasks* along with the timers and images it
is aimed at; each of those gives up a now-foreign project too. A `ProjectLink`
runs project → task, so a task's own project never appears in that list.

Only the task detail header changes a task's category
(`CategorySelectionIconButton` excludes tasks and events explicitly), so the
controller is the single funnel this rule has to sit in.

**The project side is not reconciled.** `ProjectDetailController.updateCategoryId`
persists a project's new category through `ProjectRepository.updateProject`
without touching its member tasks, so moving a *project* between categories
leaves every linked task behind in the old one and reproduces exactly the
mismatch the task side now prevents. Nothing repairs pre-existing mismatches
either — only a subsequent task-side category change clears one.

# Two hot reads are shaped for bursts

**`getProjectForTask` is microtask-coalesced.** `projectForTaskProvider` is an
autoDispose family, so a task list mounts one lookup per visible row. Instead of
N single-task queries, concurrent callers in the same microtask merge into **one
wave**:

```mermaid
sequenceDiagram
  participant Rows as "N task rows (projectForTaskProvider)"
  participant DB as "JournalDb.getProjectForTask"
  participant Wave as "_PendingProjectForTaskWave"
  Rows->>DB: getProjectForTask(taskId) xN (same microtask)
  DB->>Wave: merge taskId
  Note over Wave: one scheduleMicrotask per wave
  Wave->>DB: getProjectIdMapForTasks({all task ids})
  Wave->>DB: getJournalEntitiesForIdsUnordered({distinct project ids})
  Wave-->>Rows: each caller resolves its project from the map
```

**`watchProjectsOverview` debounces refetches.** `UpdateNotifications` already
coalesces sync bursts (~1 s) and local edits (100 ms); the repository adds a
300 ms debounce so remaining back-to-back batches collapse into a single rebuild.
The first fetch on subscribe stays immediate, and the in-flight
`fetching`/`pendingRefetch` guard is preserved.

# The overview is grouped DTOs

The tab is driven by `ProjectsOverviewSnapshot`, `ProjectCategoryGroup`,
`ProjectListItemData`, `ProjectTaskRollupData` and `ProjectsFilter` — **not raw
entities** — so the UI renders grouped rows without recomputing counts,
categories and rollups in each widget.
Project-agent one-liners are resolved in two bulk reads when the snapshot is
assembled, then stored on each `ProjectListItemData`. Rows therefore render a
stable subtitle without one provider/query chain per card, and local search
matches the same one-liner text that the list displays.

The default `Current` scope keeps open, active, monitoring and on-hold work in
view; `All` restores completed and archived projects. Projects sort by
actionability, then target date and recent activity by default, with target
date, recent and name alternatives. Category sections are collapsible, and
completion uses the interactive accent rather than pretending low completion
is a health warning. Projects with no tasks say so instead of showing a red
zero-percent ring. First-run, current-empty and filtered-empty states each
explain the state and offer the relevant recovery action.

On desktop the overview and selected detail share the standard resizable
list/detail traversal. Once a project is selected, Hide list enters focus mode:
the list and divider go offstage without being disposed, and Show list remains
available over every detail state, including initial loading and errors. A
desktop project detail never renders the mobile Back affordance because the
split has no parent route to pop; Back remains on the standalone mobile detail
route. The primary search command restores a hidden list before focusing its
search field, so keyboard search never targets an offstage control. Toggling
focus mode changes only the restore-button overlay; the detail subtree stays
mounted under a stable parent. Tasks and Projects share the persisted collapse
preference and expanded list width. The focused header and body are centered on
the shared 960 pt detail
measure with its one standard horizontal gutter, keeping report lines and cards
readable when the list releases a wide canvas without double-insetting mobile
content.

# Health is agent-authored

```mermaid
flowchart LR
  Report["Latest project-agent report"] --> Metrics["projectHealthMetricsFromReport"]
  Metrics --> HealthProv["projectHealthMetricsProvider"]
  Recos["projectRecommendationsProvider"] --> UI
  HealthProv --> UI["Health panel / neutral unassessed state"]
```

The detail pages pull project entity data, linked tasks, the latest project-agent
report, parsed health metrics from it, scheduled wake state, active
recommendations, derived presentation data, and the wake controls.

**There is no aggregator object** — each surface watches the providers it needs.

**If the latest report has no parseable health payload yet, the app shows a
neutral unassessed state** rather than falling back to invented local
heuristics. Once metrics exist, the detail leads with the agent-authored band,
rationale and optional confidence; it never converts a categorical assessment
into a fabricated numeric score. Blocker navigation appears only when blocked
tasks exist and opens the first actionable blocker.

# When the project agent actually wakes

Project agents are stale and non-waking by default. They have no recurring
daily schedule; meaningful project activity, agent-assigned work, or an
explicit request creates one-shot work instead.

```mermaid
flowchart TD
  Activity["Meaningful project or linked-task activity"] --> Pending["Persist pending work"]
  Pending --> Deferred["Persist one-shot wake deadline"]

  Creation["Create project agent"] --> CreationFallback["Persist creation fallback"]
  Creation --> Queue["Queue wake now"]
  Manual["Manual wake request"] --> Queue

  Deferred --> DueQueue["Queue wake when deadline is due"]
  CreationFallback --> DueQueue
  DueQueue --> FullRun["Load project, linked tasks, reports, run LLM"]
  Queue --> FullRun
  FullRun --> Outcome{"Wake succeeds?"}
  Outcome -->|yes| Persist["Persist fresh report + recommendations"]
  Outcome -->|no| Retry["Keep pending work and re-arm fallback"]
  Retry --> Deferred
  Persist --> Clear["Clear consumed work and deadlines"]
  Clear --> Stale["Stale / non-waking"]
```

The project detail read model exposes the active one-shot wake deadline beside
the agent report. Legacy recurring rows are retired by the agent subsystem and
do not become new daily wakes.

See [project and event agents](agents/project-and-event-agents.md) for the
workflow side.
