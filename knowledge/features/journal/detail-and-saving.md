---
type: Feature Module
title: Entry detail and saving
description: The two-state detail machine, Markdown-aware rich-text paste, the save path that writes twice for a task, and the date-time editor whose bounds can never desync.
resource: ../../../lib/features/journal/state/entry_controller.dart
tags: [journal, entry-controller, editor, drafts, datetime]
status: stable
generated: { by: claude-code/opus-5, at: 2026-08-15T00:00:00Z }
stale_after: 2027-02-01
sources:
  - id: controller
    resource: ../../../lib/features/journal/state/entry_controller.dart
    title: EntryController
    last_modified: 2026-08-15
  - id: editor-tools
    resource: ../../../lib/features/journal/ui/widgets/editor/editor_tools.dart
    title: Editor conversion helpers
    last_modified: 2026-08-15
  - id: datetime
    resource: ../../../lib/features/journal/ui/widgets/entry_details/entry_datetime_range.dart
    title: EntryDateTimeRange
    last_modified: 2026-07-15
  - id: editor-service
    resource: ../../../lib/services/editor_state_service.dart
    title: EditorStateService
    last_modified: 2026-06-21
---

`EntryController` is the detail-side brain for **one** entry. It loads the
`JournalEntity`, restores editor content from draft state, listens to unsaved-draft
state and to `UpdateNotifications` for external changes touching the same entry,
keeps focus and toolbar visibility in sync, routes saves to the correct
persistence path, and exposes focused mutations — task status and priority, event
stars, checklist ordering, cover art, privacy, starring, flagging, copying,
deletion.

`EditorWidget` contributes the lifecycle-bound **Primary+S** handler next to the
reusable rich-text editor, so the same command reaches `EntryController.save()`
whether the editor is on the entry page, in a journal card, or inside a task form.

# Rich-text clipboard precedence

Every live entry controller enables Lotti's Markdown-aware plain-text callback.
Flutter Quill still owns clipboard dispatch and keeps richer formats first:

```mermaid
flowchart TD
  Paste[Clipboard paste] --> HTML{HTML or explicit Markdown available?}
  HTML -->|yes| Quill[Flutter Quill converts rich flavor to Delta]
  HTML -->|no| Plain[Read text/plain]
  Plain --> Detect{Recognized Markdown syntax?}
  Detect -->|no| Verbatim[Insert ordinary text unchanged]
  Detect -->|yes| Convert[delta_markdown converts to Delta]
  Convert --> Code[Restore inline code attributes]
  Code --> Fragment[Drop synthetic newline from inline fragments]
  Fragment --> Insert[Replace selection with rich Delta]
```

The syntax gate recognizes supported block constructs (ATX headings,
blockquotes, rules, fenced code and lists) and inline constructs (emphasis,
strikeout, code and links). It deliberately does not claim ordinary prose,
`#hashtags`, arithmetic asterisks or emoji. The canonical `delta_markdown`
converter supplies the same headings, emphasis, list, quote and custom divider
representation already used when loading Markdown-only entries. Its decoder
predates Flutter Quill's inline-code attribute, so paste protects code spans
during conversion and restores them as `code: true` operations afterward,
including spans whose longer delimiters contain shorter backtick runs. Quill's
editor exposes three rendered heading sizes, so ATX levels four through six
use the third heading style; fenced-code contents are never normalized as
headings.
Inline fragments shed only the converter's synthetic document newline, while
explicit newlines and block-attributed newlines remain intact. Inline code
normalizes line endings and CommonMark's optional single outer padding space,
but preserves repeated spaces and tabs inside the code payload.

# The state machine has two real states

```mermaid
stateDiagram-v2
  [*] --> Saved: entry loaded
  Saved --> Dirty: editor draft or local mutation
  Dirty --> Saved: save succeeds
  Dirty --> Saved: discard (revert to saved text)
  Saved --> Saved: external update while clean
  Dirty --> Dirty: external update while unsaved
```

**Deletion does not produce a third state.** The controller clears its async state
to `null`, which is an *exit* from the machine rather than another node inside it.

# The save path writes twice for a task

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

The branching uses **two independent `if` blocks, not one exclusive switch**:

1. `if (entry is Task)` → `updateTask`, with **no `else`**.
2. `if (entry is JournalEvent)` → `updateEvent`, `else` →
   `updateJournalEntityText`.

Because a `Task` is not a `JournalEvent`, it falls into the trailing `else` as
well — so **a task save performs two persistence writes**: `updateTask` for the
task data and `updateJournalEntityText` for the editor text. Events save through
`updateEvent` only; every other type through `updateJournalEntityText` only.

## Behaviours that are easy to miss

- **Updating a category from the detail controller also propagates that category
  to currently linked outgoing entries.**
- Saving with `stopRecording: true` updates the text first, then stops the timer
  after a short delay.
- When an external update arrives and the entry is **not** dirty, the editor
  controller is rebuilt from the saved value.
- When the entry **is** dirty, the controller keeps the user's unsaved editor
  state instead of bluntly resetting it.
- **`discard()` is the inverse of `save()` without persisting**: it drops the
  in-memory and persisted draft, rebuilds the editor controller from the saved
  text, drops focus, hides the toolbar, and clears the dirty flag. The toolbar
  surfaces it beside Save only while there are unsaved changes.

# The start/end date-time editor

`entry_datetime_multipage_modal.dart` edits `dateFrom`/`dateTo` and commits via
`EntryController.updateFromTo`. Its Wolt modal has two reusable pages **rather
than stacking a date dialog over the editor**:

```mermaid
stateDiagram-v2
    [*] --> Overview
    Overview --> StartCalendar: activate start date
    Overview --> EndCalendar: activate end date
    StartCalendar --> Overview: Back or Done
    EndCalendar --> Overview: Back or Done
    Overview --> Persisted: Save changed valid range
    Overview --> Dismissed: Close
    StartCalendar --> Dismissed: Close
    EndCalendar --> Dismissed: Close
```

1. The **overview** shows a full-weekday date control, an optional separate end
   date, paired Start/End time wheels, endpoint-specific **Now** actions, and the
   live range status.
2. Activating either date transitions to an **in-sheet calendar page** with Back,
   Close, Today and Done.

## The bounds cannot desync

The editable model is the pure, testable `EntryDateTimeRange` — a `startDate` (day
only), `startTime`, `endTime`, and an optional `endDateOverride` — **from which
`dateFrom`/`dateTo` are derived**.

Date decomposition and recomposition retain the entry's timezone semantics,
including UTC, device-local and named zones. **Now** and **Today** read the
injectable clock and normalize it to that same timezone before changing an
endpoint, so shortcuts are deterministic in tests and cannot mix timezone kinds.

Endpoint-level **Now** preserves the opposite absolute endpoint. If *Start Now*
moves past the stored end, the model **exposes that exact inverted range as
invalid** instead of silently rolling the end into tomorrow.

The glass Save footer stays fixed while the regular Wolt page owns overflow
scrolling. Content padding reserves the footer's occupied height, and the status
reserves the next-day chip row in **both** states, so neither crossing midnight
nor exposing the chip moves the sheet. Save stays disabled until the range both
changed **and** is valid.

## Which mode an existing entry opens in

```mermaid
stateDiagram-v2
    [*] --> SharedDate: ordered bounds AND end day == start day
    [*] --> SharedDate: end day == start+1 AND end clock < start clock (plain overnight)
    [*] --> DifferentDates: otherwise (inverted, multi-day, or exact-24h same-clock next day)

    SharedDate --> SharedDate: select date / spin times / use Now
    note right of SharedDate
      one date control + two time wheels.
      end clock < start clock auto-rolls
      dateTo to the next day and shows a
      teal next-day chip (overnightAuto).
    end note

    SharedDate --> DifferentDates: toggle separate end date ON<br/>(freeze endDateOverride = current end day)
    DifferentDates --> SharedDate: toggle OFF<br/>(clear endDateOverride, end collapses onto start date)
    note right of DifferentDates
      reveals a second End date control;
      either date opens the same calendar page.
      Save is gated on dateTo >= dateFrom.
    end note
```
