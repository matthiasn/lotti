import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
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
      () => mockCreationService.createScreenshotEntry(
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
        analysisTrigger: any(named: 'analysisTrigger'),
      ),
    ).thenAnswer((_) async => null);
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

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          child: TaskActionBar(task: testTask),
        ),
        overrides: [
          entryCreationServiceProvider.overrideWithValue(mockCreationService),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('renders Track time pill plus all five icon affordances', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(find.byKey(TaskActionBar.trackTimeKey), findsOneWidget);
    expect(find.byKey(TaskActionBar.checklistKey), findsOneWidget);
    expect(find.byKey(TaskActionBar.imageKey), findsOneWidget);
    expect(find.byKey(TaskActionBar.audioKey), findsOneWidget);
    expect(find.byKey(TaskActionBar.moreKey), findsOneWidget);
    expect(find.byKey(TaskActionBar.screenshotKey), findsOneWidget);

    // Idle state: localized "Track time" label + stopwatch icon, no
    // stop icon.
    expect(find.text('Track time'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
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
    'while a timer is running on this task: shows live elapsed and stop icon',
    (tester) async {
      await pumpBar(tester);

      const elapsed = Duration(minutes: 1, seconds: 30);
      fakeTimeService
        ..linkedFrom = testTask
        ..emit(_runningTimerEntry(id: 'timer-1', elapsed: elapsed));
      await _settleStream(tester);

      // formatDuration normalises the leading hour digit, so 1m30s →
      // "00:01:30" (the helper prepends a 0 when position 1 is a colon).
      expect(find.text('00:01:30'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
      expect(find.text('Track time'), findsNothing);
    },
  );

  testWidgets('tapping the pill while tracking this task calls stop()', (
    tester,
  ) async {
    await pumpBar(tester);

    fakeTimeService
      ..linkedFrom = testTask
      ..emit(
        _runningTimerEntry(id: 'timer-1', elapsed: const Duration(seconds: 5)),
      );
    await _settleStream(tester);

    await tester.tap(find.byKey(TaskActionBar.trackTimeKey));
    await tester.pump();

    expect(fakeTimeService.stopCount, 1);
    // Idle handler must NOT also fire when we were in the running state.
    verifyNever(
      () => mockCreationService.createTimerEntry(linked: any(named: 'linked')),
    );
  });

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

  testWidgets('screenshot tap calls createScreenshotEntry with task ids', (
    tester,
  ) async {
    await pumpBar(tester);

    await tester.tap(find.byKey(TaskActionBar.screenshotKey));
    await tester.pump();

    verify(
      () => mockCreationService.createScreenshotEntry(
        linkedId: testTask.meta.id,
        categoryId: testTask.meta.categoryId,
        analysisTrigger: any(named: 'analysisTrigger'),
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
        () => mockCreationService.createScreenshotEntry(
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
          analysisTrigger: any(named: 'analysisTrigger'),
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

  testWidgets(
    'on a 360-wide phone every action stays within the viewport — '
    'Wrap reflows narrow rows instead of overflowing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBar(tester);

      final viewportRight =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;

      for (final key in [
        TaskActionBar.trackTimeKey,
        TaskActionBar.checklistKey,
        TaskActionBar.imageKey,
        TaskActionBar.audioKey,
        TaskActionBar.moreKey,
        TaskActionBar.screenshotKey,
      ]) {
        final finder = find.byKey(key);
        expect(finder, findsOneWidget, reason: '$key should be rendered');
        final rect = tester.getRect(finder);
        expect(
          rect.right,
          lessThanOrEqualTo(viewportRight),
          reason:
              "$key sits at ${rect.right}px which is past the phone's "
              '${viewportRight}px right edge — Wrap did not reflow',
        );
      }
    },
  );
}
