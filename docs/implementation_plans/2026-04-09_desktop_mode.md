# Desktop Mode Implementation Plan

## Context

The Lotti app currently uses a mobile-first layout on all platforms: a bottom navigation tab bar with full-screen page pushes for detail views. On macOS/desktop, this wastes screen real estate. The goal is to add a responsive desktop layout with a persistent left navigation sidebar and multi-pane content areas, matching the existing Figma designs already prototyped in Widgetbook.

Three near-identical sidebar implementations exist only for Widgetbook showcase purposes (not production). This plan unifies them into a single production widget and integrates it into the real app navigation.

---

## Phase 1: Desktop Shell (Sidebar + Full Content Area)

The minimum viable desktop experience: when the window is wide enough, replace the bottom nav bar with a persistent left sidebar. All existing page content renders to the right of the sidebar. No list+detail split yet -- detail pages still push on top as full-screen pages within the content area. This phase delivers immediate value with low risk.

### Step 1: Centralized breakpoint constants

**New file:** `lib/features/design_system/theme/breakpoints.dart`

```dart
const kDesktopBreakpoint = 960.0;
bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
```

- 960px matches the existing `_desktopBreakpoint` in `projects_overview_list.dart`
- Update `projects_overview_list.dart` to import the shared constant

### Step 2: Production `DesktopNavigationSidebar` widget

**New file:** `lib/features/design_system/components/navigation/desktop_navigation_sidebar.dart`

Port the common elements from the three existing sidebars:
- `TaskShowcaseDesktopSidebar` (`task_showcase_shared_widgets.dart:531-609`)
- `Sidebar` (`projects/ui/widgets/sidebar.dart:11-94`)
- `_SidebarFrame` / `_ExpandedSidebarContent` (`design_system_navigation_sidebar_widgetbook.dart`)

API:
- `destinations`: list of nav items (label, iconBuilder, badge)
- `activeIndex` / `onDestinationSelected`: wired to `NavService.tapIndex`
- `settingsDestination`: rendered at the bottom of the sidebar (separated by `Spacer`)
- `onNewPressed` / `onAiAssistantPressed`: action callbacks
- Fixed width: 320px
- Styling: design tokens palette (`tokens.colors.background.level02`, `tokens.colors.surface.active`, etc.)
- Includes: hamburger menu icon + `DesignSystemBrandLogo`, `DesignSystemButton` "New" + `DesignSystemAiAssistantButton`, nav items list, Settings at bottom

### Step 3: Responsive layout switch in `AppScreen`

**Modify:** `lib/beamer/beamer_app.dart` (the `_AppScreenState.build()` method)

Inside the existing `StreamBuilder<int>` builder, after computing `index` and `destinations`:

```
final isWide = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
```

**Wide layout (>= 960px):**
```
Scaffold(
  body: Row(
    children: [
      DesktopNavigationSidebar(...wired to navService...),
      Expanded(
        child: Stack(
          children: [
            IndexedStack(...same Beamer delegates as today...),
            // TimeRecordingIndicator, AudioRecordingIndicator (repositioned)
          ],
        ),
      ),
    ],
  ),
)
```

**Narrow layout (< 960px):** Current code unchanged.

Key details:
- The `IndexedStack` of Beamer delegates is identical in both branches -- only the wrapper changes.
- No `DesignSystemBottomNavigationBar` in the wide layout.
- `IncomingVerificationWrapper` present in both branches.
- Add a `toDesktopSidebarDestination()` conversion on `_AppNavigationDestination` to provide `iconBuilder` + label + badge to the sidebar.
- Settings is filtered out of the main destinations list and passed as `settingsDestination`.

### Step 4: Bottom padding fix for desktop mode

**Modify:** `lib/widgets/nav_bar/design_system_bottom_navigation_bar.dart`

Make `occupiedHeight()` return 0 in desktop mode:
```dart
static double occupiedHeight(BuildContext context) {
  if (isDesktopLayout(context)) return 0;
  // ...existing calculation...
}
```

This automatically fixes the ~24 files using `DesignSystemBottomNavigationFabPadding` -- FABs and padding will position correctly without a bottom bar.

### Step 5: Add `isDesktopMode` flag to NavService

**Modify:** `lib/services/nav_service.dart`

```dart
bool isDesktopMode = false;
```

Set by `AppScreen.build()` before building the layout:
```dart
navService.isDesktopMode = isWide;
```

This flag is needed in Phase 2 for Beamer locations to know whether to push detail pages.

### Step 6: Tests for Phase 1

**Modify:** `test/beamer/beamer_app_test.dart`

- Desktop mode triggers when width >= 960px (use `MediaQuery` override)
- Sidebar visible and bottom bar hidden in desktop mode
- Tab switching via sidebar calls `navService.tapIndex` correctly
- Feature flag toggling shows/hides sidebar items
- Overlay indicators present in both modes

---

## Phase 2: Multi-Pane List+Detail (Tasks, Projects, Dashboards)

For sections that have a list+detail pattern, show both panes side by side in desktop mode. Full-width sections (Habits, My Daily, Journal, Settings) continue to use the full content area.

### Step 7: `DesktopDetailEmptyState` widget

**New file:** `lib/features/design_system/components/navigation/desktop_detail_empty_state.dart`

Centered icon + text placeholder for the right pane when no item is selected. Uses `tokens.colors.text.mediumEmphasis`.

### Step 8: Suppress detail page push in Beamer locations (desktop mode)

**Modify:** `lib/beamer/locations/tasks_location.dart`

```dart
List<BeamPage> buildPages(BuildContext context, BeamState state) {
  final taskId = state.pathParameters['taskId'];
  final isDesktop = getIt<NavService>().isDesktopMode;

  return [
    BeamPage(
      key: const ValueKey('tasks'),
      child: TasksRootPage(selectedTaskId: isUuid(taskId) ? taskId : null),
    ),
    if (!isDesktop && isUuid(taskId))
      BeamPage(
        key: ValueKey('tasks-$taskId'),
        child: TaskDetailsPage(taskId: taskId!),
      ),
  ];
}
```

Same pattern for `ProjectsLocation` and `DashboardsLocation`.

The `selectedTaskId` parameter is passed to `TasksRootPage` so it knows which item to show in the detail pane. In mobile mode, `selectedTaskId` is null (the detail is a separate page in the Beamer stack).

### Step 9: Make root pages responsive with split layout

**Modify:** `lib/features/tasks/ui/pages/tasks_root_page.dart`

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final enabled = ref.watch(configFlagProvider(enableTasksRedesignFlag)).value ?? false;
  if (!enabled) return const InfiniteJournalPage(showTasks: true);

  final isDesktop = isDesktopLayout(context);
  if (isDesktop) {
    return TasksDesktopSplitPage(selectedTaskId: widget.selectedTaskId);
  }
  return const TasksTabPage();
}
```

**New file:** `lib/features/tasks/ui/pages/tasks_desktop_split_page.dart`

Layout:
```
Row(
  children: [
    SizedBox(width: 402, child: TasksTabPage(onTaskSelected: _handleSelect)),
    if (selectedTaskId != null)
      Expanded(child: TaskDetailsPage(taskId: selectedTaskId))
    else
      Expanded(child: DesktopDetailEmptyState(...)),
  ],
)
```

Task selection calls `navService.beamToNamed('/tasks/$taskId')` which updates the Beamer route, causing the `TasksLocation` to rebuild with the new `taskId` path parameter. Since desktop mode suppresses the detail page push (Step 8), the `TasksRootPage` receives `selectedTaskId` and renders it inline.

**Same pattern for:**
- `lib/features/projects/ui/pages/projects_tab_page.dart` -> `ProjectsDesktopSplitPage`
- `lib/features/dashboards/ui/pages/dashboards_list_page.dart` -> `DashboardsDesktopSplitPage`

### Step 10: Adapt `TasksTabPage` for embedded use

**Modify:** `lib/features/tasks/ui/pages/tasks_tab_page.dart`

Add an optional `onTaskSelected` callback. When provided (desktop mode), tapping a task calls this callback instead of doing a full-page Beamer navigation. This prevents Beamer from pushing a detail page while also updating the route for URL synchronization.

Same for `ProjectsTabPage` and `DashboardsListPage`.

---

## Phase 3: Widgetbook & Cleanup

### Step 11: Refactor Widgetbook sidebars to use production widget

**Modify:**
- `lib/features/tasks/ui/widgets/task_list_detail_showcase.dart` -- Replace `TaskShowcaseDesktopSidebar` with `DesktopNavigationSidebar`
- `lib/features/projects/ui/widgets/project_list_detail_showcase.dart` -- Replace `Sidebar` with `DesktopNavigationSidebar`
- `lib/features/design_system/widgetbook/design_system_navigation_sidebar_widgetbook.dart` -- Update to showcase the production widget

**Delete or simplify:**
- `TaskShowcaseDesktopSidebar` in `task_showcase_shared_widgets.dart`
- `Sidebar` + `_SidebarNavItem` in `projects/ui/widgets/sidebar.dart`
- `MainTopBar` in `projects/ui/widgets/sidebar.dart` (if replaced by a shared top bar)

### Step 12: Add Widgetbook stories for the full desktop layout

**New file:** `lib/features/design_system/widgetbook/design_system_desktop_layout_widgetbook.dart`

Showcase:
- Production sidebar with mock destinations
- Full desktop shell (sidebar + content placeholder)
- Desktop shell with multi-pane split (sidebar + list + detail)

---

## Navigation Sidebar Items (from requirements)

| Item | Icon | Section Type | Feature Flag |
|------|------|-------------|--------------|
| My Daily | `calendar_today_outlined` | Full-width | `enableDailyOsPageFlag` |
| Tasks | `format_list_bulleted_rounded` | Multi-pane (list+detail) | always on |
| Projects | `folder_rounded` | Multi-pane (list+detail) | `enableProjectsFlag` |
| Insights | `bar_chart_rounded` | Multi-pane (list+detail) | `enableDashboardsPageFlag` |
| Habits | `checkbox_multiple_marked` | Full-width | `enableHabitsPageFlag` |
| Dashboards | (same as Insights, TBD) | Multi-pane | `enableDashboardsPageFlag` |
| --- spacer --- | | | |
| Settings | `settings_outlined` | Full-width | always on |

Note: The Figma design shows "My Daily, Tasks, Projects, Insights" in the sidebar. The user also requested Habits and Dashboards. The exact mapping between the current tab names and sidebar labels needs confirmation -- the current bottom nav has "DailyOS" (not "My Daily") and "Insights" seems to map to the Dashboards tab.

---

## Key Files

| File | Action | Phase |
|------|--------|-------|
| `lib/features/design_system/theme/breakpoints.dart` | Create | 1 |
| `lib/features/design_system/components/navigation/desktop_navigation_sidebar.dart` | Create | 1 |
| `lib/beamer/beamer_app.dart` | Modify (AppScreen) | 1 |
| `lib/widgets/nav_bar/design_system_bottom_navigation_bar.dart` | Modify (occupiedHeight) | 1 |
| `lib/services/nav_service.dart` | Modify (isDesktopMode flag) | 1 |
| `lib/features/design_system/components/navigation/desktop_detail_empty_state.dart` | Create | 2 |
| `lib/beamer/locations/tasks_location.dart` | Modify | 2 |
| `lib/beamer/locations/projects_location.dart` | Modify | 2 |
| `lib/beamer/locations/dashboards_location.dart` | Modify | 2 |
| `lib/features/tasks/ui/pages/tasks_root_page.dart` | Modify | 2 |
| `lib/features/tasks/ui/pages/tasks_desktop_split_page.dart` | Create | 2 |
| `lib/features/tasks/ui/pages/tasks_tab_page.dart` | Modify | 2 |
| `lib/features/projects/ui/pages/projects_tab_page.dart` | Modify | 2 |
| `lib/features/dashboards/ui/pages/dashboards_list_page.dart` | Modify | 2 |
| `lib/features/tasks/ui/widgets/task_list_detail_showcase.dart` | Modify | 3 |
| `lib/features/projects/ui/widgets/project_list_detail_showcase.dart` | Modify | 3 |
| `lib/features/tasks/ui/widgets/task_showcase_shared_widgets.dart` | Modify (remove old sidebar) | 3 |
| `lib/features/projects/ui/widgets/sidebar.dart` | Modify (remove old sidebar) | 3 |

---

## Verification

1. **Phase 1:** Run on macOS with window width > 960px -- sidebar visible, bottom bar hidden, tab switching works. Resize below 960px -- falls back to bottom bar. Run analyzer + formatter + existing tests.
2. **Phase 2:** In desktop mode, navigate to Tasks/Projects/Dashboards -- list+detail side by side. Select items -- detail updates. In mobile mode, same pages push detail as before. Run targeted tests for modified pages + Beamer location tests.
3. **Phase 3:** Open Widgetbook, verify updated stories render correctly with the production sidebar widget. Run full test suite.
