---
type: Architecture
title: Shared widgets
description: "The widgets that belong to no single feature — app-bar chrome, modal presentation, selection primitives, media lifecycle policy, the entity picker and settings scaffolding."
resource: ../../lib/widgets
tags: [widgets, shared, modals, selection, picker, media, orientation]
status: stable
generated: { by: codex/5, at: 2026-08-05T01:02:35+02:00 }
stale_after: 2027-01-11
sources:
  - id: src
    resource: ../../lib/widgets
    title: Shared widgets source
    last_modified: 2026-10-05
  - id: startup-orientation
    resource: ../../lib/main.dart
    title: App startup orientation policy
    last_modified: 2026-08-05
  - id: ios-orientations
    resource: ../../ios/Runner/Info.plist
    title: iOS-supported interface orientations
    last_modified: 2026-08-05
  - id: android-orientations
    resource: ../../android/app/src/main/AndroidManifest.xml
    title: Android large-screen orientation compatibility policy
    last_modified: 2026-08-05
---

`lib/widgets/` holds the reusable widgets that belong to no single feature.
Anything with a token-backed visual identity lives in
[the design system](../features/design_system/) instead; what remains here is
composition and app-shell chrome.

# What lives here

| Group | Contents |
|-------|----------|
| `app_bar/` | Back and glass action buttons, the sliver settings header, title bars |
| `modal/` | `ModalUtils` over `wolt_modal_sheet`, the confirmation modal, and small list/card animation widgets |
| `selection/` | Reusable selection-modal primitives and the unified toggle family |
| `settings/` | The settings page grid and detail scaffold every editor sits on |
| `picker/` | `EntityPickerSheet`, shared by categories, labels, projects and the task link pickers |
| `nav_bar/` | The bottom navigation shell and its FAB clearance wrapper |
| `media/` | The lifecycle scope that temporarily permits landscape in full-screen image viewers |
| `day_indicators/` | The `DayMark` model and the day cells, strip and track geometry goals and habits share |
| `misc/` | The sidebar activity summary and similar cross-feature pieces |

**Buttons are not here.** They all come from `DesignSystemButton` and its
relatives.

**That table is the documented subset, not the directory listing.** `lib/widgets/`
holds sixteen groups; the eight not described above — `cards/`, `charts/`,
`create/`, `date_time/`, `flags/`, `form/`, `search/`, `ui/` — are
undocumented here. Read them directly, and do not infer from this concept that a
widget has no shared home just because it is absent.

# Day indicators are the one cross-feature data figure

`day_indicators/` is the exception to "composition and chrome only": it is a
small data-visualisation vocabulary — one day square, a strip of them, the
column geometry — shared by goals and habits so a day is drawn the
same way wherever it is judged. It has its own concept:
[day indicators](day-indicators.md).

# Image viewers temporarily widen the mobile orientation policy

App startup requests portrait on iOS and Android. On iPhone and Android phones,
`ImageViewerOrientationScope` temporarily changes the preferred set to portrait
plus both landscape directions while a full-screen image viewer is mounted. It
reference-counts viewers, so closing a nested viewer cannot restore portrait
under a parent that is still visible, and it reasserts the viewer policy when
the app resumes from the background. Disposing the final scope restores
portrait. On desktop the controller is a no-op; window orientation remains a
desktop concern.

iOS must declare the three phone orientations in `Info.plist` before Flutter's
runtime preference can select between them. Android uses the same runtime
controller for portrait-only and viewer-specific sets. Because the app targets
API 36, `MainActivity` also declares Android's temporary restricted-resizability
compatibility property; without it, Android 16 ignores orientation requests on
`sw600dp` and larger displays. That property stops applying at API 37, so the
non-viewer UI must become fully adaptive before that target upgrade rather than
assuming the portrait lock can remain enforceable on large screens.

Resizable iPad windows are deliberately outside the phone-scoped lock guarantee.
iPadOS can ignore runtime orientation preferences while multitasking, and Lotti
does not set the deprecated `UIRequiresFullScreen` compatibility key because
that would restrict or rescale iPad multitasking. The viewer layout remains
responsive when iPadOS chooses another orientation.

```mermaid
stateDiagram-v2
    [*] --> PortraitOnly: app starts on iOS or Android
    PortraitOnly --> ViewerOpen: first image viewer mounts
    ViewerOpen --> ViewerOpen: nested viewer mounts or closes
    ViewerOpen --> ViewerOpen: app resumes, policy reapplied
    ViewerOpen --> PortraitOnly: final image viewer disposes
```

# Every Wolt sheet opens through one entry point

`ModalUtils` is the **only public export** of `lib/widgets/modal/`, and it is how
every adaptive sheet is presented: a draggable bottom sheet on narrow layouts, a
centred dialog on wide ones, from one call. It backs the single-page pickers and
the multi-page settings flows.

Centralizing it is what keeps the responsive contract consistent — a feature that
builds its own sheet has to re-derive the breakpoint, the insets, the barrier
behaviour and the glass footer treatment, and will drift. It is also what keeps
**Escape** working: `ModalUtils.showWoltModal` is the one call to
`WoltModalSheet.show` in `lib/`, and it wraps every page in a `ModalEscapeScope`,
without which a focused field inside a sheet swallows Escape
([modal dismissal](../conventions/modal-dismissal.md) has the mechanism).
`test/architecture/wolt_modal_entry_point_test.dart` fails on any other direct
call.

Flows whose layout genuinely differs still go through it, passing their own type
or decorator rather than calling Wolt themselves:

| Flow | What it supplies |
|------|-----|
| The shared side sheet ([`side_sheet.dart`](../../lib/widgets/modal/side_sheet.dart)) | A right-anchored, full-height **side panel** over the scrim on a wide window, a bottom sheet on a phone. `sideSheetModalType` is the responsive type; `showSideSheetPane` hosts a pane that draws its own chrome — agent internals, the goal and person agent chats. Because the pane owns its header, the host shows **no drag handle**: Wolt lays the handle over the page as an opaque hit target 48 px tall and the full sheet width, which would swallow the pane's close button. Drag to dismiss still works on the whole sheet |
| [The Daily OS planning modal](../features/daily_os_next/ui-surfaces.md) | Its own step pages, pushed with `WoltModalSheet.of(context)`, and a type from the shared `sideSheetModalType`, full height on a phone |
| [What's New](../features/whats_new.md) | One page per release, its own tall dialog type, a darker scrim and a shadowed decorator |

Every yes/no question — delete, roll back, discard — is `showConfirmationModal`,
built on the same sheet, rather than a hand-built `AlertDialog`.

# Selection primitives exist to stop duplication

The selection widgets were extracted because several modals — AI modality
selection, the Gemini thinking-mode picker, and others — had each grown their own
option row with slightly different padding, selection markers and semantics.

They now share one option anatomy, which is also what
`DesignSystemSelectionRow` builds on. See
[component contracts](../features/design_system/component-contracts.md).

# The entity picker shows one query's answer at a time

`EntityPickerSheet` is the search-and-pick body behind the category, label,
project and task-link modals. Its rows, its "create from search" row, its empty message and
what Enter acts on are all derived from **one** query — the *settled* query,
which is not necessarily what is in the field right now.

That distinction only matters for a picker whose results need loading. The
category, label and project pickers filter a list already in memory, pass no
`onQueryResolve`, and apply every keystroke immediately. The task pickers
(`TaskSearchPickerBody`) need a full-text lookup, supply the hook, and get this
instead:

```mermaid
stateDiagram-v2
    [*] --> Settled
    Settled --> Debouncing: keystroke
    Debouncing --> Debouncing: another keystroke (timer restarts)
    Debouncing --> Resolving: idle for searchDebounce
    Debouncing --> Resolving: Enter (flush)
    Debouncing --> Settled: field emptied
    Resolving --> Settled: onQueryResolve completes or throws
    Resolving --> Superseded: a newer keystroke supersedes it
    Superseded --> [*]: result discarded, never committed
    note right of Debouncing
        Screen still shows the SETTLED query's
        rows — no recompute, no resize.
    end note
```

Enter does not shortcut to `Settled`: it cancels the timer and resolves the
typed query immediately, then acts only if the sheet settled on exactly that
query. An emptied field is the one transition that skips `Resolving` outright,
because there is nothing to look up.

The rule the diagram encodes: **for a non-empty query on an asynchronous
picker, nothing on screen moves until the next answer is complete.** An empty
query and a picker with no `onQueryResolve` both apply at once and are outside
the rule. Recomputing on each keystroke against results still in flight is what
made the link modal claim "No tasks found" mid-word, withhold the create row,
and then repopulate a frame later — resizing the sheet twice per character. It
also opened a fresh Drift subscription per keystroke.

Two consequences worth knowing before changing this:

* **The create row is labelled from the settled query too.** Its label, its
  eligibility, and the rows beside it must describe the same query, or the sheet
  offers to create a name nothing has checked for duplicates.
* **Enter flushes rather than waits.** It resolves the typed query first and
  then acts, and does nothing at all if a further keystroke overtook the flush —
  acting on the older answer would commit the wrong entity.

Both the sheet and `TaskSearchPickerBody` carry their own generation counter, so
a lookup for an abandoned query cannot commit over a newer one that landed
first. The body's counter is not redundant with the sheet's: without it a stale
lookup still writes its matches into the body's fields, and the next rebuild —
for any unrelated reason — then finds them describing the wrong query and drops
the current query's results.

# The mobile navigation is app-level

`MobileNavigationLauncher` (the menu button and the docked page action), the
sidebar drawer it opens (`MobileNavigationDrawerHost`), the activity island,
the clearance contract
(`DesignSystemBottomNavigationBar.occupiedHeight`) and its FAB clearance wrapper
live here rather than in the design system, because the launcher is **an
app-level overlay floating over each tab's page stack**, not a
`Scaffold.bottomNavigationBar`. Its height contract — and the clearance any
screen-level FAB must respect — is documented in
[component contracts](../features/design_system/component-contracts.md).
