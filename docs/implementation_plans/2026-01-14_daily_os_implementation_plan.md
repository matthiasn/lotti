# Daily Operating System — Implementation Plan

**Created**: 2026-01-14
**Updated**: 2026-01-15
**Status**: Phase 3 Complete — UI Implementation Done
**Design Spec**: `2026-01-14_day_view_design_spec.md`

---

## Executive Summary

This document provides a detailed implementation plan for the "Daily Operating System" feature in Lotti. The feature replaces the traditional calendar view with a philosophy-driven system separating **planning** (intention), **doing** (actual record), and **accountability** (budgets).

The implementation follows a **parallel development strategy** — building alongside the existing calendar without breaking current functionality.

---

## Current Progress Summary

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1: Foundation | ✅ Complete | Data models, database integration, repository |
| Phase 2: State Management | ✅ Complete | Riverpod providers, aggregation logic |
| Phase 3: UI Implementation | ✅ Complete | All widgets, navigation integration |
| Phase 4: Smart Features | 🔲 Not Started | Status notifier, auto-population, agreement workflow |
| Phase 5: Polish | 🔲 Not Started | Empty states, animations, edge cases |

### Files Created

**Data Layer:**
- `lib/classes/day_plan.dart` — DayPlanData, DayPlanStatus, TimeBudget, PlannedBlock, PinnedTaskRef
- `lib/features/daily_os/repository/day_plan_repository.dart`

**State Management:**
- `lib/features/daily_os/state/daily_os_controller.dart` — Date selection provider
- `lib/features/daily_os/state/day_plan_controller.dart` — DayPlan CRUD operations
- `lib/features/daily_os/state/time_budget_progress_controller.dart` — Budget aggregation
- `lib/features/daily_os/state/timeline_data_controller.dart` — Timeline data aggregation

**UI Components:**
- `lib/features/daily_os/ui/pages/daily_os_page.dart` — Main page scaffold
- `lib/features/daily_os/ui/widgets/day_header.dart` — Date navigation, status
- `lib/features/daily_os/ui/widgets/daily_timeline.dart` — Plan vs actual visualization
- `lib/features/daily_os/ui/widgets/time_budget_list.dart` — Budget list container
- `lib/features/daily_os/ui/widgets/time_budget_card.dart` — Individual budget cards
- `lib/features/daily_os/ui/widgets/day_summary.dart` — Day totals and actions

**Navigation:**
- `lib/beamer/locations/daily_os_location.dart` — Beamer route
- `lib/features/calendar/state/calendar_view_mode_controller.dart` — View toggle state
- `lib/features/calendar/ui/pages/calendar_wrapper_page.dart` — Toggle between Classic/Daily OS

**Tests:**
- `test/features/daily_os/state/day_plan_controller_test.dart`
- `test/features/daily_os/state/time_budget_progress_controller_test.dart`

### How to Access

The Daily OS view is accessible via the **Calendar tab**. A toggle button appears in the top-right corner allowing users to switch between:
- **Classic** — Traditional calendar day view
- **Daily OS** — New budget-based planning view

---

## Table of Contents

1. [Data Modeling](#1-data-modeling)
2. [Architecture](#2-architecture)
3. [Migration Strategy](#3-migration-strategy)
4. [Step-by-Step Execution](#4-step-by-step-execution)
5. [Testing Strategy](#5-testing-strategy)
6. [Risk Assessment](#6-risk-assessment)

---

## 1. Data Modeling

### 1.1 Design Decision: JournalEntity Integration

**Key insight:** Rather than creating new database tables, DayPlan is implemented as a new `JournalEntity` variant. This provides:

- Automatic sync via existing vector clock infrastructure
- No schema migrations for new tables
- Consistent patterns with existing entity types (Task, HabitCompletion, etc.)
- Embedded data structures (like Checklist embeds item references)

**Uniqueness enforcement:** Deterministic ID based on date (`dayplan-2026-01-14`) guarantees one plan per day via primary key constraint. Concurrent creation on multiple offline devices is caught by vector clock conflict detection.

### 1.2 Core Entities

#### JournalEntity.dayPlan (New Variant)

Add to `lib/classes/journal_entities.dart`:

```dart
const factory JournalEntity.dayPlan({
  required Metadata meta,
  required DayPlanData data,
  EntryText? entryText,                        // For reflection notes
  Geolocation? geolocation,
}) = DayPlan;
```

#### DayPlanData

Add to `lib/classes/day_plan.dart`:

```dart
@freezed
class DayPlanData with _$DayPlanData {
  const factory DayPlanData({
    required DateTime planDate,                // The day this plan is for (at midnight)
    required DayPlanStatus status,             // draft/agreed/needsReview
    String? dayLabel,                          // e.g., "Focused Workday", "Recovery Day"
    DateTime? completedAt,                     // When day was marked complete
    @Default([]) List<PlannedBlock> plannedBlocks,  // Embedded timeline blocks
    @Default([]) List<PinnedTaskRef> pinnedTasks,   // References to pinned tasks
  }) = _DayPlanData;

  factory DayPlanData.fromJson(Map<String, dynamic> json) =>
      _$DayPlanDataFromJson(json);
}

// Note: Time budgets are NOT stored in DayPlanData. Instead, they are derived
// at runtime from planned blocks grouped by category. See DerivedTimeBudget
// in lib/classes/day_plan.dart and TimeBudgetProgress computed by
// time_budget_progress_controller.dart. This simplifies the data model and
// ensures budgets always reflect the current block configuration.

/// Generates deterministic ID for a day's plan
String dayPlanId(DateTime date) =>
    'dayplan-${date.toIso8601String().substring(0, 10)}';
```

#### DayPlanStatus State Machine

```dart
@freezed
sealed class DayPlanStatus with _$DayPlanStatus {
  /// Initial state - plan exists but not yet committed to
  const factory DayPlanStatus.draft() = DayPlanStatusDraft;

  /// User has agreed to this plan
  const factory DayPlanStatus.agreed({
    required DateTime agreedAt,
  }) = DayPlanStatusAgreed;

  /// Plan needs review (new tasks added, budgets changed, etc.)
  const factory DayPlanStatus.needsReview({
    required DateTime triggeredAt,
    required DayPlanReviewReason reason,
    DateTime? previouslyAgreedAt,              // When it was last agreed
  }) = DayPlanStatusNeedsReview;

  factory DayPlanStatus.fromJson(Map<String, dynamic> json) =>
      _$DayPlanStatusFromJson(json);
}

enum DayPlanReviewReason {
  newDueTask,           // A task with due date was added for this day
  budgetModified,       // A time budget was changed
  taskRescheduled,      // A task was moved to this day
  manualReset,          // User requested review
}
```

#### TimeBudget (Embedded)

```dart
@freezed
class TimeBudget with _$TimeBudget {
  const factory TimeBudget({
    required String id,                        // UUID for internal reference
    required String categoryId,                // Links to CategoryDefinition
    required int plannedMinutes,               // Duration in minutes (JSON-friendly)
    @Default(0) int sortOrder,                 // Display order in budget list
  }) = _TimeBudget;

  factory TimeBudget.fromJson(Map<String, dynamic> json) =>
      _$TimeBudgetFromJson(json);
}

extension TimeBudgetX on TimeBudget {
  Duration get plannedDuration => Duration(minutes: plannedMinutes);
}
```

#### PlannedBlock (Embedded)

```dart
@freezed
class PlannedBlock with _$PlannedBlock {
  const factory PlannedBlock({
    required String id,                        // UUID for internal reference
    required String categoryId,                // Which category this block is for
    required DateTime startTime,               // When block starts
    required DateTime endTime,                 // When block ends
    String? note,                              // Optional note on the block
  }) = _PlannedBlock;

  factory PlannedBlock.fromJson(Map<String, dynamic> json) =>
      _$PlannedBlockFromJson(json);
}
```

#### PinnedTaskRef (Embedded Reference)

```dart
@freezed
class PinnedTaskRef with _$PinnedTaskRef {
  const factory PinnedTaskRef({
    required String taskId,                    // References Task entity by ID
    required String budgetId,                  // Which budget this is pinned to
    @Default(0) int sortOrder,                 // Display order within budget
  }) = _PinnedTaskRef;

  factory PinnedTaskRef.fromJson(Map<String, dynamic> json) =>
      _$PinnedTaskRefFromJson(json);
}
```

### 1.2 Computed Aggregates (Not Stored, Derived)

```dart
@freezed
class TimeBudgetProgress with _$TimeBudgetProgress {
  const factory TimeBudgetProgress({
    required TimeBudget budget,
    required CategoryDefinition category,
    required Duration plannedDuration,
    required Duration recordedDuration,        // Sum of actual time entries
    required Duration remainingDuration,       // May be negative (over budget)
    required BudgetProgressStatus status,
    required List<JournalEntity> contributingEntries,  // Actual time entries
    required List<Task> pinnedTasks,           // Tasks pinned to this budget
    required List<Task> recordedTasks,         // Tasks with time in this budget
  }) = _TimeBudgetProgress;
}

enum BudgetProgressStatus {
  underBudget,          // > 15 minutes remaining
  nearLimit,            // 0-15 minutes remaining
  exhausted,            // Exactly 0 remaining
  overBudget,           // Negative remaining (went over)
}
```

### 1.3 Database Integration

**No new tables required.** DayPlan entities are stored in the existing `journal` table:

- `type` = `'DayPlan'`
- `subtype` = date string (e.g., `'2026-01-14'`) for efficient querying
- `serialized` = full JSON including embedded budgets, blocks, pinned tasks

**Query for day's plan:**

```sql
-- Add to database.drift
dayPlanForDate:
SELECT * FROM journal
  WHERE type = 'DayPlan'
  AND id = :id
  AND deleted = false;

dayPlansInRange:
SELECT * FROM journal
  WHERE type = 'DayPlan'
  AND deleted = false
  AND date_from >= :rangeStart
  AND date_to <= :rangeEnd
  ORDER BY date_from DESC;
```

### 1.4 State Machine Transitions

```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    ▼                                     │
    ┌──────────┐  agree()  ┌──────────┐                  │
    │  DRAFT   │─────────►│  AGREED  │                  │
    └──────────┘           └──────────┘                  │
         │                      │                        │
         │                      │ [trigger event]        │
         │                      │ - newDueTask           │
         │                      │ - budgetModified       │
         │                      │ - taskRescheduled      │
         │                      ▼                        │
         │               ┌─────────────┐    agree()      │
         └──────────────►│NEEDS_REVIEW │─────────────────┘
                         └─────────────┘
```

**Trigger Events for NeedsReview**:
1. **newDueTask**: A task's `due` date is set to this day after plan was agreed
2. **budgetModified**: Time budget duration changed after agreement
3. **taskRescheduled**: Task moved to this day from another day
4. **manualReset**: User explicitly requests review

---

## 2. Architecture

### 2.1 Feature Module Structure

```
lib/features/daily_os/
├── repository/
│   └── day_plan_repository.dart              # CRUD for DayPlan (single file, embedded data)
├── state/
│   ├── daily_os_controller.dart              # Main orchestrating provider
│   ├── day_plan_controller.dart              # DayPlan state management
│   ├── time_budget_controller.dart           # Budget aggregation & progress
│   ├── timeline_controller.dart              # Combined plan vs actual data
│   ├── day_status_notifier.dart              # Watches for NeedsReview triggers
│   └── providers.dart                        # All provider exports
├── ui/
│   ├── pages/
│   │   └── daily_os_page.dart                # Main page widget
│   ├── sections/
│   │   ├── day_header_section.dart           # Section A
│   │   ├── timeline_section.dart             # Section B
│   │   ├── budget_section.dart               # Section C
│   │   └── summary_section.dart              # Section D
│   └── widgets/
│       ├── day_header/
│       │   ├── day_header.dart
│       │   └── day_status_chip.dart
│       ├── timeline/
│       │   ├── daily_timeline.dart
│       │   ├── time_axis.dart
│       │   ├── planned_time_lane.dart
│       │   ├── actual_time_lane.dart
│       │   ├── planned_block_widget.dart
│       │   └── actual_block_widget.dart
│       ├── budget/
│       │   ├── time_budget_list.dart
│       │   ├── time_budget_card.dart
│       │   ├── budget_progress_bar.dart
│       │   ├── budget_task_list.dart
│       │   └── budget_boundary_indicator.dart
│       └── summary/
│           ├── day_summary.dart
│           └── day_summary_stats.dart
└── util/
    ├── budget_calculator.dart                # Duration arithmetic
    └── timeline_builder.dart                 # Builds combined timeline data
```

### 2.2 Riverpod Provider Architecture

```dart
// ============================================================================
// FOUNDATION PROVIDERS (Data Layer)
// ============================================================================

/// Provides the DayPlan for a specific date, creating one if needed
@riverpod
Future<DayPlan> dayPlan(Ref ref, DateTime date) async {
  final repo = ref.watch(dayPlanRepositoryProvider);
  return repo.getOrCreateForDate(date.dayAtMidnight);
}

/// Watches for changes that should trigger NeedsReview
@Riverpod(keepAlive: true)
class DayStatusNotifier extends _$DayStatusNotifier {
  // Listens to:
  // - Task due date changes
  // - Budget modifications
  // - Task category reassignments
  // Triggers: status transition to NeedsReview when needed
}

// ============================================================================
// AGGREGATION PROVIDERS (Business Logic Layer)
// ============================================================================

/// Aggregates time budgets with their progress for a day
@riverpod
Future<List<TimeBudgetProgress>> timeBudgetProgress(
  Ref ref,
  DateTime date,
) async {
  final dayPlan = await ref.watch(dayPlanProvider(date).future);
  final budgets = await ref.watch(timeBudgetsForDayProvider(dayPlan.id).future);
  final entries = await ref.watch(calendarEntriesForDayProvider(date).future);

  return _calculateProgress(budgets, entries);
}

/// Provides combined timeline data (planned + actual)
@riverpod
Future<TimelineData> timelineData(Ref ref, DateTime date) async {
  final dayPlan = await ref.watch(dayPlanProvider(date).future);
  final plannedBlocks = await ref.watch(plannedBlocksProvider(dayPlan.id).future);
  final actualEntries = await ref.watch(calendarEntriesForDayProvider(date).future);

  return TimelineData(
    plannedBlocks: plannedBlocks,
    actualEntries: actualEntries,
  );
}

/// Tasks due on a specific day (auto-appears in budgets)
@riverpod
Future<List<Task>> tasksDueOnDay(Ref ref, DateTime date) async {
  final db = ref.watch(journalDbProvider);
  return db.getTasksDueOn(date);
}

// ============================================================================
// UI STATE PROVIDERS (Presentation Layer)
// ============================================================================

/// Main controller for the Daily OS page
@Riverpod(keepAlive: true)
class DailyOsController extends _$DailyOsController {
  @override
  DailyOsState build() {
    // Watch the selected day from existing DaySelectionController
    final selectedDay = ref.watch(daySelectionControllerProvider);

    return DailyOsState(
      selectedDate: selectedDay,
      expandedBudgetId: null,
      highlightedCategoryId: null,
    );
  }

  void selectDate(DateTime date) { ... }
  void expandBudget(String budgetId) { ... }
  void highlightCategory(String categoryId) { ... }
}
```

### 2.3 View Architecture (3-Section Layout)

```dart
class DailyOsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyOsControllerProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Section A: Day Header (optionally sticky)
          SliverPersistentHeader(
            pinned: true,
            delegate: DayHeaderDelegate(date: state.selectedDate),
          ),

          // Section B: Timeline (Plan vs Actual)
          SliverToBoxAdapter(
            child: TimelineSection(date: state.selectedDate),
          ),

          // Section C: Time Budgets
          SliverToBoxAdapter(
            child: BudgetSection(date: state.selectedDate),
          ),

          // Section D: Day Summary
          SliverToBoxAdapter(
            child: SummarySection(date: state.selectedDate),
          ),

          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      floatingActionButton: _buildFab(context, ref),
    );
  }
}
```

### 2.4 Cross-Component Communication

```
┌─────────────────────────────────────────────────────────────────┐
│                     DailyOsController                           │
│  (Manages: selectedDate, expandedBudgetId, highlightedCategory) │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
    ┌──────────┐       ┌──────────┐       ┌──────────┐
    │ Timeline │◄─────►│ Budgets  │◄─────►│ Summary  │
    │ Section  │       │ Section  │       │ Section  │
    └──────────┘       └──────────┘       └──────────┘
          │                   │
          │   tap planned     │   tap budget
          │   block           │   card
          └─────────┬─────────┘
                    │
                    ▼
         [highlightCategory(id)]
         - Timeline highlights related blocks
         - Budget card expands/highlights
```

**Interaction Flow: Tap Planned Block → Highlight Budget**
```dart
// In PlannedBlockWidget
onTap: () {
  ref.read(dailyOsControllerProvider.notifier)
     .highlightCategory(block.categoryId);
}

// In TimeBudgetCard
Widget build(context, ref) {
  final state = ref.watch(dailyOsControllerProvider);
  final isHighlighted = state.highlightedCategoryId == budget.categoryId;

  return AnimatedContainer(
    decoration: BoxDecoration(
      border: isHighlighted
        ? Border.all(color: categoryColor, width: 2)
        : null,
    ),
    child: ...
  );
}
```

---

## 3. Migration Strategy

### 3.1 Guiding Principles

1. **Zero Breaking Changes**: Existing calendar must remain fully functional
2. **No Shared Mutable State**: New feature has independent state management
3. **Feature Flag**: Hidden behind settings flag until ready
4. **Data Independence**: New tables, no modifications to existing schema
5. **Gradual Rollout**: Can be enabled per-user for testing

### 3.2 Implementation Phases

```
Phase 1: Foundation (No UI visible)
├── Database schema additions (new tables only)
├── Repository layer for new entities
├── Core providers (dayPlan, timeBudget)
└── Unit tests for data layer

Phase 2: Read-Only View
├── Basic DailyOsPage scaffold
├── Timeline section (read actual entries)
├── Budget section (read categories, show aggregates)
└── Integration with existing calendar entries

Phase 3: Planning Features
├── Create/edit time budgets
├── Create/edit planned blocks
├── Pin tasks to budgets
└── Agreement workflow

Phase 4: Smart Features
├── DayStatusNotifier (NeedsReview triggers)
├── Auto-populate budgets from due tasks
├── Day completion workflow
└── Budget copy to next day

Phase 5: Polish & Transition
├── Empty states and edge cases
├── Animations and transitions
├── Settings to switch default view
└── Deprecation path for old calendar
```

### 3.3 Navigation Strategy

```dart
// lib/beamer/locations/daily_os_location.dart
class DailyOsLocation extends BeamLocation<BeamState> {
  @override
  List<Pattern> get pathPatterns => ['/daily-os'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      BeamPage(
        key: const ValueKey('daily-os'),
        title: 'Daily OS',
        child: const DailyOsPage(),
      ),
    ];
  }
}

// Add to lib/beamer/beamer_app.dart
// Feature flag check:
if (settingsService.dailyOsEnabled) {
  locations.add(DailyOsLocation());
}
```

### 3.4 Settings Integration

```dart
// In settings, add toggle for Daily OS
// When enabled: show Daily OS in navigation
// When disabled: show classic Calendar
// Default: disabled (during development)
```

### 3.5 Data Migration (Future)

When transitioning fully:
1. Existing calendar entries remain unchanged
2. Users can manually create DayPlans
3. No automatic migration of historical data
4. Historical view falls back to calendar view

---

## 4. Step-by-Step Execution

### Phase 1: Foundation (Data Layer) ✅ COMPLETE

#### 1.1 Data Models
- [x] Create `lib/classes/day_plan.dart` with all Freezed classes:
  - [x] `DayPlanData`
  - [x] `DayPlanStatus` (sealed class with draft/agreed/needsReview)
  - [x] `TimeBudget` (embedded)
  - [x] `PlannedBlock` (embedded)
  - [x] `PinnedTaskRef` (embedded reference)
  - [x] `dayPlanId()` helper function
- [x] Add `JournalEntity.dayPlan` variant to `journal_entities.dart`
- [x] Update `JournalEntityExtension.affectedIds` for DayPlan
- [x] Generate Freezed code (`fvm flutter pub run build_runner build`)
- [x] Write serialization round-trip tests

#### 1.2 Database Integration
- [x] Add `dayPlanForDate` query to `database.drift`
- [x] Add `dayPlansInRange` query to `database.drift`
- [x] Add `getDayPlanById()` method to `JournalDb`
- [x] Add `getDayPlansInRange()` method to `JournalDb`
- [x] Generate Drift code
- [x] Write query tests

#### 1.3 Repository
- [x] Create `lib/features/daily_os/repository/day_plan_repository.dart`
- [x] Implement `getOrCreateForDate(DateTime date)` — creates with deterministic ID if missing
- [x] Implement `save(DayPlan plan)` — upserts via existing persistence
- [x] Implement `watchDayPlan(DateTime date)` — stream for reactivity
- [x] Write repository unit tests

### Phase 2: State Management ✅ COMPLETE

#### 2.1 Core Providers
- [x] Create `dayPlanControllerProvider` family
- [x] Create `dailyOsSelectedDateProvider`
- [x] Create providers for budgets/blocks/pinned tasks (embedded in DayPlan)
- [x] Generate Riverpod code
- [x] Write provider unit tests

#### 2.2 Aggregation Providers
- [x] Create `timeBudgetProgressControllerProvider` (calculates used vs planned)
- [x] Create `timelineDataControllerProvider` (combines plan + actual)
- [x] Create `dayBudgetStatsProvider` (summary numbers)
- [x] Write aggregation logic tests (18 tests passing)

#### 2.3 UI State
- [x] Create `DailyOsController` (date selection, navigation)
- [x] Implement provider architecture for cross-component communication
- [x] Write controller tests

### Phase 3: UI Implementation ✅ COMPLETE

#### 3.1 Page Structure
- [x] Create `DailyOsPage` scaffold (`lib/features/daily_os/ui/pages/daily_os_page.dart`)
- [x] Implement scrollable Column with sections
- [x] Add navigation via `CalendarWrapperPage` toggle button
- [x] View mode toggle between Classic and Daily OS (`CalendarViewModeController`)

#### 3.2 Section A: Day Header
- [x] Create `DayHeader` widget (`lib/features/daily_os/ui/widgets/day_header.dart`)
- [x] Implement date display with format (day name + full date)
- [x] Add day label chip (optional, from DayPlan)
- [x] Add status indicator (on track / over budget / near limit)
- [x] Implement swipe left/right for day change
- [x] Implement tap for date picker
- [x] Add "Today" button when not on current day
- [ ] Write widget tests

#### 3.3 Section B: Timeline
- [x] Create `DailyTimeline` container widget (`lib/features/daily_os/ui/widgets/daily_timeline.dart`)
- [x] Create time axis with hour labels
- [x] Create planned lane (left side, ghosted blocks)
- [x] Create actual lane (right side, solid blocks with category colors)
- [x] Create `_PlannedBlockWidget` (translucent with border)
- [x] Create `_ActualBlockWidget` (solid with shadow, tappable to navigate)
- [x] Add current time indicator (red line on today)
- [x] Add legend showing Plan vs Actual
- [ ] Implement tap → highlight related budget
- [ ] Implement long-press → edit planned block
- [ ] Write widget tests

#### 3.4 Section C: Time Budgets
- [x] Create `TimeBudgetList` container (`lib/features/daily_os/ui/widgets/time_budget_list.dart`)
- [x] Create `TimeBudgetCard` widget (`lib/features/daily_os/ui/widgets/time_budget_card.dart`)
- [x] Create `_BudgetProgressBar` widget (shows over-budget indicator)
- [x] Create contributing entries preview (expandable)
- [x] Add status text (time remaining / over budget)
- [x] Add summary chip showing total recorded/planned
- [ ] Implement tap → highlight timeline blocks
- [ ] Write widget tests

#### 3.5 Section D: Day Summary
- [x] Create `DaySummary` widget (`lib/features/daily_os/ui/widgets/day_summary.dart`)
- [x] Display total planned vs recorded time
- [x] Display remaining/over time
- [x] Show overall progress bar
- [x] Add "Done for today" action button
- [x] Add "Copy to tomorrow" action button (placeholder)
- [x] Show completion message when day is marked complete
- [ ] Write widget tests

### Phase 4: Smart Features

#### 4.1 Status Notifier
- [ ] Create `DayStatusNotifier` provider
- [ ] Implement task due date change detection
- [ ] Implement budget modification detection
- [ ] Implement task reschedule detection
- [ ] Trigger NeedsReview state transition
- [ ] Write notifier tests

#### 4.2 Auto-Population
- [ ] Auto-add due tasks to appropriate budgets
- [ ] Create budget suggestions from due tasks
- [ ] Handle category assignment for unassigned tasks

#### 4.3 Agreement Workflow
- [ ] Implement "Agree to Plan" action
- [ ] Store agreement timestamp
- [ ] Show NeedsReview alert (non-intrusive)
- [ ] Implement re-agreement flow

#### 4.4 Day Completion
- [ ] Implement "Mark Day Complete" action
- [ ] Generate reflection prompt (optional)
- [ ] Copy budgets to next day

### Phase 5: Polish

#### 5.1 Empty States
- [ ] No budgets → show creation prompt
- [ ] No planned blocks → timeline works anyway
- [ ] No recorded time → show pinned tasks
- [ ] New day → show previous day's template option

#### 5.2 Visual Polish
- [ ] Implement category color theming
- [ ] Add micro-animations for state changes
- [ ] Implement cover art thumbnails for tasks
- [ ] Add warm color escalation for over-budget

#### 5.3 Edge Cases
- [ ] Handle timezone changes gracefully
- [ ] Handle midnight boundary for running timers
- [ ] Handle deleted categories
- [ ] Handle orphaned budgets

---

## 5. Testing Strategy

### 5.1 Unit Tests

```dart
// Test categories:
group('DayPlan State Machine', () {
  test('transitions from Draft to Agreed on agree()');
  test('transitions from Agreed to NeedsReview when due task added');
  test('transitions from NeedsReview back to Agreed on agree()');
  test('preserves previouslyAgreedAt when entering NeedsReview');
});

group('TimeBudgetProgress Calculation', () {
  test('calculates remaining time correctly');
  test('identifies over-budget status');
  test('aggregates multiple entries to same category');
  test('handles entries spanning midnight');
});

group('Timeline Data Builder', () {
  test('combines planned blocks with actual entries');
  test('handles overlapping planned blocks');
  test('orders entries chronologically');
});
```

### 5.2 Widget Tests

```dart
group('DayHeader', () {
  testWidgets('displays formatted date');
  testWidgets('shows day label when set');
  testWidgets('responds to swipe gestures');
});

group('TimeBudgetCard', () {
  testWidgets('shows progress bar at correct fill level');
  testWidgets('highlights when category is selected');
  testWidgets('expands to show task list');
});

group('DailyTimeline', () {
  testWidgets('renders planned blocks in left lane');
  testWidgets('renders actual blocks in right lane');
  testWidgets('scrolls to current time on initial load');
});
```

### 5.3 Integration Tests

```dart
group('Daily OS Integration', () {
  testWidgets('creating budget reflects in timeline');
  testWidgets('recording time updates budget progress live');
  testWidgets('agreeing to plan changes status chip');
  testWidgets('adding due task triggers NeedsReview');
});
```

### 5.4 Test Time Policy

Per `test/README.md`:
- Use `fakeAsync` for all time-dependent logic
- Use `tester.pump(duration)` for widget tests
- Never use `Future.delayed` or `sleep` in tests
- Use specific dates, not `DateTime.now()`

---

## 6. Risk Assessment

### 6.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Performance with many entries | Medium | High | Use pagination, lazy loading, visibility detection |
| State synchronization complexity | Medium | Medium | Clear provider dependencies, comprehensive tests |
| Embedded data merge conflicts | Low | Medium | Vector clock handles it; test conflict scenarios |
| Riverpod circular dependencies | Low | Medium | Careful provider architecture, code review |

### 6.2 UX Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Overwhelming new users | Medium | Medium | Progressive disclosure, sensible defaults |
| Confusion with old calendar | Medium | Low | Clear navigation, feature flag |
| Over-notification on NeedsReview | Medium | Medium | Debounce triggers, user-controlled sensitivity |

### 6.3 Schedule Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Scope creep in "smart" features | High | Medium | Strict phase boundaries, defer nice-to-haves |
| Integration with existing code | Medium | Medium | Parallel implementation, no shared mutable state |

---

## Appendix A: Related Files

| Purpose | Path |
|---------|------|
| Design Spec | `docs/implementation_plans/2026-01-14_day_view_design_spec.md` |
| Existing Calendar | `lib/features/calendar/` |
| Journal Entities | `lib/classes/journal_entities.dart` |
| Task Models | `lib/classes/task.dart` |
| Categories | `lib/classes/entity_definitions.dart` |
| Habits (pattern ref) | `lib/features/habits/` |
| Database Schema | `lib/database/database.drift` |
| Day Selection | `lib/features/calendar/state/day_selection_controller.dart` |
| Time Aggregation | `lib/features/calendar/state/time_by_category_controller.dart` |

### Daily OS Feature Files (Created)

| Purpose | Path |
|---------|------|
| **Data Models** | `lib/classes/day_plan.dart` |
| **Repository** | `lib/features/daily_os/repository/day_plan_repository.dart` |
| **Date Selection State** | `lib/features/daily_os/state/daily_os_controller.dart` |
| **DayPlan State** | `lib/features/daily_os/state/day_plan_controller.dart` |
| **Budget Progress State** | `lib/features/daily_os/state/time_budget_progress_controller.dart` |
| **Timeline Data State** | `lib/features/daily_os/state/timeline_data_controller.dart` |
| **Main Page** | `lib/features/daily_os/ui/pages/daily_os_page.dart` |
| **Day Header Widget** | `lib/features/daily_os/ui/widgets/day_header.dart` |
| **Timeline Widget** | `lib/features/daily_os/ui/widgets/daily_timeline.dart` |
| **Budget List Widget** | `lib/features/daily_os/ui/widgets/time_budget_list.dart` |
| **Budget Card Widget** | `lib/features/daily_os/ui/widgets/time_budget_card.dart` |
| **Day Summary Widget** | `lib/features/daily_os/ui/widgets/day_summary.dart` |
| **Beamer Route** | `lib/beamer/locations/daily_os_location.dart` |
| **View Mode Toggle** | `lib/features/calendar/state/calendar_view_mode_controller.dart` |
| **Calendar Wrapper** | `lib/features/calendar/ui/pages/calendar_wrapper_page.dart` |
| **DayPlan Controller Tests** | `test/features/daily_os/state/day_plan_controller_test.dart` |
| **Budget Progress Tests** | `test/features/daily_os/state/time_budget_progress_controller_test.dart` |

## Appendix B: Design Principles Reference

From the design spec, every implementation decision should honor:

1. **Separation of concern** — Planning, doing, and accounting are distinct
2. **Visual humility** — Calm interface, no aggressive alerts
3. **Reality-first** — Actual time is factual, plans are mutable
4. **No forced alignment** — Actual doesn't need to match planned
5. **Boundaries without punishment** — Over-budget is information, not failure

---

## Appendix C: Future UI/UX Improvements

Based on frontend design review (2026-01-15), the following enhancements are recommended for Phase 5 (Polish):

### High Priority

| Item | Description | Effort |
|------|-------------|--------|
| **Animated progress bar** | Use `TweenAnimationBuilder` to animate fill width changes | Low |
| **Staggered budget card entrance** | Add fade-in + slide animation with staggered delays when list loads | Medium |
| **Ripple feedback on chips** | Replace `GestureDetector` with `InkWell` on `_DurationChip` | Low |

### Medium Priority

| Item | Description | Effort |
|------|-------------|--------|
| **Pulse current time indicator** | Add subtle animation to the red "now" line to draw attention | Low |
| **Selected chip scale effect** | Use `AnimatedScale` to slightly enlarge selected duration chips | Low |
| **Extract shared `DurationChip`** | DRY: Move duplicate `_DurationChip` from both sheets to `lib/features/daily_os/ui/widgets/duration_chip.dart` | Low |

### Low Priority

| Item | Description | Effort |
|------|-------------|--------|
| **Larger progress bar** | Increase height from 8px to 10-12px for better visibility | Trivial |
| **Tabular figures on duration labels** | Apply `FontFeature.tabularFigures()` to `30m`, `1h`, etc. for alignment | Trivial |
| **Theme color for "Time's up"** | Replace `Colors.orange` with theme-derived warning color | Trivial |
| **Quarter-hour tick marks** | Add subtle tick marks between hour grid lines on timeline | Low |
| **IconButton.filled for delete** | Use filled variant with error color for delete action | Trivial |

### Code Snippets

**Animated Progress Bar:**
```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: fillWidth),
  duration: const Duration(milliseconds: 400),
  curve: Curves.easeOutCubic,
  builder: (context, value, child) => Container(width: value, ...),
)
```

**Duration Chip with Ripple:**
```dart
InkWell(
  borderRadius: BorderRadius.circular(20),
  onTap: onTap,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(...),
    child: Text(label, ...),
  ),
)
```

**Staggered Entrance Animation:**
```dart
// In TimeBudgetList, wrap each card:
AnimatedOpacity(
  opacity: 1.0,
  duration: Duration(milliseconds: 300 + (index * 50)),
  child: SlideTransition(...),
)
```

---

*This implementation plan will be updated as development progresses.*
