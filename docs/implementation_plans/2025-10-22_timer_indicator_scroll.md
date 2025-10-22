# Timer Indicator — Always Scroll To Running Entry

## Summary

- Tapping the floating timer chip should always route to the running task and align its active timer row to the top.
- Introduce a task-focused scroll intent so the behavior works even when the user is already viewing the task.
- Keep analyzer/tests green and document the behavior tweak.

## Goals

- `TimeRecordingIndicator` taps consistently resolve to `/tasks/<id>` and publish which entry to reveal.
- `TaskDetailsPage` smoothly scrolls the running timer entry into view (aligned to the top) on navigation or when already open.
- Journal-only timers continue to open the journal entry without regressions.
- Analyzer reports zero warnings; new tests cover the focus intent + scroll orchestration.

## Non-Goals

- No redesign of the timer indicator UI or styling.
- No extra highlighting/animations beyond the smooth scroll.
- No changes to the journal detail page scroll experience.

## Findings

- **Timer chip tap lacks scroll intent**  
  `TimeRecordingIndicator` currently calls `beamToNamed` with `/tasks/<id>` or `/journal/<id>`
  directly, offering no scroll hook.  
  File: `lib/widgets/misc/time_recording_indicator.dart:58`

- **Task details owns an internal controller**  
  `_TaskDetailsPageState` instantiates a private `_scrollController` with no external access for
  triggering a scroll.  
  File: `lib/features/tasks/ui/pages/task_details_page.dart:33`

- **Linked entries render without stable keys**  
  `LinkedEntriesWidget` builds `EntryDetailsWidget` rows without caller-provided keys, making
  `Scrollable.ensureVisible` impractical.  
  Files:
  - `lib/features/journal/ui/widgets/entry_detail_linked.dart`
  - `lib/features/journal/ui/widgets/entry_details_widget.dart`

- **No focus channel for already-open tasks**  
  Clicking the timer while already on `/tasks/<id>` simply rebuilds nothing; there is no shared state broadcasting “scroll to entry” intents.  
  File: (conceptual gap between `lib/widgets/misc/time_recording_indicator.dart` and `lib/features/tasks/ui/pages/task_details_page.dart`)

## Design Overview

- Introduce a lightweight `TaskFocusIntent` provider (per task id) to broadcast scroll requests.
- On timer tap, continue to call `beamToNamed('/tasks/<id>')` and also publish a `TaskFocusIntent(scrollToEntryId)` via the provider; journal fallback remains unchanged.
- Update `TaskDetailsPage` to `ref.listen` for focus intents; when one arrives, register keys for linked entries (via an opt-in builder) and schedule a single `Scrollable.ensureVisible` aligned to the top once the target widget mounts.
- Clear consumed intents so repeated taps retrigger the scroll.

## Phases and Changes

### Phase 1 — Focus Intent Channel *(P0, Pending)*

- Add `TaskFocusIntent` model + `taskFocusControllerProvider` (e.g., in `lib/features/tasks/state/`).
- Expose helpers to `publishTaskFocus(taskId, entryId, alignment)` and automatically clear the intent once observed.
- Publish the intent via `Future.microtask` (or `SchedulerBinding.instance.addPostFrameCallback`) so route changes settle before listeners react; avoid arbitrary delays.
- Ensure provider is scoped per task id and survives quick successive taps.

### Phase 2 — Task Details Listener *(P0, Pending)*

- Update `TaskDetailsPage` to listen to `taskFocusControllerProvider(id: taskId)` for new intents.
- When an intent arrives (including on first build), cache it, ensure the target widget has a key, and schedule a post-frame `Scrollable.ensureVisible` with alignment `0.0`.
- Reset the provider state after the scroll completes to allow future intents.

### Phase 3 — Keyed Linked Entries *(P0, Pending)*

- Allow `LinkedEntriesWidget` to accept an optional `entryKeyBuilder`.
- When provided (from `TaskDetailsPage`), wrap each linked entry with a `GlobalObjectKey` derived from the entry id to enable stable lookup.
- Ensure other callers (journal pages) continue to behave identically without providing the builder.

### Phase 4 — Tests & Docs *(P0, Pending)*

- **Tests**
  - Add a widget test for `TimeRecordingIndicator` confirming it publishes a focus intent when linked to a task.
  - Add a widget/integration test for `TaskDetailsPage` that injects a fake linked entry, publishes a focus intent, and asserts that the scroll alignment reaches the top after the scheduled frame.
- **Docs**
  - Update `CHANGELOG.md` and `lib/features/tasks/README.md` to describe the refined timer tap behavior.
- Run `dart format`, `dart-mcp.analyze_files`, and targeted `dart-mcp.run_tests`.

## Data Flow

Timer tap → fetch `TimeService.linkedFrom` → publish `TaskFocusIntent(taskId, entryId, alignment: 0)` and call `beamToNamed('/tasks/<id>')` → `TaskDetailsPage` listens to provider → registers keys + schedules `Scrollable.ensureVisible` → running timer entry aligns to the top.

## Files to Modify / Add

- **Modify**
  - `lib/widgets/misc/time_recording_indicator.dart`
  - `lib/features/tasks/ui/pages/task_details_page.dart`
  - `lib/features/journal/ui/widgets/entry_detail_linked.dart`

- **Add**
  - `lib/features/tasks/state/task_focus_controller.dart` (focus intent provider)
  - New test files under `test/widgets/misc/` and `test/features/tasks/ui/`

- **Docs**
  - `CHANGELOG.md`
  - `lib/features/tasks/README.md`

## Tests

- `test/widgets/misc/time_recording_indicator_test.dart` — verifies focus intent publication.
- `test/features/tasks/ui/task_details_page_scroll_test.dart` — ensures focus intent aligns target entry to top.
- Re-run analyzer + existing relevant widget tests to confirm regression-free state.

## Performance

- Negligible impact: scroll trigger runs only when user taps; additional keys are lightweight.
- No new timers or streams introduced.

## Edge Cases & Handling

- If the linked timer entry is missing (deleted/filtered), skip scroll and log in debug.
- Multiple timer taps while already on the page should reuse the cached controller and re-trigger
  scroll when necessary.
- Journal-linked timers remain routed to `/journal/<entryId>` with original behavior.

## Rollout Plan

1. Implement Phases 1–3; run analyzer/formatter and targeted tests.
2. Add tests + documentation updates (Phase 4).
3. Manual sanity check: start timer, tap indicator from another tab and while already inside task.
4. Ship once analyzer/tests pass.

## Open Questions

- None; alignment (top) and absence of extra cues confirmed with stakeholders.

## Implementation Checklist

- [ ] `taskFocusControllerProvider` introduced; timer indicator publishes focus intent.
- [ ] `TaskDetailsPage` listens for focus intent and schedules `Scrollable.ensureVisible` with alignment `0.0`.
- [ ] `LinkedEntriesWidget` supports caller-provided keys.
- [ ] Tests updated/added; analyzer + formatter run; docs/CHANGELOG updated.

## Implementation discipline

- Always ensure the analyzer has no complaints and everything compiles. Also run the formatter
  frequently.
- Prefer running commands via the dart-mcp server.
- Only move on to adding new files when already created tests are all green.
- Write meaningful tests that actually assert on valuable information. Refrain from adding BS
  assertions such as finding a row or whatnot. Focus on useful information.
- Aim for full coverage of every code path.
- Every widget we touch should get as close to full test coverage as is reasonable, with meaningful
  tests.
- Add CHANGELOG entry.
- Update the feature README files we touch such that they match reality in the codebase, not
  only for what we touch but in their entirety.
- In most cases we prefer one test file for one implementation file.
