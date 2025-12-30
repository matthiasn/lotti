# Riverpod 3.0 Migration - Comprehensive Plan

## Current State Assessment (December 30, 2025 - Post Refactors)

### Recent Major Refactors
The codebase has undergone significant refactoring to **100% Riverpod**:

| Commit | Description | Impact |
|--------|-------------|--------|
| `b7781d1f5` | Journal page → Riverpod | Replaced `JournalPageCubit` with `JournalPageController` |
| `2dbbfd23f` | Habits cubit → Riverpod | Replaced `HabitsCubit` with `HabitsController` + `HabitsRepository` |
| `40d515845` | Audio player → Riverpod | New `AudioPlayerController` |
| `9c1da0a16` | Habit settings → Riverpod | Enhanced `HabitSettingsController` |
| `6cd21dbaa` | Theming → Riverpod | New `ThemingController` |
| `549fc3ce3` | Sync outbox → Riverpod | New `OutboxStateController`, removed `OutboxCubit` |
| `94f0cecff` | Dashboard list → Riverpod | New `DashboardsPageController` |

### Dependency Versions
```yaml
flutter_riverpod: ^2.4.9
riverpod: ^2.6.1
riverpod_annotation: ^2.3.5
riverpod_generator: ^2.4.0
riverpod_lint: ^2.6.5
```

### Codebase Health (Excellent - 100% Riverpod!)
| Metric | Count | Status |
|--------|-------|--------|
| `@riverpod` annotations | 98 across 63 files | Modern API |
| Generated `.g.dart` files | 102 | Will regenerate |
| `.valueOrNull` usages | 71 across 49 files | Needs rename |
| **BLoC/Cubit classes** | **0** | **Fully removed** |
| **BlocProvider/BlocBuilder/etc.** | **0** | **Fully removed** |
| **flutter_bloc dependency** | **Removed** | **Clean** |
| `StateNotifier` classes | 0 | Already migrated |
| `StateProvider/StateNotifierProvider/ChangeNotifierProvider` | 0 | Clean |
| `ProviderObserver` implementations | 0 | No changes needed |
| `listenSelf` on Ref | 0 | Already on Notifiers |
| Family providers | ~75% | Code-generated |
| AutoDispose providers | ~80% | Code-generated |

### New Riverpod Controllers (from refactors)
- `JournalPageController` - `@Riverpod(keepAlive: true)` with family parameter `(bool showTasks)`
- `HabitsController` - `@Riverpod(keepAlive: true)`, replaces HabitsCubit
- `HabitsRepository` - New repository layer
- `OutboxStateController` - Stream providers for outbox state
- `DashboardsPageController` - Dashboard list state
- `ThemingController` - App theming state
- `AudioPlayerController` - Audio playback state

### Cleanup Opportunity
The `lib/blocs/` directory is now empty (only contains `.DS_Store`) and can be deleted.

---

## Riverpod 3.0 Breaking Changes Summary

### 1. API Renames & Removals
| Change | Migration |
|--------|-----------|
| `valueOrNull` removed | Replace with `value` (71 occurrences) |
| `AutoDispose*` class prefixes removed | Automatic via code regeneration |
| `Family*` notifier variants removed | Family args move to Notifier constructor |
| `Ref` loses type parameter | Automatic via code regeneration |
| `ProviderRef.state` | Moves to `Notifier.state` |
| `Ref.listenSelf` | Moves to `Notifier.listenSelf` |
| `FutureProviderRef.future` | Moves to `AsyncNotifier.future` |

### 2. Behavioral Changes
| Change | Impact | Action |
|--------|--------|--------|
| **Automatic retry** | Providers auto-retry on failure (200ms backoff, up to 6.4s) | May want to disable for specific providers |
| **Pause/resume** | Out-of-view listeners auto-pause | Generally beneficial; watch for side effects |
| **`==` equality filtering** | All providers use `==` (was inconsistent) | May affect providers relying on `identical()` |
| **`ProviderException` wrapping** | All errors wrapped | Update any `on SpecificError` catches |
| **Async rebuild subscriptions** | Subscriptions persist during rebuild | Generally beneficial |

### 3. New Features (Optional)
- **Offline persistence** - `riverpod_sqflite` package
- **Mutations** - `@mutation` annotation for side-effects (experimental)
- **`Ref.mounted`** - Check provider still mounted after async ops
- **`AsyncValue.isFromCache`** - Distinguish cached vs fresh data
- **`ref.listen(..., weak: true)`** - Non-initializing listeners
- **Generic providers** - Type parameters in code-generated providers

---

## Migration Phases

### Phase 1: Pre-Upgrade Validation (On Riverpod 2.x)
**Goal:** Ensure codebase is ready for upgrade

#### 1.1 Cleanup Empty BLoC Directory
```bash
rm -rf lib/blocs/
```

#### 1.2 Verify All Tests Pass
```bash
fvm flutter test
```

#### 1.3 Run Analyzer
```bash
fvm flutter analyze
```

#### 1.4 Baseline Snapshot
- Document any flaky tests
- Note current analyzer warnings
- Create a git tag for rollback: `git tag pre-riverpod-3`

---

### Phase 2: Dependency Upgrade

#### 2.1 Update `pubspec.yaml`
```yaml
dependencies:
  flutter_riverpod: ^3.0.3
  riverpod: ^3.0.3
  riverpod_annotation: ^3.0.3

dev_dependencies:
  riverpod_generator: ^3.0.3
  riverpod_lint: ^3.0.3
```

#### 2.2 Get Dependencies
```bash
fvm flutter pub get
```

---

### Phase 3: Automated Migration

#### 3.1 Run riverpod_lint Fixes
```bash
dart run custom_lint --fix
```

#### 3.2 Global Search-Replace: `valueOrNull` → `value`
Files affected (49):
- `lib/widgets/` - 2 files
- `lib/beamer/` - 1 file
- `lib/features/habits/` - 2 files
- `lib/features/tasks/` - 10 files
- `lib/features/ai/` - 12 files
- `lib/features/journal/` - 5 files
- `lib/features/dashboards/` - 10 files
- `lib/features/sync/` - 7 files

**Command:**
```bash
# Preview changes
grep -rn "\.valueOrNull" lib/ --include="*.dart"

# Apply (with caution - review diff)
find lib -name "*.dart" -exec sed -i '' 's/\.valueOrNull/.value/g' {} \;
```

#### 3.3 Regenerate Code
```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

This will regenerate 102 `.g.dart` files with:
- Simplified `Ref` (no type parameter)
- Removed `AutoDispose` prefixes from class names
- Updated family handling

---

### Phase 4: Manual Fixes

#### 4.1 Error Handling Updates
Search for code that catches specific exception types from provider failures:
```bash
grep -rn "on.*Exception" lib/ --include="*.dart" | grep -v "ProviderException"
```

Update to handle `ProviderException`:
```dart
// Before
try {
  await ref.read(someProvider.future);
} on NetworkException catch (e) {
  // handle
}

// After
try {
  await ref.read(someProvider.future);
} on ProviderException catch (e) {
  if (e.exception is NetworkException) {
    // handle
  }
  rethrow;
}
```

#### 4.2 Automatic Retry Configuration
If any providers should NOT auto-retry (e.g., user-initiated actions that shouldn't retry on failure):

**Per-provider:**
```dart
@Riverpod(retry: null)  // Disable retry
class MyController extends _$MyController { ... }
```

**Global default in `main.dart`:**
```dart
ProviderScope(
  retry: (retryCount, error) => null,  // Disable globally
  // or custom logic
  child: MyApp(),
)
```

**Candidates to consider:**
- Form submission controllers
- One-shot mutation operations
- User-initiated sync actions

#### 4.3 Pause/Resume Behavior
The new pause/resume behavior is generally beneficial. However, if any provider MUST continue running when its widget is off-screen:

```dart
Consumer(
  builder: (context, ref, child) {
    // Keep listening even when paused
    ref.listen(myProvider, (prev, next) {
      // This will pause when widget is invisible
    });
    return child!;
  },
)
```

Use `TickerMode.of(context)` to control this if needed.

#### 4.4 Review New Controllers for Pause/Resume Impact
The recently refactored controllers use `keepAlive: true` and/or visibility detection:

| Controller | keepAlive | Visibility Detection | Notes |
|------------|-----------|---------------------|-------|
| `JournalPageController` | true | Yes (`_isVisible` flag) | Has own visibility handling via `VisibilityDetector` |
| `HabitsController` | true | No | Persistent state, should be unaffected |
| `DashboardsPageController` | true | No | Persistent state, should be unaffected |
| `ThemingController` | true | No | App-wide, should be unaffected |
| `AudioPlayerController` | Varies | No | Verify playback doesn't pause |
| `OutboxStateController` | Stream-based | No | Verify sync continues in background |

**Note:** `JournalPageController` already implements its own visibility detection via `VisibilityDetector` and `updateVisibility()` method. The Riverpod 3 pause/resume feature should complement this, but verify no conflicts.

---

### Phase 5: Validation

#### 5.1 Static Analysis
```bash
fvm flutter analyze
```

#### 5.2 Run Full Test Suite
```bash
fvm flutter test
```

#### 5.3 Format Code
```bash
fvm dart format lib test
```

#### 5.4 Manual Smoke Tests
Priority areas to test manually (focus on recently refactored features):

1. **Journal page** (NEW) - Infinite scroll, filtering, search, entry types
2. **Tasks page** - Status filters, category filters, label filters, priority, sorting
3. **Habits page** (NEW) - Habit list, completion, streaks, filtering, search
4. **Sync features** (NEW) - Matrix login, outbox badge, sync progress
5. **Dashboards** (NEW) - Dashboard list, chart rendering
6. **Theming** (NEW) - Theme switching, persistence
7. **Audio player** (NEW) - Playback, waveform display
8. **AI features** - Unified AI popup, inference, chat

---

### Phase 6: Post-Migration Cleanup

#### 6.1 Remove Old Migration Plans (Optional)
Consider archiving:
- `2025-09-21_riverpod_3_upgrade.md`
- `2025-09-21_riverpod_3_progress.md`
- `2025-11-21_riverpod_3_staged_upgrade.md`

#### 6.2 Update READMEs
Update feature READMEs to reflect Riverpod 3 patterns if needed.

#### 6.3 Lint Configuration
Ensure `riverpod_lint` 3.x rules are active in `analysis_options.yaml`.

---

## Risk Assessment

### Low Risk
- **valueOrNull → value rename** - Mechanical, safe
- **Code regeneration** - Well-tested generator
- **Ref simplification** - Automatic via codegen

### Medium Risk
- **Equality filtering change** - May cause unexpected rebuilds if providers relied on `identical()`
- **Automatic retry** - Could mask transient errors; need to verify error handling UX
- **Pause/resume** - Background operations might not complete; verify sync behavior

### Mitigation
- Run comprehensive test suite after each phase
- Manual smoke testing of critical flows
- Keep previous Riverpod 2.x branch/tag as fallback

---

## Estimated Effort

| Phase | Effort |
|-------|--------|
| Phase 1: Pre-validation | ~15 min |
| Phase 2: Dependency upgrade | ~5 min |
| Phase 3: Automated migration | ~15 min |
| Phase 4: Manual fixes | ~30 min - 1 hour |
| Phase 5: Validation | ~30 min - 1 hour |
| Phase 6: Cleanup | ~15 min |

**Total: ~2-3 hours** (assuming no major issues)

**Note:** Effort reduced from previous estimate because:
- No BLoC/Cubit code to handle
- No legacy provider types remain
- All providers use modern `@riverpod` code generation

---

## Rollback Plan

If critical issues arise:
1. Revert `pubspec.yaml` to Riverpod 2.x versions
2. Run `fvm flutter pub get`
3. Restore `.valueOrNull` usages (git checkout)
4. Regenerate code with 2.x generator
5. Document issues for resolution before re-attempting

---

## Success Criteria

- [ ] Empty `lib/blocs/` directory removed
- [ ] All tests pass
- [ ] No analyzer warnings/errors
- [ ] Manual smoke tests pass for journal, tasks, habits, sync, dashboards, theming, audio, AI
- [ ] No `StateProvider`/`StateNotifierProvider`/`ChangeNotifierProvider` imports
- [ ] No `.valueOrNull` usages remain
- [ ] Code formatted and committed
- [ ] Archive/remove obsolete migration plans

---

## References

- [Official Migration Guide](https://riverpod.dev/docs/3.0_migration)
- [What's New in Riverpod 3.0](https://riverpod.dev/docs/whats_new)
- [Flutter Riverpod Changelog](https://pub.dev/packages/flutter_riverpod/changelog)
- Prior plans: `2025-09-21_riverpod_3_upgrade.md`, `2025-11-21_riverpod_3_staged_upgrade.md`
