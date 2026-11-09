# Entity preview cards in the front agent chat

**Date:** 2026-11-09
**Status:** Phases 1–4 implemented

## Problem

When the front agent creates a task, mentions an event, or routes a segment to
the Daily OS, her reply carries only markdown links or plain list rows
(`FrontTaskList`). The user has to leave the chat to learn anything about the
entity. Other AI surfaces — Google AI overviews, ChatGPT — show rich visual
previews inline: a card with a title, metadata, and a summary that a tap opens.
Lotti should do the same.

## Goal

After every turn where the front agent references, creates, or changes an
entity, the chat surface shows a compact **entity preview card** inline. The
card gives the user enough context to decide whether to open the detail page —
and tapping it navigates there.

## Entity types

| Entity | Source of the reference | Existing rendering | Preview card shows |
|--------|------------------------|--------------------|--------------------|
| **Task** | `dispatch → new(task)`, `FrontReplyTasks`, task links in prose | `FrontTaskRow` (title, status glyph, one-liner, due, priority, category) | Cover thumbnail (when present), title, one-liner, status pill, due date, category, estimate |
| **Event** | `dispatch → new(event)`, check-in filing, event links in prose | None — only a markdown link today | Cover thumbnail, title, date/time, location, status pill, linked person, star rating |
| **Calendar block** | `dispatch → day`, day-planning modal acceptance | None | Time range, block title, linked task (when present), status |
| **Project** | `FrontReplyTasks` (kind = project), project links in prose | `_FrontProjectRow` (title only) | Title, category, task count, status |
| **Person** | `dispatch → person`, check-in filing | None — only the door card | Name, last-seen date, role/relationship |

The first implementation covers **tasks** and **events**. Projects, calendar
blocks and people follow as the data resolves.

## Architecture

### Data layer

A new sealed class `FrontEntityPreview` with subtypes per entity kind:

```
lib/features/front_agent/model/front_entity_preview.dart
```

```dart
sealed class FrontEntityPreview {
  const FrontEntityPreview({required this.entityId, required this.entityKind});
  final String entityId;
  final FrontDestinationKind entityKind;
}

class FrontTaskPreview extends FrontEntityPreview { ... }
class FrontEventPreview extends FrontEntityPreview { ... }
```

Each subtype holds the display fields the card needs — not the full domain
object, only the glance-level data. For tasks this is close to the existing
`TaskPreview` in `task_preview_provider.dart`; for events it mirrors
`EventCardData`.

### Thread integration

`FrontChatThread` gains a new map:

```dart
final Map<String, List<FrontEntityPreview>> entityPreviewsByMessageId;
```

keyed by the agent reply's message id, parallel to the existing
`closedTasksByMessageId` and `loggedTimeByMessageId`.

`FrontChatThreadBuilder` populates it by:

1. **From doors** — when a door's outcome is `FrontDoorTaskCreated`,
   `FrontDoorFiled`, or a new `FrontDoorEventCreated`, read the created
   entity's preview data and attach it to the reply that carries that door.
2. **From reply text** — when `frontReplyParts` yields `FrontReplyTasks`,
   resolve each mentioned entity's preview. This upgrades the existing task-row
   rendering with richer data (cover, estimate, one-liner).
3. **From the day door** — when the user accepts a planning change and
   `FrontDoorDayPlanned` is recorded, attach the affected block(s) as previews.

### Rendering

Two card variants, both in a new file:

```
lib/features/front_agent/ui/front_entity_preview_card.dart
```

**Compact card** (`FrontEntityPreviewCompactCard`) — a single row:
icon tile (colored by entity kind) → title + meta line → chevron.
Used for tasks in a list context (replacing or augmenting `FrontTaskRow`
when preview data is available).

**Rich card** (`FrontEntityPreviewRichCard`) — a small card with an
optional cover-image header, title, summary snippet (2 lines max), and a
metadata row (date, status, people, category). Used for events and
newly-created tasks where the agent explicitly surfaced one entity.

Both cards:
- Tap navigates via the existing `openLink` in `FrontChatThreadView`,
  which pushes the detail page on top of the chat surface for tasks, or
  closes the surface and beams for events.
- Use design-system tokens for colors, spacing, radii, and typography.
- Show live data via a provider (the entity may change between when the
  card is built and when the user taps it — the card must not go stale).

### Integration in `FrontChatPane.replyBodyBuilder`

The existing `replyBodyBuilder` (lines 381–447 of `front_chat_pane.dart`)
already interleaves `FrontReplyText` prose with `FrontTaskList` rows,
`FrontClosedTaskList`, and chart cards. Entity preview cards slot in
alongside:

```dart
// After the existing parts loop:
if (entityPreviews != null)
  for (final preview in entityPreviews)
    switch (preview) {
      FrontTaskPreview() => FrontEntityPreviewCompactCard(preview: preview, onTap: ...),
      FrontEventPreview() => FrontEntityPreviewRichCard(preview: preview, onTap: ...),
    },
```

When a reply has both task-list rows and entity previews, the previews
replace the plain rows for entities they cover (keyed by id) — no
duplicates.

### Provider

```
lib/features/front_agent/state/front_entity_preview_provider.dart
```

A `FutureProvider.family` keyed by `(FrontDestinationKind, String)` that
reads the entity from the repository and returns its preview model. The
card widgets watch this provider, so they show live data and handle the
entity being deleted (graceful fallback to a minimal "entity not found"
state).

## Interaction design

1. **Single tap** → navigate to the entity's detail page. Tasks push on
   top of the chat surface (back returns to chat). Events close the
   surface and beam to `/events/:id`.
2. **Long press** (future) → quick-action menu (change status, reschedule,
   file under).
3. **Card sections** — when a reply references multiple entities of the same
   kind, they group under a quiet section label ("Due this week",
   "Upcoming events") as the front agent's prose headings suggest.

## Visual design

The card styling follows the existing design-system vocabulary:

- **Surface**: `dsCardSurface` (the same surface as `EventSummaryCard` and
  `TaskDetailSectionCard`).
- **Border**: `tokens.radii.m` corner radius, 0.5px border in
  `tokens.colors.outline.variant`.
- **Cover image**: `EventCoverImage` for events; task cover from
  `coverImagePathProvider`. Aspect ratio capped at a compact height
  (~56–72pt) so the card stays inline-sized.
- **Typography**: title in `styles.body.medium` (500 weight), meta in
  `styles.body.small` (secondary color), summary in `styles.body.small`
  (2-line clamp).
- **Status pill**: reuse `EventStatusPill` / `StatusGlyph` + status name.
- **Icons**: category color dot, Tabler-style kind icons from the design
  system.

A precise visual design pass via Claude Design is recommended before
implementation — these token choices are a starting point, not final.

## Files to create or modify

### New files
| Path | Purpose |
|------|---------|
| `lib/features/front_agent/model/front_entity_preview.dart` | `FrontEntityPreview` sealed class and subtypes |
| `lib/features/front_agent/state/front_entity_preview_provider.dart` | Provider that resolves an entity id to its preview |
| `lib/features/front_agent/ui/front_entity_preview_card.dart` | Compact and rich card widgets |
| `test/features/front_agent/model/front_entity_preview_test.dart` | Unit tests for the model |
| `test/features/front_agent/ui/front_entity_preview_card_test.dart` | Widget tests for both card variants |

### Modified files
| Path | Change |
|------|--------|
| `lib/features/front_agent/model/front_chat_thread.dart` | Add `entityPreviewsByMessageId` map |
| `lib/features/front_agent/service/front_chat_thread_builder.dart` | Populate entity previews from doors and reply parts |
| `lib/features/front_agent/ui/front_chat_pane.dart` | Render entity preview cards in `replyBodyBuilder` |
| `lib/features/front_agent/model/front_door.dart` | Add `FrontDoorEventCreated` outcome (if events are created from doors) |
| `test/features/front_agent/service/front_chat_thread_builder_test.dart` | Test preview population |
| `test/features/front_agent/ui/front_chat_pane_test.dart` | Test card rendering in the chat |

## Scope and sequence

### Phase 1 — Task preview cards (this PR)
- `FrontEntityPreview` model with `FrontTaskPreview`
- Provider resolving task id → preview
- `FrontEntityPreviewCompactCard` widget
- Thread builder populates previews from `FrontDoorTaskCreated` doors
- `replyBodyBuilder` renders compact cards alongside existing task rows
- Tests

### Phase 2 — Event preview cards
- `FrontEventPreview` subtype
- `FrontEntityPreviewRichCard` widget (cover image, summary, people)
- Thread builder populates from doors and check-in filing
- Navigation: tap closes surface and beams to event detail
- Tests

As built: none of the event sources above existed — the router has no
`new(event)`, nothing files check-ins, and events are not in her index — so
Phase 2 adds the one the user picks: *Make it an event* on an inbox item
(offered only while Events are turned on),
which records `FrontDoorEventCreated` (Open goes to `/events/:id`, Undo
deletes the event and the item waits again). A preview's kind is its own
`FrontEntityKind { task, event }`, so `event` never becomes a routing
destination. The rich card is `LinkedEventCard` → `EventSummaryCard`, the
event card the app already draws wherever an event is linked (cover,
rating, category, date, status pill, summary, counts); people are not on
it, as they are not on that card anywhere else. Router guessing of events
(`new(event)`) stays out of scope.

### Phase 3 — Section grouping and answer enrichment
- Section labels in the reply body ("Due this week", "Upcoming events")
  derived from the front agent's prose headings
- Preview cards under "what's on my plate?" answers, replacing plain
  task-list rows with richer previews
- Calendar block previews from Daily OS integration

As built: her prompt forbids headings — her words may be read aloud — and
has a due answer be one list, so a label from her prose would never show.
The label is taken from the data instead: the window the turn's
`list_due_tasks` read (`FrontDueSection`, stored on her reply as
`dueTasks`), drawn over her first list — *Due today*, *Overdue*, *Due
through …*. Her lists are drawn as preview cards, not rows: the compact task
card gained the priority the row showed, a project is a title card under
the folder glyph until Phase 4, and `FrontTaskList` / `FrontTaskRow` are
gone. The day door records only the day, never which blocks changed, so a
planned day is previewed whole: its blocks from `currentDraftPlanProvider`,
buffers and dropped ones left out, at most five and how many more.

### Phase 4 — Additional entity types
- Project previews, person previews
- Long-press quick-action menu

As built: a project's card is the Projects list's own `ProjectRow`, its
progress counted from the project's tasks as its page counts them (done
only), re-read when the project or any of its tasks changes; it shows for a
project a tap made (`FrontDoorProjectCreated`) and for one her words list.
A person's card is the People list's own `PeopleListRow` — their face, name
and newest check-in — for a person a turn was handed to (`FrontDoorChatTurn`
on a person door); the relationship status shows on their page, not on the
row, as everywhere else they are listed. The long-press menu is on task
cards only — the plan's three actions are a task's — and each item opens the
picker the task's own page uses (`TaskMetaPickers`): *Change status…*,
*Reschedule…* (its due date) and *Move to project…* (file it under a
project, offered only when the task has a category, as on its page).

## Open questions

1. **Should previews replace `FrontTaskRow` entirely, or coexist?** The
   compact card carries more data (cover, estimate) but takes slightly
   more vertical space. Recommendation: replace when preview data is
   available; fall back to the current row when it is not (e.g. the task
   was deleted).
2. **Live data vs. snapshot?** The card should show live data (the task's
   status may change after the turn). This means watching a provider, not
   caching the preview at thread-build time. The thread builder stores the
   entity id and kind; the card widget resolves the preview.
3. **Visual design authority.** The mockups in this session are a starting
   point. A Claude Design pass with codebase integration should produce
   the final card layout before Phase 1 ships.
