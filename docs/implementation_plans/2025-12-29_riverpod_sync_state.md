# Refactor Sync BLoC to Riverpod

## Status: COMPLETED (2025-12-29)

All tasks completed successfully:
- Created Riverpod providers in `lib/features/sync/state/outbox_state_controller.dart`
- Updated `OutboxBadgeIcon` to use Riverpod providers
- Removed `BlocProvider<OutboxCubit>` from `beamer_app.dart`
- Created comprehensive unit tests (13 test cases)
- Deleted old Bloc files from `lib/blocs/sync/`
- Updated CHANGELOG and flatpak metainfo

## Overview

Migrate the sync outbox state management from BLoC (`lib/blocs/sync/`) to Riverpod (`lib/features/sync/state/`), following the patterns established in the Dashboards refactor (PR #2548).

## Current State Analysis

### Files in lib/blocs/sync/

| File | Lines | Purpose |
|------|-------|---------|
| `outbox_cubit.dart` | 27 | Minimal cubit watching `enableMatrixFlag` config |
| `outbox_state.dart` | 17 | Freezed state: `initial`, `online`, `disabled` |
| `outbox_state.freezed.dart` | 287 | Generated freezed code |

### Current OutboxCubit Logic

```dart
class OutboxCubit extends Cubit<OutboxState> {
  OutboxCubit() : super(const OutboxState.initial()) {
    _subscription = getIt<JournalDb>()
        .watchConfigFlag(enableMatrixFlag)
        .listen((bool enabled) {
      if (enabled) {
        emit(const OutboxState.online());
      } else {
        emit(const OutboxState.disabled());
      }
    });
  }
  // ... dispose cancels subscription
}
```

**Key Observation**: The cubit is extremely simple - it only watches a config flag and emits one of three states.

### Current Usage in Codebase

| Location | Usage |
|----------|-------|
| `beamer/beamer_app.dart:278-331` | BlocProvider creation (but state not watched) |
| No other direct consumers | Cubit registered but not actively consumed |

### Existing Riverpod Infrastructure

Already in place in `lib/providers/service_providers.dart`:
- `outboxServiceProvider` - Provides OutboxService
- `outboxLoginGateStreamProvider` - Exposes login gate stream

Already in `lib/features/sync/state/`:
- `matrix_login_controller.dart` - Login state management
- `matrix_stats_provider.dart` - Matrix sync metrics
- Various other sync-related providers

## Proposed Riverpod Implementation

### Step 1: Create Outbox State Provider

**File:** `lib/features/sync/state/outbox_state_controller.dart`

```dart
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'outbox_state_controller.g.dart';

/// Enum representing the outbox connectivity state.
enum OutboxConnectionState {
  initial,
  online,
  disabled,
}

/// Stream provider watching the Matrix sync enable flag.
/// Replaces OutboxCubit's config flag watching.
@riverpod
Stream<OutboxConnectionState> outboxConnectionState(Ref ref) {
  final db = getIt<JournalDb>();
  return db.watchConfigFlag(enableMatrixFlag).map(
    (enabled) => enabled
        ? OutboxConnectionState.online
        : OutboxConnectionState.disabled,
  );
}

/// Provider for outbox pending count (for badge display).
@riverpod
Stream<int> outboxPendingCount(Ref ref) {
  final syncDb = getIt<SyncDatabase>();
  return syncDb.watchOutboxCount();
}
```

### Step 2: Update UI Components

**File:** `lib/beamer/beamer_app.dart`

Remove:
```dart
BlocProvider<OutboxCubit>(
  lazy: false,
  create: (BuildContext context) => widget.outboxCubit ?? OutboxCubit(),
)
```

The app already uses `ProviderScope`, so no additional wrapper needed.

**File:** `lib/features/settings/ui/pages/outbox/outbox_badge.dart`

Already uses streams directly - may benefit from using the new `outboxPendingCountProvider` for consistency.

### Step 3: Clean Up Old Files

Delete after migration complete:
- `lib/blocs/sync/outbox_cubit.dart`
- `lib/blocs/sync/outbox_state.dart`
- `lib/blocs/sync/outbox_state.freezed.dart`

Check if `lib/blocs/sync/` directory becomes empty and delete if so.

## Implementation Order

1. **Create new provider file** (`outbox_state_controller.dart`)
2. **Run code generation** (`fvm flutter pub run build_runner build`)
3. **Update beamer_app.dart** - Remove BlocProvider for OutboxCubit
4. **Update outbox_badge.dart** - Use new provider (optional, for consistency)
5. **Add unit tests** for new providers
6. **Run analyzer and all tests**
7. **Delete old bloc files**
8. **Final verification**

## Files to Create

- `lib/features/sync/state/outbox_state_controller.dart`
- `lib/features/sync/state/outbox_state_controller.g.dart` (generated)
- `test/features/sync/state/outbox_state_controller_test.dart`

## Files to Modify

- `lib/beamer/beamer_app.dart` - Remove BlocProvider<OutboxCubit>
- `lib/features/settings/ui/pages/outbox/outbox_badge.dart` - Optional: use new provider

## Files to Delete

- `lib/blocs/sync/outbox_cubit.dart`
- `lib/blocs/sync/outbox_state.dart`
- `lib/blocs/sync/outbox_state.freezed.dart`
- `lib/blocs/sync/` directory (if empty)

## Test Strategy

### Unit Tests for New Providers

Following the Dashboards pattern with `ProviderContainer` and `fakeAsync`:

```dart
void main() {
  group('OutboxStateController', () {
    late MockJournalDb mockDb;
    late StreamController<bool> flagStreamController;
    late ProviderContainer container;

    setUp(() {
      mockDb = MockJournalDb();
      flagStreamController = StreamController<bool>.broadcast();

      when(() => mockDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => flagStreamController.stream);

      getIt.registerSingleton<JournalDb>(mockDb);
      container = ProviderContainer();
    });

    tearDown(() async {
      await flagStreamController.close();
      container.dispose();
      await getIt.reset();
    });

    group('outboxConnectionStateProvider', () {
      test('initial state is loading', () {
        final state = container.read(outboxConnectionStateProvider);
        expect(state.isLoading, isTrue);
      });

      test('emits online when flag is true', () {
        fakeAsync((async) {
          container.listen(outboxConnectionStateProvider, (_, __) {});
          async.flushMicrotasks();

          flagStreamController.add(true);
          async.flushMicrotasks();

          final state = container.read(outboxConnectionStateProvider);
          expect(state.value, OutboxConnectionState.online);
        });
      });

      test('emits disabled when flag is false', () {
        fakeAsync((async) {
          container.listen(outboxConnectionStateProvider, (_, __) {});
          async.flushMicrotasks();

          flagStreamController.add(false);
          async.flushMicrotasks();

          final state = container.read(outboxConnectionStateProvider);
          expect(state.value, OutboxConnectionState.disabled);
        });
      });

      test('handles stream errors', () async {
        final completer = Completer<void>();
        container.listen(outboxConnectionStateProvider, (_, next) {
          if (next.hasError && !completer.isCompleted) {
            completer.complete();
          }
        });

        flagStreamController.addError(Exception('test error'));
        await completer.future.timeout(const Duration(milliseconds: 100));

        final state = container.read(outboxConnectionStateProvider);
        expect(state.hasError, isTrue);
      });
    });

    group('outboxPendingCountProvider', () {
      late MockSyncDatabase mockSyncDb;
      late StreamController<int> countStreamController;

      setUp(() {
        mockSyncDb = MockSyncDatabase();
        countStreamController = StreamController<int>.broadcast();

        when(() => mockSyncDb.watchOutboxCount())
            .thenAnswer((_) => countStreamController.stream);

        getIt.registerSingleton<SyncDatabase>(mockSyncDb);
      });

      tearDown(() async {
        await countStreamController.close();
      });

      test('emits count from database stream', () {
        fakeAsync((async) {
          container.listen(outboxPendingCountProvider, (_, __) {});
          async.flushMicrotasks();

          countStreamController.add(5);
          async.flushMicrotasks();

          final state = container.read(outboxPendingCountProvider);
          expect(state.value, 5);
        });
      });

      test('emits zero when no pending items', () {
        fakeAsync((async) {
          container.listen(outboxPendingCountProvider, (_, __) {});
          async.flushMicrotasks();

          countStreamController.add(0);
          async.flushMicrotasks();

          final state = container.read(outboxPendingCountProvider);
          expect(state.value, 0);
        });
      });
    });
  });
}
```

### Test Coverage Targets

| Provider | Test Cases |
|----------|------------|
| `outboxConnectionStateProvider` | initial loading, online state, disabled state, error handling |
| `outboxPendingCountProvider` | count emission, zero count, error handling |

**Target:** Match Dashboards pattern with ~85%+ coverage on new provider code.

## Migration Complexity Assessment

| Aspect | Complexity | Notes |
|--------|------------|-------|
| Bloc Logic | **Low** | Only watches one config flag |
| UI Dependencies | **Low** | Cubit registered but not actively consumed |
| Service Impact | **None** | OutboxService already has Riverpod provider |
| Test Effort | **Low** | Simple stream provider tests |

**Overall: LOW COMPLEXITY** - This is simpler than the Dashboards migration.

## Consistency with Dashboards Pattern

| Pattern | Dashboards | Sync (Proposed) |
|---------|------------|-----------------|
| Stream Provider | `dashboardsProvider` | `outboxConnectionStateProvider` |
| Database Watch | `db.watchDashboards()` | `db.watchConfigFlag()` |
| File Location | `lib/features/dashboards/state/` | `lib/features/sync/state/` |
| Test Pattern | `fakeAsync` + `ProviderContainer` | Same |
| Naming | `dashboards_page_controller.dart` | `outbox_state_controller.dart` |

## CHANGELOG Entry (Draft)

```markdown
## [0.9.7XX] - YYYY-MM-DD
### Changed
- Migrated outbox state management from Bloc to Riverpod
  - Replaced `OutboxCubit` with `outboxConnectionStateProvider`
  - Added `outboxPendingCountProvider` for badge display
  - Consistent with codebase-wide Riverpod adoption
```

## Questions/Decisions

1. **OutboxBadge Enhancement**: Should we update `outbox_badge.dart` to use the new `outboxPendingCountProvider` instead of directly watching `SyncDatabase.watchOutboxCount()`?
   - **Recommendation**: Yes, for consistency with the provider-based architecture.

2. **State Enum vs Freezed**: The original used freezed for state. Should we keep using freezed or switch to a simple enum?
   - **Recommendation**: Simple enum is sufficient for this tri-state (initial/online/disabled).

3. **Provider Scope**: Should `outboxConnectionStateProvider` be auto-dispose or kept alive?
   - **Recommendation**: Auto-dispose (default `@riverpod`) is fine since it's a stream that doesn't need warm-keeping.

## Approval Checklist

- [ ] Implementation plan reviewed
- [ ] Test strategy approved
- [ ] File structure approved
- [ ] Ready to proceed with implementation
