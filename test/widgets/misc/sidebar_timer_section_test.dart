import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/misc/sidebar_timer_section.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

/// Stateful fake of [TimeService] used for stream-driven UI assertions.
/// Mocktail's `Mock` doesn't fit here — we want emissions and a real
/// stream subscription, not stubbed return values. The shared
/// `MockTimeService` in `test/mocks/mocks.dart` is for tests that only
/// need stubbed methods.
class _FakeTimeService extends TimeService {
  final _controller = StreamController<JournalEntity?>.broadcast();
  JournalEntity? _linkedFrom;
  int stopCalls = 0;

  @override
  Stream<JournalEntity?> getStream() => _controller.stream;

  @override
  JournalEntity? get linkedFrom => _linkedFrom;

  void emit(JournalEntity? entity, {JournalEntity? linkedFrom}) {
    _linkedFrom = linkedFrom;
    _controller.add(entity);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    _linkedFrom = null;
    _controller.add(null);
  }

  void disposeController() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTimeService timeService;
  late MockNavService navService;
  late ValueNotifier<String?> desktopSelectedTaskId;
  late StreamController<int> indexStreamController;

  /// Push a new currentPath into the stubbed [NavService] and emit on
  /// the index stream so subscribed widgets re-evaluate.
  void setCurrentPath(String path) {
    when(() => navService.currentPath).thenReturn(path);
    indexStreamController.add(0);
  }

  setUp(() async {
    timeService = _FakeTimeService();
    navService = MockNavService();
    desktopSelectedTaskId = ValueNotifier<String?>(null);
    indexStreamController = StreamController<int>.broadcast();
    // Mocktail records every call by default; nav routes are inspected
    // via `verify(...).captured` in the assertion phase.
    when(() => navService.beamToNamed(any())).thenAnswer((_) {});
    when(
      () => navService.desktopSelectedTaskId,
    ).thenReturn(desktopSelectedTaskId);
    when(
      () => navService.getIndexStream(),
    ).thenAnswer((_) => indexStreamController.stream);
    // Default to a task-detail route so the existing tests, which
    // expect the sidebar to render the running card, hit the
    // common-path branch. Tests exercising tab-switch behavior
    // override this via [setCurrentPath].
    when(() => navService.currentPath).thenReturn('/tasks/some-task');

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<TimeService>(timeService)
          ..registerSingleton<NavService>(navService);
      },
    );
  });

  tearDown(() async {
    timeService.disposeController();
    desktopSelectedTaskId.dispose();
    await indexStreamController.close();
    await tearDownTestGetIt();
  });

  String? lastBeamedPath() {
    final captured = verify(
      () => navService.beamToNamed(captureAny()),
    ).captured;
    return captured.isEmpty ? null : captured.last as String;
  }

  JournalEntity makeTimerEntry(String id, {Duration elapsed = Duration.zero}) {
    final from = DateTime(2026, 5, 5, 21, 30);
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: from,
        updatedAt: from.add(elapsed),
        dateFrom: from,
        dateTo: from.add(elapsed),
      ),
    );
  }

  Task makeTask(String id, {String? title}) {
    final now = DateTime(2026, 5, 5, 21);
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: TaskData(
        title: title ?? 'Implement sidebar timer',
        dateFrom: now,
        dateTo: now,
        status: TaskStatus.open(
          id: 'status-id',
          createdAt: now,
          utcOffset: 0,
        ),
        statusHistory: const [],
      ),
      entryText: const EntryText(plainText: 'task plain text'),
    );
  }

  testWidgets('renders nothing when no timer is running', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const SidebarTimerSection()),
    );

    timeService.emit(null);
    await tester.pump();
    await tester.pump(SidebarTimerSection.animationDuration);

    expect(find.byType(InkWell), findsNothing);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
  });

  testWidgets('shows task title and formatted duration when timer active', (
    tester,
  ) async {
    final task = makeTask('task-1', title: 'Payment confirmation');
    final timer = makeTimerEntry(
      'timer-1',
      elapsed: const Duration(hours: 1, minutes: 23, seconds: 45),
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const SidebarTimerSection()),
    );

    timeService.emit(timer, linkedFrom: task);
    await tester.pump();
    await tester.pump(SidebarTimerSection.animationDuration);

    expect(find.text('Payment confirmation'), findsOneWidget);
    expect(find.text('01:23:45'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
  });

  testWidgets('time text uses Inter font features (tabular + open digits)', (
    tester,
  ) async {
    final task = makeTask('task-2');
    final timer = makeTimerEntry(
      'timer-2',
      elapsed: const Duration(minutes: 4, seconds: 9),
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const SidebarTimerSection()),
    );

    timeService.emit(timer, linkedFrom: task);
    await tester.pump();
    await tester.pump(SidebarTimerSection.animationDuration);

    final timeWidget = tester.widget<Text>(find.text('00:04:09'));
    final features = timeWidget.style?.fontFeatures ?? const <FontFeature>[];
    expect(features, contains(const FontFeature.tabularFigures()));
    expect(features, contains(const FontFeature.slashedZero()));
    expect(features, contains(const FontFeature('cv02'))); // open 4
    expect(features, contains(const FontFeature('cv03'))); // open 6
    expect(features, contains(const FontFeature('cv04'))); // open 9
  });

  testWidgets('tapping body navigates to task and publishes focus intent', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final task = makeTask('task-3');
    final timer = makeTimerEntry('timer-3');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: makeTestableWidgetWithScaffold(
          const SidebarTimerSection(),
        ),
      ),
    );

    timeService.emit(timer, linkedFrom: task);
    await tester.pump();
    await tester.pump(SidebarTimerSection.animationDuration);

    // Tap on the title text to ensure body taps (not the stop button) navigate
    await tester.tap(find.text('Implement sidebar timer'));
    await tester.pump();

    expect(lastBeamedPath(), equals('/tasks/task-3'));
    final intent = container.read(taskFocusControllerProvider(id: 'task-3'));
    expect(intent, isNotNull);
    expect(intent!.taskId, equals('task-3'));
    expect(intent.entryId, equals('timer-3'));
  });

  testWidgets('tapping stop button calls TimeService.stop and not navigate', (
    tester,
  ) async {
    final task = makeTask('task-4');
    final timer = makeTimerEntry('timer-4');

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const SidebarTimerSection()),
    );

    timeService.emit(timer, linkedFrom: task);
    await tester.pump();
    await tester.pump(SidebarTimerSection.animationDuration);

    await tester.tap(find.byIcon(Icons.stop_rounded));
    // Two pumps for the broadcast stream + rebuild, then settle the
    // fade-out so the outgoing card is removed from the tree.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(timeService.stopCalls, equals(1));
    verifyNever(() => navService.beamToNamed(any()));
    // After stopping, the section collapses
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
  });

  testWidgets('falls back to "(untitled)" when task has empty title', (
    tester,
  ) async {
    final task = makeTask('task-5', title: '');
    final timer = makeTimerEntry('timer-5');

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const SidebarTimerSection()),
    );

    timeService.emit(timer, linkedFrom: task);
    await tester.pump();
    await tester.pump(SidebarTimerSection.animationDuration);

    // Falls back to plainText when title is empty
    expect(find.text('task plain text'), findsOneWidget);
  });

  testWidgets(
    'hides the card when the running task is open in the details pane',
    (tester) async {
      final task = makeTask('task-open', title: 'Refine sidebar visibility');
      final timer = makeTimerEntry(
        'timer-open',
        elapsed: const Duration(minutes: 12),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SidebarTimerSection()),
      );

      timeService.emit(timer, linkedFrom: task);
      await tester.pump();
      expect(find.text('Refine sidebar visibility'), findsOneWidget);

      desktopSelectedTaskId.value = 'task-open';
      // Pump past the fade+collapse animation.
      await tester.pump();
      await tester.pump(SidebarTimerSection.animationDuration);

      expect(find.text('Refine sidebar visibility'), findsNothing);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    },
  );

  testWidgets(
    'reappears when navigating away from the running task',
    (tester) async {
      final task = makeTask('task-here', title: 'Tracked');
      final timer = makeTimerEntry('timer-here');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SidebarTimerSection()),
      );

      timeService.emit(timer, linkedFrom: task);
      desktopSelectedTaskId.value = 'task-here';
      await tester.pump();
      await tester.pump(SidebarTimerSection.animationDuration);
      expect(find.text('Tracked'), findsNothing);

      desktopSelectedTaskId.value = 'some-other-task';
      await tester.pump();
      await tester.pump(SidebarTimerSection.animationDuration);

      expect(find.text('Tracked'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'stays visible when on a non-task route, even if selected task matches',
    (tester) async {
      // Sticky state: user opened a task, started a timer, then
      // switched tabs. desktopSelectedTaskId is still pointing at the
      // task, but the user is now on /habits, so the sticky action bar
      // is no longer visible — the sidebar must keep showing the
      // running indicator.
      final task = makeTask('task-sticky', title: 'Sticky');
      final timer = makeTimerEntry('timer-sticky');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SidebarTimerSection()),
      );

      timeService.emit(timer, linkedFrom: task);
      desktopSelectedTaskId.value = 'task-sticky';
      await tester.pump();
      await tester.pump(SidebarTimerSection.animationDuration);
      // Sanity: while on the task route, the card is hidden.
      expect(find.text('Sticky'), findsNothing);

      // User switches to the Habits tab — currentPath is no longer a
      // task-detail route. The card must come back.
      setCurrentPath('/habits');
      await tester.pump();
      await tester.pump(SidebarTimerSection.animationDuration);

      expect(find.text('Sticky'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'stays visible when the running timer is not linked to a task',
    (tester) async {
      // A bare journal-entry timer (no Task linkedFrom) should never be
      // hidden by the open-task check, even if a task happens to be
      // selected in the details pane.
      final linked = makeTimerEntry('linked-loose');
      final timer = makeTimerEntry('timer-loose');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SidebarTimerSection()),
      );

      timeService.emit(timer, linkedFrom: linked);
      desktopSelectedTaskId.value = 'unrelated-task';
      await tester.pump();
      await tester.pump(SidebarTimerSection.animationDuration);

      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    },
  );

  testWidgets('non-task linkedFrom navigates to journal entry', (tester) async {
    final linked = makeTimerEntry('linked-6');
    final timer = makeTimerEntry('timer-6');

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const SidebarTimerSection()),
    );

    timeService.emit(timer, linkedFrom: linked);
    await tester.pump();
    await tester.pump(SidebarTimerSection.animationDuration);

    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pump();

    expect(lastBeamedPath(), equals('/journal/linked-6'));
  });
}
