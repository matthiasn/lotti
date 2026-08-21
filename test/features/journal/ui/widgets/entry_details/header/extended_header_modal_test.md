# Testing the ExtendedHeaderModal

The entry `•••` menu is a two-page Wolt modal on the design system's action
modal shell (`DsActionModal`): the action list, and the speech-recognition page
an audio entry can push. It pulls in most of the entry stack, so tests need a
fair amount of scaffolding.

## Required test doubles

Register through `setUpTestGetIt()` rather than hand-rolling a container:

- `JournalDb`, `PersistenceLogic`, `UpdateNotifications` — entry reads/writes.
- `EditorStateService` — `EntryController`'s field initializers resolve it from
  `getIt`, so a missing registration fails the *build*, not an assertion.
- `LinkService` — the Link from / Link to rows.
- Riverpod: override `entryControllerProvider` (see
  `test/helpers/fake_entry_controller.dart`, which also tracks toggle calls)
  and `linkedEntriesControllerProvider`.

## What to test where

- **Rows in isolation** — `modern_action_items_test.dart`. Each `Modern*Item`
  is a thin `DsActionRow` wrapper; assert the glyph, title, tone and trailing
  contract plus the service call its tap makes.
- **Which rows appear** — `initial_modal_page_content_test.dart`. Visibility is
  resolved in the list, before the rows exist, so it is testable without
  opening a modal at all.
- **The chips** — `entry_toggle_chips_test.dart`. Starred / private / flagged
  are `DsActionToggleChip`s that write through and leave the sheet standing.
- **Page navigation** — `extended_header_modal_test.dart`, which really opens
  the modal.

## Gotchas

- **Tap the header's affordances with `.hitTestable()`.** The header rides
  Wolt's nav-bar slot and Wolt keeps the other page's copy in the tree behind
  an `IgnorePointer`, so a plain finder can match the inert one.
- **A bare `MaterialApp` has no `DsTokens`.** `DsActionRow` reads
  `context.designTokens` and throws without the app theme — use
  `resolveTestTheme()` or the shared `makeTestableWidget*` helpers.
- **`pumpAndSettle` after opening**: the modal has a real entrance animation.
