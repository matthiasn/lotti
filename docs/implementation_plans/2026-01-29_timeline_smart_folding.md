# Timeline Smart Folding — Implementation Plan

**Created**: 2026-01-29
**Status**: Draft
**Epic**: Daily Operating System
**Related Plans**:
- `2026-01-14_daily_os_implementation_plan.md` — Core Daily OS architecture
- `2026-01-14_day_view_design_spec.md` — Design principles (visual humility, reality-first)
- `2026-01-27_calendar_sync_visual_fixes.md` — Unified data controller, lane assignment algorithm

---

## Executive Summary

This plan addresses the blank timeline rendering bug and transforms it into a UX improvement: **Smart Folding**. Instead of showing empty hours (which can waste significant vertical space), the timeline intelligently compresses gaps between activity clusters while maintaining visual continuity.

**Key Innovation**: Rather than completely hiding folded hours, they render as a compressed timeline (8px per hour vs 40px normal) with a zigzag edge pattern—preserving spatial awareness while dramatically reducing wasted space.

---

## Problem Statement

### Current Bug
When viewing the Daily OS Timeline with no entries (or entries only in certain hours), the view renders as a large empty black space without hour markers or grid lines. This appears to be a rendering issue when `TimelineEmptyState` doesn't trigger properly or when bounds calculation results in a valid but empty visual range.

### UX Issue
Even when working correctly, displaying 24 hours of empty timeline creates excessive vertical scrolling. A day with entries at 1 AM and 2 PM would show ~10+ hours of empty space.

---

## Requirements Summary

| Aspect | Decision |
|--------|----------|
| **Approach** | Combined bug fix + smart folding implementation |
| **Fold trigger** | Any gap > 4 hours between entry clusters |
| **Night boundaries** | Before 6 AM / after 10 PM (if no entries) |
| **Entry buffer** | ±1 hour around each entry |
| **Collapsed height** | 8px per hour (vs 40px normal) |
| **Visual style** | Compressed hour lines + zigzag edge indicator |
| **Interaction** | Tap compressed section to expand |
| **Animation** | Smooth expand ~300ms |
| **Persistence** | Reset per day (collapsed by default) |

---

## Technical Design

### 1. Folding Algorithm

The algorithm identifies "visible clusters" and compresses gaps between them.

#### 1.1 Data Model

```dart
/// Represents a time range that should remain visible (not compressed).
class VisibleCluster {
  const VisibleCluster({
    required this.startHour,
    required this.endHour,
  });

  final int startHour;  // Inclusive
  final int endHour;    // Exclusive
}

/// Represents a compressed time range between visible clusters.
class CompressedRegion {
  const CompressedRegion({
    required this.startHour,
    required this.endHour,
    required this.isExpanded,
  });

  final int startHour;
  final int endHour;
  bool isExpanded;

  int get hourCount => endHour - startHour;
}

/// Complete folding state for a day's timeline.
class TimelineFoldingState {
  const TimelineFoldingState({
    required this.visibleClusters,
    required this.compressedRegions,
  });

  final List<VisibleCluster> visibleClusters;
  final List<CompressedRegion> compressedRegions;
}
```

#### 1.2 Clustering Algorithm

**Location**: New utility in `lib/features/daily_os/util/timeline_folding_utils.dart`

```dart
TimelineFoldingState calculateFoldingState({
  required List<PlannedTimeSlot> plannedSlots,
  required List<ActualTimeSlot> actualSlots,
  int gapThreshold = 4,        // Hours
  int bufferHours = 1,         // Buffer around entries
  int defaultDayStart = 6,     // 6 AM
  int defaultDayEnd = 22,      // 10 PM
}) {
  // Step 1: Collect all entry hours with buffer
  final occupiedHours = <int>{};

  for (final slot in [...plannedSlots, ...actualSlots]) {
    final startHour = slot.startTime.hour;
    final endHour = slot.endTime.hour + (slot.endTime.minute > 0 ? 1 : 0);

    // Add buffer
    final bufferedStart = (startHour - bufferHours).clamp(0, 23);
    final bufferedEnd = (endHour + bufferHours).clamp(1, 24);

    for (var h = bufferedStart; h < bufferedEnd; h++) {
      occupiedHours.add(h);
    }
  }

  // Step 2: If no entries, use default day bounds
  if (occupiedHours.isEmpty) {
    return TimelineFoldingState(
      visibleClusters: [VisibleCluster(startHour: defaultDayStart, endHour: defaultDayEnd)],
      compressedRegions: [
        CompressedRegion(startHour: 0, endHour: defaultDayStart, isExpanded: false),
        CompressedRegion(startHour: defaultDayEnd, endHour: 24, isExpanded: false),
      ],
    );
  }

  // Step 3: Build visible clusters from occupied hours
  final sortedHours = occupiedHours.toList()..sort();
  final clusters = <VisibleCluster>[];

  var clusterStart = sortedHours.first;
  var clusterEnd = clusterStart + 1;

  for (var i = 1; i < sortedHours.length; i++) {
    final hour = sortedHours[i];
    if (hour <= clusterEnd) {
      // Extend current cluster
      clusterEnd = hour + 1;
    } else {
      // Finalize current cluster, start new one
      clusters.add(VisibleCluster(startHour: clusterStart, endHour: clusterEnd));
      clusterStart = hour;
      clusterEnd = hour + 1;
    }
  }
  // Add final cluster
  clusters.add(VisibleCluster(startHour: clusterStart, endHour: clusterEnd));

  // Step 4: Identify compressed regions (gaps > threshold)
  final compressed = <CompressedRegion>[];

  // Before first cluster
  if (clusters.first.startHour > 0) {
    compressed.add(CompressedRegion(
      startHour: 0,
      endHour: clusters.first.startHour,
      isExpanded: false,
    ));
  }

  // Between clusters
  for (var i = 0; i < clusters.length - 1; i++) {
    final gap = clusters[i + 1].startHour - clusters[i].endHour;
    if (gap >= gapThreshold) {
      compressed.add(CompressedRegion(
        startHour: clusters[i].endHour,
        endHour: clusters[i + 1].startHour,
        isExpanded: false,
      ));
    } else {
      // Merge adjacent clusters if gap is small
      clusters[i] = VisibleCluster(
        startHour: clusters[i].startHour,
        endHour: clusters[i + 1].endHour,
      );
      clusters.removeAt(i + 1);
      i--; // Re-check this cluster
    }
  }

  // After last cluster
  if (clusters.last.endHour < 24) {
    compressed.add(CompressedRegion(
      startHour: clusters.last.endHour,
      endHour: 24,
      isExpanded: false,
    ));
  }

  return TimelineFoldingState(
    visibleClusters: clusters,
    compressedRegions: compressed.where((r) => r.hourCount >= gapThreshold).toList(),
  );
}
```

### 2. Zigzag Visual Design

**Location**: New CustomPainter in `lib/features/daily_os/ui/widgets/zigzag_fold_indicator.dart`

The zigzag pattern runs along the left edge of compressed regions, creating a visual "torn paper" effect that signals hidden/compressed content.

```dart
class ZigzagFoldPainter extends CustomPainter {
  const ZigzagFoldPainter({
    required this.color,
    required this.zigzagWidth,
    required this.zigzagHeight,
    this.strokeWidth = 1.5,
  });

  final Color color;
  final double zigzagWidth;   // Width of each zigzag peak (e.g., 8px)
  final double zigzagHeight;  // Height of each zigzag peak (e.g., 6px)
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    var y = 0.0;
    var goingRight = true;

    // Start at top-left
    path.moveTo(0, 0);

    while (y < size.height) {
      final nextY = (y + zigzagHeight).clamp(0.0, size.height);
      final x = goingRight ? zigzagWidth : 0.0;
      path.lineTo(x, nextY);
      y = nextY;
      goingRight = !goingRight;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ZigzagFoldPainter oldDelegate) {
    return color != oldDelegate.color ||
        zigzagWidth != oldDelegate.zigzagWidth ||
        zigzagHeight != oldDelegate.zigzagHeight;
  }
}
```

### 3. Compressed Region Widget

**Location**: New widget in `lib/features/daily_os/ui/widgets/compressed_timeline_region.dart`

```dart
class CompressedTimelineRegion extends StatelessWidget {
  const CompressedTimelineRegion({
    required this.region,
    required this.onTap,
    super.key,
  });

  final CompressedRegion region;
  final VoidCallback onTap;

  static const double compressedHourHeight = 8.0;  // vs 40px normal
  static const double zigzagWidth = 10.0;

  @override
  Widget build(BuildContext context) {
    final totalHeight = region.hourCount * compressedHourHeight;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: totalHeight,
        child: Row(
          children: [
            // Zigzag indicator on left edge
            SizedBox(
              width: zigzagWidth,
              child: CustomPaint(
                painter: ZigzagFoldPainter(
                  color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  zigzagWidth: 6,
                  zigzagHeight: 4,
                ),
                size: Size(zigzagWidth, totalHeight),
              ),
            ),

            // Compressed hour lines
            Expanded(
              child: Stack(
                children: [
                  // Background tint
                  Container(
                    color: context.colorScheme.surfaceContainerLow
                        .withValues(alpha: 0.5),
                  ),

                  // Compressed hour markers
                  ...List.generate(region.hourCount, (i) {
                    final hour = region.startHour + i;
                    return Positioned(
                      top: i * compressedHourHeight,
                      left: 0,
                      right: 0,
                      child: _CompressedHourLine(hour: hour),
                    );
                  }),

                  // Expand hint
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${region.startHour}:00 - ${region.endHour}:00',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompressedHourLine extends StatelessWidget {
  const _CompressedHourLine({required this.hour});

  final int hour;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: context.colorScheme.outlineVariant.withValues(alpha: 0.15),
    );
  }
}
```

### 4. State Management

**Location**: Extend existing `DailyOsController` in `lib/features/daily_os/state/daily_os_controller.dart`

```dart
// Add to DailyOsState
@freezed
class DailyOsState with _$DailyOsState {
  const factory DailyOsState({
    required DateTime selectedDate,
    String? expandedBudgetId,
    String? highlightedCategoryId,
    @Default({}) Set<int> expandedFoldRegions,  // NEW: Set of startHour values
  }) = _DailyOsState;
}

// Add methods to DailyOsController
extension DailyOsControllerFolding on DailyOsController {
  void toggleFoldRegion(int startHour) {
    final current = state.expandedFoldRegions;
    final updated = current.contains(startHour)
        ? {...current}..remove(startHour)
        : {...current, startHour};
    state = state.copyWith(expandedFoldRegions: updated);
  }

  void resetFoldState() {
    state = state.copyWith(expandedFoldRegions: {});
  }
}
```

### 5. Timeline Widget Modifications

**Location**: Modify `lib/features/daily_os/ui/widgets/daily_timeline.dart`

Key changes to `_TimelineContent`:

```dart
class _TimelineContent extends ConsumerWidget {
  const _TimelineContent({required this.data});

  final DailyTimelineData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedRegions = ref.watch(
      dailyOsControllerProvider.select((s) => s.expandedFoldRegions),
    );

    // Calculate folding state
    final foldingState = calculateFoldingState(
      plannedSlots: data.plannedSlots,
      actualSlots: data.actualSlots,
    );

    // Build timeline sections (visible clusters + compressed regions)
    final sections = _buildTimelineSections(
      foldingState: foldingState,
      expandedRegions: expandedRegions,
      data: data,
    );

    // Calculate total height
    final totalHeight = sections.fold<double>(
      0,
      (sum, section) => sum + section.height,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (unchanged)
        _buildHeader(context),

        // Timeline grid with folding
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
          height: totalHeight + 20,
          decoration: _buildContainerDecoration(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            child: Stack(
              children: [
                // Render each section
                ..._buildSectionWidgets(sections, context, ref),

                // Current time indicator (if visible)
                if (_isToday(data.date))
                  _CurrentTimeIndicator(
                    startHour: foldingState.visibleClusters.first.startHour,
                    foldingState: foldingState,
                    expandedRegions: expandedRegions,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

### 6. Animation

Use `AnimatedContainer` and `TweenAnimationBuilder` for smooth expand/collapse:

```dart
class _AnimatedTimelineRegion extends StatelessWidget {
  const _AnimatedTimelineRegion({
    required this.region,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  final CompressedRegion region;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final collapsedHeight = region.hourCount * 8.0;
    final expandedHeight = region.hourCount * DailyTimeline._hourHeight;

    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: isExpanded ? collapsedHeight : expandedHeight,
        end: isExpanded ? expandedHeight : collapsedHeight,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, height, _) {
        return SizedBox(
          height: height,
          child: child,
        );
      },
    );
  }
}
```

---

## Implementation Phases

### Phase 1: Foundation & Bug Fix

- [ ] Create `lib/features/daily_os/util/timeline_folding_utils.dart`
  - [ ] Implement `calculateFoldingState()` algorithm
  - [ ] Add unit tests for clustering logic
  - [ ] Test edge cases: no entries, single entry, adjacent entries, midnight crossing

- [ ] Diagnose blank timeline bug
  - [ ] Add logging to identify when empty state triggers
  - [ ] Verify hour grid line generation logic
  - [ ] Fix any rendering issues found

### Phase 2: Visual Components

- [ ] Create `lib/features/daily_os/ui/widgets/zigzag_fold_indicator.dart`
  - [ ] Implement `ZigzagFoldPainter` CustomPainter
  - [ ] Test with different heights and colors

- [ ] Create `lib/features/daily_os/ui/widgets/compressed_timeline_region.dart`
  - [ ] Implement compressed hour lines
  - [ ] Add time range label
  - [ ] Style to match existing dark theme

### Phase 3: State & Integration

- [ ] Extend `DailyOsController` with fold state
  - [ ] Add `expandedFoldRegions` to state
  - [ ] Implement `toggleFoldRegion()` method
  - [ ] Reset fold state on date change

- [ ] Modify `_TimelineContent` in `daily_timeline.dart`
  - [ ] Integrate folding algorithm
  - [ ] Build section-based rendering
  - [ ] Wire up tap-to-expand interaction

### Phase 4: Animation & Polish

- [ ] Add expand/collapse animation
  - [ ] Use `TweenAnimationBuilder` for height animation
  - [ ] Ensure smooth 300ms transition

- [ ] Update current time indicator
  - [ ] Account for folded regions in position calculation
  - [ ] Hide if in collapsed region, show in expanded

- [ ] Accessibility
  - [ ] Add semantics labels to compressed regions
  - [ ] Ensure tap target meets minimum size (48px)

### Phase 5: Testing & Verification

- [ ] Unit tests
  - [ ] Folding algorithm with various entry patterns
  - [ ] Edge cases: empty day, full day, single entry

- [ ] Widget tests
  - [ ] Compressed region renders correctly
  - [ ] Tap expands/collapses region
  - [ ] Animation completes properly

- [ ] Integration testing
  - [ ] Run app with real data
  - [ ] Verify folding behavior across different days
  - [ ] Test with midnight-crossing entries

---

## Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| `lib/features/daily_os/util/timeline_folding_utils.dart` | Folding algorithm |
| `lib/features/daily_os/ui/widgets/zigzag_fold_indicator.dart` | Zigzag CustomPainter |
| `lib/features/daily_os/ui/widgets/compressed_timeline_region.dart` | Compressed region widget |
| `test/features/daily_os/util/timeline_folding_utils_test.dart` | Algorithm unit tests |

### Modified Files

| File | Changes |
|------|---------|
| `lib/features/daily_os/state/daily_os_controller.dart` | Add fold state management |
| `lib/features/daily_os/ui/widgets/daily_timeline.dart` | Integrate folding into rendering |

---

## Testing Strategy

### Unit Tests

```dart
group('TimelineFoldingUtils', () {
  test('empty day shows default 6AM-10PM with compressed regions', () {
    final state = calculateFoldingState(plannedSlots: [], actualSlots: []);

    expect(state.visibleClusters, hasLength(1));
    expect(state.visibleClusters.first.startHour, 6);
    expect(state.visibleClusters.first.endHour, 22);
    expect(state.compressedRegions, hasLength(2));  // 0-6, 22-24
  });

  test('entry at 1AM creates morning cluster', () {
    final slots = [_makeSlot(hour: 1, duration: 30)];
    final state = calculateFoldingState(plannedSlots: [], actualSlots: slots);

    // Should have cluster 0-3 (1AM with ±1 hour buffer)
    expect(state.visibleClusters.first.startHour, 0);
    expect(state.visibleClusters.first.endHour, 3);
  });

  test('entries at 1AM and 2PM create two clusters with compressed gap', () {
    final slots = [
      _makeSlot(hour: 1, duration: 30),
      _makeSlot(hour: 14, duration: 60),
    ];
    final state = calculateFoldingState(plannedSlots: [], actualSlots: slots);

    expect(state.visibleClusters, hasLength(2));
    expect(state.compressedRegions.any((r) => r.startHour == 3 && r.endHour == 13), isTrue);
  });

  test('adjacent entries within 4 hours merge into single cluster', () {
    final slots = [
      _makeSlot(hour: 9, duration: 60),
      _makeSlot(hour: 12, duration: 60),  // 3 hour gap, < 4 threshold
    ];
    final state = calculateFoldingState(plannedSlots: [], actualSlots: slots);

    expect(state.visibleClusters, hasLength(1));  // Merged
    expect(state.visibleClusters.first.startHour, 8);  // 9 - 1 buffer
    expect(state.visibleClusters.first.endHour, 14);   // 13 + 1 buffer
  });
});
```

### Widget Tests

```dart
testWidgets('CompressedTimelineRegion shows time range label', (tester) async {
  final region = CompressedRegion(startHour: 3, endHour: 13, isExpanded: false);

  await tester.pumpWidget(
    MaterialApp(
      home: CompressedTimelineRegion(
        region: region,
        onTap: () {},
      ),
    ),
  );

  expect(find.text('3:00 - 13:00'), findsOneWidget);
});

testWidgets('tapping compressed region calls onTap', (tester) async {
  var tapped = false;
  final region = CompressedRegion(startHour: 0, endHour: 6, isExpanded: false);

  await tester.pumpWidget(
    MaterialApp(
      home: CompressedTimelineRegion(
        region: region,
        onTap: () => tapped = true,
      ),
    ),
  );

  await tester.tap(find.byType(CompressedTimelineRegion));
  expect(tapped, isTrue);
});
```

---

## Visual Mockup

```
Normal Timeline (current):
┌────────────────────────────────────────┐
│ 00:00 ─────────────────────────────────│  40px
│ 01:00 ───[Entry]───────────────────────│  40px
│ 02:00 ─────────────────────────────────│  40px
│ 03:00 ─────────────────────────────────│  40px
│ ...                                     │
│ 13:00 ─────────────────────────────────│  40px
│ 14:00 ───[Entry]───────────────────────│  40px
│ 15:00 ─────────────────────────────────│  40px
│ ...                                     │
└────────────────────────────────────────┘
Total: 24 × 40px = 960px

Smart Folded Timeline (proposed):
┌────────────────────────────────────────┐
│ 00:00 ─────────────────────────────────│  40px
│ 01:00 ───[Entry]───────────────────────│  40px
│ 02:00 ─────────────────────────────────│  40px
├╱╲╱╲╱╲─ 03:00-13:00 ─────────── tap ────│  80px (10hr × 8px)
│ 13:00 ─────────────────────────────────│  40px
│ 14:00 ───[Entry]───────────────────────│  40px
│ 15:00 ─────────────────────────────────│  40px
├╱╲╱╲╱╲─ 16:00-24:00 ─────────── tap ────│  64px (8hr × 8px)
└────────────────────────────────────────┘
Total: 6 × 40px + 144px = 384px (60% reduction!)
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Complex position calculations | Medium | Medium | Thorough unit tests for folding algorithm |
| Animation jank | Low | Low | Use hardware-accelerated animations |
| Current time indicator misplaced | Medium | Medium | Calculate position accounting for all regions |
| Accessibility issues | Low | Medium | Ensure tap targets ≥48px, add semantics |

---

## Success Criteria

1. **Bug Fixed**: Timeline renders hour markers and grid when entries exist
2. **Folding Works**: Gaps > 4 hours are compressed by default
3. **Visual Continuity**: Hour lines visible in compressed regions at 8px scale
4. **Interaction**: Tap on compressed region expands to full height
5. **Animation**: Smooth 300ms expand/collapse transition
6. **No Regression**: All existing timeline tests pass
7. **Performance**: No noticeable lag when switching dates

---

## Appendix: Related Code Locations

| Purpose | Path |
|---------|------|
| Daily Timeline Widget | `lib/features/daily_os/ui/widgets/daily_timeline.dart` |
| Unified Data Controller | `lib/features/daily_os/state/unified_daily_os_data_controller.dart` |
| Daily OS Controller | `lib/features/daily_os/state/daily_os_controller.dart` |
| Timeline Data Models | `lib/features/daily_os/state/timeline_data_controller.dart` |
| Empty State Painters | `lib/features/daily_os/ui/widgets/daily_os_empty_states.dart` |
| App Theme Constants | `lib/themes/theme.dart` |
