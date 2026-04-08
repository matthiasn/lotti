# Tasks Tab Design-System Migration

## Summary

- Write this plan into the existing `docs/implementation_plans` directory as
  the Phase 1 migration spec.
- Treat Figma as the source of truth once the Desktop Bridge is connected; use
  the current Widgetbook task showcase only as a scaffold.
- Execute only the page migration now. Filters stay on the current model and
  controller behavior until Phase 2.

## Public Interfaces

- Add a temporary runtime config flag `enableTasksRedesignFlag`
  (`enable_tasks_redesign`) using the same plumbing pattern as the existing
  projects flag.
- Add a new root widget for `/tasks` that decides between the legacy browse
  page and the new DS browse page; keep the detail route unchanged in
  `tasks_location.dart`.
- Introduce slim production list view-model/adapter types for the tasks browse
  page; keep the current Widgetbook-only list/detail showcase models demo-only
  instead of reusing them in production.

## Phase 1

- Keep `JournalPageController` as the single source of truth for search,
  paging, sort, selection, task filters, quick-label state, project-header
  state, vector mode, and refresh behavior.
- Keep the legacy browse page alive by routing `/tasks` through a new root
  widget: flag off renders the current `InfiniteJournalPage(showTasks: true)`
  path, flag on renders a new `TasksTabPage`.
- Keep the existing infinite scroll path intact. The redesign must stay on the
  current `PagingController` and `PagedSliverList` because the list needs to
  support thousands of tasks without loading everything eagerly.
- Do not ship the Widgetbook split list/detail showcase. Extract only the
  reusable list/header/row pieces from the tasks showcase and adapt them to
  production data.
- Reuse the recent projects redesign patterns where they fit, but do not force
  the projects-page scaffold onto the task list if it would compromise the
  current infinite-scroll behavior.
- Build the new page around the existing paged task results. Group already
  loaded tasks into presentation buckets that follow the active controller sort:
  - due-date sort: due buckets such as `Due Today`, `Due Yesterday`, or exact
    due dates
  - priority sort: priority buckets
  - creation-date sort: creation-date buckets
- Preserve existing runtime behavior that is outside the visual redesign:
  - pull-to-refresh
  - search string updates
  - vector/full-text mode switching when enabled
  - quick label strip
  - project health header
  - create-task FAB and its current create-and-navigate flow
  - row tap navigation to `/tasks/:taskId`
- Keep filter behavior untouched in Phase 1. The new page's filter button opens
  the existing task filter modal/content instead of wiring the DS filter sheet
  yet.
- Before coding visual details, connect Figma Desktop Bridge, inspect the
  target task-list frame via MCP, and validate spacing, typography, row height,
  FAB placement, and active states against the live node.

## Phase 2

- Replace the legacy task filter modal with the DS filter sheet.
- Add an adapter between `JournalPageState`/`JournalPageController` and a
  production `DesignSystemTaskFilterState`.
- Decide only then how to place the current non-Figma legacy controls such as
  agent assignment and visual toggles.

## Phase 3

- Remove `enableTasksRedesignFlag`.
- Delete the legacy `/tasks` browse-page branch and any temporary migration
  adapters.
- Remove old task-list-only widgets/tests that are no longer referenced.

## Test Plan

- Add a route/root-page test proving `/tasks` switches old vs new page by flag
  while `/tasks/:taskId` still opens the existing detail page.
- Add page tests for grouped rendering, search updates, filter-button behavior,
  quick-label strip visibility, project-header visibility, FAB behavior, and
  row navigation.
- Add adapter/model tests for section grouping and the section-boundary
  behavior that keeps partial counts out of the last visible paged section.
- Keep Widgetbook tests only for extracted showcase widgets that remain valid
  after the production extraction.
- Run targeted analyzer and targeted tests for the new tasks tab, touched
  shared widgets, and task routing before broader verification.

## Assumptions

- Use the existing `docs/implementation_plans` path rather than creating a new
  `doc/` tree.
- Filters are explicitly deferred; Phase 1 does not change filter persistence
  keys, controller methods, or filter semantics.
- The temporary toggle is a runtime config flag, not a compile-time constant.
