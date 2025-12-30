# Refactor AudioPlayerCubit to Riverpod

## Status: PENDING APPROVAL

## Overview

Migrate the audio player state management from BLoC (`lib/features/speech/state/player_cubit.dart`) to Riverpod, following the patterns established in:
- **PR #2551**: Theming refactor (merged 2025-12-30) - *Primary reference*
- **PR #2548**: Dashboards refactor (merged 2025-12-29)
- **PR #2550**: Sync outbox refactor (merged 2025-12-30)

This is the fourth phase of the codebase-wide BLoC-to-Riverpod migration.

## Current State Analysis

### Files in lib/features/speech/state/

| File | Lines | Purpose |
|------|-------|---------|
| `player_cubit.dart` | 226 | Cubit managing audio playback state |
| `player_state.dart` | 20 | Freezed state + AudioPlayerStatus enum |
| `player_state.freezed.dart` | ~generated | Generated freezed code |

### Current AudioPlayerCubit Logic

The `AudioPlayerCubit` is a moderately complex media playback controller:

```dart
class AudioPlayerCubit extends Cubit<AudioPlayerState> {
  // Manages:
  // - Playback status (initializing, playing, paused, stopped)
  // - Progress tracking (current position, total duration)
  // - Buffer tracking (amount buffered)
  // - Playback speed (0.5x to 2x)
  // - Active audio note reference (JournalAudio)
  // - UI flag for transcript list visibility

  // Key stream subscriptions:
  // - _positionSubscription: tracks playback position
  // - _bufferSubscription: tracks buffer amount
  // - _completedSubscription: handles playback completion

  // Key methods:
  // - setAudioNote(JournalAudio audioNote) - Load audio file
  // - play() - Start/resume playback
  // - pause() - Pause playback
  // - seek(Duration position) - Seek to position
  // - setSpeed(double speed) - Change playback speed
}
```

### AudioPlayerState Structure

```dart
enum AudioPlayerStatus { initializing, playing, paused, stopped }

@freezed
abstract class AudioPlayerState with _$AudioPlayerState {
  factory AudioPlayerState({
    required AudioPlayerStatus status,
    required Duration totalDuration,
    required Duration progress,
    required Duration pausedAt,
    required double speed,
    required bool showTranscriptsList,
    @Default(Duration.zero) Duration buffered,
    JournalAudio? audioNote,
  }) = _AudioPlayerState;
}
```

### Current Registration & Provision

**GetIt Registration (`lib/get_it.dart:328-331`):**
```dart
_registerLazyServiceSafely<AudioPlayerCubit>(
  AudioPlayerCubit.new,
  'AudioPlayerCubit',
);
```

**BlocProvider (`lib/beamer/beamer_app.dart:339-341`):**
```dart
BlocProvider<AudioPlayerCubit>(
  create: (BuildContext context) =>
      widget.audioPlayerCubit ?? getIt<AudioPlayerCubit>(),
)
```

### Current Usage in Codebase

| Location | Usage Pattern |
|----------|---------------|
| `lib/features/speech/ui/widgets/audio_player.dart` | BlocBuilder + context.read for playback UI |
| `lib/features/journal/ui/widgets/entry_details_widget.dart` | Renders AudioPlayerWidget |
| `lib/features/speech/state/recorder_controller.dart` | Pauses playback when recording starts |

### Existing Tests

| Test File | Tests | Purpose |
|-----------|-------|---------|
| `test/features/speech/state/player_cubit_test.dart` | 32 | Core cubit logic (progress, buffering, seeking, speed) |
| `test/features/speech/state/player_cubit_completion_test.dart` | 7 | Completion handling with fake_async |
| `test/features/speech/ui/widgets/audio_player_widget_test.dart` | 22 | Widget tests with mocked cubit |

**Total: 61 existing tests**

### Special Considerations

1. **Media Kit Dependency**: The cubit wraps `media_kit` Player which requires platform-specific initialization
2. **Lazy Singleton**: Registered lazily to handle initialization failures in sandboxed environments (Flatpak)
3. **Graceful Degradation**: RecorderController checks `getIt.isRegistered<AudioPlayerCubit>()` before access
4. **Stream-Driven Updates**: Position, buffer, and completion are tracked via Player stream subscriptions
5. **Completion Debouncing**: Uses a 50ms timer to debounce completion events

## Proposed Riverpod Implementation

### Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Provider Type | `@Riverpod(keepAlive: true)` | Audio state should persist for app lifecycle (like theming) |
| State Class | Simple immutable class with `copyWith` | Consistent with theming pattern, Freezed not required |
| Player Instance | Managed within controller | Controller owns Player lifecycle |
| Error Handling | Logging via LoggingService | Consistent with existing pattern |

### Step 1: Create Audio Player State Model

**File:** `lib/features/speech/model/audio_player_state.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';

/// Playback status enum
enum AudioPlayerStatus { initializing, playing, paused, stopped }

/// Immutable state representing audio playback configuration
@immutable
class AudioPlayerState {
  const AudioPlayerState({
    this.status = AudioPlayerStatus.initializing,
    this.totalDuration = Duration.zero,
    this.progress = Duration.zero,
    this.pausedAt = Duration.zero,
    this.speed = 1.0,
    this.showTranscriptsList = false,
    this.buffered = Duration.zero,
    this.audioNote,
  });

  final AudioPlayerStatus status;
  final Duration totalDuration;
  final Duration progress;
  final Duration pausedAt;
  final double speed;
  final bool showTranscriptsList;
  final Duration buffered;
  final JournalAudio? audioNote;

  AudioPlayerState copyWith({
    AudioPlayerStatus? status,
    Duration? totalDuration,
    Duration? progress,
    Duration? pausedAt,
    double? speed,
    bool? showTranscriptsList,
    Duration? buffered,
    JournalAudio? audioNote,
  }) {
    return AudioPlayerState(
      status: status ?? this.status,
      totalDuration: totalDuration ?? this.totalDuration,
      progress: progress ?? this.progress,
      pausedAt: pausedAt ?? this.pausedAt,
      speed: speed ?? this.speed,
      showTranscriptsList: showTranscriptsList ?? this.showTranscriptsList,
      buffered: buffered ?? this.buffered,
      audioNote: audioNote ?? this.audioNote,
    );
  }
}
```

### Step 2: Create Audio Player Controller

**File:** `lib/features/speech/state/audio_player_controller.dart`

```dart
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';

part 'audio_player_controller.g.dart';

/// Notifier managing the complete audio player state.
/// Marked as keepAlive since audio state should persist for the entire app lifecycle.
@Riverpod(keepAlive: true)
class AudioPlayerController extends _$AudioPlayerController {
  Player? _audioPlayer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferSubscription;
  StreamSubscription<bool>? _completedSubscription;
  Timer? _completionTimer;

  @override
  AudioPlayerState build() {
    ref.onDispose(_cleanup);
    _init();
    return const AudioPlayerState();
  }

  void _init() {
    try {
      _audioPlayer = Player();
      _setupSubscriptions();
    } catch (e, st) {
      // Log initialization failure, allow graceful degradation
    }
  }

  void _cleanup() {
    _completionTimer?.cancel();
    _positionSubscription?.cancel();
    _bufferSubscription?.cancel();
    _completedSubscription?.cancel();
    _audioPlayer?.dispose();
  }

  // Public methods:
  Future<void> setAudioNote(JournalAudio audioNote) async {...}
  Future<void> play() async {...}
  Future<void> pause() async {...}
  Future<void> seek(Duration position) async {...}
  void setSpeed(double speed) {...}
  void updateProgress(Duration duration) {...}
  void toggleTranscriptsList() {...}
}
```

### Step 3: Update Widget Components

**File:** `lib/features/speech/ui/widgets/audio_player.dart`

Convert from mixed `BlocBuilder` + `ConsumerWidget` to pure Riverpod:

```dart
// Before
class AudioPlayerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (context, state) {
        final cubit = context.read<AudioPlayerCubit>();
        // ...
      },
    );
  }
}

// After
class AudioPlayerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerControllerProvider);
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    // ...
  }
}
```

### Step 4: Update RecorderController Integration

**File:** `lib/features/speech/state/recorder_controller.dart`

**Decision:** Inject ProviderContainer for testability.

```dart
// Before
AudioPlayerCubit? _audioPlayerCubit;

Future<void> record({String? linkedId}) async {
  if (_audioPlayerCubit == null && getIt.isRegistered<AudioPlayerCubit>()) {
    try {
      _audioPlayerCubit = getIt<AudioPlayerCubit>();
    } catch (e) { /* ... */ }
  }

  if (_audioPlayerCubit?.state.status == AudioPlayerStatus.playing) {
    await _audioPlayerCubit!.pause();
  }
}

// After
class RecorderController {
  RecorderController({ProviderContainer? container})
    : _container = container;

  final ProviderContainer? _container;

  Future<void> record({String? linkedId}) async {
    if (_container != null) {
      final playerState = _container!.read(audioPlayerControllerProvider);
      if (playerState.status == AudioPlayerStatus.playing) {
        await _container!.read(audioPlayerControllerProvider.notifier).pause();
      }
    }
  }
}
```

### Step 5: Remove BlocProvider from BeamerApp

**File:** `lib/beamer/beamer_app.dart`

Remove:
```dart
BlocProvider<AudioPlayerCubit>(
  create: (BuildContext context) =>
      widget.audioPlayerCubit ?? getIt<AudioPlayerCubit>(),
  child: ...
)
```

The Riverpod provider will be automatically available via the existing `ProviderScope` at the app root.

### Step 6: Update GetIt Registration

**File:** `lib/get_it.dart`

Remove:
```dart
_registerLazyServiceSafely<AudioPlayerCubit>(
  AudioPlayerCubit.new,
  'AudioPlayerCubit',
);
```

### Step 7: Delete Old Files

After migration complete:
- `lib/features/speech/state/player_cubit.dart`
- `lib/features/speech/state/player_state.dart`
- `lib/features/speech/state/player_state.freezed.dart`

## Implementation Order

1. **Create state model file**
   - `lib/features/speech/model/audio_player_state.dart`
2. **Create Riverpod controller file**
   - `lib/features/speech/state/audio_player_controller.dart`
3. **Run code generation** (`fvm flutter pub run build_runner build`)
4. **Update audio_player.dart widget** - Convert BlocBuilder to Consumer
5. **Update recorder_controller.dart** - Inject ProviderContainer, use provider access
6. **Update beamer_app.dart** - Remove BlocProvider
7. **Update get_it.dart** - Remove cubit registration
8. **Create merged test file** - `test/features/speech/state/audio_player_controller_test.dart`
9. **Update widget tests** - Use provider mocks
10. **Run analyzer and all tests**
11. **Delete old cubit and test files**
12. **Final verification with dart fix and dart format**

## Files to Create

| File | Purpose |
|------|---------|
| `lib/features/speech/state/audio_player_controller.dart` | New Riverpod controller |
| `lib/features/speech/state/audio_player_controller.g.dart` | Generated (build_runner) |
| `lib/features/speech/model/audio_player_state.dart` | State class and AudioPlayerStatus enum |
| `test/features/speech/state/audio_player_controller_test.dart` | Merged unit tests (core + completion) |

## Files to Modify

| File | Changes |
|------|---------|
| `lib/features/speech/ui/widgets/audio_player.dart` | BlocBuilder → Consumer |
| `lib/features/speech/state/recorder_controller.dart` | Inject ProviderContainer, use provider access |
| `lib/beamer/beamer_app.dart` | Remove BlocProvider |
| `lib/get_it.dart` | Remove cubit registration |
| `test/features/speech/ui/widgets/audio_player_widget_test.dart` | Update to use provider mocks |

## Files to Delete

| File | Reason |
|------|--------|
| `lib/features/speech/state/player_cubit.dart` | Replaced by controller |
| `lib/features/speech/state/player_state.dart` | State moved to model file |
| `lib/features/speech/state/player_state.freezed.dart` | No longer using Freezed |
| `test/features/speech/state/player_cubit_test.dart` | Merged into controller test |
| `test/features/speech/state/player_cubit_completion_test.dart` | Merged into controller test |

## Test Strategy

### Test Coverage Targets

| Requirement | Target |
|-------------|--------|
| Minimum coverage | **90%** |
| Goal coverage | **95%** |
| Existing test count | 61 tests |
| Expected final count | 65+ tests |

### Unit Tests for AudioPlayerController

Following the theming controller test pattern with `ProviderContainer` and `fakeAsync`:

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPlayerController', () {
    late MockPlayer mockPlayer;
    late MockLoggingService loggingService;
    late ProviderContainer container;
    late StreamController<Duration> positionController;
    late StreamController<Duration> bufferController;
    late StreamController<bool> completedController;

    setUp(() {
      GetIt.I.allowReassignment = true;
      mockPlayer = MockPlayer();
      loggingService = MockLoggingService();
      positionController = StreamController<Duration>.broadcast();
      bufferController = StreamController<Duration>.broadcast();
      completedController = StreamController<bool>.broadcast();

      // Setup mock streams
      when(() => mockPlayer.stream).thenReturn(MockPlayerStreams(
        position: positionController.stream,
        buffer: bufferController.stream,
        completed: completedController.stream,
      ));

      GetIt.I.registerSingleton<LoggingService>(loggingService);
      container = ProviderContainer();
    });

    tearDown(() async {
      await positionController.close();
      await bufferController.close();
      await completedController.close();
      container.dispose();
      await GetIt.I.reset();
    });

    group('audioPlayerControllerProvider', () {
      test('initial state has initializing status', () {...});
      test('setAudioNote loads audio file and updates state', () {...});
      test('play starts playback and updates status', () {...});
      test('pause stops playback and preserves position', () {...});
      test('seek updates progress and buffered amount', () {...});
      test('setSpeed updates playback rate', () {...});
      test('progress is clamped to total duration', () {...});
      test('buffered is clamped to total duration', () {...});
      test('completion triggers progress update after delay', () {...});
      test('handles player initialization failure gracefully', () {...});
    });

    group('stream subscriptions', () {
      test('position stream updates progress', () {...});
      test('buffer stream updates buffered amount', () {...});
      test('completed stream handles playback completion', () {...});
      test('subscriptions cancelled on dispose', () {...});
    });

    group('error handling', () {
      test('logs error when play fails', () {...});
      test('logs error when seek fails', () {...});
      test('logs error when setAudioNote fails', () {...});
      test('handles disposed state gracefully', () {...});
    });

    group('edge cases', () {
      test('handles zero duration audio', () {...});
      test('handles progress exceeding duration', () {...});
      test('handles rapid consecutive speed changes', () {...});
      test('same audio note skips reload', () {...});
    });
  });
}
```

### Widget Tests

Update existing widget tests to use Riverpod overrides:

```dart
void main() {
  group('AudioPlayerWidget', () {
    late MockAudioPlayerController mockController;

    setUp(() {
      mockController = MockAudioPlayerController();
    });

    Widget buildTestWidget(AudioPlayerState state) {
      return ProviderScope(
        overrides: [
          audioPlayerControllerProvider.overrideWith(() => mockController),
        ],
        child: MaterialApp(
          home: AudioPlayerWidget(journalAudio: testAudioNote),
        ),
      );
    }

    testWidgets('renders play button when paused', (tester) async {
      when(() => mockController.state).thenReturn(
        AudioPlayerState(status: AudioPlayerStatus.paused),
      );

      await tester.pumpWidget(buildTestWidget(mockController.state));
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
    });

    // ... remaining widget tests
  });
}
```

### Test Migration Mapping

| Original Test File | New Test File |
|--------------------|---------------|
| `player_cubit_test.dart` (32 tests) | `audio_player_controller_test.dart` |
| `player_cubit_completion_test.dart` (7 tests) | Merged into `audio_player_controller_test.dart` |
| `audio_player_widget_test.dart` (22 tests) | Updated in place |

**Total: 61 tests → 61+ tests (merged into 2 files)**

### Coverage Verification

After migration, run coverage analysis:
```bash
fvm flutter test --coverage
lcov --remove coverage/lcov.info 'lib/**/*.g.dart' 'lib/**/*.freezed.dart' -o coverage/lcov_filtered.info
genhtml coverage/lcov_filtered.info -o coverage/html
```

Verify `lib/features/speech/state/audio_player_controller.dart` has ≥90% coverage.

## Quality Gates

### Pre-Implementation
- [ ] Implementation plan reviewed and approved

### During Implementation
- [ ] Run analyzer after each file change: `fvm flutter analyze`
- [ ] Run tests frequently: `fvm flutter test test/features/speech/`
- [ ] Run dart fix: `fvm dart fix --apply`
- [ ] Run dart format: `fvm dart format lib/features/speech/ test/features/speech/`

### Post-Implementation
- [ ] All existing tests pass (no regressions)
- [ ] New controller tests achieve ≥90% coverage
- [ ] Analyzer shows zero issues
- [ ] dart format shows no changes needed
- [ ] Manual testing of audio playback in app

## Learnings from Theming Refactor (PR #2551)

### Patterns to Apply

1. **State Class Design**
   - Use simple immutable class with `copyWith` instead of Freezed
   - Include all state fields in one class, no separate enum file
   - Use `const` constructors and default values

2. **Provider Annotation**
   - Use `@Riverpod(keepAlive: true)` for app-wide persistent state
   - Register `ref.onDispose()` callback for cleanup

3. **Initialization Pattern**
   - Return valid default state immediately from `build()`
   - Initialize async resources in separate `_init()` method
   - Handle initialization errors gracefully without blocking

4. **Error Handling**
   - Wrap all operations in try-catch
   - Log errors via LoggingService with domain/subDomain
   - Continue with fallback behavior when possible

5. **Test Patterns**
   - Use `ProviderContainer` for unit tests
   - Use `fakeAsync` for time-dependent tests
   - Use `StreamController.broadcast()` for mock streams
   - Register fallback values in `setUpAll`

### Patterns NOT Applicable

1. **Sync Message Enqueueing** - Audio player doesn't sync across devices
2. **Debouncing** - Audio operations are immediate, not debounced
3. **Settings Persistence** - Audio state is ephemeral, not persisted

## Migration Complexity Assessment

| Aspect | Complexity | Notes |
|--------|------------|-------|
| Cubit Logic | **Medium** | Multiple streams, Player lifecycle, completion handling |
| UI Dependencies | **Low** | Only 1 widget uses BlocBuilder directly |
| Service Impact | **Medium** | RecorderController integration needs care |
| Test Effort | **Medium** | 61 existing tests to migrate |
| Platform Concerns | **Medium** | Media Kit initialization in sandboxed environments |

**Overall: MEDIUM COMPLEXITY** - Similar to theming, with additional media library concerns.

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Media Kit initialization failures | Keep lazy initialization pattern, test on all platforms |
| Breaking RecorderController | Update and test recorder interaction carefully |
| Missing test cases | Compare test counts before/after migration |
| Widget rendering issues | Manual testing of audio playback UI |

## CHANGELOG Entry (Draft)

```markdown
## [0.9.7XX] - YYYY-MM-DD
### Changed
- Migrated audio player state management from Bloc to Riverpod
  - Replaced `AudioPlayerCubit` with `AudioPlayerController` notifier
  - Consistent with codebase-wide Riverpod adoption
```

---

## Workflow Phases

### Phase 1: Implementation

1. Create Riverpod controller following the patterns above
2. Update UI components to use Riverpod
3. Update RecorderController integration
4. Migrate existing tests to Riverpod patterns
5. Delete old BLoC files
6. Ensure all tests pass and analyzer is clean

### Phase 2: Pull Request

1. Create PR with title: `refactor: use Riverpod for audio player state`
2. Include summary of changes following PR #2551 format
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

## Approval Checklist

- [ ] Implementation plan reviewed
- [ ] Test strategy approved (90% minimum, 95% goal)
- [ ] File structure approved
- [ ] RecorderController integration approach approved
- [ ] Ready to proceed with implementation
