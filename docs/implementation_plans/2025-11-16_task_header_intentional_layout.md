# Task Header — Intentional Layout & Progress Integration (2025-11-16)

## Summary

- Redesign the task details header so it feels intentional and stable, not like a wrapped row of
  developer widgets.
- Move the progress indicator into a more compact, contextually relevant position and reduce its
  visual dominance.
- Eliminate layout jumps when changing task status or resizing to narrower widths by restructuring
  the metadata layout.
- Keep all existing fields — estimate, priority, category, language, and status — but present them
  with a clearer hierarchy.
- Preserve AI actions, labels, and the AI Task Summary / checklist sections; focus changes on the
  header and metadata only.

## Goals

- Give the task details header a “Series A product” level of polish:
  - Clear visual hierarchy: title → status/progress → metadata → labels → AI summary.
  - Stable layout when status changes (e.g., In Progress → On Hold) or when text wraps.
  - Consistent visual language with task cards and settings headers.
- De-emphasize the progress bar while keeping a quick, legible progress indicator.
- Make metadata (estimate, priority, category, language, status) easy to scan and interact with.
- Maintain existing behaviors (modals, pickers, AI menu) and keep analyzer/tests at zero warnings.
- Keep the implementation incremental and well-tested: no regressions to timers, labels, or
  checklist flows.

## Non‑Goals

- No changes to the underlying task data model, persistence, or filters.
- No overhaul of AI behavior, summaries, or checklist logic.
- No changes to labels management UX beyond how labels sit relative to the header.
- No new feature flags; this is a direct visual/structural refinement.
- No changes to how timers themselves are recorded or stored.

## Current Findings (Grounded in Code)

### Structure

- Task details page:
  - `lib/features/tasks/ui/pages/task_details_page.dart`
    - Uses a `CustomScrollView` with:
      - `TaskSliverAppBar(taskId: ...)` (pinned).
      - `PinnedHeaderSliver(child: TaskTitleHeader(taskId: ...))` (pinned title band).
      - Content slivers with `TaskForm`, linked entries, etc.
  - `TaskForm` (`lib/features/tasks/ui/task_form.dart`) composes:
    - `TaskDateRow` (created date/time, star/flag, save button).
    - `TaskInfoRow` (estimate, priority, category, language, status).
    - `TaskLabelsWrapper` (labels section).
    - Optional legacy editor.
    - `LatestAiResponseSummary` (AI Task Summary card).
    - `ChecklistsWidget` (checklists card).

- App bar & progress:
  - `TaskSliverAppBar` (`lib/features/tasks/ui/task_app_bar.dart`):
    - Pinned sliver app bar with:
      - `leading`: `BackWidget`.
      - `title`: `LinkedDuration(taskId: ...)` (full-width progress bar + 2 time labels).
      - `actions`: AI popup menu, “more”/extended header modal.
  - `LinkedDuration` (`lib/features/tasks/ui/linked_duration.dart`):
    - If estimate is `Duration.zero` or missing, renders nothing.
    - Otherwise: a wide `LinearProgressIndicator` (minHeight: 5) plus a row of tabular time text (
      `progress` vs `estimate`).
    - Styled to be visually prominent across the entire app bar width.
  - `CompactTaskProgress` (`lib/features/tasks/ui/compact_task_progress.dart`):
    - Already used on task cards; compact bar (width ~50) with optional HH:MM text on desktop.
    - Uses tabular figures and has width-stability tests.

- Header title and metadata:
  - `TaskTitleHeader` (`lib/features/tasks/ui/header/task_title_header.dart`):
    - Pinned header band with app bar background and subtle elevation.
    - Cross-fades between:
      - `TitleTextField` for editing (`onSave` goes through `entryControllerProvider`).
      - A row with plain title text and an edit icon.
    - No status or progress information today.
  - `TaskDateRow` (`lib/features/tasks/ui/task_date_row.dart`):
    - Single row above metadata:
      - `EntryDatetimeWidget` (created date/time).
      - Optional star toggle and import flag toggle.
      - `SaveButton`.
  - `TaskInfoRow` (`lib/features/tasks/ui/header/task_info_row.dart`):
    - Uses `SpaceBetweenWrap` (`lib/widgets/layouts/space_between_wrap.dart`) with 5 children:
      - `EstimatedTimeWrapper` (estimate + time-recording icon).
      - `TaskPriorityWrapper`.
      - `TaskCategoryWrapper`.
      - `TaskLanguageWrapper`.
      - `TaskStatusWrapper`.
  - `TaskStatusWrapper` → `TaskStatusWidget` (
    `lib/features/tasks/ui/header/task_status_widget.dart`):
    - Column with “Status” label and colored text for the current status.
    - Tap opens a status picker modal (`TaskStatusModalContent`).

### Problems Observed

- Layout “jumping”:
  - `SpaceBetweenWrap` behaves like a `Row` with `MainAxisAlignment.spaceBetween` when everything
    fits on one line, but falls back to a wrapped layout when total width exceeds the available
    space.
  - Changing status label length (e.g., `In Progress` → `On Hold` → `Blocked`) changes
    `minRequiredWidth` and can flip the layout between:
    - “Everything on one line” vs. “wrapped into two lines”.
  - Result: visible vertical jumps when status changes; feels unintentional and jittery.

- Visual hierarchy:
  - Progress bar in the app bar is visually dominant but not the most important information at this
    moment.
  - Title, status, and key metadata are spread across multiple rows without a strong grouping:
    - Title is pinned but visually isolated.
    - Metadata row looks like a collection of individual fields instead of a cohesive, intentional
      header.
  - Labels and AI summary cards look more designed than the header above them, which amplifies the
    “developer layout” feel.

- Consistency:
  - Task cards already use `CompactTaskProgress` and `ModernStatusChip`-style chips, but the task
    details header still uses plain text and a large `LinkedDuration`.
  - Settings headers have had a modernization pass (`2025-10-24_settings_header_modernization.md`),
    but task details header hasn’t adopted those lessons yet.

## UX & Interaction Design

### 1) New Hierarchy Overview

Target hierarchy for the upper part of the task details page:

1. Navigation + actions (unchanged structure):

- Back button, AI popup, overflow menu in the sliver app bar.

2. Pinned title band (primary header):

- Task title with inline edit.
- Status chip and compact progress indicator.

3. Metadata card (secondary header):

- Created date/time, star/flag, save.
- Estimate, priority, category, language — structured and stable.

4. Labels (unchanged content, improved spacing context).
5. AI Task Summary + checklists (unchanged design and behavior).

### 2) Progress Indicator — From Wide Bar to Compact Signal

- Move progress indicator out of the attention-grabbing full-width bar in `TaskSliverAppBar` and
  integrate it into the pinned title header.
- Replace the current `LinkedDuration` usage in the app bar with either:
  - A much lighter title (e.g., app name / section label), or
  - No title content (actions and back button only), depending on what feels least busy in
    implementation.
- Use `CompactTaskProgress` inside the pinned title header:
  - Positioned near the status chip so “status + progress” read as a pair.
  - On desktop, retain “HH:MM / HH:MM” text; on mobile, the bar alone may be enough.
  - When no estimate is set, hide the progress indicator entirely (same behavior as today).

### 3) Title + Status Band (Pinned Header)

- Extend `TaskTitleHeader` to be the primary “hero” band:
- Keep the existing `AnimatedCrossFade` between edit and view modes.
- Replace the simple title row with a structured layout:
  - Left (expanded):
    - Title text (current `titleLarge` style), allowed to wrap across multiple lines (target 3–4)
      with `ellipsis` only after that, since long titles are common.
    - Edit affordance remains (icon or inline gesture).
  - Right:
    - Clickable status chip (reusing `TaskStatusWidget` logic but with modern chip visuals).
    - Compact progress indicator just below the status chip.
- Visual styling:
  - Background uses the app bar/theme surface to remain visually connected to the top chrome.
  - Slight increase in vertical padding vs. today to accommodate status + progress without feeling
    cramped.
  - Keep elevation subtle (no heavy drop shadow).

- Status chip behavior:
  - Tap opens the same status modal (`TaskStatusModalContent`) as today.
  - Uses a chip-style component, mirroring `ModernStatusChip` from task cards:
    - Icon + label.
    - Color derived from `task.data.status.colorForBrightness`.
  - Single place to update status (we will remove the status field from the metadata row to avoid
    duplication).

### 4) Metadata Card (Date + Estimate/Priority/Category/Language)

- Introduce a dedicated metadata card just below the title band:
  - New widget: `TaskHeaderMetaCard` (name up for discussion).
  - Visual treatment:
    - Use `ModernBaseCard`-like styling (surface container, rounded corners, internal padding).
    - Align left/right padding with AI summary and checklist cards for a cohesive column.

- Layout inside the card:
  1. **Top row (created + controls)**

  - Left:
    - `EntryDatetimeWidget` (created date/time), using the same monospace/tabular style.
  - Right:
    - Star toggle (if applicable).
    - Flag toggle (if applicable).
    - `SaveButton` aligned to the far right.
  - Behavior should remain identical to `TaskDateRow` today; this is a relocation and visual
    refinement.

  2. **Metadata grid (estimate, priority, category, language)**

  - Four metadata items presented as a structured grid instead of a `SpaceBetweenWrap` of standalone
    widgets:
    - Estimate (tap to open duration picker; still shows recording icon when active; when none is
      set, shows a subtle “No estimate set” pill instead of a timer value).
    - Priority (existing `ModernStatusChip` pill; opens priority picker).
    - Category (chip-like pill with proper padding/spacing; opens category picker).
    - Language (opens language picker).
  - Layout:
    - Use a responsive grid-like layout with fixed minimum item widths and consistent spacing:
      - On wider screens: 2x2 (two columns, two rows).
      - On narrow screens: items wrap into more rows, but each item remains visually intact;
        wrapping happens based on container width, not on status text.
    - Each item uses a shared `TaskMetaItem` visual:
      - Label (small, outline-colored).
      - Value (medium weight, primary text).
      - Optional icon (e.g., language flag or category icon) inline with the value.
  - Status is intentionally not part of this grid; status belongs near the title.

- The labels section stays separate below the card:
  - `TaskLabelsWrapper` remains its own block.
  - We may slightly adjust vertical spacing so the transition from metadata card → labels → AI
    summary feels intentional.

### 5) Responsiveness & Layout Stability

- Target behaviors:
  - Changing status text (e.g., In Progress → On Hold → Done) must not change the number of metadata
    rows or cause vertical jumps in the metadata card.
  - Adding/removing labels, toggling star/flag, or editing estimate/priority/category/language
    should cause only local changes, not restructure the entire header.

- Implementation-level ideas:
  - Use `CompactTaskProgress` inside a fixed-width container (already the case) next to the status
    chip.
  - In the metadata grid, set a minimum width per `TaskMetaItem` (e.g., 140–160 px) and rely on
    wrapping at that granularity.
  - Ensure timer text and estimates continue using `monoTabularStyle` for width stability (as per
    `2025-10-20_timer_tabular_figures_fix.md`).

## Implementation Plan

### A. App Bar & Progress Indicator

- File: `lib/features/tasks/ui/task_app_bar.dart`
  - Replace `title: LinkedDuration(taskId: item.id)` with a lighter alternative:
    - Option 1 (preferred): no title content; rely on the pinned title header for context.
    - Option 2: a small section label (e.g., “Task”) or compact icon, if needed to avoid an empty
      feel.
  - Keep `BackWidget`, AI popup, and overflow menu as-is.

- File: `lib/features/tasks/ui/linked_duration.dart`
  - Leave implementation intact (still used elsewhere and covered by existing tests).
  - No behavioral changes; we simply stop using it as the app bar title.

- File: `lib/features/tasks/ui/compact_task_progress.dart`
  - Reuse this widget inside the title header (see section B).
  - Ensure no regressions to existing tests that assert width stability.

### B. Pinned Title Header (Title + Status + Progress)

- File: `lib/features/tasks/ui/header/task_title_header.dart`

1. State and data

- Continue to resolve the task via `entryControllerProvider(id: widget.taskId)`.
- Retrieve `task.data.status` and `task.meta.id` for progress.

2. Layout changes

- Replace the existing “view mode” row with a more structured layout:
  - `Row` (or `LayoutBuilder` + `Row`) with:
    - `Expanded` left column:
      - Title text (`Text(title, softWrap: true, maxLines: 3, overflow: ellipsis)`).
    - Right column:
      - Status chip (clickable).
      - `SizedBox(height: 8)`.
      - `CompactTaskProgress(taskId: task.meta.id)` (hidden when estimate is zero).
- Maintain the `TitleTextField` as the “edit mode” of the `AnimatedCrossFade`.
- It is acceptable if status/progress temporarily disappear while editing; we can revisit later if
  needed.

3. Status chip integration

- Reuse `TaskStatusWidget` behavior but adapt visuals:
  - Either:
    - Extract the modal-opening logic out of `TaskStatusWidget` into a shared helper, or
    - Allow `TaskStatusWidget` to support a “chip-only” presentation mode.
- Ensure the chip is keyboard- and screen-reader accessible, with a clear semantics label (e.g.,
  “Task status: In Progress, double tap to change”).

### C. Metadata Card (Date + Estimate/Priority/Category/Language)

- File: `lib/features/tasks/ui/task_form.dart`
  - Replace the top-level `TaskDateRow` + `TaskInfoRow` stack with a new
    `TaskHeaderMetaCard(taskId: ...)` widget.
  - Keep `TaskLabelsWrapper` and the rest of the column order unchanged.

- New file: `lib/features/tasks/ui/header/task_header_meta_card.dart` (proposed name)

1. Structure

- Wrap contents in a card-style container:
  - Likely `ModernBaseCard` or a local variation that matches checklists/AI summary cards.
  - Internal padding and rounded corners consistent with the rest of the UI.

2. Top row (created + controls)

- Inline the logic currently in `TaskDateRow`:
  - `EntryDatetimeWidget`.
  - Optional star and import-flag toggles.
  - `SaveButton`.
- Keep semantics and tooltips identical; only the visual context and spacing change.

3. Metadata grid

- Recompose the wrappers:
  - `EstimatedTimeWrapper(taskId: ...)`.
  - `TaskPriorityWrapper(taskId: ...)`.
  - `TaskCategoryWrapper(taskId: ...)`.
  - `TaskLanguageWrapper(taskId: ...)`.
- Present them via a reusable `TaskMetaItem` widget:
  - Consider a shared signature like:
    -
    `TaskMetaItem({required String label, required Widget value, Widget? leadingIcon, VoidCallback? onTap})`.
  - Each wrapper can build such an item, or the card can wrap them itself.
- Use a `Wrap` or `LayoutBuilder` + `GridView`-style layout with:
  - Consistent horizontal spacing between items.
  - `runSpacing` for vertical rhythm.
  - A minimum width per item to avoid awkward truncation.

- File: `lib/features/tasks/ui/header/task_info_row.dart`
  - Either:
    - Retain as a thin wrapper on top of the new metadata grid inside the card, OR
    - Mark as deprecated and migrate call sites to the new card.
  - In either case, ensure `TaskStatusWrapper` is no longer part of this row to eliminate the layout
    jumping problem.

### D. Status Widget Refactor (If Needed)

- File: `lib/features/tasks/ui/header/task_status_widget.dart`
  - Optionally refactor to better support both:
    - A “full” presentation (label + value in a column).
    - A condensed “chip” presentation for the header.
  - Ensure the modal-opening behavior is shared and tested independently of the visual style.

- File: `lib/features/tasks/ui/header/task_status_wrapper.dart`
  - Update to use the new chip-style widget in contexts where it still appears (if any remain
    outside the header).

### E. Spacing & Visual Polish

- File: `lib/features/tasks/ui/task_form.dart`
  - Adjust vertical `SizedBox` values around the new metadata card and `TaskLabelsWrapper` so
    spacing feels intentional and consistent with AI summary / checklists cards.

- File: `lib/features/tasks/README.md`
  - Update the task details section to reflect the new header structure:
    - Mention status chip in the title band.
    - Describe the metadata card and its contents.
    - Include notes about the compact progress indicator location.

### F. Testing Strategy (Implementation Phase)

- Use MCP (`dart-mcp`) for analyzer, format, and tests as per AGENTS.md.

1. Widget tests — header and metadata

- New tests under `test/features/tasks/ui/`:
  - `task_title_header_layout_test.dart`
    - Asserts that in view mode, the title, status chip, and `CompactTaskProgress` are present and
      ordered as expected.
    - Confirms `CompactTaskProgress` disappears when no estimate is set.
  - `task_header_meta_card_test.dart`
    - Asserts that created date/time, star/flag (when applicable), and `SaveButton` render inside
      the card.
    - Verifies that all four metadata items (estimate, priority, category, language) are visible and
      tappable.
    - Ensures the number of rows in the metadata grid does not change when status changes (
      indirectly via a mocked provider).

2. Regression tests for layout stability

- Extend/augment existing tests around timers:
  - Confirm `CompactTaskProgress` within the header still exhibits width stability (possibly via a
    small additional test, or by reusing existing ones).

3. Integration tests (optional/targeted)

- Task details flow test to cover:
  - Changing status does not cause the metadata card to gain/lose rows.
  - Editing the title still works and does not regress pinned behavior.

4. Analyzer and format

- Run `dart-mcp.analyze_files` and `dart-mcp.dart_format` after changes.
- Maintain zero analyzer warnings throughout.

5. Docs & CHANGELOG

- Update `CHANGELOG.md` with a concise entry describing the improved task header UX.
- Update or add screenshots in `screenshots/` if used in documentation/user guides.

## Decisions From Plan Review

- Status placement
  - Status appears only in the pinned title band as a chip (no duplicate readout in the metadata
    card). The chip uses the same `ModernStatusChip` visual language as task cards and opens the
    existing status modal on tap.

- App bar title
  - `TaskSliverAppBar` is effectively “chrome only”: back button + AI popup + overflow actions. The
    `title` slot no longer shows `LinkedDuration` or any additional text; context comes from the
    pinned title header.

- Progress visibility
  - The compact progress indicator in the pinned title header is the single progress surface on the
    page. We reuse `CompactTaskProgress` there (bar + optional time text) and do not show a second
    bar near the estimate. A circular indicator is explicitly out of scope for this pass but can be
    explored later within the same header slot if needed.

- Metadata card styling
  - `TaskHeaderMetaCard` visually aligns with `ModernBaseCard` but uses slightly more subtle
    treatment (e.g., lower elevation/softer shadow) so the primary visual emphasis stays on the
    title band and status chip.

- Mobile density & layout
  - The metadata grid targets up to 3 columns where width allows (especially on larger phones and
    tablets). On very narrow phones we allow it to fall back to 2 columns, but the wrapping happens
    at the level of whole metadata items, not based on changing text lengths, to avoid jumps.

- No-estimate tasks
  - When a task has no estimate:
    - The compact progress indicator in the title band is hidden.
    - The estimate slot in the metadata card shows a subtle “No estimate set” pill/value instead of
      a time, making the absence intentional rather than an empty field.

## Risks & Mitigations

- **Risk:** Over-tight coupling between title header and metadata card makes future changes hard.
  - **Mitigation:** Keep `TaskTitleHeader` and `TaskHeaderMetaCard` as separate widgets with clear
    responsibilities and no cross-dependencies beyond `taskId`.

- **Risk:** Moving status into the title band breaks existing muscle memory for users who expect it
  in the metadata row.
  - **Mitigation:** Status remains highly visible near the title; consider a short entry in the
    CHANGELOG / release notes to call out the new location.

- **Risk:** New card and layout introduce subtle overflow issues on very small screens.
  - **Mitigation:** Use `Wrap`/flexible layout with minimum widths and test on small form factors;
    add targeted widget tests for narrow constraints.

- **Risk:** Reusing `CompactTaskProgress` in a new context might cause unexpected visual overlaps
  with themes.
  - **Mitigation:** Leverage existing tests and keep the component itself unchanged; only adjust its
    placement and surrounding padding.

## Process Notes

- Follow AGENTS.md discipline:
  - Prefer MCP (`dart-mcp`) for analysis, tests, and formatting.
  - Keep analyzer at zero warnings; fix root causes rather than adding ignores.
  - Update `CHANGELOG.md` and any relevant feature README(s) touched.
  - Aim for meaningful, high-coverage widget tests for each touched widget file; generally one test
    file per implementation file.

## References

### Code Pointers

- Task details & header:
  - `lib/features/tasks/ui/pages/task_details_page.dart`
  - `lib/features/tasks/ui/task_app_bar.dart`
  - `lib/features/tasks/ui/header/task_title_header.dart`
  - `lib/features/tasks/ui/task_form.dart`
  - `lib/features/tasks/ui/task_date_row.dart`
  - `lib/features/tasks/ui/header/task_info_row.dart`
  - `lib/features/tasks/ui/header/estimated_time_wrapper.dart`
  - `lib/features/tasks/ui/header/task_priority_wrapper.dart`
  - `lib/features/tasks/ui/header/task_category_wrapper.dart`
  - `lib/features/tasks/ui/header/task_language_wrapper.dart`
  - `lib/features/tasks/ui/header/task_status_wrapper.dart`
  - `lib/features/tasks/ui/header/task_status_widget.dart`
  - `lib/features/tasks/ui/compact_task_progress.dart`
  - `lib/features/tasks/ui/linked_duration.dart`
  - `lib/features/tasks/ui/labels/task_labels_wrapper.dart`
  - `lib/widgets/layouts/space_between_wrap.dart`

- Theming & shared components:
  - `lib/themes/theme.dart`
  - `lib/widgets/cards/modern_base_card.dart`
  - `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart`

### Related Implementation Plans — Tasks & Checklists

- `docs/implementation_plans/2025-10-26_task_labels_system.md`
- `docs/implementation_plans/2025-10-28_task_priority_field.md`
- `docs/implementation_plans/2025-10-31_task_labels_applicable_categories.md`
- `docs/implementation_plans/2025-11-03_task_cards_title_focus_and_bottom_padding.md`
- `docs/implementation_plans/2025-11-04_tasks_search_app_bar_label_filters_visibility.md`
- `docs/implementation_plans/2025-10-19_checklist_markdown_export.md`
- `docs/implementation_plans/2025-10-28_checklist_ui_polish.md`
- `docs/implementation_plans/2025-11-06_checklist_multi_create_array_only_unification.md`
- `docs/implementation_plans/2025-11-09_checklist_ergonomics_keyboard_focus_and_filter.md`
- `docs/implementation_plans/2025-11-09_checklist_updates_entry_directives_and_scoping.md`
- `docs/implementation_plans/2025-11-11_checklist_creation_current_entry_default.md`

### Related Implementation Plans — Header / UI / UX

- `docs/implementation_plans/2025-10-20_sync_settings_ux_overhaul.md`
- `docs/implementation_plans/2025-10-22_sync_list_pages_polish.md`
- `docs/implementation_plans/2025-10-22_timer_indicator_scroll.md`
- `docs/implementation_plans/2025-10-24_settings_header_modernization.md`
- `docs/implementation_plans/2025-10-24_ai_popup_defaults_and_mobile_filter.md`
- `docs/implementation_plans/2025-10-28_theming_selection_sync.md`
- `docs/implementation_plans/2025-10-20_timer_tabular_figures_fix.md`
- `docs/implementation_plans/2025-11-03_labels_management_alignment.md`
