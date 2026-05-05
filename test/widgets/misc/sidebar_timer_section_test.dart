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

  setUp(() async {
    timeService = _FakeTimeService();
    navService = MockNavService();
    // Mocktail records every call by default; nav routes are inspected
    // via `verify(...).captured` in the assertion phase.
    when(() => navService.beamToNamed(any())).thenAnswer((_) {});

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

    // Tap on the title text to ensure body taps (not the stop button) navigate
    await tester.tap(find.text('Implement sidebar timer'));
    await tester.pumpAndSettle();

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

    await tester.tap(find.byIcon(Icons.stop_rounded));
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

    // Falls back to plainText when title is empty
    expect(find.text('task plain text'), findsOneWidget);
  });

  testWidgets('non-task linkedFrom navigates to journal entry', (tester) async {
    final linked = makeTimerEntry('linked-6');
    final timer = makeTimerEntry('timer-6');

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const SidebarTimerSection()),
    );

    timeService.emit(timer, linkedFrom: linked);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pumpAndSettle();

    expect(lastBeamedPath(), equals('/journal/linked-6'));
  });
}
