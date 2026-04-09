# Daily OS Feature

The `daily_os` feature is Lotti's day-operations workspace.

It combines:

- a day plan
- planned timeline blocks
- actual recorded time
- per-category time budgets
- due-task context
- a day summary

into one screen that answers a practical question: "What is this day supposed to look like, and how is it actually going?"

## What This Feature Owns

At runtime, the feature owns:

1. the selected date plus lightweight Daily OS UI-coordination state
2. lazy day-plan reads and persisted mutations
3. unified day aggregation for timeline, budget cards, summary stats, and rating linkage
4. time-history header aggregation and backward paging
5. per-category task-card view preferences
6. category highlighting, timeline folding, active-focus helpers, and running-timer indicators

It is not just a page. It is a planning-and-feedback layer built on top of tasks, entries, ratings, and categories.

## Directory Shape

```text
lib/features/daily_os/
├── repository/
├── state/
├── ui/
│   ├── pages/
│   └── widgets/
├── util/
└── widgetbook/
```

## Architecture

```mermaid
flowchart LR
  Date["DailyOsSelectedDate"] --> Page["DailyOsPage"]
  Date --> Unified["UnifiedDailyOsDataController(date)"]
  Date --> Header["TimeHistoryHeader"]
  Date --> Stats["dayBudgetStatsProvider(date)"]

  Ui["DailyOsController"] --> TimelineUi["DailyTimeline"]
  Ui --> BudgetsUi["TimeBudgetList"]

  Unified --> PlanRepo["DayPlanRepository"]
  Unified --> DB["JournalDb"]
  Unified --> Time["TimeService"]
  Unified --> Cache["EntitiesCacheService"]
  Unified --> Notify["UpdateNotifications"]

  Unified --> TimelineData["DailyTimelineData"]
  Unified --> BudgetData["TimeBudgetProgress"]
  Unified --> Ratings["ratingIds"]

  Header --> HeaderCtl["TimeHistoryHeaderController"]
  HeaderCtl --> DB
  HeaderCtl --> Notify
  HeaderCtl --> Cache
```

The important split is:

- `UnifiedDailyOsDataController` owns the day's persisted model and derived day data
- `DailyOsController` is a thin UI-coordination layer for highlight and fold behavior
- `DailyOsSelectedDate` stands alone because the page, header, and prefetched day data all key off it directly

That separation matters because the UI does not build its day model by stitching together a pile of small providers. It asks one controller for the day and lets that controller update atomically when something changes.

## Day-Plan Lifecycle

The day plan itself has an explicit status machine in `DayPlanStatus`:

```mermaid
stateDiagram-v2
  [*] --> Draft
  Draft --> Agreed: agreeToPlan()
  Agreed --> NeedsReview: blockModified / taskRescheduled
  NeedsReview --> Agreed: agreeToPlan()
```

Those are real code-backed states:

- `draft`
- `agreed`
- `needsReview`

This matters because the Daily OS page is not just an editor. It has a lightweight commitment model:

- the plan starts as draft
- the user can agree to it
- later changes can invalidate that agreement and mark it for review

`DayPlanReviewReason` also defines `newDueTask` and `manualReset`, but Daily OS's current mutation paths only emit `blockModified` and `taskRescheduled`.

## Daily OS Page Composition

```mermaid
flowchart TD
  Open["Open Daily OS page"] --> Header["TimeHistoryHeader"]
  Header --> HeaderBits["day strip + stream chart + date row"]
  Open --> Body["RefreshIndicator + scroll view"]
  Body --> Banner["Draft / needs-review agreement banner"]
  Body --> Timeline["DailyTimeline"]
  Body --> Budgets["TimeBudgetList"]
  Body --> Summary["DaySummary"]
  Open --> FAB["DesignSystemBottomNavigationFabPadding + GameyFab -> AddBlockSheet"]
```

The page is intentionally stacked in that order:

- historical context first
- current-day agreement status
- timeline
- budgets
- summary

That gives the page a clear "past -> plan -> execution" flow instead of making the user hunt for the day model across unrelated panels.

## Unified Data Flow

`UnifiedDailyOsDataController` is the core runtime object here.

It:

- keeps itself alive across navigation
- listens to `UpdateNotifications.updateStream`
- listens to `TimeService` for the currently running timer
- returns a transient empty `DayPlanEntry` when the day has no persisted plan yet
- fetches the day plan, calendar entries, due tasks, entry links, linked parent entities, and rating IDs
- recomputes timeline data, budget progress, and synthetic zero-budget rows together
- refetches after plan mutations so derived state stays consistent

```mermaid
sequenceDiagram
  participant UI as "DailyOsPage"
  participant Unified as "UnifiedDailyOsDataController"
  participant Plan as "DayPlanRepository"
  participant DB as "JournalDb"
  participant Time as "TimeService"

  UI->>Unified: build(date)
  Unified->>Plan: getDayPlan(date)
  Unified->>DB: sortedCalendarEntries(day)
  Unified->>DB: getTasksDueOn / getTasksDueOnOrBefore(day)
  Unified->>DB: resolve links and linked parent entities
  Unified->>DB: getRatingIdsForTimeEntries(entryIds)
  Unified->>Unified: build timeline + budgets + synthetic budget rows
  Unified-->>UI: DailyOsData

  Time-->>Unified: running timer update
  Unified->>Unified: patch affected budget without full refetch

  DB-->>Unified: update notifications
  Unified->>Unified: refetch and emit fresh DailyOsData
```

That timer patch path is especially nice: when possible, the controller updates budget progress from the live timer entry instead of performing a full refetch every second.

## Day-Plan Mutation Flow

The controller surface includes mutations such as:

- `agreeToPlan()`
- `markComplete()`
- `addPlannedBlock(...)`
- `updatePlannedBlock(...)`
- `removePlannedBlock(...)`
- `pinTask(...)`
- `unpinTask(...)`
- `setDayLabel(...)`

Today's page wiring uses `agreeToPlan()` and the planned-block mutation paths directly. The rest are still part of the persisted day-plan API, even if they are not all surfaced from the current page widgets.

All of them eventually go through `_mutateDayPlan(...)` and `_saveDayPlan(...)`.

```mermaid
flowchart TD
  Mutate["User action"] --> Transform["_mutateDayPlan(...)"]
  Transform --> Review{"was plan agreed and does change require review?"}
  Review -->|yes| NeedsReview["transitionToNeedsReviewIfAgreed(...)"]
  Review -->|no| Updated["updated plan data"]
  NeedsReview --> Save["DayPlanRepository.save(...)"]
  Updated --> Save
  Save --> Refetch["Refetch all derived day data"]
  Refetch --> UI["Timeline / budgets / summary update together"]
```

That "save then refetch derived state" pattern is deliberate. It keeps the UI honest instead of letting different subpanels drift into different interpretations of the same day.

## Daily OS View State

`DailyOsController` is the thin coordination layer that sits on top of `DailyOsSelectedDate` plus the unified day data.

In practice, the behavior that is meaningfully wired today is:

- highlighted category
- expanded fold regions
- derived focus helpers such as `activeFocusCategoryId`
- running-timer category lookup for budget-card indicators

`expandedSection` and `isEditingPlan` still exist in `DailyOsState`, but they are currently more scaffold than core page behavior.

### Daily OS view state machine

There is not one giant monolithic state machine, but there are two real UI-state transitions worth documenting.

#### Timeline fold regions

```mermaid
stateDiagram-v2
  [*] --> AllCollapsed
  AllCollapsed --> RegionExpanded: toggleFoldRegion(startHour)
  RegionExpanded --> RegionExpanded: toggleFoldRegion(...)
  RegionExpanded --> AllCollapsed: resetFoldState()
```

#### Category highlighting

```mermaid
stateDiagram-v2
  [*] --> NoHighlight
  NoHighlight --> Highlighted: highlightCategory(categoryId)
  Highlighted --> NoHighlight: clearHighlight()
  Highlighted --> NoHighlight: highlight same category again
  Highlighted --> Highlighted: highlight different category
```

Those two small pieces are why the page can cross-highlight the same category between timeline and budgets, and compress dead air in the timeline, without introducing a lot of widget-to-widget spaghetti.

## Time History Header

`TimeHistoryHeaderController` builds the data for the multi-day time-history visualization.

It:

- loads a roughly 60-day rolling window around today
- aggregates daily time spent by category
- computes stacked heights for rendering
- supports incremental backward loading in 14-day chunks
- refreshes on relevant entry notifications with a throttled stream

This is a good example of the feature doing real derived-data work rather than just painting raw rows from the database.

## Task View Preferences

`TaskViewPreference` stores a per-category preference for how tasks appear in time-budget cards:

- `list`
- `grid`

That preference is persisted in `SettingsDb` under a category-specific key, which means Daily OS remembers how the user likes each category's task list to look.

## Current Constraints

- day plans are created lazily on first meaningful interaction, not on page open, to avoid unnecessary sync churn and ID conflicts
- the feature depends heavily on correct category and link data, because budgets and timeline grouping are category-centric
- the unified controller creates synthetic zero-budget rows for categories that have due tasks or recorded work but no planned blocks, so the user still sees the work even when the plan is sparse
- some due-task behavior is folded into the unified controller rather than split into a separate service, which keeps the day model coherent but also makes that controller very important

## Relationship to Other Features

- `journal` and `tasks` provide the underlying entries, task metadata, and linked work
- `ratings` contributes same-day rating linkage in the unified data model
- `categories` define the buckets that budgets and planned blocks are grouped by
- `user_activity` is used elsewhere to avoid background processing while the user is active; Daily OS itself is mostly a presentation-and-planning layer

If the tasks feature is about individual work units, Daily OS is about the day as a system.
