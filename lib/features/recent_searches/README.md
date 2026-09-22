# Recent searches

Remembers what the user searched for, anywhere in the app, and offers each
search again from the mobile sidebar navigation's **Recents** section.

It exists for one surface. The sidebar is an experiment behind
`enable_mobile_sidebar_navigation`, and so is everything here: while that flag
is off nothing is recorded, nothing is timed and the stored list is not even
read.

## What it does for the user

- **Every section's searches in one list.** A search typed in Tasks, the
  Logbook, Projects or Habits shows up under Recents, newest first, marked
  with the glyph of the section it was run in.
- **One tap runs it again.** Tapping a row closes the sidebar, opens that
  section's list and puts the query back in its search field. Reusing a search
  moves it back to the top.
- **Searches, not keystrokes.** The app's search fields filter as you type, so
  a query counts once it has rested for a moment, or at once when it is
  submitted through the search glyph. Typing on after a pause replaces the
  fragment instead of adding a second row; a repeat moves up instead of
  doubling; the list keeps the twelve most recent.
- **Private by construction.** The list lives in the device's settings store
  and is never synced. *Clear* empties it.
- **No dead rows.** A search remembered in a section that has since been
  switched off is hidden until that section comes back — but *Clear* stays
  reachable while anything is stored, so hidden history can still be deleted.

## What it owns

The `RecentSearch` model and its storage format, the rules that decide what one
search is, the settings-backed store, the controller with its settle timer, the
Recents section widget, and the small function that runs a search again.

It does not own the search fields or what a query does to a list. Each field
reports to the controller from its own `onChanged` and submit callbacks, and
running a search again hands the query to the controller that already owns
that list's search — `JournalPageController` for Tasks and the Logbook,
`ProjectsFilterController`, `HabitsController`. Nor does it own the sidebar:
the app shell decides which sections are offered and hosts the section in the
sidebar's `belowDestinations` slot.

Adding a search surface is one `RecentSearchSurface` value, its root path in
`recent_search_opener.dart`, and one recording call at the new field.

## Where the code lives

```text
lib/features/recent_searches/
├── domain/recent_search.dart            model, surfaces, storage format
├── domain/recent_search_list.dart       what counts as one search
├── state/recent_searches_repository.dart
├── state/recent_searches_controller.dart
├── ui/recent_searches_section.dart
└── ui/recent_search_opener.dart
```

## How it works

The recording rules, the flag gate and its three states, the settle timer's
lifecycle and the gotchas are in the knowledge bundle:

**→ [knowledge/features/recent_searches.md](../../../knowledge/features/recent_searches.md)**
