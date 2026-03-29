# Projects Feature

Projects provide the middle layer between categories and tasks.

They group related tasks, power the dedicated projects tab, and integrate with
the agent system so a project can accumulate health signals, recommendations,
and scheduled digests instead of just acting as a nicer folder.

## What This Feature Owns

- `ProjectEntry` persistence and editing
- Task-to-project linking
- The top-level projects overview tab
- Both project detail pages
- Project health built from project-agent reports
- The filters and grouped list models used by the projects tab

## Feature Flag

The visible project experience is controlled by `enableProjects`.

When the flag is off:

- no top-level projects tab
- no category projects section
- no task project chip
- no project health header on tasks

Routes may still exist, but the normal ways into the feature are hidden.

## Architecture

```mermaid
flowchart TD
  ProjectEntry["ProjectEntry"] --> Repo["ProjectRepository"]
  Repo --> Journal["JournalDb + PersistenceLogic"]
  Repo --> Links["EntryLink.project"]
  Links --> Tasks["Task membership"]

  Repo --> Overview["Projects overview snapshot"]
  Overview --> Filters["ProjectsFilterController"]
  Filters --> Tab["Projects tab UI"]

  Agent["Project agent"] --> Health["Health metrics provider"]
  Agent --> Summary["Project agent summary provider"]
  Agent --> Recos["Project recommendations provider"]
  Health --> Snapshot["ProjectHealthSnapshot"]
  Summary --> Snapshot
  Recos --> Snapshot
  Snapshot --> Detail["Project detail UI"]
```

Projects are therefore both:

- a journal-backed grouping feature
- a view of project health built from project-agent data

## Directory Shape

```text
lib/features/projects/
├── model/
├── repository/
│   └── project_repository.dart
├── state/
│   ├── project_providers.dart
│   ├── project_detail_controller.dart
│   ├── project_detail_record_provider.dart
│   └── project_health_metrics.dart
├── ui/
│   ├── pages/
│   ├── model/
│   └── widgets/
└── widgetbook/
```

## Core Data Model

Projects are stored as `ProjectEntry`, a `JournalEntity.project` variant.

The important user-facing fields live in `ProjectData`:

- `title`
- `status`
- `statusHistory`
- `targetDate`
- `dateFrom`
- `dateTo`

Projects can also carry free-form body text through `entryText`. The newer
top-level detail page uses that text as fallback text when no project-agent
TL;DR exists yet.

Tasks are linked to projects through `EntryLink.project`. The database also
maintains a denormalized `project_id` on tasks so overview queries do not need
to rediscover the relationship expensively every time.

## Create Flow

Project creation is where project data and the agent system connect.

```mermaid
sequenceDiagram
  participant UI as "ProjectCreatePage"
  participant Repo as "ProjectRepository"
  participant Template as "AgentTemplateService"
  participant Agent as "ProjectAgentService"

  UI->>Repo: createProject(ProjectEntry)
  Repo-->>UI: persisted project
  UI->>Template: find matching projectAgent template
  alt template available
    UI->>Agent: createProjectAgent(projectId, template)
    Agent-->>UI: agent identity created
  else no template
    UI-->>UI: project exists without agent
  end
```

The template lookup prefers category-scoped project-agent templates and falls
back to global ones. If no matching template exists, the project still exists
just fine. It simply starts life without an agent until one is created later.

## Repository Responsibilities

`ProjectRepository` owns the data-heavy part of the feature:

- fetch one project
- fetch projects for a category
- fetch tasks for a project
- fetch the project for a task
- create and update projects
- link and relink tasks
- remove task links
- compute grouped overview snapshots
- watch overview snapshots against update notifications

Two design choices matter here:

1. linking enforces both the same-category rule and the single-project-per-task rule
2. project overview queries are batched and grouped so the top-level tab can stay fast

## Overview Tab Model

The top-level projects tab is driven by grouped DTOs rather than raw entities:

- `ProjectsOverviewSnapshot`
- `ProjectCategoryGroup`
- `ProjectListItemData`
- `ProjectTaskRollupData`
- `ProjectsFilter`

That lets the tab UI render grouped rows without recomputing counts,
categories, and task rollups in each widget.

## Filter Model

`ProjectsFilterController` is small, but important.

It stores:

- selected status IDs
- selected category IDs
- text query
- search mode

The current production UI only drives `disabled` and `localText`. The enum also
already has a `vector` case, but it is not wired into the projects UI yet.

Local text search runs over the already-loaded grouped snapshot. That is the
current tradeoff: cheap, deterministic, and good enough until vector search is
actually worth adding here.

## Detail State

The two detail routes do different jobs:

- `/settings/projects/:projectId` is the edit page driven by `ProjectDetailController`
- `/projects/:projectId` is the newer detail page built from `ProjectRecord` via `projectDetailRecordProvider`

`ProjectDetailController` follows the same pattern as the other edit pages:

- keep an original copy
- keep a pending copy
- compute `hasChanges`
- only append status history when save actually persists

That last point prevents status-history inflation when users flip between statuses during editing.

## Project Health Composition

The health state is assembled across `project_providers.dart` and
`project_detail_record_provider.dart`.

The detail pages pull from a few separate inputs:

- project entity data
- linked tasks
- latest project-agent report
- parsed health metrics from that report
- summary freshness and scheduled wake state
- active recommendation entities
- derived `ProjectRecord` presentation data

```mermaid
flowchart LR
  Project["ProjectEntry"] --> Snapshot["ProjectHealthSnapshot"]
  Report["Latest project-agent report"] --> Metrics["projectHealthMetricsFromReport"]
  Metrics --> Snapshot
  Summary["ProjectAgentSummaryState"] --> Snapshot
  Recos["ProjectRecommendationEntity list"] --> Snapshot
  Snapshot --> Header["Health chip / header"]
  Snapshot --> Panel["Health panel"]
  Snapshot --> Detail["Detail page sections"]
```

This is why project health is agent-authored rather than locally guessed. If
the latest project-agent report has no parseable health payload yet, the app
shows no health state instead of falling back to invented local heuristics.

## UI Surfaces

### Top-Level Projects Tab

The tab renders grouped project rows using the shared overview content and list
widgets.

It is responsible for:

- grouped category sections
- search
- filter modal
- navigation into project details
- floating create action that still hands off to `/settings/projects/create`

### Project Detail Pages

There are currently two detail routes in play:

- the newer top-level `/projects/:projectId` path
- the older settings-scoped detail path used by category-driven flows

The newer top-level route is not just a renamed editor. It assembles a
`ProjectRecord` and renders the shared detail widgets
(`ProjectMobileDetailContent`, `HealthPanel`, `ProjectTasksPanel`), which keeps
the production surface aligned with Widgetbook.

### Category and Task Integrations

Projects surface in:

- category details via `CategoryProjectsSection`
- task metadata via `TaskProjectWrapper` and `TaskProjectWidget`
- the tasks page via `ProjectHealthHeader`

## When the Project Agent Actually Wakes

Plainly: the project agent is not supposed to wake for every microscopic ripple
in a linked task.

It has three real wake paths:

1. Creation wake. `ProjectAgentService.createProjectAgent()` provisions the agent, sets `scheduledWakeAt` to the next local digest time, and immediately enqueues a `creation` wake.
2. Immediate direct-project wake. The agent is subscribed to `projectEntityUpdateNotification(projectId)`, so explicit project edits can enqueue an orchestrated wake immediately. Manual reanalysis uses the same immediate path.
3. Scheduled digest wake. Linked task activity does not wake the model immediately. `ProjectActivityMonitor` resolves affected project IDs and writes `pendingProjectActivityAt` on the agent state instead.

That third path is the key design choice. Task churn marks the summary as stale
now, and the digest decides later whether the model should spend tokens on a
fresh project report.

```mermaid
flowchart TD
  Create["Create project agent"] --> CreationWake["Enqueue creation wake now"]
  Create --> NextDigest["Set scheduledWakeAt to next local digest"]

  DirectEdit["Direct project edit"] --> DirectSub["projectEntityUpdateNotification(projectId)"]
  DirectSub --> Orchestrator["WakeOrchestrator"]
  Orchestrator --> ImmediateWake["Immediate project-agent wake"]

  TaskActivity["Linked task activity"] --> Monitor["ProjectActivityMonitor"]
  Monitor --> Mark["Set pendingProjectActivityAt"]
  Mark --> Due["Wait for scheduled digest"]

  NextDigest --> Due
  Due --> Scheduler["ScheduledWakeManager checks due wakes roughly hourly"]
  Scheduler --> ScheduledWake["Scheduled project-agent wake"]

  ScheduledWake --> Stale{"pendingProjectActivityAt set?"}
  Stale -->|no| Skip["Skip model run, advance scheduledWakeAt"]
  Stale -->|yes| FullRun["Load project, linked tasks, reports, run LLM"]
  FullRun --> Persist["Persist fresh report + recommendations"]
  Persist --> Clear["Clear pendingProjectActivityAt, set lastDailyWakeAt"]
```

### Project-agent state machine

```mermaid
stateDiagram-v2
  [*] --> Scheduled: project agent created
  Scheduled --> WakingNow: creation wake
  Scheduled --> WakingNow: direct project edit / manual reanalysis
  Scheduled --> PendingActivity: linked task activity recorded
  PendingActivity --> WakingNow: scheduled digest due
  Scheduled --> SkipAndReschedule: scheduled digest due and no pending activity
  SkipAndReschedule --> Scheduled: next digest scheduled
  WakingNow --> Scheduled: report persisted and pending marker cleared
```

What the digest actually does:

- every project agent gets a `scheduledWakeAt` when created
- `ScheduledWakeManager` scans for due wakes on startup and then on a periodic timer with a default one-hour check interval
- when the wake is due, `ProjectAgentWorkflow` checks whether a report already exists and whether `pendingProjectActivityAt` is still `null`
- if there is no pending activity, the workflow performs a cheap skip: it updates `lastWakeAt`, increments the wake counter, and rolls `scheduledWakeAt` forward without calling the model
- if pending activity exists, the workflow loads the project, linked tasks, and task-agent reports, runs the conversation, persists a fresh project report and deferred recommendations, clears the pending marker, records `lastDailyWakeAt`, and schedules the next digest

So the short version is:

- project creation: wake now
- direct project edit or manual reanalysis: wake now
- task churn inside the project: mark stale now, think later

That is an intentional tradeoff. The project feature is meant to summarize
meaningful change, not narrate every checkbox toggle.

## Why The Feature Looks Like This

Projects are not just "tags but bigger". They sit between category-level organization and task-level execution, and they aggregate agent outputs into something a human can scan quickly.

That requires:

- proper persistence
- strict linking rules
- grouped overview models
- filtered list state
- project health built from agent reports, freshness state, and recommendations

Without those pieces, the feature would collapse into a nice-looking list of vague nouns. With them, it becomes an actual project layer.
