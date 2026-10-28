# History

Remembers every task, entry, project, event, person, dashboard and habit the
user opened, and lets them go back to one from a list that searches and
filters by time.

## What it does for the user

- **One list of where they have been.** Newest first, each row shows the
  item's title as it reads **now** — a task renamed since, or titled only
  after it was first opened, shows its current name — with the section it
  lives in and when it was opened ("Yesterday, 3:45 PM").
- **Opens from anywhere on desktop.** ⌘Y on macOS (⌘H is the system's Hide),
  Ctrl+H on Linux and Windows, *View → History* in the macOS menu bar, or the
  command palette. It opens as a panel over the app behind the shared dimmed
  scrim; Escape, the close button or a tap on the scrim dismisses it.
- **Back in one tap.** Tapping a row closes the panel and navigates to the
  item. A row whose item was deleted (or is private while private entries are
  hidden) says so and goes nowhere.
- **Search and time filters.** The search field matches every word against
  current titles, in any order. The time filter offers the last 7, 30 or 90
  days, all time, or a custom first-to-last day picked with two date pickers.
- **Loads as it scrolls.** Twenty rows at a time.
- **Removing is for good.** The trash button asks first, then deletes the
  visit outright; the item itself is untouched.
- **Private by construction.** The log lives in `history.sqlite` in the
  profile's own folder: never synced, kept per profile (the demo world has its
  own), included in profile backups.

## What it owns

The `HistoryEntry` and `HistoryTarget` models and the route-to-entity rules,
the `HistoryFilter` (query and time window), the `HistoryService` that appends,
pages and deletes, the `HistoryTitleResolver` that reads current titles, the
`HistoryRecorder` that turns navigation into visits, the page's controller, and
the page itself.

It does not own navigation or storage plumbing. It **watches** `NavService` —
the tab delegates and the desktop detail selections — and beams back through
it. The `HistoryDb` database lives in `lib/database/` with the other stores;
the composition root registers it and binds `historyDbProvider`. The app shell
starts the recorder and owns the `openHistory` command handler; the keyboard
feature owns the command's identity and bindings.

## Where the code lives

```text
lib/database/history_db.{drift,dart}          the append-only table
lib/features/history/
├── domain/history_entry.dart                 kinds, targets, route rules, rows
├── domain/history_filter.dart                query terms and time windows
├── state/history_service.dart                record, page, delete
├── state/history_title_resolver.dart         current titles from the journal
├── state/history_recorder.dart               navigation → visits
├── state/history_controller.dart             the open page's state
├── state/history_providers.dart
├── ui/history_page.dart                      the panel and showHistoryModal
└── ui/history_timestamp.dart                 "Yesterday, 3:45 PM"
```

## How it works

What counts as a visit, how search pages over live titles, and the controller's
load states are in the knowledge bundle:

**→ [knowledge/features/history.md](../../../knowledge/features/history.md)**
