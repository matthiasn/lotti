# Swipable Time History Header — Implementation Plan

**Created**: 2026-01-31
**Status**: Planning
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

| Section | Description |
|---------|-------------|
| **Day Segments** | Fixed-width columns (56px), showing day number, optional month indicator on 1st |
| **Stream Chart** | Stacked area chart flowing across segments, categories colored by definition |
| **Selection Highlight** | Current day has border/glow effect |
| **Date Label** | Full date text below the strip (e.g., "Saturday, January 31, 2026") |
| **Status Indicator** | Budget health chip (on track / near limit / over budget) |
| **Today Button** | Appears when scrolled away from today |

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
  }) = _TimeHistoryData;
}
```

#### 1.2 Controller

**Location**: `lib/features/daily_os/state/time_history_header_controller.dart`

```dart
@riverpod
class TimeHistoryHeaderController extends _$TimeHistoryHeaderController {
  static const int _initialDays = 30;
  static const int _loadMoreDays = 14;
  static const double _loadThreshold = 0.8;  // 80% scroll position triggers load
  static const int _maxLoadedDays = 180;     // Cap to keep memory/paint bounded

  @override
  Future<TimeHistoryData> build() async {
    // Subscribe to database updates for live refresh.
    // Use UpdateNotifications directly (no provider in codebase).
    _listenToUpdates();

    return _fetchInitialData();
  }

  Future<TimeHistoryData> _fetchInitialData() async {
    final today = DateTime.now().dayAtMidnight;
    final startDate = today.subtract(Duration(days: _initialDays - 1));

    return _fetchDataForRange(startDate, today);
  }

  Future<void> loadMoreDays() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    final newEarliest =
        current.earliestDay.subtract(const Duration(days: _loadMoreDays));
    final additionalData = await _fetchDataForRange(
      newEarliest,
      current.earliestDay.subtract(const Duration(days: 1)),
    );

    // Merge with existing data
    final mergedDays = [...current.days, ...additionalData.days];
    final prunedDays = mergedDays.length > _maxLoadedDays
        ? mergedDays.sublist(0, _maxLoadedDays)
        : mergedDays;
    state = AsyncData(
      current.copyWith(
        days: prunedDays,
        earliestDay: newEarliest,
        maxDailyTotal: _max(
          current.maxDailyTotal,
          additionalData.maxDailyTotal,
        ),
        isLoadingMore: false,
        canLoadMore: additionalData.days.isNotEmpty,
      ),
    );
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
  const TimeHistoryChartPainter({
    required this.data,
    required this.selectedDate,
    required this.categoryColors,
    required this.dayWidth,
    required this.visibleDayCount,
    required this.scrollOffset,
  }) : super(repaint: repaint);

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
      ..color = color.withValues(alpha: 0.7)
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
                // Stream chart background
                CustomPaint(
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
                    isSelected: data.days[index].date == selectedDate,
                    onTap: () => _selectDay(data.days[index].date),
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
              '${day.date.day}',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurface,
              ),
            ),
            // Month indicator on 1st
            if (day.date.day == 1)
              Text(
                DateFormat('MMM').format(day.date),
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

**Hard requirements**
- **No DB work on scroll**: all queries happen off the scroll path.
- **Paint only visible days**: O(V * C) per frame, V = visible segments.
- **Precompute geometry**: stack heights per day when data changes, not per frame.
- **Repaint without rebuild**: use `CustomPaint(repaint: _scrollController)` or
  `ListenableBuilder` so scroll updates invalidate paint only.
- **Bounded memory**: cap loaded history window (e.g., 180 days).
- **Throttle update stream**: avoid frequent rebuilds from notifications.

**Big-O targets**
- Initial/LoadMore aggregation: **O(E + L + D)** time, **O(D * C_nonzero)** memory
- Scroll paint: **O(V * C)** per frame (constant in practice)
- UI interactions: **O(1)** per event

**DB load strategy**
- Batch `linksForEntryIds` and linked entity lookups to avoid SQLite variable limits.
- Keep ranges small (initial 30 days, increment 14 days).
- Consider `Isolate.run` for aggregation if entry count spikes.

---

## Implementation Phases

### Phase 1: Data Layer & Logic

**Goal**: Build the data infrastructure for loading and aggregating multi-day time data.

**Files to Create**:
| File | Purpose |
|------|---------|
| `lib/features/daily_os/state/time_history_header_controller.dart` | Controller with data models |

**Tasks**:
- [ ] Define `DayTimeSummary` and `TimeHistoryData` freezed classes
- [ ] Implement `TimeHistoryHeaderController` Riverpod provider
- [ ] Port aggregation logic from `TimeByCategoryController._fetch()` using
      `dayAtNoon` (DST safe) and sparse category maps
- [ ] Implement batched `linksForEntryIds` and linked-entity lookups
- [ ] Implement `loadMoreDays()` for incremental backward loading with
      history window cap (e.g., 180 days)
- [ ] Subscribe to `UpdateNotifications` via `getIt<UpdateNotifications>()`
      with throttling
- [ ] Precompute per-day stacked heights on data changes
- [ ] Write unit tests for data aggregation
- [ ] Test incremental loading produces correct date ranges
- [ ] Test category resolution through entry links

**Verification**:
```bash
fvm flutter test test/features/daily_os/state/time_history_header_controller_test.dart
```

### Phase 2: Basic UI & Navigation

**Goal**: Implement the swipable header UI skeleton without chart rendering.

**Files to Create**:
| File | Purpose |
|------|---------|
| `lib/features/daily_os/ui/widgets/time_history_header.dart` | Main header widget |

**Files to Modify**:
| File | Changes |
|------|---------|
| `lib/features/daily_os/ui/pages/daily_os_page.dart` | Replace `DayHeader` with `TimeHistoryHeader` |

**Tasks**:
- [ ] Create `TimeHistoryHeader` widget with `ListView.builder`
- [ ] Configure `reverse: true` and `scrollDirection: Axis.horizontal`
- [ ] Set `itemExtent: 56.0` for fixed-width day segments
- [ ] Implement `_DaySegment` widget with day number and selection state
- [ ] Implement scroll listener for load-more triggering (80% threshold)
- [ ] Add day segment tap handling → update `dailyOsSelectedDateProvider`
- [ ] Add date label row with full date text
- [ ] Add "Today" button with scroll-to-today animation
- [ ] Preserve existing day label chip, status indicator, and date picker tap
- [ ] Add loading skeleton for initial data fetch
- [ ] Preserve existing status indicator (on track / near limit / over budget)
- [ ] Write widget tests for scroll behavior and day selection

**Verification**:
- Run app, navigate to Daily OS tab
- Verify horizontal scrolling with multiple day segments
- Verify tapping a day updates the selected date
- Verify scrolling left loads more days
- Verify "Today" button scrolls back to current day

### Phase 3: Stream Chart Integration

**Goal**: Implement custom canvas rendering for the stream chart visualization.

**Files to Create**:
| File | Purpose |
|------|---------|
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

| Question | Decision | Rationale |
|----------|----------|-----------|
| **Scrolling approach** | `ListView.builder` with `reverse: true` | Positions today at right edge; efficient memory usage |
| **Segment width** | 56 logical pixels | Adequate tap target (>48px Material guideline); shows ~6-7 days on phone |
| **Chart library** | Custom `CustomPainter` | Full control, no Graphic library dependency, better performance |
| **Initial buffer** | 30 days | Matches existing chart default; sufficient for typical use |
| **Load increment** | 14 days | Balances UX smoothness against database queries |
| **Load threshold** | 80% scroll position | Provides buffer for smooth infinite scroll |
| **Y-axis normalization** | Max daily total across loaded range | Consistent scale for comparison |
| **History cap** | 180 days (configurable) | Keeps paint + memory bounded |

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

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Scroll position jump when loading more | Medium | Medium | Calculate offset adjustment after insert |
| Performance with large date ranges | Medium | Medium | Cap history window; precompute geometry; isolate if needed |
| Category color inconsistency | Low | Low | Use `EntitiesCacheService` consistently |
| Complex position calculations | Medium | Medium | Thorough unit tests for coordinate math |
| Animation jank during scroll | Medium | High | Paint-only scroll invalidation; avoid rebuilds; RepaintBoundary |

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

## Appendix: Related Code Locations

| Purpose | Path |
|---------|------|
| **Current Day Header** | `lib/features/daily_os/ui/widgets/day_header.dart` |
| **Date Selection Provider** | `lib/features/daily_os/state/daily_os_controller.dart` |
| **Existing Stream Chart** | `lib/features/calendar/ui/widgets/time_by_category_chart.dart` |
| **Existing Chart Controller** | `lib/features/calendar/state/time_by_category_controller.dart` |
| **Database Queries** | `lib/database/database.dart` (`sortedCalendarEntries`) |
| **Category Colors** | `lib/services/entities_cache_service.dart` |
| **Entry Duration Utility** | `lib/features/journal/util/entry_tools.dart` (`entryDuration`) |
| **CustomPainter Pattern** | `lib/features/daily_os/ui/widgets/zigzag_fold_indicator.dart` |
| **Daily OS Page** | `lib/features/daily_os/ui/pages/daily_os_page.dart` |

---

*This implementation plan will be updated as development progresses.*
