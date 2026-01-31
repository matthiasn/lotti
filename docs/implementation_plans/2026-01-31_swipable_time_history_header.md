# Swipable Time History Header — Implementation Plan

**Created**: 2026-01-31
**Status**: In Progress (Phase 1 Complete, Phase 1b Complete)
**Epic**: Daily Operating System
**Related Plans**:
- `2026-01-14_daily_os_implementation_plan.md` — Core Daily OS architecture (DayHeader, providers)
- `2026-01-14_day_view_design_spec.md` — Design principles (visual humility, reality-first)
- `2026-01-29_timeline_smart_folding.md` — Pattern for CustomPainter-based visualization
- `2026-01-05_timeline_visualization_design.md` — Histogram and time-based visualization patterns

---

## Executive Summary

Replace the current static `DayHeader` widget with a **swipable time history header** containing horizontally scrollable day segments with an integrated **stream chart visualization**. This provides an immediate visual "DNA" of time allocation across days, enabling intuitive navigation through time while showing category distribution patterns at a glance, with a hard requirement of **silky-smooth scrolling**.

**Key Innovation**: The stream chart flows continuously across day boundaries as a background layer, while each day segment remains clickable for selection. This transforms navigation from discrete arrow-taps to fluid exploration.

---

## Problem Statement

### Current State
The existing `DayHeader` widget (`lib/features/daily_os/ui/widgets/day_header.dart`) is:
- **Space-inefficient**: Shows only date text and navigation arrows
- **Context-poor**: No visual indication of time patterns across days
- **Navigation-limited**: One day at a time via discrete taps

### Goal
Create a header that:
- Shows multiple days simultaneously as a horizontal strip
- Integrates the stream chart (time-by-category visualization) as the background
- Supports infinite backward scrolling for historical exploration
- Uses **custom canvas rendering** (not the Graphic library) for performance and flexibility

---

## Visual Design

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Swipable Time History Header                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   ◄ scroll                                            scroll ►       │
│                                                                       │
│   │  27  │  28  │  29  │  30  │ [31] │                               │
│   │      │      │      │      │      │                               │
│   │▓▓▓▓▓▓│▓▓▓▓  │▓▓▓▓▓▓│▓▓▓   │▓▓▓▓▓▓│  ◄── Stream chart flows      │
│   │░░░░░░│░░░░░░│░░░░░░│░░░░░░│░░░░░░│      across all segments      │
│   │▒▒▒   │▒▒▒▒▒▒│▒▒▒▒  │▒▒▒▒▒▒│▒▒▒▒▒▒│                               │
│   │      │      │      │      │      │                               │
│   └──────┴──────┴──────┴──────┴──────┘                               │
│                                  ▲                                    │
│                          Selected day (highlighted)                   │
│                                                                       │
│            Saturday, January 31, 2026    [Today]                     │
│                     ◐ Near limit                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Anatomy

| Section                  | Description                                                                       |
|--------------------------|-----------------------------------------------------------------------------------|
| **Day Segments**         | Fixed-width columns (56px), showing day number, optional month indicator on 1st   |
| **Stream Chart**         | Stacked area chart flowing across segments, categories colored by definition      |
| **Selection Highlight**  | Current day has border/glow effect                                                |
| **Date Label**           | Full date text below the strip (e.g., "Saturday, January 31, 2026")               |
| **Status Indicator**     | Budget health chip (on track / near limit / over budget)                          |
| **Today Button**         | Appears when scrolled away from today                                             |

---

## Technical Architecture

### 1. Data Layer

#### 1.1 Data Models

**Location**: `lib/features/daily_os/state/time_history_header_controller.dart`

```dart
/// Summary of time spent per category for a single day.
/// Matches the structure from TimeByCategoryController but optimized for header display.
@freezed
class DayTimeSummary with _$DayTimeSummary {
  const factory DayTimeSummary({
    required DateTime day, // date at local noon, avoids DST artifacts
    required Map<String?, Duration> durationByCategoryId, // categoryId -> duration
    required Duration total,
  }) = _DayTimeSummary;

  const DayTimeSummary._();

  Duration get totalDuration => total;
}

/// Precomputed stacked heights for efficient painting.
/// Maps category ID to its cumulative height (sum of lower categories).
typedef StackedHeights = Map<DateTime, Map<String?, double>>;

/// Aggregated data for the time history header visualization.
@freezed
class TimeHistoryData with _$TimeHistoryData {
  const factory TimeHistoryData({
    required List<DayTimeSummary> days,  // Ordered newest to oldest
    required DateTime earliestDay,
    required DateTime latestDay,
    required Duration maxDailyTotal,     // For Y-axis normalization
    required List<String> categoryOrder, // Consistent stacking order
    required bool isLoadingMore,
    required bool canLoadMore,
    required StackedHeights stackedHeights, // Precomputed heights for rendering
  }) = _TimeHistoryData;
}
```

#### 1.2 Controller

**Location**: `lib/features/daily_os/state/time_history_header_controller.dart`

**Key behaviors:**
- **Infinite scroll**: `canLoadMore` is always `true` - the sliding window handles memory,
  and we don't stop on gaps (periods with no entries)
- **Sliding window**: When cap (180 days) is reached, drops **newest** days (front of list)
  to preserve backward scroll position
- **Rescale on merge**: If `maxDailyTotal` changes after loading more, all stacked heights
  are recomputed for scale consistency
- **Refresh preserves state**: `_refresh()` preserves `canLoadMore` to avoid repeated loads
- **resetToToday()**: API to restore the initial view after scrolling far into history

```dart
@riverpod
class TimeHistoryHeaderController extends _$TimeHistoryHeaderController {
  static const int _initialDays = 30;
  static const int _loadMoreDays = 14;
  static const int _maxLoadedDays = 180;     // Sliding window cap

  @override
  Future<TimeHistoryData> build() async {
    _listenToUpdates();
    return _fetchInitialData();
  }

  Future<void> loadMoreDays() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.canLoadMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    // Use dayAtMidnight for DB query boundaries
    final currentEarliestMidnight = current.earliestDay.dayAtMidnight;
    final newRangeEnd = currentEarliestMidnight.subtract(const Duration(days: 1));
    final newRangeStart = currentEarliestMidnight.subtract(const Duration(days: _loadMoreDays));

    final additionalData = await _fetchDataForRange(newRangeStart, newRangeEnd);

    // Merge: append older days to end (list is newest-to-oldest)
    final mergedDays = [...current.days, ...additionalData.days];

    // Sliding window: drop NEWEST days (front) when over cap
    final prunedDays = mergedDays.length > _maxLoadedDays
        ? mergedDays.sublist(mergedDays.length - _maxLoadedDays)
        : mergedDays;

    // Recompute maxDailyTotal from pruned days (handles dropped days)
    final newMax = _computeMaxFromDays(prunedDays);

    // Always recompute stacked heights for scale consistency.
    // Merging heights from different scales would cause rendering bugs.
    final stackedHeights = _computeStackedHeights(prunedDays, current.categoryOrder, newMax);

    state = AsyncData(current.copyWith(
      days: prunedDays,
      earliestDay: prunedDays.isNotEmpty ? prunedDays.last.day : current.earliestDay,
      latestDay: prunedDays.isNotEmpty ? prunedDays.first.day : current.latestDay,
      maxDailyTotal: newMax,
      isLoadingMore: false,
      canLoadMore: true,  // Always allow more loading for infinite scroll
      stackedHeights: stackedHeights,
    ));
  }

  /// Reset to today's view after scrolling far into history
  Future<void> resetToToday() async {
    state = const AsyncLoading();
    final data = await _fetchInitialData();
    if (ref.mounted) state = AsyncData(data);
  }

  Future<TimeHistoryData> _fetchDataForRange(DateTime start, DateTime end) async {
    final db = getIt<JournalDb>();

    // Query calendar entries for the range
    final entries = await db.sortedCalendarEntries(
      rangeStart: start,
      rangeEnd: end.add(const Duration(days: 1)),
    );

    // Resolve category links
    final entryIds = entries.map((e) => e.meta.id).toSet();
    final links = await _batchedLinksForEntryIds(entryIds);

    // Aggregate by day and category (adapted from TimeByCategoryController)
    return _aggregateEntries(entries, links, start, end);
  }
}
```

### 2. Custom Stream Chart Painter

**Location**: `lib/features/daily_os/ui/widgets/time_history_chart_painter.dart`

**Key Design Decisions**:
- Use `CustomPainter` instead of Graphic library for full control and performance
- Paint stacked areas with smooth curves between days using quadratic Bezier
- Stack categories symmetrically around center baseline (mirrored stream chart effect)
- Normalize Y-axis based on `maxDailyTotal` across visible range
- Precompute stacked heights per day on data changes; avoid per-frame recompute
- Repaint on scroll with a `Listenable` (`repaint: _scrollController`)

```dart
class TimeHistoryChartPainter extends CustomPainter {
  TimeHistoryChartPainter({
    required this.data,
    required this.selectedDate,
    required this.categoryColors,
    required this.dayWidth,
    required this.visibleDayCount,
    required this.scrollOffset,
    required Listenable scrollController,
  }) : super(repaint: scrollController);

  final TimeHistoryData data;
  final DateTime selectedDate;
  final Map<String, Color> categoryColors;
  final double dayWidth;
  final int visibleDayCount;
  final double scrollOffset;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.days.isEmpty) return;

    final chartHeight = size.height * 0.7;  // Leave room for date labels
    final centerY = chartHeight / 2;
    final maxMinutes = data.maxDailyTotal.inMinutes.toDouble();

    if (maxMinutes == 0) return;

    // Draw stacked areas for each category
    for (final categoryId in data.categoryOrder) {
      _paintCategoryArea(
        canvas,
        size,
        categoryId,
        centerY,
        chartHeight,
        maxMinutes,
      );
    }

    // Draw selection highlight
    _paintSelectionHighlight(canvas, size);
  }

  void _paintCategoryArea(
    Canvas canvas,
    Size size,
    String categoryId,
    double centerY,
    double chartHeight,
    double maxMinutes,
  ) {
    final color = categoryColors[categoryId] ?? Colors.grey;
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final path = Path();
    var started = false;

    // Calculate cumulative heights for stacking
    for (var i = 0; i < data.days.length; i++) {
      final day = data.days[i];
      final x = _dayIndexToX(i);

      // Skip if not visible
      if (x < -dayWidth || x > size.width + dayWidth) continue;

      final categoryMinutes = day.durationByCategory[categoryId]?.inMinutes ?? 0;
      final lowerCategories = _sumLowerCategories(day, categoryId);

      final lowerHeight = (lowerCategories / maxMinutes) * (chartHeight / 2);
      final categoryHeight = (categoryMinutes / maxMinutes) * (chartHeight / 2);

      final topY = centerY - lowerHeight - categoryHeight;
      final bottomY = centerY + lowerHeight + categoryHeight;

      if (!started) {
        path.moveTo(x, centerY);
        started = true;
      }

      // Use quadratic bezier for smooth curves
      path.lineTo(x, topY);
    }

    // Close path back through bottom edge
    // ... (mirror for symmetric stream chart)

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TimeHistoryChartPainter oldDelegate) {
    return data != oldDelegate.data ||
        selectedDate != oldDelegate.selectedDate ||
        scrollOffset != oldDelegate.scrollOffset;
  }
}
```

### 3. Header Widget

**Location**: `lib/features/daily_os/ui/widgets/time_history_header.dart`

```dart
class TimeHistoryHeader extends ConsumerStatefulWidget {
  const TimeHistoryHeader({super.key});

  static const double dayWidth = 56.0;
  static const double headerHeight = 120.0;

  @override
  ConsumerState<TimeHistoryHeader> createState() => _TimeHistoryHeaderState();
}

class _TimeHistoryHeaderState extends ConsumerState<TimeHistoryHeader> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Check if we need to load more data
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll > maxScroll * 0.8) {
      ref.read(timeHistoryHeaderControllerProvider.notifier).loadMoreDays();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(timeHistoryHeaderControllerProvider);
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final categoryColors = ref.watch(categoryColorsProvider);

    return dataAsync.when(
      data: (data) => _buildHeader(context, data, selectedDate, categoryColors),
      loading: () => _buildSkeleton(context),
      error: (e, st) => _buildError(context, e),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    TimeHistoryData data,
    DateTime selectedDate,
    Map<String, Color> categoryColors,
  ) {
    return SizedBox(
      height: TimeHistoryHeader.headerHeight,
      child: Column(
        children: [
          // Swipable chart area
          Expanded(
            child: Stack(
              children: [
                // Stream chart background - repaint on scroll for smooth animation
                CustomPaint(
                  repaint: _scrollController,
                  painter: TimeHistoryChartPainter(
                    data: data,
                    selectedDate: selectedDate,
                    categoryColors: categoryColors,
                    dayWidth: TimeHistoryHeader.dayWidth,
                    visibleDayCount: _visibleDayCount,
                    scrollOffset: _scrollController.hasClients
                        ? _scrollController.offset
                        : 0,
                  ),
                  size: Size.infinite,
                ),

                // Day segment hit targets
                ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  reverse: true,  // Today at right edge, scroll left for history
                  itemCount: data.days.length,
                  itemExtent: TimeHistoryHeader.dayWidth,
                  itemBuilder: (context, index) => _DaySegment(
                    day: data.days[index],
                    isSelected: data.days[index].day == selectedDate,
                    onTap: () => _selectDay(data.days[index].day),
                  ),
                ),
              ],
            ),
          ),

          // Date label and status
          _DateLabelRow(
            date: selectedDate,
            onTodayTap: _scrollToToday,
          ),
        ],
      ),
    );
  }

  void _selectDay(DateTime date) {
    ref.read(dailyOsSelectedDateProvider.notifier).selectDate(date);
    // Optionally animate scroll to center selected day
  }

  void _scrollToToday() {
    ref.read(dailyOsSelectedDateProvider.notifier).goToToday();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
}

class _DaySegment extends StatelessWidget {
  const _DaySegment({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final DayTimeSummary day;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: TimeHistoryHeader.dayWidth,
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(
                  color: context.colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Day number
            Text(
              '${day.day.day}',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurface,
              ),
            ),
            // Month indicator on 1st
            if (day.day.day == 1)
              Text(
                DateFormat('MMM').format(day.day),
                style: context.textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}
```

### 4. Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User Interaction                             │
│    Scroll horizontally  │  Tap day segment  │  Tap "Today" button   │
└─────────────────────────┼───────────────────┼───────────────────────┘
                          │                   │
                          ▼                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    TimeHistoryHeader Widget                          │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ ListView.builder (reverse: true, horizontal, itemExtent: 56)    │ │
│  │   - Day segments as hit targets                                 │ │
│  │   - ScrollController tracks position for load-more              │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              │                                       │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ TimeHistoryChartPainter (CustomPainter)                         │ │
│  │   - Paints stacked area chart across all visible days           │ │
│  │   - Categories colored from EntitiesCacheService                │ │
│  │   - Selection highlight on current day                          │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              │ ref.watch / ref.read
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│             TimeHistoryHeaderController (Riverpod)                   │
│  - days: List<DayTimeSummary>                                        │
│  - isLoadingMore: bool                                               │
│  - loadMoreDays() async                                              │
│  - Watches UpdateNotifications for live refresh                      │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              │ Database queries
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          JournalDb                                   │
│  - sortedCalendarEntries(rangeStart, rangeEnd)                       │
│  - linksForEntryIds(ids)                                             │
│  - EntitiesCacheService for category colors                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Performance Budget & Smoothness Guarantees

### Hard requirements

- **No DB work on scroll**: all queries happen off the scroll path.
- **Paint only visible days**: O(V * C) per frame, V = visible segments.
- **Precompute geometry**: stack heights per day when data changes, not per frame.
- **Repaint without rebuild**: use `CustomPaint(repaint: _scrollController)` or
  `ListenableBuilder` so scroll updates invalidate paint only.
- **Bounded memory**: cap loaded history window (e.g., 180 days).
- **Throttle update stream**: avoid frequent rebuilds from notifications.

### Big-O targets

- Initial/LoadMore aggregation: **O(E + L + D)** time, **O(D * C_nonzero)** memory
- Scroll paint: **O(V * C)** per frame (constant in practice)
- UI interactions: **O(1)** per event

### DB load strategy

- Batch `linksForEntryIds` and linked entity lookups to avoid SQLite variable limits.
- Keep ranges small (initial 30 days, increment 14 days).
- Consider `Isolate.run` for aggregation if entry count spikes.

---

## Implementation Phases

### Phase 1: Data Layer & Logic

**Goal**: Build the data infrastructure for loading and aggregating multi-day time data.

**Files to Create**:

| File                                                              | Purpose                    |
|-------------------------------------------------------------------|----------------------------|
| `lib/features/daily_os/state/time_history_header_controller.dart` | Controller with data models |

**Tasks**:
- [x] Define `DayTimeSummary` and `TimeHistoryData` freezed classes
- [x] Implement `TimeHistoryHeaderController` Riverpod provider
- [x] Port aggregation logic from `TimeByCategoryController._fetch()` using
      `dayAtNoon` (DST safe) and sparse category maps
- [x] Implement batched `linksForEntryIds` and linked-entity lookups
- [x] Implement `loadMoreDays()` for incremental backward loading with
      history window cap (180 days)
- [x] Subscribe to `UpdateNotifications` via `getIt<UpdateNotifications>()`
      with throttling (5 seconds)
- [x] Precompute per-day stacked heights on data changes
- [x] Write unit tests for data aggregation (16 tests)
- [x] Test incremental loading produces correct date ranges
- [x] Test category resolution through entry links
- [x] Add `resetToToday()` for returning to initial view after scrolling far
- [x] Add sliding window that drops **newest** days when cap is exceeded

**Verification**:
```bash
fvm flutter test test/features/daily_os/state/time_history_header_controller_test.dart
# All 16 tests pass ✓
```

### Phase 1b: DST-Safe Calendar Arithmetic

**Goal**: Fix Duration-based date arithmetic that's unsafe across DST transitions.

**Problem**: The current implementation uses `Duration` subtraction which can skip/duplicate days around DST transitions:
- `today.subtract(Duration(days: n))` - subtracts 24h durations, not calendar days
- `difference.inDays` followed by `Duration(days: i)` loop - same issue

**Proven Pattern**: `getDaysAtNoon()` in `time_by_category_controller.dart:205-217` uses calendar arithmetic:
```dart
DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day - i, 12)
```

**Files to Modify**:

| File | Location | Change |
|------|----------|--------|
| `lib/features/daily_os/state/time_history_header_controller.dart` | Line 159 | Fix initial date range |
| `lib/features/daily_os/state/time_history_header_controller.dart` | Lines 179-182 | Fix loadMoreDays range |
| `lib/features/daily_os/state/time_history_header_controller.dart` | Lines 372-377 | Fix day bucket generation |

**Tasks**:
- [x] Fix `_fetchInitialData` start date calculation (line 159)
  - Before: `today.subtract(const Duration(days: _initialDays - 1))`
  - After: `DateTime(today.year, today.month, today.day - (_initialDays - 1))`
- [x] Fix `loadMoreDays` range math (lines 179-182)
  - Before: `currentEarliestMidnight.subtract(const Duration(days: n))`
  - After: `DateTime(e.year, e.month, e.day - n)` where `e = current.earliestDay`
- [x] Fix `_aggregateEntries` day generation loop (lines 372-377)
  - Before: `endMidnight.subtract(Duration(days: i))`
  - After: `DateTime(endNoon.year, endNoon.month, endNoon.day - i, 12)`
- [x] Fix `_aggregateEntries` day count calculation (discovered during EU DST testing)
  - Before: `endMidnight.difference(startMidnight).inDays + 1` (DST-unsafe)
  - After: Use UTC dates for difference: `DateTime.utc(end...).difference(DateTime.utc(start...)).inDays + 1`
- [x] Add DST boundary regression tests (5 tests: US spring/fall, EU spring/fall, loadMoreDays)

**New Tests**:
```dart
test('generates correct days across US DST spring forward (March 8, 2026)', () async {
  // Clocks spring forward 2:00 AM -> 3:00 AM
  final dstDay = DateTime(2026, 3, 10, 12);
  final fixedClock = Clock.fixed(dstDay);
  await withClock(fixedClock, () async {
    // ... verify 30 unique days with March 8 present exactly once
  });
});

test('generates correct days across US DST fall back (November 1, 2026)', () async {
  // Clocks fall back 2:00 AM -> 1:00 AM
  final dstDay = DateTime(2026, 11, 3, 12);
  // ... verify 30 unique days with November 1 present exactly once
});

test('loadMoreDays produces exact day count near DST transition', () async {
  // Verify 44 unique days after loadMore near March DST
});
```

**Verification**:
```bash
fvm flutter test test/features/daily_os/state/time_history_header_controller_test.dart
# All 23 tests pass ✓ (18 original + 5 DST boundary tests)

fvm flutter analyze
# No issues found ✓
```

**Design Note**: Entries spanning midnight are attributed to the start day (`dateFrom.dayAtNoon`). This is intentional for header visualization - splitting entries across days would add complexity without improving UX.

---

### Phase 2: Basic UI & Navigation

**Goal**: Implement the swipable header UI skeleton without chart rendering.

**Files to Create**:

| File                                                       | Purpose            |
|------------------------------------------------------------|--------------------|
| `lib/features/daily_os/ui/widgets/time_history_header.dart` | Main header widget |
| `test/features/daily_os/ui/widgets/time_history_header_test.dart` | Widget tests |

**Files to Modify**:

| File                                                  | Changes                                    |
|-------------------------------------------------------|--------------------------------------------|
| `lib/features/daily_os/ui/pages/daily_os_page.dart`   | Replace `DayHeader` with `TimeHistoryHeader` |

**Widget Structure**:
```
TimeHistoryHeader (ConsumerStatefulWidget, 120px height)
├── Container (surfaceContainerHighest background, outlineVariant border)
│   └── Column
│       ├── SizedBox (76px - chart area)
│       │   └── Stack
│       │       ├── Placeholder for CustomPaint (Phase 3)
│       │       └── ListView.builder (reverse: true, horizontal)
│       │           └── _DaySegment (56px width each)
│       └── _DateLabelRow (44px)
│           ├── Date text (tappable → date picker)
│           ├── _DayLabelChip (if present)
│           ├── _StatusIndicator (if budgets exist)
│           └── _TodayButton (if not viewing today)
```

**Providers to Watch**:
- `timeHistoryHeaderControllerProvider` → `TimeHistoryData` (from Phase 1)
- `dailyOsSelectedDateProvider` → selected date for highlighting
- `unifiedDailyOsDataControllerProvider(date:)` → day label for chip
- `dayBudgetStatsProvider(date:)` → status indicator data

**Tasks**:
- [ ] Create `TimeHistoryHeader` ConsumerStatefulWidget with ScrollController
- [ ] Configure `ListView.builder` with `reverse: true`, `scrollDirection: Axis.horizontal`, `itemExtent: 56.0`
- [ ] Implement `_DaySegment` widget:
  - Day number text at bottom
  - Month indicator ("Jan", "Feb") when `day.day == 1`
  - Selection border highlight (primary color, 2px)
  - Semantic label for accessibility
- [ ] Implement scroll listener for load-more at 80% threshold:
  ```dart
  if (position.pixels > position.maxScrollExtent * 0.8) {
    ref.read(timeHistoryHeaderControllerProvider.notifier).loadMoreDays();
  }
  ```
- [ ] Add day segment tap handling → `ref.read(dailyOsSelectedDateProvider.notifier).selectDate(day.day)`
- [ ] Implement `_DateLabelRow` ConsumerWidget:
  - Date text tappable for date picker (reuse `_showDatePicker` from DayHeader)
  - Day name formatting (reuse `_formatDayName` from DayHeader)
  - Date formatting (reuse `_formatDate` from DayHeader)
- [ ] Copy `_DayLabelChip` widget from DayHeader (lines 221-246)
- [ ] Copy `_StatusIndicator` widget from DayHeader (lines 249-327)
- [ ] Implement `_TodayButton`:
  - Visible only when `!_isToday(selectedDate)`
  - Calls `goToToday()` and `_scrollController.animateTo(0, ...)`
- [ ] Implement loading skeleton with 7 placeholder day segments
- [ ] Implement `_LoadingMoreIndicator` (small spinner at left edge when `isLoadingMore`)
- [ ] Update `daily_os_page.dart`:
  - Change import from `day_header.dart` to `time_history_header.dart`
  - Replace `const DayHeader()` with `const TimeHistoryHeader()` (line 38)
- [ ] Write widget tests for:
  - Day segments render for loaded data
  - Day segment tap updates selected date
  - Selection highlight on selected day
  - Month indicator on first of month
  - Loading skeleton during initial load
  - Today button visibility based on selected date
  - Today button scrolls to today
  - Day label chip when present
  - Budget status indicator
  - Date picker opens on date text tap
  - Load-more triggers at 80% scroll threshold
  - Loading indicator when isLoadingMore is true

**Reference Files**:
- `lib/features/daily_os/ui/widgets/day_header.dart` — widgets to reuse
- `test/features/daily_os/ui/widgets/day_header_test.dart` — test patterns

**Verification**:
```bash
fvm flutter analyze
fvm flutter test test/features/daily_os/
```
- Run app, navigate to Daily OS tab
- Verify horizontal scrolling with multiple day segments
- Verify tapping a day updates the selected date
- Verify scrolling left loads more days
- Verify "Today" button scrolls back to current day

### Phase 3: Stream Chart Integration

**Goal**: Implement custom canvas rendering for the stream chart visualization.

**Files to Create**:

| File                                                               | Purpose                       |
|--------------------------------------------------------------------|-------------------------------|
| `lib/features/daily_os/ui/widgets/time_history_chart_painter.dart` | CustomPainter for stream chart |

**Tasks**:

- [ ] Create `TimeHistoryChartPainter` extending `CustomPainter`
- [ ] Implement Y-axis normalization based on `maxDailyTotal`
- [ ] Paint stacked areas with category colors from `EntitiesCacheService`
- [ ] Use quadratic Bezier curves for smooth flow between days
- [ ] Implement symmetric stacking around center baseline
- [ ] Add selection highlight effect for current day column
- [ ] Implement `shouldRepaint` for efficient updates
- [ ] Handle edge cases: empty days, single category, no data
- [ ] Add subtle day boundary separators
- [ ] Write golden tests comparing rendered output
- [ ] Test with varying data densities (empty days, heavy days)
- [ ] Ensure scroll-driven repaint is paint-only (no rebuilds)

**Verification**:
- Run app, navigate to Daily OS tab
- Verify stream chart renders with category colors
- Verify chart flows smoothly across day boundaries
- Verify selected day has visual highlight
- Profile performance during rapid scrolling (target: 60fps)

### Phase 4: Polish & Cleanup

**Goal**: Refine the implementation and remove deprecated code.

**Tasks**:
- [ ] Add smooth scroll-to-selected-date animation when tapping segments
- [ ] Handle edge case: scroll position preservation when loading more days
- [ ] Add loading indicator when fetching additional days
- [ ] Ensure accessibility: semantic labels, adequate tap targets (≥48px)
- [ ] Add haptic feedback on day selection (iOS)
- [ ] Performance optimization: cache category colors lookup
- [ ] Confirm no UI thread work on scroll; move heavy aggregation to isolate if needed
- [ ] Calendar chart removal is a separate feature-level change (dependency);
      do not delete `time_by_category_*` until Calendar is redesigned
- [ ] Full test suite verification
- [ ] Manual testing on multiple screen sizes
- [ ] Update `CHANGELOG.md` and `flatpak/com.matthiasn.lotti.metainfo.xml`

**Files to Remove (after verification)**:
- None in this phase. Calendar chart removal needs a separate plan.

**Verification**:
```bash
fvm flutter analyze
fvm flutter test
```

---

## Technical Decisions

| Question                 | Decision                               | Rationale                                                           |
|--------------------------|----------------------------------------|---------------------------------------------------------------------|
| **Scrolling approach**   | `ListView.builder` with `reverse: true` | Positions today at right edge; efficient memory usage               |
| **Segment width**        | 56 logical pixels                      | Adequate tap target (>48px Material guideline); shows ~6-7 days on phone |
| **Chart library**        | Custom `CustomPainter`                 | Full control, no Graphic library dependency, better performance     |
| **Initial buffer**       | 30 days                                | Matches existing chart default; sufficient for typical use          |
| **Load increment**       | 14 days                                | Balances UX smoothness against database queries                     |
| **Load threshold**       | 80% scroll position                    | Provides buffer for smooth infinite scroll                          |
| **Y-axis normalization** | Max daily total across loaded range    | Consistent scale for comparison                                     |
| **History cap**          | 180 days (configurable)                | Keeps paint + memory bounded                                        |
| **Date arithmetic**      | Calendar arithmetic (day - n), not Duration | Avoids DST artifacts; proven in `getDaysAtNoon()`             |
| **Midnight attribution** | Entry attributed to `dateFrom.dayAtNoon` | Simple, avoids splitting complexity; acceptable for header viz    |

---

## Testing Strategy

### Unit Tests

```dart
group('TimeHistoryHeaderController', () {
  test('initial load fetches 30 days of data');
  test('loadMoreDays fetches 14 additional days');
  test('category aggregation matches TimeByCategoryController logic');
  test('handles empty entries for a day');
  test('maxDailyTotal updates when loading more data');
});
```

### Widget Tests

```dart
group('TimeHistoryHeader', () {
  testWidgets('renders day segments for loaded data');
  testWidgets('tapping day segment updates selected date');
  testWidgets('scrolling triggers loadMoreDays at threshold');
  testWidgets('Today button scrolls to current day');
  testWidgets('selected day has visual highlight');
});
```

### Golden Tests

```dart
group('TimeHistoryChartPainter', () {
  testWidgets('renders stream chart with multiple categories');
  testWidgets('handles empty data gracefully');
  testWidgets('selection highlight renders correctly');
});
```

---

## Risk Assessment

| Risk                                   | Likelihood | Impact | Mitigation                                                       |
|----------------------------------------|------------|--------|------------------------------------------------------------------|
| Scroll position jump when loading more | Medium     | Medium | Calculate offset adjustment after insert                         |
| Performance with large date ranges     | Medium     | Medium | Cap history window; precompute geometry; isolate if needed       |
| Category color inconsistency           | Low        | Low    | Use `EntitiesCacheService` consistently                          |
| Complex position calculations          | Medium     | Medium | Thorough unit tests for coordinate math                          |
| Animation jank during scroll           | Medium     | High   | Paint-only scroll invalidation; avoid rebuilds; RepaintBoundary  |
| DST boundary day count errors          | Medium     | High   | Use calendar arithmetic, not Duration math; add DST tests        |

---

## Success Criteria

1. **Navigation**: Swipe left/right navigates through days fluidly
2. **Infinite Scroll**: Scrolling left loads additional historical days seamlessly
3. **Visual**: Stream chart renders with category colors flowing across days
4. **Selection**: Tapping a day segment selects it and updates the main view
5. **Performance**: 60fps maintained during scrolling
6. **Cleanup**: Daily OS header fully replaced; no dead code in Daily OS
7. **Tests**: All new code covered by unit and widget tests

---

## Future Considerations

### Audio Entry Aggregation

Currently, `JournalAudio` entries are **excluded** from time aggregation to avoid double-counting. The issue is:

1. **Audio during timer**: When a user records audio while a timer is running, both the timer (JournalEntry) and the audio entry have duration. Counting both would inflate the time.

2. **Standalone audio**: Audio recorded without an active timer should probably be counted.

3. **Partial overlap**: An audio entry might partially overlap with a timer entry.

**Future enhancement**: Implement proper overlap detection:
- Check if audio entry's time range overlaps with any JournalEntry linked to the same task
- Only count audio duration for non-overlapping portions
- Consider whether the existing `TimeByCategoryController` also needs this fix

**Note**: The existing `TimeByCategoryController` includes `JournalAudio` (line 113), which may also be incorrect. This should be reviewed as part of a broader fix.

---

## Appendix: Related Code Locations

| Purpose                        | Path                                                              |
|--------------------------------|-------------------------------------------------------------------|
| **Current Day Header**         | `lib/features/daily_os/ui/widgets/day_header.dart`                |
| **Date Selection Provider**    | `lib/features/daily_os/state/daily_os_controller.dart`            |
| **Existing Stream Chart**      | `lib/features/calendar/ui/widgets/time_by_category_chart.dart`    |
| **Existing Chart Controller**  | `lib/features/calendar/state/time_by_category_controller.dart`    |
| **Database Queries**           | `lib/database/database.dart` (`sortedCalendarEntries`)            |
| **Category Colors**            | `lib/services/entities_cache_service.dart`                        |
| **Entry Duration Utility**     | `lib/features/journal/util/entry_tools.dart` (`entryDuration`)    |
| **CustomPainter Pattern**      | `lib/features/daily_os/ui/widgets/zigzag_fold_indicator.dart`     |
| **Daily OS Page**              | `lib/features/daily_os/ui/pages/daily_os_page.dart`               |

---

*This implementation plan will be updated as development progresses.*
