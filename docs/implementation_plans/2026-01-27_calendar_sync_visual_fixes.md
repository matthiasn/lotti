# Implementation Plan: Calendar View Sync and Visual Fixes

**Date:** 2026-01-27
**Status:** PARTIALLY COMPLETE
**Epic:** Daily Operating System
**Related PR:** #2580 (Calendar Refresh Fix - provides context on visibility-based refresh pattern)

---

## Implementation Status

### Completed (v0.9.825)

- [x] **Phase 1: Unified Daily OS Data Controller** - COMPLETE
  - Created `UnifiedDailyOsDataController` with `ref.keepAlive()` + manual `StreamSubscription`
  - Consolidated day plan, timeline data, and budget progress into single atomic state
  - All UI components now update together when data changes
  - Updated all widget tests to use the unified controller
  - Added comprehensive unit tests for the unified controller (27 tests)

- [x] **Controller Cleanup** - COMPLETE
  - Removed `TimelineDataController` class (kept data types: `TimelineSlot`, `PlannedTimeSlot`, `ActualTimeSlot`, `DailyTimelineData`)
  - Removed `TimeBudgetProgressController` class (kept data types: `BudgetProgressStatus`, `TimeBudgetProgress`, `DayBudgetStats`, `dayBudgetStatsProvider`)
  - Deleted generated files for removed controllers
  - Deleted obsolete test file that used removed `timeBudgetProgressControllerProvider`

- [x] **Test Coverage** - COMPLETE
  - Added `unified_daily_os_data_controller_test.dart` with 27 tests covering:
    - Budget progress status calculation (underBudget, nearLimit, exhausted, overBudget)
    - Timeline data building (planned slots, actual slots, sorting)
    - Day bounds calculation (start/end hours with buffer)
    - Midnight crossing handling (entries/blocks ending on next day)
    - Linked entry category resolution (parent category takes precedence)
    - DayBudgetStats aggregation

- [x] **Phase 3: Overlapping Entries (Option A)** - COMPLETE
  - Implemented greedy lane assignment algorithm in `_assignLanes()`
  - Non-overlapping entries share the same lane (full width)
  - Overlapping entries placed in adjacent lanes with equal widths
  - Small gap (2px) between lanes for visual separation
  - Added 8 widget tests covering various overlap scenarios
  - Edge cases handled: single entry, identical times, back-to-back entries, lane reuse

### Pending

- [ ] **Phase 2: Remove Tracked Labels** - ALREADY COMPLETE (done in previous session)
  - Text labels removed from actual blocks in `_ActualBlockWidget`
  - Category name preserved via `Semantics` widget for accessibility

---

## Executive Summary

This plan addresses three critical issues in the Daily OS Calendar View:
1. **Auto-Update Failure** - UI not reflecting real-time data changes from sync or local creation
2. **Visual Clutter** - Text labels on tracked entries overflowing into adjacent entries
3. **Overlapping Entries** - Entries stacked illegibly when times overlap

---

## 1. Investigation Strategy: Tracing Broken Update Signals

### Current Architecture Analysis

Based on code exploration, the update system works as follows:

```
Data Change (local or sync)
    ↓
PersistenceLogic.createDbEntity() / SyncEventProcessor
    ↓
UpdateNotifications.notify(affectedIds, fromSync: bool)
    ↓ (debounced: 100ms local, 1000ms sync)
UpdateNotifications.updateStream (broadcast)
    ↓
Controllers subscribe:
    - TimelineDataController._listen() → re-fetches on ANY notification
    - DayPlanController._listen() → filters for dayPlanNotification + specific plan ID
    - TimeBudgetProgressController → uses ref.watch(dayPlanControllerProvider)
```

### Root Cause Identification

**Issue 1: TimeBudgetProgressController Does NOT Listen to Calendar Entry Changes**

Location: `lib/features/daily_os/state/time_budget_progress_controller.dart:76-78`

```dart
@override
Future<List<TimeBudgetProgress>> build({required DateTime date}) async {
  final dayPlanEntity = await ref.watch(
    dayPlanControllerProvider(date: date).future,  // Only watches day plan!
  );
  // ... fetches calendar entries but doesn't watch for their changes
}
```

**Problem:** The `TimeBudgetProgressController` only watches the `dayPlanControllerProvider`. When a new time entry is created (e.g., recording time on a task), the day plan doesn't change - only the calendar entries do. Therefore, the budget progress bars NEVER update automatically when time is recorded.

**Issue 2: Missing Direct Stream Listener in TimeBudgetProgressController**

Unlike `TimelineDataController` which has `_listen()` method subscribing to `UpdateNotifications.updateStream`, the `TimeBudgetProgressController` relies entirely on Riverpod's `ref.watch()` mechanism - but it only watches the day plan, not the calendar entries.

**Issue 3: Potential Race Condition in TimelineDataController**

Location: `lib/features/daily_os/state/timeline_data_controller.dart:253-255`

```dart
final result = await _fetchData();
_listen();  // Listener starts AFTER initial fetch completes
return result;
```

If an update notification arrives during the initial fetch, it could be missed because the listener isn't set up yet.

### Verification Steps

1. Add logging to `UpdateNotifications.notify()` to confirm notifications are firing
2. Add logging to `TimelineDataController._listen()` to confirm it receives notifications
3. Add logging to `TimeBudgetProgressController.build()` to confirm when it rebuilds
4. Test creating a time entry and observe which controllers update

---

## 2. Proposed Fix for Auto-Update System

### 2.1 Riverpod 3 Automatic Pausing Behavior

**Critical Context:** Riverpod 3.x introduces automatic listener pausing based on `TickerMode`:

- When a widget is not visible, its `ref.watch`/`ref.listen` subscriptions are **paused**
- A provider is "paused" if ALL its listeners are paused
- `StreamProvider` pauses its `StreamSubscription` when not actively listened
- There is **no global setting** to disable this behavior

**Key Insight:** Manual Dart `StreamSubscription`s (like our `UpdateNotifications.updateStream.listen()`) are **NOT** affected by Riverpod's pausing - they're pure Dart streams. However, if the provider itself is **disposed** (not just paused), the subscription is cancelled.

**Solution:** Use `ref.keepAlive()` to prevent disposal, and own the stream subscription manually.

**References:**
- [Riverpod 3.0 Migration Guide](https://riverpod.dev/docs/3.0_migration)
- [What's New in Riverpod 3.0](https://riverpod.dev/docs/whats_new)
- [GitHub Issue #2671](https://github.com/rrousselGit/riverpod/issues/2671)

### 2.2 Architecture: Unified Daily OS Data Controller (RECOMMENDED)

Instead of patching individual controllers, we'll create a **unified data controller** that owns all data fetching and streaming.

#### Current Architecture (Problematic)

```
DailyOsController
    ↓ ref.watch (PAUSED when not visible!)
├─ dayPlanControllerProvider
├─ timeBudgetProgressControllerProvider (no stream listener!)
└─ timelineDataControllerProvider
```

#### New Architecture (Recommended)

```
UnifiedDailyOsDataController
    ├─ ref.keepAlive() → prevents disposal
    ├─ StreamSubscription → UpdateNotifications.updateStream (NOT paused)
    ├─ _fetchAllData() → fetches plan + entries + links atomically
    └─ state = AsyncData(DailyOsData) → single source of truth
```

#### Implementation Design

**File:** `lib/features/daily_os/state/unified_daily_os_data_controller.dart`

```dart
@riverpod
class UnifiedDailyOsDataController extends _$UnifiedDailyOsDataController {
  late DateTime _date;
  StreamSubscription<Set<String>>? _updateSubscription;
  bool _isDisposed = false;

  @override
  Future<DailyOsData> build({required DateTime date}) async {
    _date = date;
    _isDisposed = false;

    // CRITICAL: Keep alive to prevent disposal when navigating away
    ref.keepAlive();

    ref.onDispose(() {
      _isDisposed = true;
      _updateSubscription?.cancel();
    });

    // Start listening BEFORE fetch
    _listen();
    return _fetchAllData();
  }

  void _listen() {
    final notifications = getIt<UpdateNotifications>();
    _updateSubscription = notifications.updateStream.listen((_) async {
      if (_isDisposed) return;

      try {
        final data = await _fetchAllData();
        if (!_isDisposed) {
          state = AsyncData(data);
        }
      } catch (e, stackTrace) {
        if (_isDisposed) return;
        getIt<LoggingService>().captureException(
          e,
          domain: 'unified_daily_os_data_controller',
          subDomain: '_listen',
          stackTrace: stackTrace,
        );
      }
    });
  }

  Future<DailyOsData> _fetchAllData() async {
    final db = getIt<JournalDb>();
    final dayPlanRepository = getIt<DayPlanRepository>();
    final dayStart = _date.dayAtMidnight;
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Fetch all data in parallel
    final results = await Future.wait([
      dayPlanRepository.getOrCreateDayPlan(_date),
      db.sortedCalendarEntries(rangeStart: dayStart, rangeEnd: dayEnd),
    ]);

    final dayPlan = results[0] as DayPlanEntry;
    final entries = results[1] as List<JournalEntity>;

    // Fetch links for entries
    final entryIds = entries.map((e) => e.meta.id).toSet();
    final links = await db.linksForEntryIds(entryIds);
    // ... build timeline slots and budget progress from raw data ...

    return DailyOsData(
      date: _date,
      dayPlan: dayPlan,
      timelineData: timelineData,
      budgetProgress: budgetProgress,
    );
  }
}
```

#### Data Model

```dart
/// Combined data for Daily OS view - single source of truth.
class DailyOsData {
  const DailyOsData({
    required this.date,
    required this.dayPlan,
    required this.timelineData,
    required this.budgetProgress,
  });

  final DateTime date;
  final DayPlanEntry dayPlan;
  final DailyTimelineData timelineData;
  final List<TimeBudgetProgress> budgetProgress;
}
```

### 2.3 Alternative: Patch Individual Controllers (FALLBACK)

If the unified approach proves too risky, here's the fallback fix:

#### Fix A: Add Stream Listener to TimeBudgetProgressController

**File:** `lib/features/daily_os/state/time_budget_progress_controller.dart`

Add the same listener pattern used in `TimelineDataController`:

```dart
@riverpod
class TimeBudgetProgressController extends _$TimeBudgetProgressController {
  late DateTime _date;
  StreamSubscription<Set<String>>? _updateSubscription;
  bool _isDisposed = false;

  void _listen() {
    final notifications = getIt<UpdateNotifications>();
    _updateSubscription = notifications.updateStream.listen((_) async {
      if (_isDisposed) return;

      try {
        // Re-fetch and rebuild state when any entries change
        state = const AsyncLoading();
        final data = await _fetchBudgetProgress();
        if (!_isDisposed) {
          state = AsyncData(data);
        }
      } catch (e, stackTrace) {
        if (_isDisposed) return;
        getIt<LoggingService>().captureException(
          e,
          domain: 'time_budget_progress_controller',
          subDomain: '_listen',
          stackTrace: stackTrace,
        );
      }
    });
  }

  @override
  Future<List<TimeBudgetProgress>> build({required DateTime date}) async {
    _date = date;
    _isDisposed = false;

    ref.onDispose(() {
      _isDisposed = true;
      _updateSubscription?.cancel();
    });

    // Start listener before fetch (fixed order)
    _listen();
    return _fetchBudgetProgress();
  }

  Future<List<TimeBudgetProgress>> _fetchBudgetProgress() async {
    // Move current build() logic here
    // ...existing fetch logic...
  }
}
```

### Fix B: Fix Listener Order in TimelineDataController

**File:** `lib/features/daily_os/state/timeline_data_controller.dart:253-255`

Change from:
```dart
final result = await _fetchData();
_listen();
return result;
```

To:
```dart
_listen();  // Start listening BEFORE fetch to avoid missing updates
return _fetchData();
```

### Fix C: Add DayBudgetStats Provider Invalidation

The `dayBudgetStatsProvider` also needs to invalidate when budget progress updates. Since it uses `ref.watch(timeBudgetProgressControllerProvider)`, it should automatically rebuild, but we should verify this chain works correctly.

### PRIMARY FIX: Unified Daily OS Data Controller

After investigating Riverpod 3's automatic pausing behavior (see Section 2.1 below), the recommended approach is to create a **unified data controller** that:

1. Uses `ref.keepAlive()` to prevent disposal when navigating away
2. Owns a single `StreamSubscription` to `UpdateNotifications.updateStream`
3. Fetches ALL data directly (day plan, calendar entries, links) rather than watching sub-controllers
4. Updates state atomically when any relevant notification arrives

This solves multiple problems at once:
- Riverpod 3 pausing doesn't affect manual `StreamSubscription`s
- Single listener ensures consistent state across all UI components
- `keepAlive()` ensures the controller persists through navigation
- Data is fresh when user returns to the page

---

## 3. Frontend Changes: Remove Tracked Labels

### Requirement

Remove text labels from the **tracked/actual** side of the timeline only. The planned side should retain labels.

### Implementation

**File:** `lib/features/daily_os/ui/widgets/daily_timeline.dart`

**Location:** `_ActualBlockWidget.build()` (lines 337-465)

**Current Code (lines 438-448):**
```dart
child: Text(
  title,
  style: context.textTheme.labelSmall?.copyWith(
    color: _getTextColor(categoryColor),
    fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

**Proposed Change:**
```dart
// Remove text child entirely - show only colored block
child: const SizedBox.shrink(),
```

Or, for better accessibility, keep the text but make it invisible while preserving semantics:
```dart
child: Semantics(
  label: title,
  child: const SizedBox.shrink(),
),
```

### Additional Cleanup

Also remove the `_getEntryTitle()` helper method (lines 453-458) and the `title` variable calculation (lines 363-366) since they become unused:

```dart
// REMOVE these lines:
final title = _getEntryTitle(
  slot.entry,
  category?.name ?? context.messages.dailyOsEntry,
);
```

### Visual Verification

After implementation, verify:
- Planned blocks (left lane) still show category names
- Actual blocks (right lane) show only colored rectangles
- Short entries no longer have overflowing text
- Tap/long-press interactions still work on actual blocks

---

## 4. Feasibility Report: Multi-Lane Overlap Feature

### Current State

The Daily Timeline currently renders all actual entries in a single lane using a simple `Stack` widget:

```dart
// lib/features/daily_os/ui/widgets/daily_timeline.dart:218-225
Positioned(
  // ... actual blocks lane
  child: Stack(
    children: data.actualSlots.map((slot) {
      return _ActualBlockWidget(...);
    }).toList(),
  ),
),
```

When entries overlap, they render on top of each other with no visual separation.

### Old Calendar Approach

The old calendar view (`lib/features/calendar/ui/pages/day_view_page.dart`) uses the external `calendar_view` package (v1.2.0) which has built-in overlap handling via its `EventArranger` system. **There is no custom lane logic in the Lotti codebase.**

### Implementation Options

#### Option A: Simple Horizontal Offset (Low Complexity)

**Approach:** Detect overlaps and offset each overlapping entry horizontally by a fixed amount.

**Algorithm:**
```dart
List<List<ActualTimeSlot>> assignLanes(List<ActualTimeSlot> slots) {
  final lanes = <List<ActualTimeSlot>>[];

  for (final slot in slots.sortedBy((s) => s.startTime)) {
    // Find first lane where this slot doesn't overlap
    var placed = false;
    for (final lane in lanes) {
      final lastInLane = lane.last;
      if (slot.startTime.isAfter(lastInLane.endTime) ||
          slot.startTime.isAtSameMomentAs(lastInLane.endTime)) {
        lane.add(slot);
        placed = true;
        break;
      }
    }
    if (!placed) {
      lanes.add([slot]);
    }
  }
  return lanes;
}
```

**Rendering:**
```dart
final lanes = assignLanes(data.actualSlots);
final laneWidth = availableWidth / lanes.length;

for (var i = 0; i < lanes.length; i++) {
  for (final slot in lanes[i]) {
    // Position at left: i * laneWidth, width: laneWidth
  }
}
```

**Effort Estimate:** 2-4 hours
**Pros:** Simple, predictable, similar to calendar apps
**Cons:** Narrow entries when many overlaps; fixed lane widths

#### Option B: Dynamic Width Allocation (Medium Complexity)

**Approach:** Calculate overlap groups and dynamically allocate widths.

**Algorithm:**
1. Group overlapping entries into "conflict groups"
2. Within each group, assign lanes using greedy algorithm
3. Render each group with proportional lane widths

**Effort Estimate:** 4-8 hours
**Pros:** Better space utilization
**Cons:** More complex positioning math; potential edge cases

#### Option C: Use calendar_view Package (Low Complexity)

**Approach:** Replace custom timeline with `calendar_view`'s `DayView` widget.

**Effort Estimate:** 2-4 hours for basic integration
**Pros:** Battle-tested overlap handling; consistent with old calendar
**Cons:** May not match design spec's dual-lane layout; less customization control

### Recommendation

**For immediate fix:** Implement **Option A (Simple Horizontal Offset)**

**Rationale:**
- Directly addresses the visual stacking problem
- Low risk of regression
- Can be implemented alongside the label removal
- Provides clear visual separation without major architectural changes

**For follow-up:** If more sophisticated handling is needed, Option B can be implemented as an enhancement, or the timeline could be migrated to use `calendar_view` package components.

### Complexity Assessment

| Aspect | Option A | Option B | Option C |
|--------|----------|----------|----------|
| Code changes | ~50-100 lines | ~150-250 lines | ~100-150 lines |
| Risk | Low | Medium | Medium |
| Time | 2-4 hours | 4-8 hours | 2-4 hours |
| Customization | High | High | Low |
| Maintenance | Low | Medium | Low (external) |

---

## 5. Step-by-Step Execution Plan

### Phase 1: Unified Daily OS Data Controller (Priority)

**Step 1.1:** Create new unified data controller
- Create `lib/features/daily_os/state/unified_daily_os_data_controller.dart`
- Define `DailyOsData` class combining all view data
- Implement `UnifiedDailyOsDataController` with:
  - `ref.keepAlive()` to prevent disposal
  - Manual `StreamSubscription` to `UpdateNotifications.updateStream`
  - `_fetchAllData()` method that queries DB directly
  - `_listen()` called BEFORE initial fetch

**Step 1.2:** Implement data fetching logic
- Fetch day plan from `DayPlanRepository`
- Fetch calendar entries from `JournalDb.sortedCalendarEntries()`
- Fetch links from `JournalDb.linksForEntryIds()`
- Build `PlannedTimeSlot` list from day plan blocks
- Build `ActualTimeSlot` list from entries + links
- Build `TimeBudgetProgress` list by grouping entries by category

**Step 1.3:** Update UI to use unified controller
- Update `DailyOsPage` to watch `unifiedDailyOsDataControllerProvider`
- Update `DailyTimeline` to use data from unified controller
- Update `TimeBudgetList` to use data from unified controller
- Update `DaySummary` to use data from unified controller

**Step 1.4:** Update existing `DailyOsController`
- Modify to watch `unifiedDailyOsDataControllerProvider` instead of individual controllers
- Keep UI state (highlighting, expanded sections) in `DailyOsController`
- Data comes from unified controller

**Step 1.5:** Test the fix
- Create a time entry locally → verify all components update
- Navigate away and back → verify data is fresh
- Wait for sync → verify all components update
- Verify no duplicate updates or infinite loops

**Step 1.6:** Deprecate old controllers (optional follow-up)
- Mark `TimelineDataController` as deprecated if no other consumers
- Mark `TimeBudgetProgressController` as deprecated if no other consumers
- Keep `DayPlanController` for plan mutations

### Phase 2: Visual Fix - Remove Tracked Labels

**Step 2.1:** Modify `_ActualBlockWidget`
- Remove text content from the container
- Keep semantics label for accessibility
- Remove unused `_getEntryTitle()` method
- Remove unused `title` variable

**Step 2.2:** Visual testing
- Verify short entries render as clean color blocks
- Verify no text overflow issues
- Verify tap interactions still work
- Verify accessibility (screen reader announces entry info)

### Phase 3: Overlapping Entries - Option A (Simple Horizontal Offset)

**Step 3.1:** Create lane assignment utility
- Create `_assignLanes()` function in `daily_timeline.dart`
- Algorithm: greedy assignment, slots sorted by start time
- Return `List<List<ActualTimeSlot>>` where each inner list is a lane

**Step 3.2:** Update timeline rendering
- Calculate lane count from `_assignLanes()` result
- Compute lane width: `availableWidth / laneCount`
- Update `_ActualBlockWidget` to accept `laneIndex` and `laneCount` parameters
- Position each block at: `left: laneIndex * laneWidth`, `width: laneWidth`

**Step 3.3:** Handle edge cases
- Single entry: full width (laneCount = 1)
- Many overlaps: minimum width threshold (e.g., 40px)
- If too narrow, allow overlap rather than making entries unusable

### Phase 4: Verification & Cleanup

**Step 4.1:** Run analyzer
```bash
fvm dart analyze
```

**Step 4.2:** Run formatter
```bash
fvm dart format .
```

**Step 4.3:** Run related tests
```bash
fvm flutter test test/features/daily_os/
```

**Step 4.4:** Manual testing
- Test on device with real data
- Verify sync updates work
- Verify visual improvements

---

## 6. Files to Modify

| File | Changes |
|------|---------|
| `lib/features/daily_os/state/unified_daily_os_data_controller.dart` | **NEW** - Unified data controller with keepAlive + stream listener |
| `lib/features/daily_os/state/daily_os_controller.dart` | Update to watch unified controller for data |
| `lib/features/daily_os/ui/pages/daily_os_page.dart` | Update to use unified controller |
| `lib/features/daily_os/ui/widgets/daily_timeline.dart` | Remove tracked labels, add lane assignment logic |
| `lib/features/daily_os/ui/widgets/time_budget_list.dart` | Update data source to unified controller |
| `lib/features/daily_os/ui/widgets/day_summary.dart` | Update data source to unified controller |

## 7. Testing Strategy

### Unit Tests

Add/verify tests for:
- `TimeBudgetProgressController` updates when notifications fire
- `TimelineDataController` updates when notifications fire
- Lane assignment algorithm (if implementing overlap handling)

### Widget Tests

- Verify `_ActualBlockWidget` renders without text
- Verify `_PlannedBlockWidget` still renders with text
- Verify highlight behavior still works

### Integration Tests

- Create time entry → verify all UI sections update
- Simulate sync → verify all UI sections update

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Excessive re-renders causing performance issues | Medium | Medium | Add throttling if needed; monitor with DevTools |
| Listener memory leak | Low | High | Proper disposal in `ref.onDispose()` |
| Race condition in initialization | Low | Medium | Start listener before fetch |
| Breaking existing functionality | Low | High | Thorough testing; preserve all existing behavior |

---

## 9. Success Criteria

1. **Auto-Update:**
   - Creating a time entry immediately updates the timeline visualization
   - Creating a time entry immediately updates the budget progress bars
   - Synced entries update the UI within the debounce window (1 second)

2. **Visual:**
   - Tracked entries show as clean colored blocks without text
   - No text overflow between adjacent entries
   - Planned entries still show category labels

3. **Overlap (if implemented):**
   - Overlapping entries are visually distinguishable
   - Each entry can be tapped/selected independently

---

## Appendix: Key Code Locations

- **UpdateNotifications:** `lib/services/db_notification.dart`
- **TimelineDataController:** `lib/features/daily_os/state/timeline_data_controller.dart`
- **TimeBudgetProgressController:** `lib/features/daily_os/state/time_budget_progress_controller.dart`
- **DayPlanController:** `lib/features/daily_os/state/day_plan_controller.dart`
- **DailyTimeline Widget:** `lib/features/daily_os/ui/widgets/daily_timeline.dart`
- **PersistenceLogic (notifications):** `lib/logic/persistence_logic.dart:467`
- **SyncEventProcessor (notifications):** `lib/features/sync/matrix/sync_event_processor.dart:894`
