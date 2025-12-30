# Refactor Theming BLoC to Riverpod

## Status: COMPLETED (2025-12-30)

## Overview

Migrate the theming state management from BLoC (`lib/blocs/theming/`) to Riverpod (`lib/features/theming/state/` or similar), following the patterns established in:
- **PR #2548**: Dashboards refactor (merged 2025-12-29)
- **PR #2550**: Sync outbox refactor (merged 2025-12-30)

This is the third phase of the codebase-wide BLoC-to-Riverpod migration.

## Current State Analysis

### Files in lib/blocs/theming/

| File | Lines | Purpose |
|------|-------|---------|
| `theming_cubit.dart` | 273 | Cubit managing theme state, tooltip preferences, and sync |
| `theming_state.dart` | 55 | Freezed state + theme definitions + surface overrides |
| `theming_state.freezed.dart` | ~200 | Generated freezed code |

### Current ThemingCubit Logic

The `ThemingCubit` is more complex than the previously migrated cubits:

```dart
class ThemingCubit extends Cubit<ThemingState> {
  // Manages:
  // - Light theme (ThemeData + theme name)
  // - Dark theme (ThemeData + theme name)
  // - Theme mode (light/dark/system)
  // - Tooltip enable flag
  // - Sync message enqueueing for theme selection changes
  // - Theme preferences reload from sync

  // Key subscriptions:
  // - _tooltipSubscription: watches enableTooltipFlag config
  // - _themePrefsSubscription: watches themePrefsUpdatedAtKey for sync updates

  // Key methods:
  // - setLightTheme(String themeName)
  // - setDarkTheme(String themeName)
  // - onThemeSelectionChanged(Set<ThemeMode> modes)
}
```

### ThemingState Structure

```dart
@freezed
abstract class ThemingState with _$ThemingState {
  factory ThemingState({
    required bool enableTooltips,
    ThemeData? darkTheme,
    ThemeData? lightTheme,
    String? darkThemeName,
    String? lightThemeName,
    ThemeMode? themeMode,
  }) = _ThemingState;
}
```

### Current Usage in Codebase

| Location | Usage |
|----------|-------|
| `lib/beamer/beamer_app.dart:329-334` | BlocProvider creation + BlocBuilder for MaterialApp theme |
| `lib/features/settings/ui/pages/theming_page.dart:22,131` | BlocBuilder for theme selection UI |

### Existing Tests

| Test File | Purpose |
|-----------|---------|
| `test/blocs/theming/theming_state_test.dart` | State tests |
| `test/blocs/theming/theming_cubit_sync_test.dart` | Sync integration tests |
| `test/blocs/theming/theming_cubit_sync_listener_test.dart` | Sync listener tests |
| `test/blocs/theming/theming_cubit_error_handling_test.dart` | Error handling tests |
| `test/features/settings/ui/pages/manual/theming_page_test.dart` | Widget tests |

## Proposed Riverpod Implementation

### Step 1: Create Theming Provider Structure

**File:** `lib/features/theming/state/theming_controller.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theming_controller.g.dart';

/// Stream provider watching the tooltip enable flag.
@riverpod
Stream<bool> enableTooltips(Ref ref) {
  return getIt<JournalDb>().watchConfigFlag(enableTooltipFlag);
}

/// Notifier managing the complete theming state.
@Riverpod(keepAlive: true)
class ThemingController extends _$ThemingController {
  StreamSubscription<List<SettingsItem>>? _themePrefsSubscription;
  bool _isApplyingSyncedChanges = false;
  final _debounceKey = 'theming.sync.${identityHashCode(Object())}';

  @override
  ThemingState build() {
    ref.onDispose(() {
      _themePrefsSubscription?.cancel();
      EasyDebounce.cancel(_debounceKey);
    });

    // Initialize and watch for theme pref updates
    _init();

    return ThemingState(
      darkTheme: _buildTheme('Grey Law', isDark: true),
      lightTheme: _buildTheme('Grey Law', isDark: false),
      darkThemeName: 'Grey Law',
      lightThemeName: 'Grey Law',
      themeMode: ThemeMode.system,
    );
  }

  Future<void> _init() async {
    await _loadSelectedSchemes();
    _watchThemePrefsUpdates();
  }

  void setLightTheme(String themeName) { /* ... */ }
  void setDarkTheme(String themeName) { /* ... */ }
  void setThemeMode(ThemeMode mode) { /* ... */ }
  // ... sync message enqueueing
}

/// State class (can be freezed or simple class)
class ThemingState {
  final ThemeData? darkTheme;
  final ThemeData? lightTheme;
  final String? darkThemeName;
  final String? lightThemeName;
  final ThemeMode themeMode;

  const ThemingState({
    this.darkTheme,
    this.lightTheme,
    this.darkThemeName,
    this.lightThemeName,
    this.themeMode = ThemeMode.system,
  });
}
```

### Step 2: Relocate Theme Definitions

Move theme-related constants from `theming_state.dart`:

**File:** `lib/features/theming/model/theme_definitions.dart`
- `LightModeSurfaces` class
- `themes` map (FlexScheme definitions)

### Step 3: Update UI Components

**File:** `lib/beamer/beamer_app.dart`

Remove:
```dart
BlocProvider<ThemingCubit>(
  create: (BuildContext context) => widget.themingCubit ?? ThemingCubit(),
)
```

Replace BlocBuilder with Consumer:
```dart
Consumer(
  builder: (context, ref, child) {
    final themingState = ref.watch(themingControllerProvider);
    final enableTooltips = ref.watch(enableTooltipsProvider).valueOrNull ?? true;

    return MaterialApp(
      theme: themingState.lightTheme,
      darkTheme: themingState.darkTheme,
      themeMode: themingState.themeMode,
      // ...
    );
  },
)
```

**File:** `lib/features/settings/ui/pages/theming_page.dart`

Convert to `ConsumerWidget`:
```dart
class ThemingPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themingState = ref.watch(themingControllerProvider);
    final controller = ref.read(themingControllerProvider.notifier);

    // Replace context.read<ThemingCubit>() with controller
  }
}
```

### Step 4: Clean Up Old Files

Delete after migration complete:
- `lib/blocs/theming/theming_cubit.dart`
- `lib/blocs/theming/theming_state.dart`
- `lib/blocs/theming/theming_state.freezed.dart`

Check if `lib/blocs/theming/` directory becomes empty and delete if so.

## Implementation Order

1. **Create new provider files**
   - `lib/features/theming/state/theming_controller.dart`
   - `lib/features/theming/model/theme_definitions.dart`
2. **Run code generation** (`fvm flutter pub run build_runner build`)
3. **Update beamer_app.dart** - Remove BlocProvider, convert BlocBuilder to Consumer
4. **Update theming_page.dart** - Convert to ConsumerWidget
5. **Migrate tests** to Riverpod patterns
6. **Run analyzer and all tests**
7. **Delete old bloc files**
8. **Final verification**

## Files to Create

- `lib/features/theming/state/theming_controller.dart`
- `lib/features/theming/state/theming_controller.g.dart` (generated)
- `lib/features/theming/model/theme_definitions.dart`
- `test/features/theming/state/theming_controller_test.dart`

## Files to Modify

- `lib/beamer/beamer_app.dart` - Remove BlocProvider<ThemingCubit>, convert BlocBuilder
- `lib/features/settings/ui/pages/theming_page.dart` - Convert to ConsumerWidget

## Files to Delete

- `lib/blocs/theming/theming_cubit.dart`
- `lib/blocs/theming/theming_state.dart`
- `lib/blocs/theming/theming_state.freezed.dart`
- `lib/blocs/theming/` directory (if empty)

## Test Strategy

### Unit Tests for New Providers

Following the established pattern with `ProviderContainer` and `fakeAsync`:

```dart
void main() {
  group('ThemingController', () {
    late MockSettingsDb mockSettingsDb;
    late MockJournalDb mockJournalDb;
    late ProviderContainer container;

    setUp(() {
      mockSettingsDb = MockSettingsDb();
      mockJournalDb = MockJournalDb();
      // Register mocks in getIt
    });

    group('themingControllerProvider', () {
      test('initializes with default Grey Law theme', () { /* ... */ });
      test('loads saved theme preferences on init', () { /* ... */ });
      test('setLightTheme updates light theme and enqueues sync', () { /* ... */ });
      test('setDarkTheme updates dark theme and enqueues sync', () { /* ... */ });
      test('setThemeMode updates mode and persists', () { /* ... */ });
      test('reloads themes when sync updates arrive', () { /* ... */ });
      test('handles errors during theme loading gracefully', () { /* ... */ });
    });

    group('enableTooltipsProvider', () {
      test('emits true when flag is enabled', () { /* ... */ });
      test('emits false when flag is disabled', () { /* ... */ });
      test('handles stream errors', () { /* ... */ });
    });
  });
}
```

### Test Coverage Targets

| Provider | Test Cases |
|----------|------------|
| `themingControllerProvider` | initial state, theme loading, light/dark theme changes, mode changes, sync message enqueueing, sync reload handling, error handling |
| `enableTooltipsProvider` | enabled state, disabled state, error handling |

**Target:** Match previous refactors with ~85%+ coverage on new provider code.

## Migration Complexity Assessment

| Aspect | Complexity | Notes |
|--------|------------|-------|
| Bloc Logic | **Medium** | Multiple streams, sync integration, theme building |
| UI Dependencies | **Low** | Only 2 files use BlocBuilder |
| Service Impact | **Low** | OutboxService already has Riverpod provider |
| Test Effort | **Medium** | Several existing test files to migrate |

**Overall: MEDIUM COMPLEXITY** - More complex than Sync, comparable to Dashboards.

## Consistency with Previous Patterns

| Pattern | Dashboards | Sync | Theming (Proposed) |
|---------|------------|------|-------------------|
| Stream Provider | `dashboardsProvider` | `outboxConnectionStateProvider` | `enableTooltipsProvider` |
| Stateful Notifier | `SelectedCategoryIds` | N/A | `ThemingController` |
| File Location | `lib/features/dashboards/state/` | `lib/features/sync/state/` | `lib/features/theming/state/` |
| Test Pattern | `fakeAsync` + `ProviderContainer` | Same | Same |
| keepAlive | No (auto-dispose) | No (auto-dispose) | **Yes** (theme state needed app-wide) |

## CHANGELOG Entry (Draft)

```markdown
## [0.9.7XX] - YYYY-MM-DD
### Changed
- Migrated theming state management from Bloc to Riverpod
  - Replaced `ThemingCubit` with `ThemingController` notifier
  - Added `enableTooltipsProvider` for tooltip flag streaming
  - Consistent with codebase-wide Riverpod adoption
```

---

## Workflow Phases

### Phase 1: Implementation

1. Create Riverpod providers following the patterns above
2. Update UI components to use Riverpod
3. Migrate existing tests to Riverpod patterns
4. Delete old BLoC files
5. Ensure all tests pass and analyzer is clean

### Phase 2: Pull Request

1. Create PR with title: `refactor: use Riverpod for theming state`
2. Include summary of changes following PR #2548 and #2550 format
3. Reference this implementation plan in PR description

### Phase 3: Review

1. Address review comments from:
   - **Gemini** - AI code review
   - **CodeRabbit** - Automated review bot
2. Iterate until reviews are satisfied

### Phase 4: Merge

1. Ensure CI passes (all tests green)
2. Squash and merge to main branch

### Phase 5: Release

1. **TestFlight iOS**: Deploy to TestFlight for iOS testing
2. **TestFlight macOS**: Deploy to TestFlight for macOS testing
3. **Note**: Flathub release is NOT included in this task

---

## Questions/Decisions

1. **State Class**: Keep using Freezed for ThemingState or switch to simple immutable class?
   - **Recommendation**: Simple immutable class is sufficient (consistent with Sync pattern).

2. **Provider Scope**: Should `themingControllerProvider` be keepAlive?
   - **Recommendation**: Yes, theme state should persist for the entire app lifecycle.

3. **Feature Directory**: Create new `lib/features/theming/` or place under existing location?
   - **Recommendation**: Create `lib/features/theming/` for consistency with feature-based organization.

## Approval Checklist

- [ ] Implementation plan reviewed
- [ ] Test strategy approved
- [ ] File structure approved
- [ ] Ready to proceed with implementation
