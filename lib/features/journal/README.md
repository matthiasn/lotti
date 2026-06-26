# Journal Feature

The `journal` feature is Lotti's entry workspace layer.

Most other product features eventually end up depending on it, because this is where entries are loaded, created, edited, paged, filtered, linked, highlighted, and deleted. Even when another feature owns the domain-specific widget, the journal feature usually still owns the surrounding runtime: the page shell, the controller, the repository facade, the linked-entry plumbing, or the list/browse substrate.

It is not the whole app, but it is the closest thing the app has to a canonical entry surface.

## What This Feature Owns

At runtime, the journal feature owns:

- single-entry detail pages and the shared detail controller
- the paged journal/tasks browse controller and its persisted filter state
- full-text and vector-search orchestration for journal-style pages
- create/import entry surfaces, including clipboard and drag-and-drop entry points
- linked-entry rendering, link mutation, focus intents, and scroll highlighting
- repository helpers for common entry and link mutations

It does not own every entity-specific summary or form. Tasks, ratings, speech, AI, measurements, and projects all plug their own UI into the journal surface. The journal feature is the switchboard they plug into.

## Directory Shape

```text
lib/features/journal/
├── model/
├── repository/
├── state/
├── ui/
│   ├── mixins/
│   ├── pages/
│   └── widgets/
│       ├── create/         # entry-creation affordances
│       ├── editor/         # rich-text editor widgets
│       ├── entry_details/  # detail body + header/ subtree
│       └── list_cards/     # journal list row cards
├── util/
└── utils/
```

## Runtime Centers

```mermaid
flowchart LR
  DB["JournalDb"] --> Repo["JournalRepository"]
  DB --> PageCtl["JournalPageController"]
  FTS["Fts5Db"] --> PageCtl
  Settings["SettingsDb"] --> PageCtl
  Persist["PersistenceLogic"] --> Repo
  Persist --> EntryCtl["EntryController"]
  Notify["UpdateNotifications"] --> EntryCtl
  Notify --> PageCtl
  Editor["EditorStateService"] --> EntryCtl
  Time["TimeService"] --> EntryCtl
  Cache["EntitiesCacheService"] --> PageCtl
  Vector["VectorSearchRepository"] --> PageCtl

  Detail["EntryDetailsPage"] --> EntryCtl
  Detail --> Focus["JournalFocusController"]
  Focus --> Highlight["HighlightScrollMixin"]
  Detail --> Linked["LinkedEntriesWidget / LinkedFromEntriesWidget"]

  Browse["InfiniteJournalPage"] --> PageCtl
  Browse --> Create["CreateEntryModal / FAB flows"]
```

The feature has two real controller centers:

- [`EntryController`](state/entry_controller.dart) for one entry detail surface
- [`JournalPageController`](state/journal_page_controller.dart) for paged browse and search surfaces

Everything else is mostly glue around those two: entry-type dispatch, linked-entry composition, create/import actions, and scroll/focus behavior.

## The Core Model Boundary

The journal layer operates on `JournalEntity` variants, not on one canonical entry type.

That includes, among others:

- `JournalEntry`
- `Task`
- `JournalEvent`
- `JournalAudio`
- `JournalImage`
- `MeasurementEntry`
- `SurveyEntry`
- `WorkoutEntry`
- `HabitCompletionEntry`
- `Checklist`
- `ChecklistItem`
- `AiResponseEntry`
- `RatingEntry`

That breadth is why this feature feels large. It is not "the text note feature". It is the shared create/edit/browse substrate for a whole family of entry types.

## Detail Surface

[`entry_details_page.dart`](ui/pages/entry_details_page.dart) is the outer detail-page shell.

It composes:

- [`EntryDetailsWidget`](ui/widgets/entry_details_widget.dart) for the main entry body
- [`LinkedEntriesWithTimer`](ui/widgets/linked_entries_with_timer.dart) for outgoing linked entries
- [`LinkedFromEntriesWidget`](ui/widgets/entry_detail_linked_from.dart) for reverse links
- checklist-specific linked-from widgets when the current item is a checklist or checklist item
- media entry Actions menu items for images and audio, including
  file-manager reveal actions on desktop platforms
- a floating add action button scoped to the current entry and category and
  lifted above the shared bottom-navigation shell
- a drag-and-drop target for media import
- an AI-running overlay card at the bottom of the page

`EntryDetailsWidget` is the central type dispatcher. It renders the shared header, labels, editor, footer, and then switches into the right feature-specific summary or form for the current `JournalEntity`.

That is the real boundary: the journal feature owns the page frame and the switching logic, while other features supply some of the per-type payload UI.

## Entry Controller

[`entry_controller.dart`](state/entry_controller.dart) is the detail-side brain for one entry.

It:

- loads the current `JournalEntity`
- restores editor content from draft state when available
- listens to unsaved-draft state from `EditorStateService`
- listens to `UpdateNotifications` for external DB changes touching the same entry
- keeps focus and editor-toolbar visibility in sync with the active editor
- registers desktop `Cmd+S` hotkeys while the relevant focus nodes are active
- routes save operations to the correct persistence path
- exposes focused mutations such as task status/priority, event stars, checklist ordering, cover art, privacy, starring, flagging, copying, and deletion

### Detail State Machine

`EntryState` is a sealed union with only two real states:

```mermaid
stateDiagram-v2
  [*] --> Saved: entry loaded
  Saved --> Dirty: editor draft or local mutation
  Dirty --> Saved: save succeeds
  Dirty --> Saved: discard (revert to saved text)
  Saved --> Saved: external update while clean
  Dirty --> Dirty: external update while unsaved
```

Deletion does not produce a third `EntryState`. The controller clears its async state to `null`, which is an exit from the state machine rather than another node inside it.

### Save Path

```mermaid
sequenceDiagram
  participant UI as "Entry UI"
  participant Ctl as "EntryController"
  participant Draft as "EditorStateService"
  participant Persist as "PersistenceLogic"
  participant Notify as "UpdateNotifications"

  UI->>Ctl: edit content / metadata
  Ctl->>Draft: saveTempState(...)
  Draft-->>Ctl: unsaved stream -> dirty
  UI->>Ctl: save(...)
  opt entry is Task
    Ctl->>Persist: updateTask(...)
  end
  alt entry is JournalEvent
    Ctl->>Persist: updateEvent(...)
  else not a JournalEvent (includes Task and everything else)
    Ctl->>Persist: updateJournalEntityText(...)
  end
  Persist-->>Notify: affected IDs
  Ctl->>Draft: entryWasSaved(...)
  Ctl-->>UI: saved state + haptic feedback
```

The branching uses two independent `if` blocks rather than one exclusive switch:

- a `Task` is persisted via `updateTask` (its own `if (entry is Task)` block, with no `else`)
- the second block is `if (entry is JournalEvent) updateEvent else updateJournalEntityText`

Because a `Task` is not a `JournalEvent`, it falls into the trailing `else` as well, so a task save performs two persistence writes: `updateTask` for the task data and `updateJournalEntityText` for the editor text. Events save through `updateEvent` only; every other entity type saves through `updateJournalEntityText` only.

The controller is not trying to invent a second write model on top of the persistence layer.

A few detail-level behaviors are worth calling out because they are easy to miss:

- updating a category from the detail controller also propagates that category to currently linked outgoing entries
- saving with `stopRecording: true` updates the text first and then stops the timer after a short delay
- when an external update arrives and the entry is not dirty, the editor controller is rebuilt from the saved value
- when the entry is dirty, the controller keeps the user's unsaved editor state instead of bluntly resetting it
- `discard()` is the inverse of `save()` without persisting: it drops the in-memory and persisted draft (`EditorStateService.dropDraft`), rebuilds the editor controller from the saved text, drops focus, hides the toolbar, and clears the dirty flag. The editor toolbar surfaces it as a discard control that appears beside Save only while there are unsaved changes.

### Start/End Date-Time Editor

[`entry_datetime_multipage_modal.dart`](ui/widgets/entry_details/entry_datetime_multipage_modal.dart) edits an entry's `dateFrom`/`dateTo` and commits them via `EntryController.updateFromTo`. It is a single-page modal: one **Date** wheel over **paired Start/End time wheels**, so the date is entered once and stamped onto both timestamps rather than picked twice.

The editable model is the pure, testable [`EntryDateTimeRange`](ui/widgets/entry_details/entry_datetime_range.dart) — a `startDate` (day only) + `startTime` + `endTime` + an optional `endDateOverride` — from which `dateFrom`/`dateTo` are *derived* (they can never desync). The pinned glass bar shows a live duration (`formatRangeDuration`, multi-day aware) and disables Save until the range both changed and is valid.

`EntryDateTimeRange.fromBounds` decides which mode an existing entry opens in:

```mermaid
stateDiagram-v2
    [*] --> SharedDate: end day == start day
    [*] --> SharedDate: end day == start+1 AND end clock < start clock (plain overnight)
    [*] --> DifferentDates: otherwise (multi-day, or exact-24h same-clock next day)

    SharedDate --> SharedDate: spin date / times
    note right of SharedDate
      one Date wheel + two time wheels.
      end clock < start clock auto-rolls
      dateTo to the next day and shows a
      teal "+1 day" chip (overnightAuto).
    end note

    SharedDate --> DifferentDates: toggle "Ends on another day" ON\n(freeze endDateOverride = current end day)
    DifferentDates --> SharedDate: toggle OFF\n(clear endDateOverride; end collapses onto start date)
    note right of DifferentDates
      reveals a second End date wheel;
      dateTo decomposes independently.
      Save is gated on dateTo >= dateFrom.
    end note
```

## Browse Surface

[`infinite_journal_page.dart`](ui/pages/infinite_journal_page.dart) is the journal-tab browse page. It is hardcoded to `journalPageControllerProvider(false)` (`showTasks=false`) and is wired only into the journal route. The tasks tab has its own page widget, `TasksTabPage` in the tasks feature (`lib/features/tasks/ui/pages/tasks_tab_page.dart`), which watches `journalPageControllerProvider(true)`. What is shared between the two tabs is the controller (`JournalPageController`, keyed by `showTasks`), not the page widget.

Its job is mostly composition. The heavy lifting sits in [`journal_page_controller.dart`](state/journal_page_controller.dart).

The controller owns:

- the `PagingController`
- filter state
- search mode
- feature-flag gating for entry types and vector search
- private-entry visibility
- persisted filter state in `SettingsDb`
- update-driven refresh behavior, including retained loaded-page refreshes that
  keep visible rows mounted until replacement data resolves
- vector-search timing and distance metadata for the UI

### List Row Cards

Each browse row is rendered by [`CardWrapperWidget`](ui/widgets/list_cards/card_wrapper_widget.dart), the per-row dispatcher: images go to `ModernJournalImageCard`, tasks to `ModernTaskCard`, and every other entry type to `ModernJournalCard`. All three share one visual anatomy so the feed reads as a single system:

- a leading ~40dp **glyph tile** (`TintedTypeGlyph`) — the icon identifies the entry type, and the tile is tinted by the entry's **category** color (via `_categoryColor`), so the feed's left rail also colour-codes life-area at a glance;
- a **content-first title** — the entry's own content (note preview, task/event title, humanized metric name) as the brightest element;
- a **de-emphasized meta line**: a locale-aware relative date (`entryDateLabel`) plus an optional category dot;
- type-specific **metric chips** (`ModernStatusChip`) on their own row.

Structured types are humanized rather than surfacing storage values: health/quantitative shows `humanHealthTypeName` + a `value unit` chip (e.g. `Systolic Blood Pressure` · `122 mmHg`, never the raw `HealthDataType.*`/`HealthDataUnit.*` enum); workout shows the sport name + duration/energy/distance chips; measurement shows the measurable name + value; survey shows the instrument name + compact score chips. Checklist rows surface `done/total` progress (via `checklistCompletionControllerProvider`) with a thin progress bar; habit-completion rows resolve the habit name and show an explicit status chip (Completed / Skipped / Failed). `ModernJournalCard` is also reused on detail and linked-from surfaces, where the same anatomy renders with `showLinkedDuration` / `removeHorizontalMargin`.

### Browse and Search Flow

```mermaid
flowchart TD
  Open["Open journal/tasks page"] --> Build["JournalPageController.build(showTasks)"]
  Build --> Persisted["Load persisted filters and entry types"]
  Build --> Flags["Subscribe to feature flags and private flag"]
  Build --> Paging["Create PagingController and fetch first page"]

  Paging --> Mode{"Search mode"}
  Mode -->|fullText| FTS["FTS5 match IDs + JournalDb query"]
  Mode -->|vector| Vec["VectorSearchRepository\n(first page only)"]

  FTS --> Post["Optional post-filters:\nprojects / agent assignment"]
  Vec --> Emit["Store elapsed time,\nresult count, distances"]
  Post --> Page["Append page to controller"]
  Emit --> Page
  Updates["Throttled UpdateNotifications"] --> Refresh["Refresh if page is visible\nand affected IDs matter"]
  Refresh --> Paging
```

When a visible browse page already has rows on screen, the controller now
replaces the currently loaded page window only after the refreshed pages
resolve. That avoids the `PagingController.refresh()..fetchNextPage()` path that
would otherwise clear the list immediately and produce a visible desktop flicker
during saves or live updates, while still allowing regrouping when task ordering
changes.
For the normal offset-based path, those already-loaded pages are refreshed in
parallel; the slower sequential reload is kept only for post-filtered task
queries where project or agent filters consume raw rows before returning a
page. Visible task-row updates also bypass the extra leading-page probe and
refresh the retained page window directly.

### What The Page Controller Persists

The controller persists more than a plain search string. It stores:

- selected entry types
- category filters
- task status filters
- project filters
- label filters
- priority filters
- task sort option
- visual toggles such as creation date, due date, cover art, projects header, and vector distances
- agent-assignment filter

Tasks filter persistence is tab-aware. The controller writes to per-tab settings keys (`TASKS_CATEGORY_FILTERS` for the tasks tab, `JOURNAL_CATEGORY_FILTERS` for the journal tab).

### Search Modes

The controller supports two modes:

- `fullText`
- `vector`

Vector mode is feature-gated. If the vector-search flag is disabled while the controller is in vector mode, it falls back to full-text mode instead of leaving the UI in a dead state.

Vector search also behaves differently from normal paging:

- it bypasses the DB paging pipeline
- it only runs on the first page
- it stores elapsed time, result count, and per-entry distance values in `JournalPageState`

### Post-Filter Pagination

Two filters are not pushed directly into the main task query:

- selected projects
- agent assignment filter

When those are active, the controller fetches raw task pages from `JournalDb`, filters them in memory, and tracks a separate raw offset so pagination does not repeat or skip rows.

That is a small implementation detail with a large bug-prevention payoff.

### Sorting

Due-date sorting is done in SQL, not in memory:

- the v41 migration backfilled a denormalized `due_at` column for every task with a non-null `data.due`, regardless of status
- the partial `idx_journal_tasks_due_open` index covers the open-task subset; closed tasks stream from the priority/date task indexes
- `JournalQueryRunner` routes `TaskSortOption.byDueDate` to `JournalDb.getTasksSortedByDueDate`, a raw SQL query that orders by `CASE WHEN due_at IS NULL THEN 1 ELSE 0 END, due_at ASC, date_from DESC` with `LIMIT`/`OFFSET`

Because the ordering happens in the database against the indexed column, results are globally stable across page boundaries. The static in-memory `JournalQueryRunner.sortByDueDate` helper still exists but is exercised only by tests, not by the live query path.

## Linked Entries, Focus, and Highlighting

The journal feature owns the generic linked-entry machinery used in detail pages.

That includes:

- outgoing link lookup via [`LinkedEntriesController`](state/linked_entries_controller.dart)
- reverse-link lookup via [`LinkedFromEntriesController`](state/linked_from_entries_controller.dart)
- hidden-link, AI-entry, and flagged-only visibility toggles
- timer-aware highlighting of active linked entries
- scroll-to-entry focus intents and temporary highlight pulses

```mermaid
flowchart LR
  Intent["JournalFocusController"] --> Mixin["HighlightScrollMixin"]
  Mixin --> Scroll["Scrollable.ensureVisible with retry"]
  Scroll --> Target["EntryDetailsWidget key"]
  Target --> Temp["Temporary highlight pulse"]

  Links["LinkedEntriesController"] --> Outgoing["LinkedEntriesWidget"]
  Reverse["LinkedFromEntriesController"] --> Incoming["LinkedFromEntriesWidget"]
  Timer["TimeService active entry ID"] --> Outgoing
```

The important runtime details are:

- outgoing links are fetched from `JournalRepository.getLinksFromId(...)`
- hidden links can be included or excluded without changing the rest of the page
- the Filter & Sort modal can narrow the outgoing list to flagged entries only (`meta.flag == EntryFlag.import`); the check runs per row in `LinkedEntriesWidget` against the watched entry, so flagging or unflagging an entry updates the filtered list reactively
- outgoing links are ordered by the linked entity's editable `dateFrom`, not by link creation time, with a user-selectable direction (newest-first / oldest-first) via `LinkedEntriesSortController`, exposed as sort pills in the linked-entries Filter & Sort modal (links whose target has not yet resolved fall back to `link.createdAt`)
- `LinkedEntriesWithTimer` only reacts to active timer entry ID changes, not every timer tick
- `HighlightScrollMixin` retries scroll-to-entry until the target widget is actually mounted, then applies a temporary highlight pulse

This is one of those features that feels trivial until it breaks. Then it immediately becomes obvious why it exists.

## Create, Import, and Paste Paths

The journal feature also owns the generic entry-creation surfaces that sit above domain-specific creation logic.

The main pieces are:

- [`CreateEntryModal`](ui/widgets/create/create_entry_action_modal.dart)
- [`FloatingAddActionButton`](ui/widgets/create/create_entry_action_button.dart)
- [`create_entry_items.dart`](ui/widgets/create/create_entry_items.dart)
- [`ImagePasteController`](state/image_paste_controller.dart)

Supported entry points include:

- create text entries
- create tasks
- create events
- start audio recordings
- create timer entries when already inside a parent entry
- import images
- create screenshots
- paste images from the clipboard
- drag and drop media onto the detail page

Two integration details are worth documenting because they are easy to miss:

- image import and paste flows can trigger automatic image-analysis callbacks supplied by the AI feature
- drag-and-drop, photo-library and clipboard image imports preserve JPEG and PNG bytes; on platforms with HEIC/HEIF conversion support, high-efficiency inputs are converted to JPEG unless the HEIF metadata declares an alpha auxiliary image, in which case they are converted to PNG so transparency survives
- creating a timer from a linked context polls for the new linked entry and then publishes a focus intent so the page scrolls to the freshly created timer entry
- image and audio entries add a desktop-only file-manager reveal action to the
  existing entry Actions sheet without changing the underlying entity model

## Repository Responsibilities

[`journal_repository.dart`](repository/journal_repository.dart) is intentionally an app-facing facade, not a second persistence layer.

It handles:

- loading entries by ID
- updating category IDs
- updating entry dates
- soft-deleting journal entities
- updating full entities
- creating text entries
- creating image entries
- updating links
- removing links
- fetching outgoing linked entities, reverse-linked entities, and linked images for tasks

It delegates the actual storage and sync work to:

- `JournalDb`
- `PersistenceLogic`
- `VectorClockService`
- `OutboxService`
- `NotificationService`
- `TimeService`

## Side Effects That Matter

The journal feature looks like basic CRUD until you follow the side effects.

Some of the important ones already wired here are:

- deleting an image clears any task `coverArtId` that references it
- deleting a currently running entry stops the timer
- deleting an entry updates the badge through `NotificationService`
- updating a link emits `UpdateNotifications`
- updating a link also writes a sync outbox message with a fresh vector clock
- creating image entries can invoke higher-level callbacks such as automatic analysis

That is normal for this feature. It is the app's entry hub. Quiet side effects would be stranger than visible ones.

## Current Constraints

- the journal feature owns the shared surface, not every per-entity widget
- browse state for journal and tasks still lives in one controller because the underlying pagination and search substrate is shared
- vector search depends on the embedding stack being available and only runs as a first-page search mode
- some cross-feature behaviors, especially AI, ratings, tasks, and speech, are layered onto journal surfaces rather than reimplemented elsewhere

## Relationship To Other Features

- `tasks` adds task-specific forms, checklists, labels, priorities, and progress behavior
- `speech` adds recording and playback around `JournalAudio`
- `ratings` plugs `RatingSummary` and post-session prompts into journal detail surfaces
- `ai` adds analysis, automatic image handling, nested AI responses, and vector search infrastructure
- `sync` propagates entry and link mutations across devices

If you want to understand where an entry is created, loaded, edited, searched, linked, or deleted, start here first. Even when another feature owns the headline behavior, there is a good chance the journal feature is still holding the floorboards together.
