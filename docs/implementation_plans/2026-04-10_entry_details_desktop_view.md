# Entry Details Desktop View — Implementation Plan

**Date:** 2026-04-10
**Status:** Draft
**Branch:** `feat/entry_details_ds`

## Context

The entry details view (right pane in the desktop three-column layout) is being rebuilt desktop-first
before touching the mobile implementation. The new desktop interface introduces a multi-column layout
with subsection filtering, a redesigned task header, AI summary section, collapsible description, and
an integrated time tracker — all matching the Figma design system.

The legacy entry details view (`EntryDetailsWidget`, `TaskForm`, `TaskDetailsPage`) remains in place
for mobile users. Only once the desktop version is stable will we migrate mobile.

**Guiding principles:**
- Desktop-first: build for ≥960px first, adapt mobile later.
- Component-driven: build/validate each section in Widgetbook before integration.
- No dependencies from new code to old code (per AGENTS.md).
- Design-system tokens mandatory for all visual values.

---

## Phase 0: Widgetbook Audit & Gap Analysis

### 0.1 — Audit Existing Components Against Figma

Systematically compare the Figma entry details design against existing Widgetbook stories and
production widgets. For each section of the new design, classify as: **Reuse** (exists and matches),
**Modify** (exists but needs changes), or **New** (must be built from scratch).

| Figma Section | Existing Widget(s) | Status | Notes |
|---------------|-------------------|--------|-------|
| **Task Header** (title, priority, project) | `TaskTitleHeader`, `TaskCompactAppBar`, `TaskExpandableAppBar` | Modify | Current header is an app bar; new design is an inline card with priority badge, project pill, and tags row |
| **Priority Badge** (P1, P2, etc.) | `TaskBrowseListItem` shows priority icon | Modify | Need standalone badge widget; list item has the icon but not as a reusable component |
| **Tags/Labels Row** (Work, Bug fix, Release blocker) | `EntryLabelsDisplay`, `DesignSystemChip` | Modify | Labels exist but styling needs alignment with Figma chip variants (outlined vs filled) |
| **Jump to Section Sidebar** | — | **New** | No equivalent exists; needs a vertical nav with icon+label links and scroll anchoring |
| **AI Task Summary Card** | `AiResponseSummary`, showcase `aiSummary` field | Modify | Summary data exists; need a card container with "Read more" toggle matching Figma |
| **Task Description Card** | `EditorWidget` (Flutter Quill) | Modify | Editor exists; need collapsible card wrapper with chevron toggle and overflow menu |
| **Time Tracker Section** | `TimeRecordingIcon`, `DurationWidget`, time entry widgets | Modify | Components exist but need composition into the new card layout with "Track time" button |
| **Bottom Action Bar** (camera, settings, mic, link icons) | Various FABs and action buttons | Modify | Individual actions exist; need horizontal toolbar composition |
| **Cover Image / Hero** | `TaskExpandableAppBar` with 16:9 image | Reuse | Existing SliverAppBar approach works; may need non-sliver variant for the detail pane |
| **Status Selector** (Open, Blocked, etc.) | `TaskStatusModal` (recently redesigned) | Reuse | Recently rebuilt in #2921 |
| **Due Date Pill** | `DueDateChip` in task browse item | Modify | Exists in list context; extract as standalone for header |
| **Project Affiliation** | Project name in `TaskForm` | Modify | Shown as text; Figma shows it as a subtle pill with folder icon |

### 0.2 — Identify Misalignments

**Strategy for resolving misalignments:**

1. **Token audit**: For each Figma section, extract the design tokens (colors, spacing, radii,
   typography) from Figma using the MCP `get_variable_defs` tool. Cross-reference against
   `assets/design_system/tokens.json` → `design_tokens.g.dart`. Flag any tokens present in Figma
   but missing from the generated file.

2. **Visual diff**: Use Figma MCP `get_screenshot` to capture each section. Compare against
   Widgetbook screenshots of corresponding components. Document pixel-level differences.

3. **Component mapping**: Use `get_design_context` to extract component structure from Figma nodes.
   Map each Figma component to its Flutter counterpart. Identify structural mismatches (e.g., Figma
   uses a card container that Flutter doesn't have yet).

4. **Resolution priority**: Fix token gaps first (they cascade to all components), then structural
   mismatches, then visual polish.

### 0.3 — Deliverable

Create a spreadsheet/table in this plan (update after audit) documenting:
- Every Figma component → Flutter widget mapping
- Missing tokens
- Estimated effort per component (S/M/L)

---

## Phase 1: Architecture & Routing

### 1.1 — Desktop Detail View Scaffold

Create the new desktop entry details container that will host all detail sections.

**New file:** `lib/features/tasks/ui/widgets/desktop_entry_detail_view.dart`

This widget receives a task ID and composes the full detail pane:

```
┌──────────────────────────────────────────────────────┐
│  Hero Image (optional, 16:9)                          │
├──────────┬───────────────────────────────────────────┤
│ Jump to  │  Task Header                              │
│ Section  │  ─────────────────────────────────────────│
│          │  AI Summary Card                          │
│ ○ Timer  │  ─────────────────────────────────────────│
│ ○ Todo   │  Task Description Card                    │
│ ○ Audio  │  ─────────────────────────────────────────│
│ ○ Images │  Time Tracker Section                     │
│ ○ Linked │  ─────────────────────────────────────────│
│          │  Todo / Checklist Section                  │
│          │  ─────────────────────────────────────────│
│          │  Audio Section                            │
│          │  ─────────────────────────────────────────│
│          │  Images Section                           │
│          │  ─────────────────────────────────────────│
│          │  Linked Items Section                     │
├──────────┴───────────────────────────────────────────┤
│  Bottom Action Bar                                    │
└──────────────────────────────────────────────────────┘
```

### 1.2 — Routing: Desktop vs Mobile

**Current routing architecture** (Beamer-based):

- `TasksRootPage` already checks `isDesktopLayout(context)` (960px breakpoint).
- Desktop: shows `Row` with 540px list pane + expanded detail pane.
- Mobile: shows only `TasksTabPage`; detail pushes as full-screen route.

**Change required:**

In `TasksRootPage`, swap the desktop detail pane from the legacy `TaskDetailsPage` to the
new `DesktopEntryDetailView`:

```dart
// lib/features/tasks/ui/pages/tasks_root_page.dart
// CURRENT (desktop branch):
Expanded(child: TaskDetailsPage(itemId: selectedId))

// NEW (desktop branch):
Expanded(child: DesktopEntryDetailView(taskId: selectedId))
```

Mobile routing remains untouched — `TasksLocation` still pushes `TaskDetailsPage` for
`/tasks/:taskId` on mobile.

**No new routes needed.** The desktop detail view is rendered inline (not routed), controlled
by `NavService.desktopSelectedTaskId`.

### 1.3 — Feature Flag (Optional)

If we want a safety net during development, add a config flag `kUseDesktopEntryDetails` in
`consts.dart` to toggle between legacy and new desktop detail view. Remove once stable.

---

## Phase 2: Component Development (Bottom-Up)

Build each section as an independent widget with its own Widgetbook story and tests.
Order: smallest/most reusable components first, then composed sections.

### 2.1 — Priority Badge Widget

**New file:** `lib/features/tasks/ui/widgets/detail/priority_badge.dart`

A compact badge showing P0–P3 with appropriate color coding. Extract the priority icon logic
from `TaskBrowseListItem` into a reusable widget.

- **Widgetbook story:** Show all priority levels (P0 critical, P1 high, P2 medium, P3 low)
- **Tests:** Renders correct label and color for each priority level

### 2.2 — Project Affiliation Pill

**New file:** `lib/features/tasks/ui/widgets/detail/project_affiliation_pill.dart`

A subtle pill showing folder icon + project name. Uses `tokens.colors.text.mediumEmphasis`
and `tokens.radii.badgesPills`.

- **Widgetbook story:** With/without project name
- **Tests:** Renders project name, handles null project

### 2.3 — Due Date Pill

Extract from `TaskBrowseListItem`'s due date chip into a standalone widget.

**New file:** `lib/features/tasks/ui/widgets/detail/due_date_pill.dart`

- **Widgetbook story:** Various dates, overdue state
- **Tests:** Formatting, overdue visual treatment

### 2.4 — Section Navigation Sidebar ("Jump to Section")

**New file:** `lib/features/tasks/ui/widgets/detail/section_nav_sidebar.dart`

A vertical list of icon+label buttons. Each button scrolls the main content to the
corresponding section using `ScrollController.animateTo()` with `GlobalKey`-based
position lookup.

Sections (conditionally shown based on content availability):
- Timer (clock icon)
- Todo (checkbox icon)
- Audio (waveform icon)
- Images (image icon)
- Linked (link icon)

**State:** A `ValueNotifier<String?>` tracks the currently visible section (updated via
`ScrollController` listener and section `GlobalKey` positions).

- **Widgetbook story:** All sections visible, some sections hidden
- **Tests:** Tap navigates to section, active state highlights correctly

### 2.5 — AI Summary Card

**New file:** `lib/features/tasks/ui/widgets/detail/ai_summary_card.dart`

A card with:
- "AI Task Summary" header with AI icon
- Summary text (truncated to ~3 lines by default)
- "Read more" / "Read less" toggle button
- Uses `tokens.colors.surface.enabled` background, `tokens.radii.sectionCards` radius

Data source: `AgentReportEntity` via existing `agentRepository.getLatestTaskReport(taskId)`.

- **Widgetbook story:** Short summary, long summary (truncated), expanded state
- **Tests:** Truncation behavior, toggle state, empty/null summary handling

### 2.6 — Collapsible Description Card

**New file:** `lib/features/tasks/ui/widgets/detail/collapsible_description_card.dart`

A card container wrapping the existing `EditorWidget` with:
- "Task description" header
- Collapse/expand chevron toggle
- Overflow menu (three-dot) for edit/copy actions
- Collapsed state shows first ~4 lines with fade-out

- **Widgetbook story:** Collapsed, expanded, empty description
- **Tests:** Toggle behavior, menu actions

### 2.7 — Time Tracker Card

**New file:** `lib/features/tasks/ui/widgets/detail/time_tracker_card.dart`

Composes existing time-tracking widgets into the new card layout:
- Header: "Time Tracker" + elapsed time display (e.g., "11m 38s")
- Expand/collapse toggle
- "Track time" action button (uses existing `TimeService`)
- List of time entries when expanded

- **Widgetbook story:** Recording active, idle, with history
- **Tests:** Start/stop tracking interaction, time display formatting

### 2.8 — Desktop Task Header

**New file:** `lib/features/tasks/ui/widgets/detail/desktop_task_header.dart`

Composes the sub-components from 2.1–2.3 into the full header layout:

```
┌─────────────────────────────────────────────────────┐
│  Task Title                        🔴 P1    ⋮       │
│  📁 Project Name                                     │
│  [Work] [Due: Apr 1, 2026]                          │
│  ┌─────────┐ ┌───────────────┐ ┌─────────────────┐  │
│  │ Bug fix  │ │Release blocker│ │                 │  │
│  └─────────┘ └───────────────┘ └─────────────────┘  │
│                                        ○ Open ↕     │
└─────────────────────────────────────────────────────┘
```

- **Widgetbook story:** Full header with all metadata, minimal header (no labels/project)
- **Tests:** All sub-components render, status selector triggers callback

### 2.9 — Bottom Action Bar

**New file:** `lib/features/tasks/ui/widgets/detail/bottom_action_bar.dart`

Horizontal toolbar with icon buttons:
- Track time (primary action, wider)
- Settings/filter
- Camera/image
- Microphone/audio
- Link/attach

Uses `tokens.colors.surface.enabled` background, fixed to bottom of detail pane.

- **Widgetbook story:** All actions, disabled states
- **Tests:** Each button triggers correct callback

---

## Phase 3: Layout Composition

### 3.1 — Desktop Entry Detail View Assembly

Compose all Phase 2 widgets into `DesktopEntryDetailView`:

```dart
// Simplified structure
Row(
  children: [
    // Left: Jump to section sidebar (fixed width ~80px)
    SectionNavSidebar(
      sections: visibleSections,
      activeSection: activeSection,
      onSectionTap: scrollToSection,
    ),
    // Right: Scrollable content
    Expanded(
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                // Hero image (conditional)
                if (hasCoverImage) SliverToBoxAdapter(child: HeroImage(...)),
                // Task header
                SliverToBoxAdapter(key: headerKey, child: DesktopTaskHeader(...)),
                // AI Summary
                SliverToBoxAdapter(key: aiKey, child: AiSummaryCard(...)),
                // Description
                SliverToBoxAdapter(key: descKey, child: CollapsibleDescriptionCard(...)),
                // Time Tracker
                SliverToBoxAdapter(key: timerKey, child: TimeTrackerCard(...)),
                // Todo/Checklist
                SliverToBoxAdapter(key: todoKey, child: ChecklistSection(...)),
                // Audio entries
                SliverToBoxAdapter(key: audioKey, child: AudioSection(...)),
                // Images
                SliverToBoxAdapter(key: imagesKey, child: ImagesSection(...)),
                // Linked items
                SliverToBoxAdapter(key: linkedKey, child: LinkedItemsSection(...)),
              ],
            ),
          ),
          // Bottom action bar (fixed)
          BottomActionBar(...),
        ],
      ),
    ),
  ],
)
```

### 3.2 — Widgetbook Showcase

**New file:** `lib/features/tasks/ui/widgets/desktop_entry_detail_showcase.dart`

Full-page Widgetbook story showing the assembled detail view with mock data.
Use the existing `TaskListDetailMockData` patterns for consistent sample data.

**New file:** `lib/features/tasks/widgetbook/desktop_entry_detail_widgetbook.dart`

Register the showcase in widgetbook with multiple use cases:
- Task with all sections populated
- Minimal task (title only, no linked items)
- Task with active time recording
- Task with long AI summary (tests truncation)

### 3.3 — Integration with TasksRootPage

Wire `DesktopEntryDetailView` into the desktop layout branch of `TasksRootPage`.
The three-column layout becomes:

```
┌──────────────┬────────────────────┬──────────────────────────────┐
│  Navigation  │    Task List       │      Task Details             │
│  Sidebar     │    (540px)         │      (expanded)               │
│  (320px)     │                    │                               │
│              │                    │                               │
│  from        │  from              │  DesktopEntryDetailView       │
│  beamer_app  │  TasksTabPage      │  (new)                        │
│              │                    │                               │
└──────────────┴────────────────────┴──────────────────────────────┘
```

Note: The 320px navigation sidebar is rendered by `AppScreen` in `beamer_app.dart`,
not by `TasksRootPage`. So `TasksRootPage` only manages the list + detail split.

---

## Phase 4: State Integration

### 4.1 — Entry Controller Wiring

The existing `entryControllerProvider(id: taskId)` already provides all task data
(title, description, labels, linked entries, status, priority, etc.). Wire each
detail section widget to read from this provider.

### 4.2 — Section Scroll Tracking

Create a provider or controller that:
- Holds `GlobalKey` references for each section
- Listens to `ScrollController` position changes
- Computes which section is currently in viewport (for sidebar active state)
- Exposes `scrollToSection(String sectionId)` method

**New file:** `lib/features/tasks/state/detail_section_scroll_controller.dart`

### 4.3 — AI Summary Provider

Reuse the existing `AgentRepository.getLatestTaskReport(taskId)` via a new Riverpod provider
that exposes the summary text and "read more" expansion state.

**New file:** `lib/features/tasks/state/task_ai_summary_provider.dart`

### 4.4 — Time Tracker State

Reuse existing `TimeService` and `TimeRecordingIcon` stream. The new `TimeTrackerCard`
subscribes to the same `TimeService.getStream()` for recording state.

---

## Phase 5: Testing

### 5.1 — Unit Tests

| Provider/Controller | Test File | Key Assertions |
|--------------------|-----------|----|
| `detailSectionScrollController` | `test/features/tasks/state/detail_section_scroll_controller_test.dart` | Scroll-to-section calculates correct offset; active section updates on scroll |
| `taskAiSummaryProvider` | `test/features/tasks/state/task_ai_summary_provider_test.dart` | Returns summary from agent report; handles null/empty |

### 5.2 — Widget Tests

One test file per new widget, following `test/` mirror structure:

| Widget | Test File |
|--------|-----------|
| `PriorityBadge` | `test/features/tasks/ui/widgets/detail/priority_badge_test.dart` |
| `ProjectAffiliationPill` | `test/features/tasks/ui/widgets/detail/project_affiliation_pill_test.dart` |
| `DueDatePill` | `test/features/tasks/ui/widgets/detail/due_date_pill_test.dart` |
| `SectionNavSidebar` | `test/features/tasks/ui/widgets/detail/section_nav_sidebar_test.dart` |
| `AiSummaryCard` | `test/features/tasks/ui/widgets/detail/ai_summary_card_test.dart` |
| `CollapsibleDescriptionCard` | `test/features/tasks/ui/widgets/detail/collapsible_description_card_test.dart` |
| `TimeTrackerCard` | `test/features/tasks/ui/widgets/detail/time_tracker_card_test.dart` |
| `DesktopTaskHeader` | `test/features/tasks/ui/widgets/detail/desktop_task_header_test.dart` |
| `BottomActionBar` | `test/features/tasks/ui/widgets/detail/bottom_action_bar_test.dart` |
| `DesktopEntryDetailView` | `test/features/tasks/ui/widgets/desktop_entry_detail_view_test.dart` |

### 5.3 — Widgetbook Tests

One test file per widgetbook story to ensure stories build without errors:

| Story | Test File |
|-------|-----------|
| Desktop entry detail | `test/features/tasks/widgetbook/desktop_entry_detail_widgetbook_test.dart` |

### 5.4 — Integration Testing

- Verify desktop layout renders three columns at ≥960px
- Verify mobile layout still routes to legacy `TaskDetailsPage`
- Verify section navigation scrolls correctly
- Verify time tracking starts/stops from the new detail view

---

## Phase 6: Polish & Validation

### 6.1 — Figma Alignment Pass

Use Figma MCP tools to perform a final visual comparison:
1. `get_screenshot` of each Figma section
2. Compare against Widgetbook renders
3. Fix spacing, color, typography discrepancies

### 6.2 — Accessibility

- Ensure all interactive elements have semantic labels
- Verify keyboard navigation through sections
- Test with screen reader

### 6.3 — Performance

- Profile scroll performance with large linked entry lists
- Ensure `SectionNavSidebar` scroll listener doesn't cause excessive rebuilds
- Verify no unnecessary provider rebuilds in detail sections

### 6.4 — Final Checklist

- [ ] `make analyze` → zero warnings
- [ ] All new widget tests pass
- [ ] Widgetbook stories render correctly
- [ ] Desktop three-column layout works at 960px+
- [ ] Mobile still uses legacy detail view
- [ ] Design tokens used throughout (no hardcoded values)
- [ ] Localization: all new user-visible strings in ARB files
- [ ] CHANGELOG updated
- [ ] Feature README updated

---

## Implementation Sequence

```
Phase 0 (Audit)          ── do first, informs all subsequent work
  0.1 Component audit     ── map Figma → Flutter
  0.2 Token gap analysis  ── identify missing design tokens
  0.3 Document findings   ── update this plan

Phase 1 (Architecture)   ── can start in parallel with Phase 0
  1.1 Detail view scaffold
  1.2 Routing switch       ── depends on 1.1
  1.3 Feature flag (optional)

Phase 2 (Components)     ── depends on Phase 0 findings
  2.1–2.3 Small widgets    ── parallel, independent
  2.4 Section sidebar      ── independent
  2.5–2.7 Card sections    ── parallel, independent
  2.8 Desktop header       ── depends on 2.1–2.3
  2.9 Bottom action bar    ── independent

Phase 3 (Composition)    ── depends on Phase 2
  3.1 Assemble detail view ── depends on all Phase 2 widgets
  3.2 Widgetbook showcase  ── depends on 3.1
  3.3 Route integration    ── depends on 3.1 + Phase 1

Phase 4 (State)          ── can start with Phase 2, finish with Phase 3
  4.1 Entry controller     ── parallel with Phase 2
  4.2 Scroll tracking      ── depends on 2.4
  4.3 AI summary provider  ── parallel with 2.5
  4.4 Time tracker state   ── parallel with 2.7

Phase 5 (Testing)        ── incremental, test each widget as built
  5.1 Unit tests           ── with Phase 4
  5.2 Widget tests         ── with each Phase 2 widget
  5.3 Widgetbook tests     ── with Phase 3
  5.4 Integration tests    ── after Phase 3

Phase 6 (Polish)         ── after Phase 5
  6.1 Figma alignment
  6.2 Accessibility
  6.3 Performance
  6.4 Final checklist
```

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Missing design tokens in `tokens.json` | Blocks component styling | Run Figma MCP `get_variable_defs` early; add missing tokens to source before building widgets |
| `SectionNavSidebar` scroll tracking causes jank | Poor UX | Throttle scroll listener; use `SchedulerBinding.addPostFrameCallback` for position calculations |
| Legacy entry details diverge during development | Maintenance burden | Feature flag allows instant rollback; no cross-dependencies between old and new code |
| Figma design changes mid-implementation | Rework | Build bottom-up with isolated components; changes affect individual widgets, not the whole layout |
| `CustomScrollView` with mixed sliver/non-sliver content | Layout errors | Use `SliverToBoxAdapter` consistently; test each section independently before composing |
| Large number of linked entries degrades scroll performance | Slow detail view | Use `SliverList.builder` for linked entries section; lazy-load heavy content (images, audio players) |

---

## Critical File Reference

| File | Role |
|------|------|
| `lib/features/tasks/ui/pages/tasks_root_page.dart` | Desktop/mobile layout switch (Phase 1) |
| `lib/features/design_system/theme/breakpoints.dart` | `kDesktopBreakpoint = 960.0` |
| `lib/features/design_system/theme/generated/design_tokens.g.dart` | All design tokens |
| `lib/features/journal/ui/widgets/entry_details_widget.dart` | Legacy detail view (reference, not modified) |
| `lib/features/tasks/ui/task_form.dart` | Legacy task form (reference, not modified) |
| `lib/features/tasks/ui/pages/task_details_page.dart` | Legacy detail page (mobile keeps using this) |
| `lib/services/nav_service.dart` | `desktopSelectedTaskId` for detail selection |
| `lib/beamer/beamer_app.dart` | App shell with sidebar (not modified) |
| `lib/features/tasks/widgetbook/task_list_detail_mock_data.dart` | Existing mock data for showcases |
| `lib/features/tasks/ui/widgets/task_list_pane.dart` | Existing list pane (not modified) |
| `lib/features/tasks/ui/widgets/task_detail_pane.dart` | Existing showcase detail pane (reference) |
