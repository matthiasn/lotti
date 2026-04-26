# Per-saved-filter view persistence

A focused, end-to-end plan for the work that comes after Phase 1 (live counts).
The high-level intent: each saved filter behaves like its own "view" —
switching between filters preserves scroll position and selected task, with no
cross-talk between scopes. Counts already update live thanks to Phase 1.

This plan is a fresh, self-contained proposal — not a continuation of any
earlier roman-numeral list.

## Goals

1. **Switching saved filters keeps the user where they were.** Tap "DEV in
   progress", scroll to task #47, click into it. Switch to "P0 Urgent", do
   something. Switch back to "DEV in progress" → list is at task #47, detail
   pane shows the same task.
2. **No leakage.** Filter mutations in scope A never affect scope B. Selecting
   a task in scope A doesn't change the active task in scope B.
3. **Default scope behaves identically.** The plain "Tasks" tab (no saved
   filter) is just another scope with a stable identity. Backward compatible —
   existing persisted filter state under `TASKS_CATEGORY_FILTERS` is its key.

## Non-goals (explicitly out of scope)

- Deep-linking to a saved filter via URL — saved filters are user-private, the
  URL stays flat (`/tasks` and `/tasks/:taskId`).
- Cross-device sync of scroll/selection — those are session-local.
- Restoring scroll position across app restarts — out of scope; keep it
  in-memory.
- Mobile per-scope retention — desktop-only feature; mobile uses the existing
  single-scope behavior (Beamer push navigation already covers it).
- Changing the saved-filter shape (still `TasksFilter`, no new fields).

## Architecture

### The scope value type

```dart
@freezed
abstract class JournalPageScope with _$JournalPageScope {
  const factory JournalPageScope({
    required bool showTasks,
    String? savedFilterId, // null = default (no saved filter active)
  }) = _JournalPageScope;
}
```

Used as the family key for every per-scope provider. Equality is value-based
(freezed) so Riverpod retains the same instance for the same scope.

### State that becomes per-scope

| State | Today | New |
|---|---|---|
| Filter / search / sort / paging | `journalPageControllerProvider(bool)` (single instance per `showTasks`) | `journalPageControllerProvider(JournalPageScope)` — one instance per scope, each `keepAlive: true` |
| Persisted filter (`SettingsDb`) | Single key: `TASKS_CATEGORY_FILTERS` | Per-scope key: `TASKS_CATEGORY_FILTERS` for the default scope (unchanged), `TASKS_CATEGORY_FILTERS_<savedFilterId>` for saved scopes |
| Scroll position | A `ScrollController` owned by the `_TasksTabPageBodyState` | `scopedScrollPositionProvider(JournalPageScope)` — a `Notifier<double>` (just the offset, not the full controller) read at `pumpWidget` time |
| Selected task (desktop detail pane) | Global `NavService.desktopSelectedTaskId` (`ValueNotifier<String?>`) | `scopedSelectedTaskIdProvider(JournalPageScope)` — a `Notifier<String?>` per scope. The global notifier becomes a derived view of the active scope's notifier for backward compat. |
| Active scope | n/a | `activeJournalPageScopeProvider` — a `Notifier<JournalPageScope>` that the Tasks tab watches to decide which scope to render |

### What stays global

- `savedTaskFiltersControllerProvider` — the list of saved filters is shared
  across the app.
- `currentSavedTaskFilterIdProvider` — drives sidebar highlight; computed
  from the active scope.
- `savedTaskFilterCountsProvider` — Phase 1's count map, unchanged.
- `NavService` routing primitives — the Beamer locations don't gain scope
  awareness.

## Migration strategy

This is wide but mechanical. To keep PRs reviewable I'll ship in
**independent, individually mergeable slices**, each leaving the app in a
working state.

### Slice A — introduce the scope without changing behavior

Add `JournalPageScope`, change the family key, but every existing call site
passes `JournalPageScope(showTasks: true, savedFilterId: null)` — equivalent
to the current `(true)`. No new behavior; the goal is to migrate the API
surface in one safe PR.

- New file: `lib/features/journal/state/journal_page_scope.dart` (freezed
  value type).
- Modify: `journal_page_controller.dart` — change family parameter, derive
  persistence key from scope (when `savedFilterId` is null, use the legacy
  `TASKS_CATEGORY_FILTERS` key for backward compat).
- Update every caller: the sidebar tree, the modal save flow, `TasksTabPage`,
  `_SavedFilterTitleSuffix`, the activator, all tests.
- Tests: a regression sweep ensures nothing changes for the default scope.

**Risk: low.** No behavioral change. **Size: medium.** Many callsite updates,
but each is a one-line rename.

### Slice B — active-scope notifier and saved-filter activation flips it

Add `activeJournalPageScopeProvider`. Default value: the no-saved-filter
scope. Update `SavedTaskFilterActivator` so it switches the active scope to
the saved filter's scope instead of mutating the live filter. The
`TasksTabPage` reads the active scope and passes it to the page controller
family.

- New file: `lib/features/journal/state/active_journal_page_scope.dart`.
- Modify: `SavedTaskFilterActivator` — its `activate(SavedTaskFilter)` now
  reads/writes the active scope notifier.
- Modify: `TasksTabPage` —
  `final scope = ref.watch(activeJournalPageScopeProvider); final state = ref.watch(journalPageControllerProvider(scope));`.
- Modify: `currentSavedTaskFilterIdProvider` — reads from the active scope
  notifier instead of comparing the live filter shape against the
  saved-filter list. (This is a simplification: scope identity replaces
  fuzzy equality.)
- Persistence: when a saved-filter scope's controller builds for the first
  time, it loads from `TASKS_CATEGORY_FILTERS_<id>`. If absent, it seeds from
  the saved filter's `TasksFilter` payload. Subsequent edits (the user
  tweaks chips while in the scope) persist to the same key — they ARE the
  scope's living filter, separate from the saved filter's frozen template.

  **Open question to confirm with the user**: should edits inside a
  saved-filter scope **mutate the saved filter itself**, or do they branch
  into "scope filter" that drifts from the saved template? Two designs:

  - **Live coupling** (simpler): saved filter = source of truth; editing
    chips while in the scope updates the saved filter immediately. The
    sidebar count moves accordingly. No drift.
  - **Branched** (closer to current Save UX): saved filter is a frozen
    template; the scope's live filter starts from it but drifts on edits.
    The user explicitly hits "Save" in the modal to write the scope's
    drifted filter back to the saved filter. The sidebar count tracks the
    saved filter's template, not the scope's live edits.

  Recommended: **live coupling**, because (a) the user's mental model treats
  saved filters as "this view's settings", (b) the modal still has a Save
  button — but it now becomes "save as new" rather than "save into the
  active filter". Branched is more flexible but adds a "drift indicator" UI
  burden.

**Risk: medium.** Changes the activation semantics. **Size: small.** Few
files touched but the behavioral change needs testing.

### Slice C — per-scope scroll position

`scopedScrollPositionProvider(JournalPageScope)` returns a `double` (the last-
saved offset). The `TasksTabPage`'s scroll controller listens, debounces, and
writes through. On scope switch, the page rebuilds, attaches a new
`ScrollController` whose `initialScrollOffset` is the stored value.

- New file: `lib/features/tasks/state/scoped_scroll_position.dart`.
- Modify: `TasksTabPage`'s `_TasksTabPageBodyState` — replace
  `final _scrollController = ScrollController()` with one constructed at
  build time using `ref.read(scopedScrollPositionProvider(scope))` as the
  initial offset.
- Debounce write: 200 ms `Timer` after last scroll event (to avoid thrash).
- Tests: scroll to offset, switch scope, switch back → offset restored.

**Risk: low-medium.** Has to coexist with `infinite_scroll_pagination`'s own
restoration. Need to confirm the page controller's paging state survives
scope switches (it does — `keepAlive: true`).

**Size: small.** ~50 LOC plus tests.

### Slice D — per-scope task selection

The desktop detail pane currently reads
`NavService.desktopSelectedTaskId.value`. This becomes derived:
`scopedSelectedTaskIdProvider(JournalPageScope)` is the source of truth, and
`NavService.desktopSelectedTaskId` becomes a thin reactive bridge that
mirrors the active scope's notifier (for backward compatibility with the
Beamer routing).

- New file: `lib/features/tasks/state/scoped_selected_task_id.dart`.
- Modify: `TasksLocation` (Beamer location) — when the URL has `:taskId`,
  write to the active scope's notifier rather than the global one. When
  `:taskId` is absent, clear the notifier for that scope.
- Modify: `NavService` — `desktopSelectedTaskId` becomes a derived/synced
  `ValueNotifier` (or remove and update consumers to read the Riverpod
  provider).
- Tests: select task in scope A → switch to B → A's notifier still holds the
  id; switch back to A → the URL/UI returns to that task.

**Risk: medium.** The selection-id flow is plumbed through Beamer + several
widgets. Worth a careful audit of `NavService.desktopSelectedTaskId`
consumers.

**Size: medium.** Touches routing surface.

### Slice E — modal save flow

After A-D, "Save" in the filter modal needs to either (1) save the active
scope's current filter into a new saved-filter entity and switch to that
scope, or (2) save into the active saved filter. This is essentially what
the current Save flow does — its semantics should already align if we picked
the **live coupling** model in Slice B.

- Verify: typing a new name → `create()` + flip active scope to the new id.
- Verify: typing the existing name → `updateFilter()` (a no-op under live
  coupling, but the toast still fires for user feedback).
- Tests: end-to-end save flow with scope switching.

**Risk: low.** Mostly verification.

**Size: small.**

### Slice F — polish + cleanup

- Remove dead code: the activator's `applyBatchFilterUpdate` mutation path
  is gone; `currentSavedTaskFilterIdProvider`'s fuzzy-equality logic
  simplifies.
- Memory: add a guard against unbounded scope retention. If the user creates
  100 saved filters, do we keep 100 paging controllers alive? Probably yes
  (cheap), but worth a cap or LRU on first sign of trouble. Defer until
  measured.
- README + CHANGELOG entry (under whatever the current pubspec version is —
  ask before bumping).

## Tests per slice

Each slice ships with focused tests. The integration test that exercises the
whole loop:

> Open scope A (default), apply filter X, scroll to row 50, select task T1 →
> activate saved filter B → its persisted state loads, scroll/selection are
> at B's last positions → activate saved filter C → fresh state for C →
> switch back to B → scroll/selection match what we left → switch back to A
> → filter X, row 50, T1 still active.

This test belongs in Slice F as the capstone.

## Ordering and shipping

- A and B can ship together as one PR ("scope-keyed page controller +
  active-scope notifier + activation switches scopes"). They don't make
  sense apart.
- C and D can each ship alone after A/B.
- E and F roll up the rest.

So in practice: **3 PRs** — `(A+B)`, `(C)`, `(D+E+F)`.

## Risks called out

1. **Activation semantics drift.** The "live coupling" model means editing
   chips while a saved scope is active mutates the saved filter directly.
   The user has no "discard my edits" affordance. We could add one (a
   "Reset" button in the modal when on a saved scope) but that's UX scope
   creep. Confirm before committing.
2. **Selection-id global notifier.** `NavService.desktopSelectedTaskId` is
   read in places that haven't been fully audited. Slice D needs a thorough
   grep before changing semantics. Worst case: keep the global as a
   forwarding notifier and migrate consumers incrementally.
3. **Beamer URL contract.** Currently `/tasks/:taskId` works regardless of
   which "scope" the user is in. After Slice D, the URL is interpreted
   relative to the active scope. Refresh / cold start with `/tasks/T1` in
   the URL — which scope owns T1? Probably the default scope (no
   saved-filter context). This needs a graceful fallback: if no scope claims
   the task, route to the default scope.
4. **`SettingsDb` key proliferation.** N saved filters → N settings keys.
   They're cleaned up when the saved filter is deleted (need to wire that
   into `SavedTaskFiltersController.delete`). Easy to forget — add to the
   test plan.

## Open questions to confirm before starting

1. **Confirm "live coupling"** for activation semantics (Slice B).
2. **Confirm shipping in 3 PRs** vs. a single mega-PR.
3. **Confirm the URL-scope question** — is the cold-start fallback for
   `/tasks/T1` supposed to be the default scope?
