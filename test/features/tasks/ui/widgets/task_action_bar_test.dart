import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

/// In-memory [TimeService] stand-in: lets the test push values onto the
/// stream and assert against `getCurrent()` / `linkedFrom`. We can't use
/// `MockTimeService` from mocks.dart because the bar reads
/// `timeService.linkedFrom` directly (a field, not a method) and
/// mocktail can't stub field reads.
class _FakeTimeService implements TimeService {
  final StreamController<JournalEntity?> _controller =
      StreamController<JournalEntity?>.broadcast();
  JournalEntity? _current;
  int stopCount = 0;

  @override
  JournalEntity? linkedFrom;

  @override
  Stream<JournalEntity?> getStream() => _controller.stream;

  @override
  JournalEntity? getCurrent() => _current;

  @override
  Future<void> start(JournalEntity entity, JournalEntity? linked) async {
    _current = entity;
    linkedFrom = linked;
    _controller.add(entity);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _current = null;
    linkedFrom = null;
    _controller.add(null);
  }

  @override
  void updateCurrent(JournalEntity? current) {
    _current = current;
  }

  /// Pushes a value through the stream as if a tick had just fired.
  void emit(JournalEntity? entity) {
    _current = entity;
    _controller.add(entity);
  }

  Future<void> close() => _controller.close();
}

class _MockEntryCreationService extends Mock implements EntryCreationService {}

/// Stand-in for the audio recorder controller so the action bar can
/// observe a recorder state without booting the real recorder
/// repository (which depends on platform plugins).
class _StubAudioRecorderController extends AudioRecorderController {
  _StubAudioRecorderController(this._initial);
  final AudioRecorderState _initial;

  @override
  AudioRecorderState build() => _initial;
}

AudioRecorderState _idleRecorderState() => AudioRecorderState(
  status: AudioRecorderStatus.stopped,
  progress: Duration.zero,
  vu: -20,
  dBFS: -160,
  showIndicator: false,
  modalVisible: false,
);

AudioRecorderState _recordingRecorderState({required String linkedId}) =>
    AudioRecorderState(
      status: AudioRecorderStatus.recording,
      progress: const Duration(seconds: 5),
      vu: -10,
      dBFS: -100,
      showIndicator: true,
      modalVisible: false,
      linkedId: linkedId,
    );

/// Fallback shell so mocktail's `any<BuildContext>()` matcher has a
/// valid prototype value for null safety. The instance is never
/// interacted with — it only needs to exist.
class _FakeBuildContext extends Fake implements BuildContext {}

/// Builds a timer entry whose dateTo - dateFrom == [elapsed]. Used to
/// drive the live-elapsed-time readout the bar shows while tracking.
JournalEntry _runningTimerEntry({
  required String id,
  required Duration elapsed,
}) {
  final start = DateTime(2026, 5, 5, 9);
  return JournalEntry(
    meta: Metadata(
      id: id,
      createdAt: start,
      updatedAt: start.add(elapsed),
      dateFrom: start,
      dateTo: start.add(elapsed),
    ),
    entryText: const EntryText(plainText: ''),
  );
}

/// Drains the broadcast stream listener (one async hop) and pumps a
/// frame. Replaces the previous "two bare pumps" pattern.
Future<void> _settleStream(WidgetTester tester) async {
  await tester.pump(Duration.zero);
  await tester.pump();
}

void main() {
  late _FakeTimeService fakeTimeService;
  late _MockEntryCreationService mockCreationService;

  setUpAll(() {
    registerFallbackValue(testTask);
    registerFallbackValue(_FakeBuildContext());
  });

  setUp(() async {
    fakeTimeService = _FakeTimeService();
    mockCreationService = _MockEntryCreationService();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<TimeService>(fakeTimeService);
      },
    );

    // Default stubs so taps on each affordance complete cleanly even
    // when the test isn't asserting on that specific call.
    when(
      () => mockCreationService.createTimerEntry(linked: any(named: 'linked')),
    ).thenAnswer((_) async => null);
    when(
      () => mockCreationService.createChecklist(task: any(named: 'task')),
    ).thenAnswer((_) async => null);
    when(
      () => mockCreationService.importImage(
        any(),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
        analysisTrigger: any(named: 'analysisTrigger'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockCreationService.showCreateEntryModal(
        any(),
        linkedFromId: any(named: 'linkedFromId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockCreationService.showAudioRecordingModal(
        any(),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) {});
  });

  tearDown(() async {
    await fakeTimeService.close();
    await tearDownTestGetIt();
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    AudioRecorderState? recorderState,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          child: TaskActionBar(task: testTask),
        ),
        overrides: [
          entryCreationServiceProvider.overrideWithValue(mockCreationService),
          audioRecorderControllerProvider.overrideWith(
            () => _StubAudioRecorderController(
              recorderState ?? _idleRecorderState(),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('renders Track time pill plus all four icon affordances', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(find.byKey(TaskActionBar.trackTimeKey), findsOneWidget);
    expect(find.byKey(TaskActionBar.checklistKey), findsOneWidget);
    expect(find.byKey(TaskActionBar.imageKey), findsOneWidget);
    expect(find.byKey(TaskActionBar.audioKey), findsOneWidget);
    expect(find.byKey(TaskActionBar.moreKey), findsOneWidget);

    // Idle state: localized "Track time" label + stopwatch icon, no
    // inset stop button.
    expect(find.text('Track time'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byKey(TaskActionBar.trackTimeStopKey), findsNothing);
  });

  testWidgets(
    'idle Track time tap calls createTimerEntry(linked: this task)',
    (tester) async {
      await pumpBar(tester);

      await tester.tap(find.byKey(TaskActionBar.trackTimeKey));
      await tester.pump();

      verify(
        () => mockCreationService.createTimerEntry(linked: testTask),
      ).called(1);
    },
  );

  testWidgets(
    'while a timer is running on this task: shows live elapsed and inset stop button',
    (tester) async {
      await pumpBar(tester);

      const elapsed = Duration(minutes: 1, seconds: 30);
      fakeTimeService
        ..linkedFrom = testTask
        ..emit(_runningTimerEntry(id: 'timer-1', elapsed: elapsed));
      await _settleStream(tester);

      // Under one hour the pill drops the hour field for compactness:
      // 1m30s → "01:30".
      expect(find.text('01:30'), findsOneWidget);
      expect(find.byKey(TaskActionBar.trackTimeStopKey), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
      expect(find.text('Track time'), findsNothing);
    },
  );

  testWidgets(
    'at one hour or more the pill falls back to hh:mm:ss',
    (tester) async {
      await pumpBar(tester);

      const elapsed = Duration(hours: 1, minutes: 2, seconds: 3);
      fakeTimeService
        ..linkedFrom = testTask
        ..emit(_runningTimerEntry(id: 'timer-1', elapsed: elapsed));
      await _settleStream(tester);

      // Shared formatDuration prepends a leading zero when the hour is
      // a single digit, so 1h02m03s → "01:02:03".
      expect(find.text('01:02:03'), findsOneWidget);
    },
  );

  testWidgets(
    'duration text uses tabular figures + cv02/03/04 + slashed zero',
    (tester) async {
      await pumpBar(tester);

      fakeTimeService
        ..linkedFrom = testTask
        ..emit(
          _runningTimerEntry(
            id: 'timer-1',
            elapsed: const Duration(seconds: 5),
          ),
        );
      await _settleStream(tester);

      final durationText = tester.widget<Text>(find.text('00:05'));
      final features =
          durationText.style?.fontFeatures ?? const <FontFeature>[];
      expect(features, contains(const FontFeature.tabularFigures()));
      expect(features, contains(const FontFeature('cv02')));
      expect(features, contains(const FontFeature('cv03')));
      expect(features, contains(const FontFeature('cv04')));
      expect(features, contains(const FontFeature.slashedZero()));
    },
  );

  testWidgets(
    'tapping the inset stop button stops the timer; the body does not',
    (tester) async {
      await pumpBar(tester);

      fakeTimeService
        ..linkedFrom = testTask
        ..emit(
          _runningTimerEntry(
            id: 'timer-1',
            elapsed: const Duration(seconds: 5),
          ),
        );
      await _settleStream(tester);

      await tester.tap(find.byKey(TaskActionBar.trackTimeStopKey));
      await tester.pump();

      expect(fakeTimeService.stopCount, 1);
      verifyNever(
        () =>
            mockCreationService.createTimerEntry(linked: any(named: 'linked')),
      );
    },
  );

  testWidgets(
    'tapping the pill body while tracking navigates to the running '
    'task and does NOT stop the timer',
    (tester) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;
      addTearDown(() => beamToNamedOverride = null);

      await pumpBar(tester);

      fakeTimeService
        ..linkedFrom = testTask
        ..emit(
          _runningTimerEntry(
            id: 'timer-1',
            elapsed: const Duration(seconds: 5),
          ),
        );
      await _settleStream(tester);

      // The duration text is the visible centre of the pill body, well
      // away from the inset stop circle on the leading edge — so a
      // direct tap on it can only hit the navigate handler.
      await tester.tap(find.text('00:05'));
      await tester.pump();

      expect(navigatedPath, '/tasks/${testTask.meta.id}');
      expect(fakeTimeService.stopCount, 0);
      verifyNever(
        () =>
            mockCreationService.createTimerEntry(linked: any(named: 'linked')),
      );
    },
  );

  testWidgets(
    'a timer running for a different task leaves this bar in the idle state',
    (tester) async {
      await pumpBar(tester);

      final otherTask = testTask.copyWith(
        meta: testTask.meta.copyWith(id: 'some-other-task-id'),
      );
      fakeTimeService
        ..linkedFrom = otherTask
        ..emit(
          _runningTimerEntry(
            id: 'timer-1',
            elapsed: const Duration(seconds: 5),
          ),
        );
      await _settleStream(tester);

      expect(find.text('Track time'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    },
  );

  testWidgets('checklist tap calls createChecklist(task: this task)', (
    tester,
  ) async {
    await pumpBar(tester);

    await tester.tap(find.byKey(TaskActionBar.checklistKey));
    await tester.pump();

    verify(
      () => mockCreationService.createChecklist(task: testTask),
    ).called(1);
  });

  testWidgets('image tap calls importImage with task ids', (tester) async {
    await pumpBar(tester);

    await tester.tap(find.byKey(TaskActionBar.imageKey));
    await tester.pump();

    verify(
      () => mockCreationService.importImage(
        any(),
        linkedId: testTask.meta.id,
        categoryId: testTask.meta.categoryId,
        analysisTrigger: any(named: 'analysisTrigger'),
      ),
    ).called(1);
  });

  testWidgets('audio button calls showAudioRecordingModal with task ids', (
    tester,
  ) async {
    await pumpBar(tester);

    await tester.tap(find.byKey(TaskActionBar.audioKey));
    await tester.pump();

    verify(
      () => mockCreationService.showAudioRecordingModal(
        any(),
        linkedId: testTask.meta.id,
        categoryId: testTask.meta.categoryId,
      ),
    ).called(1);
  });

  /// Reads the round audio button's background color directly off the
  /// inner Container so we can compare against the design tokens'
  /// alert/error red and the default surface-hover color.
  Color audioButtonFill(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byKey(TaskActionBar.audioKey),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      ),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  testWidgets(
    'audio button turns red while recording is active for THIS task',
    (tester) async {
      await pumpBar(
        tester,
        recorderState: _recordingRecorderState(linkedId: testTask.meta.id),
      );

      final tokens = tester
          .element(find.byKey(TaskActionBar.audioKey))
          .designTokens;
      expect(audioButtonFill(tester), tokens.colors.alert.error.defaultColor);
    },
  );

  testWidgets(
    'audio button stays neutral while recording is active for ANOTHER task',
    (tester) async {
      await pumpBar(
        tester,
        recorderState: _recordingRecorderState(linkedId: 'some-other-task-id'),
      );

      final tokens = tester
          .element(find.byKey(TaskActionBar.audioKey))
          .designTokens;
      expect(audioButtonFill(tester), tokens.colors.surface.hover);
      expect(
        audioButtonFill(tester),
        isNot(tokens.colors.alert.error.defaultColor),
      );
    },
  );

  testWidgets(
    'audio button stays neutral when recorder is idle',
    (tester) async {
      await pumpBar(tester);

      final tokens = tester
          .element(find.byKey(TaskActionBar.audioKey))
          .designTokens;
      expect(audioButtonFill(tester), tokens.colors.surface.hover);
    },
  );

  testWidgets('more tap opens the create-entry modal with task ids', (
    tester,
  ) async {
    await pumpBar(tester);

    await tester.tap(find.byKey(TaskActionBar.moreKey));
    await tester.pump();

    verify(
      () => mockCreationService.showCreateEntryModal(
        any(),
        linkedFromId: testTask.meta.id,
        categoryId: testTask.meta.categoryId,
      ),
    ).called(1);
  });

  testWidgets(
    'each round button only fires its own handler — wiring is not crossed',
    (tester) async {
      await pumpBar(tester);

      await tester.tap(find.byKey(TaskActionBar.checklistKey));
      await tester.pump();

      // After a checklist tap, none of the other handlers should fire.
      verifyNever(
        () => mockCreationService.importImage(
          any(),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
          analysisTrigger: any(named: 'analysisTrigger'),
        ),
      );
      verifyNever(
        () => mockCreationService.showAudioRecordingModal(
          any(),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      );
      verifyNever(
        () => mockCreationService.showCreateEntryModal(
          any(),
          linkedFromId: any(named: 'linkedFromId'),
          categoryId: any(named: 'categoryId'),
        ),
      );
      verifyNever(
        () =>
            mockCreationService.createTimerEntry(linked: any(named: 'linked')),
      );
    },
  );

  testWidgets(
    'paints an edge-to-edge glass strip via DesignSystemGlassStrip',
    (tester) async {
      await pumpBar(tester);

      // Per the Figma: no rounded outer card — instead a hairline
      // divider on top and a BackdropFilter behind the row, both
      // bundled inside [DesignSystemGlassStrip].
      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);

      // Hairline: a 1-px-tall Container that lives inside the strip.
      // Match by predicate so the assertion isn't tied to tree position.
      final hairline = find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.maxHeight == 1,
        description: '1-px-tall hairline divider',
      );
      expect(hairline, findsOneWidget);
    },
  );

  /// Asserts that every key in [keys] is on the same horizontal row
  /// (vertical centres aligned within 1 px) and stays within the
  /// viewport's horizontal bounds.
  void expectSingleRowWithin(WidgetTester tester, List<Key> keys) {
    final centres = keys
        .map((k) => tester.getRect(find.byKey(k)).center.dy)
        .toList();
    for (final dy in centres.skip(1)) {
      expect(
        (dy - centres.first).abs(),
        lessThan(1),
        reason: 'Children must stay on a single row',
      );
    }
    final viewportRight =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final key in keys) {
      expect(
        tester.getRect(find.byKey(key)).right,
        lessThanOrEqualTo(viewportRight),
        reason: '$key extends past the ${viewportRight}px right edge',
      );
    }
  }

  testWidgets(
    'when inner width is below the checklist threshold, both image and '
    'checklist are hidden so the remaining three affordances fit on a row',
    (tester) async {
      // Outer 360 → inner ~328, which is below
      // [TaskActionBar.minWidthForChecklistButton] (340).
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBar(tester);

      expect(find.byKey(TaskActionBar.imageKey), findsNothing);
      expect(find.byKey(TaskActionBar.checklistKey), findsNothing);

      expectSingleRowWithin(tester, const [
        TaskActionBar.trackTimeKey,
        TaskActionBar.audioKey,
        TaskActionBar.moreKey,
      ]);
    },
  );

  testWidgets(
    'when inner width is between the checklist and image thresholds, only '
    'image is hidden — checklist stays on the row',
    (tester) async {
      // Outer 420 → inner ~388, which is at-or-above
      // [TaskActionBar.minWidthForChecklistButton] (340) and below
      // [TaskActionBar.minWidthForImageButton] (400).
      await tester.binding.setSurfaceSize(const Size(420, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBar(tester);

      expect(find.byKey(TaskActionBar.imageKey), findsNothing);
      expect(find.byKey(TaskActionBar.checklistKey), findsOneWidget);

      expectSingleRowWithin(tester, const [
        TaskActionBar.trackTimeKey,
        TaskActionBar.audioKey,
        TaskActionBar.checklistKey,
        TaskActionBar.moreKey,
      ]);
    },
  );

  testWidgets(
    'on a wide viewport (>= minWidthForImageButton) every affordance is '
    'rendered',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBar(tester);

      expect(find.byKey(TaskActionBar.imageKey), findsOneWidget);
      expect(find.byKey(TaskActionBar.checklistKey), findsOneWidget);
    },
  );
}
