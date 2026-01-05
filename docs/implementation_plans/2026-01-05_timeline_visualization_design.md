# Timeline Visualization and Time-Slice Navigation Design

## Overview

This document describes the design for a timeline-based navigation and filtering component for task backlogs in Lotti. The feature provides a video-editor-style timeline that visualizes task distribution over time and allows users to select a time window to filter the task list.

## Visual Design Concept

### Inspiration: Video Editor Timeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Task Timeline                                          [14d] [30d] [90d] [All]│
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    ▂▂▂▂▄▄▆▆████▆▆▄▄▂▂▂▂▁▁▁▁▁▁▂▂▂▂▄▄▆▆████████▆▆▆▆▄▄▂▂▂▂▁▁▁▁▁▁▂▂▂▂▄▄▆▆▆▆     │
│                                                                              │
│   ╔══════════════════╗                                                       │
│   ║    SELECTION     ║  ◄─── Draggable time-slice window                     │
│   ╚══════════════════╝                                                       │
│                                                                              │
│   ●────────────────●─────────────────────────────────────────────────────●   │
│  Jan 2024      Mar 2024                                             Jan 2025 │
│                                                                              │
│   [◄]  Nov 12 - Nov 26, 2024 (23 tasks)  [►]                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Component Anatomy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. HEADER BAR                                                                │
│    ├── Title: "Task Timeline"                                               │
│    ├── Collapse/Expand toggle                                               │
│    └── Timeframe selector: [14d] [30d] [90d] [All]                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. HISTOGRAM AREA                                                            │
│    ├── Bar chart showing task count per time bucket                         │
│    ├── Color coding: by task status or priority (user selectable)          │
│    └── Height: ~60-80px (configurable)                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. SELECTION OVERLAY                                                         │
│    ├── Semi-transparent selection window                                    │
│    ├── Draggable left/right edges for resizing                             │
│    ├── Draggable center for repositioning                                   │
│    └── Outside selection: dimmed/grayed                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│ 4. TIMELINE AXIS                                                             │
│    ├── Date labels (adaptive: days/weeks/months based on range)            │
│    └── Today marker (vertical line)                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ 5. SELECTION INFO BAR                                                        │
│    ├── Selected date range display                                          │
│    ├── Task count in selection                                              │
│    ├── Quick navigation arrows [◄] [►]                                      │
│    └── "Clear Selection" button                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Interaction Design

### Core Interactions

| Action | Behavior |
|--------|----------|
| **Tap on histogram** | Centers selection window on tapped date |
| **Drag selection edges** | Resizes the time window (min: 1 week, max: full range) |
| **Drag selection center** | Moves the window along the timeline |
| **Pinch gesture** | Zooms in/out on the timeline |
| **[◄] / [►] buttons** | Steps the selection window by its own width |
| **Double-tap** | Resets to full range (clears filter) |
| **Long-press on bar** | Shows tooltip with date and task count |

### Selection Behavior

- **No selection** → All tasks shown (default state)
- **Active selection** → Only tasks within the date range are shown
- **Selection indicator** → Badge or chip showing "Filtered: Nov 1-15" in the filter bar

### Animation & Feedback

- Selection window snaps to date boundaries with spring animation
- Histogram bars highlight on hover/touch
- Smooth interpolation when changing timeframe selector
- Haptic feedback on iOS when dragging past boundaries

## Technical Architecture

### State Model

```dart
/// Represents the timeline selection state
@freezed
abstract class TimelineSelectionState with _$TimelineSelectionState {
  const factory TimelineSelectionState({
    /// The earliest date with tasks (for range calculation)
    required DateTime dataStartDate,

    /// The latest date with tasks (usually today or future due dates)
    required DateTime dataEndDate,

    /// Current view window (what's visible on the timeline)
    required DateTimeRange viewWindow,

    /// User's selection window (null = no filter active)
    /// NOTE: Not persisted across app restarts
    DateTimeRange? selectionWindow,

    /// Histogram data by status for stacked bars: date -> {status -> count}
    required Map<DateTime, Map<String, int>> histogramByStatus,

    /// Count of tasks without due dates (for due-date mode)
    @Default(0) int undatedTaskCount,

    /// Count of tasks in current selection
    @Default(0) int selectedTaskCount,

    /// Whether the timeline is expanded or collapsed (persisted)
    @Default(true) bool isExpanded,

    /// Whether to show creation dates or due dates
    @Default(DateFilterMode.creationDate) DateFilterMode dateMode,
  }) = _TimelineSelectionState;
}
```

### Provider Structure

```dart
/// Controls timeline state and selection
@riverpod
class TimelineController extends _$TimelineController {
  @override
  TimelineSelectionState build(bool showTasks) {
    // Initialize with data from the database
    // Watch the task filter to stay in sync
  }

  void setSelection(DateTimeRange? range);
  void moveSelectionBy(Duration offset);
  void resizeSelectionStart(DateTime newStart);
  void resizeSelectionEnd(DateTime newEnd);
  void setViewWindow(DateTimeRange window);
  void clearSelection();
  void collapseTimeline();
  void expandTimeline();
}

/// Provides histogram data grouped by status for stacked bars
@riverpod
Future<Map<DateTime, Map<String, int>>> taskHistogramByStatus(Ref ref, {
  required List<String> statuses,
  required List<String> categoryIds,
  required DateFilterMode dateMode,
}) async {
  // Query database for task counts by date AND status
  // Returns: { date -> { status -> count } }
  // Example: { 2024-11-15 -> { 'GROOMED': 5, 'IN PROGRESS': 3, 'OPEN': 2 } }
}
```

### Integration with Existing Filters

The timeline selection will integrate with `JournalPageController` as an additional filter:

```dart
// In journal_page_state.dart - extend TasksFilter
@freezed
abstract class TasksFilter with _$TasksFilter {
  const factory TasksFilter({
    // ... existing fields ...

    /// Date range filter from timeline selection
    DateTimeRange? dateRangeFilter,

    /// Whether to filter by creation date or due date
    @Default(DateFilterMode.creationDate) DateFilterMode dateFilterMode,
  }) = _TasksFilter;
}

enum DateFilterMode {
  creationDate,  // Filter by when task was created
  dueDate,       // Filter by due date
}
```

### Database Query for Histogram

```sql
-- New query in database.drift for creation date histogram (grouped by status)
-- Note: date_from is stored as ISO8601 string by Drift
taskCountsByDateAndStatus:
SELECT
  date(date_from) as task_date,
  task_status,
  COUNT(*) as task_count
FROM journal
WHERE
  type = 'Task'
  AND deleted = false
  AND task_status IN :taskStatuses
  AND category IN :categories
GROUP BY date(date_from), task_status
ORDER BY task_date ASC;

-- Query for due dates (grouped by status)
-- WARNING: json_extract requires full table scan - see Performance Considerations
taskCountsByDueDateAndStatus:
SELECT
  date(json_extract(serialized, '$.meta.data.dueDate')) as due_date,
  task_status,
  COUNT(*) as task_count
FROM journal
WHERE
  type = 'Task'
  AND deleted = false
  AND json_extract(serialized, '$.meta.data.dueDate') IS NOT NULL
  AND task_status IN :taskStatuses
GROUP BY date(json_extract(serialized, '$.meta.data.dueDate')), task_status
ORDER BY due_date ASC;

-- Count of tasks without due dates (for "Undated" bucket)
taskCountWithoutDueDate:
SELECT
  task_status,
  COUNT(*) as task_count
FROM journal
WHERE
  type = 'Task'
  AND deleted = false
  AND (json_extract(serialized, '$.meta.data.dueDate') IS NULL
       OR json_extract(serialized, '$.meta.data.dueDate') = '')
  AND task_status IN :taskStatuses
GROUP BY task_status;

-- Query for filtering task list by date range (creation date)
-- Add to existing filteredTasks query with optional date bounds
-- AND (:startDate IS NULL OR date_from >= :startDate)
-- AND (:endDate IS NULL OR date_from <= :endDate)
```

## Widget Structure

```
TaskTimelineWidget (ConsumerStatefulWidget)
├── TimelineHeader
│   ├── Text("Task Timeline")
│   ├── CollapseButton
│   └── TimeSpanSegmentedControl
│
├── TimelineHistogram (CustomPainter or Chart widget)
│   ├── HistogramBars
│   │   └── Per-bar: height based on count, color by status
│   └── SelectionOverlay
│       ├── DimmedRegion (left of selection)
│       ├── SelectionWindow (GestureDetector)
│       │   ├── LeftHandle
│       │   └── RightHandle
│       └── DimmedRegion (right of selection)
│
├── TimelineAxis
│   ├── DateLabels
│   └── TodayMarker
│
└── SelectionInfoBar
    ├── DateRangeText
    ├── TaskCountBadge
    ├── NavigationArrows
    └── ClearButton
```

## Implementation Plan

### Phase 1: Data Layer (Foundation)
1. Add `taskCountsByDateAndStatus` and `taskCountsByDueDateAndStatus` queries to `database.drift`
2. Add `taskCountWithoutDueDate` query for the "Undated" bucket
3. Modify `filteredTasks` and `filteredTasksByDate` queries to accept optional date range bounds
4. Create `TimelineHistogramProvider` to fetch and cache histogram data by status
5. Add `dateRangeFilter` and `dateFilterMode` fields to `TasksFilter` model
6. Modify `JournalPageController._runQuery()` to respect date range filter
7. Write unit tests for histogram queries and date range filtering

### Phase 2: State Management
1. Create `TimelineSelectionState` freezed model
2. Implement `TimelineController` Riverpod controller
3. Wire up selection changes to trigger task list refresh
4. Persist collapsed/expanded state in `SettingsDb`
5. Write tests for controller logic

### Phase 3: Basic UI Components
1. Create `TaskTimelineWidget` container
2. Implement `TimelineHeader` with collapse toggle and date mode toggle
3. Build `TimelineHistogram` using `fl_chart` StackedBarChart (stacked by status)
4. Add `TimelineAxis` with adaptive date labels
5. Create `SelectionInfoBar` with date display
6. Implement "Undated" bucket for due-date mode

### Phase 4: Interactive Selection
1. Add `SelectionOverlay` with draggable window
2. Implement drag-to-resize handles
3. Add drag-to-move for the selection window
4. Implement tap-to-select behavior
5. Add keyboard navigation support for accessibility
6. Write widget tests for interactions

### Phase 5: Polish & Integration
1. Add animations for selection changes
2. Implement haptic feedback on iOS
3. Add "Filtered by date" indicator in filter bar
4. Handle edge cases (empty data, single-task dates)
5. Performance optimization for large datasets
6. Integration tests

### Phase 6: Advanced Features (Optional)
1. Pinch-to-zoom gesture for timeline
2. Alternative color modes (by priority or category instead of status)
3. Export histogram data as CSV/image
4. Animated transitions between date modes

## File Structure

```
lib/features/tasks/
├── state/
│   ├── timeline_controller.dart          # New
│   └── timeline_histogram_provider.dart  # New
├── ui/
│   └── timeline/                         # New directory
│       ├── task_timeline_widget.dart
│       ├── timeline_header.dart
│       ├── timeline_histogram.dart
│       ├── timeline_axis.dart
│       ├── selection_overlay.dart
│       └── selection_info_bar.dart
└── models/
    └── timeline_selection_state.dart     # New

lib/features/journal/state/
└── journal_page_state.dart               # Modified (add dateRangeFilter)

lib/database/
└── database.drift                        # Modified (add histogram queries)

test/features/tasks/
├── state/
│   ├── timeline_controller_test.dart
│   └── timeline_histogram_provider_test.dart
└── ui/
    └── timeline/
        ├── task_timeline_widget_test.dart
        └── selection_overlay_test.dart
```

## UI/UX Considerations

### Responsive Design

| Screen Size | Default State | Behavior |
|-------------|---------------|----------|
| Phone portrait | **Collapsed** | Tap header to expand; saves vertical space |
| Phone landscape | **Collapsed** | Same as portrait; user expands when needed |
| Tablet | **Expanded** | Full histogram visible; more date labels |
| Desktop | **Expanded** | Larger histogram height (~100px); keyboard nav enabled |

Note: Collapsed/expanded state is persisted per device, but selection is cleared on app restart.

### Accessibility

- Screen reader support: Announce selection range and task count
- Keyboard navigation: Arrow keys to move selection, Enter to clear
- High contrast mode: Ensure selection overlay is visible
- Minimum touch target: 44x44pt for handles

### Color Palette

Use existing theme colors from `lotti/themes/`:
- Selection window: Primary color at 30% opacity
- Dimmed regions: Surface color at 60% opacity
- Stacked bar segments (by status):
  - OPEN: Blue (neutral, awaiting triage)
  - GROOMED: Purple (ready for work)
  - IN PROGRESS: Green (active)
  - BLOCKED/ON HOLD: Orange (attention needed)
  - DONE: Gray (completed, low emphasis)
- Today marker: Accent color vertical line
- "Undated" bucket: Hatched/striped pattern to distinguish from dated bars

## Performance Considerations

1. **Histogram caching**: Cache histogram data, invalidate on task changes
2. **Debounced updates**: When dragging selection, debounce filter refresh (150ms)
3. **Lazy rendering**: Only render visible histogram bars
4. **Database indexing for creation dates**: The existing `idx_journal_date_from_asc` index supports ordering, but `GROUP BY date(date_from)` may not use it efficiently. Consider adding an expression index:
   ```sql
   CREATE INDEX idx_journal_task_date ON journal (date(date_from)) WHERE type = 'Task';
   ```
5. **Due date query performance**: The `json_extract()` function requires a full table scan since SQLite cannot index JSON fields. For acceptable performance:
   - Cache due-date histogram aggressively (invalidate only on task create/update/delete)
   - Consider future schema migration: add `due_date` as a denormalized indexed column
   - For large datasets (>10,000 tasks), display a loading indicator during initial computation
6. **Batch status queries**: Fetch all statuses in a single query rather than per-status queries

## Design Decisions

The following decisions were made during the design review:

| Question | Decision | Rationale |
|----------|----------|-----------|
| **Date mode** | Toggle between creation/due date | Most flexible; user can switch views based on current need |
| **Default state** | Collapsed on mobile, expanded on tablet/desktop | Saves vertical space on phones while maximizing discoverability on larger screens |
| **Bar styling** | Stacked by task status | Shows status composition at a glance (groomed vs in-progress vs open) |
| **Selection persistence** | Reset on app launch | Avoids confusion from forgotten filters; fresh start each session |
| **Minimum selection** | 1 week | Prevents overly narrow selections; aligns with weekly planning workflows |

### Handling Tasks Without Due Dates

In due-date mode, tasks without a due date will be shown in an "Undated" bucket on the right side of the timeline, visually separated from the dated histogram.

## Dependencies

- `fl_chart: ^1.0.0` (already in pubspec) - For histogram visualization
- `graphic: ^2.3.0` (already in pubspec) - Alternative charting option
- `freezed` - For state models (already in use)
- `riverpod` - For state management (already in use)

## Success Metrics

### Functional Criteria
1. Timeline accurately reflects task distribution across all date ranges
2. Selection filtering correctly shows only tasks within the chosen date window
3. Stacked bars correctly represent task status proportions per time period
4. Toggle between creation date and due date modes works seamlessly

### Performance Criteria
1. Initial histogram render completes in <500ms for datasets up to 5,000 tasks
2. Selection drag interactions maintain 60fps (no frame drops during drag)
3. Filter refresh after selection change completes in <100ms
4. Memory footprint increase is <5MB for cached histogram data

### Quality Criteria
1. All unit tests pass for histogram queries and controller logic
2. Widget tests cover all interaction states (tap, drag, resize, clear)
3. Accessibility: VoiceOver/TalkBack correctly announces selection range and task counts
4. No regressions in existing task filtering functionality
