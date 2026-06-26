import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/misc/timer_navigation.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  late MockNavService mockNavService;

  setUp(() async {
    mockNavService = MockNavService();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  final now = DateTime(2025, 1, 1, 12);

  JournalEntity makeEntry(String id) => JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
  );

  Task makeTask(String id) => Task(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: TaskData(
      title: 'Task',
      status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
    ),
  );

  /// Pumps a probe widget exposing a [WidgetRef] and returns its container.
  Future<(WidgetRef, ProviderContainer)> pumpRef(WidgetTester tester) async {
    late WidgetRef capturedRef;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return (capturedRef, container);
  }

  testWidgets(
    'linked task: publishes focus intent and beams to the task route',
    (tester) async {
      final (ref, container) = await pumpRef(tester);
      final task = makeTask('task-1');
      final entry = makeEntry('entry-1');

      navigateToTimerTarget(current: entry, linkedFrom: task, ref: ref);

      verify(() => mockNavService.beamToNamed('/tasks/task-1')).called(1);
      final intent = container.read(taskFocusControllerProvider('task-1'));
      expect(intent?.entryId, 'entry-1');
    },
  );

  testWidgets(
    'linked non-task entity beams to its journal route without focus intent',
    (tester) async {
      final (ref, container) = await pumpRef(tester);
      final parent = makeEntry('parent-1');
      final entry = makeEntry('entry-1');

      navigateToTimerTarget(current: entry, linkedFrom: parent, ref: ref);

      verify(() => mockNavService.beamToNamed('/journal/parent-1')).called(1);
      expect(
        container.read(taskFocusControllerProvider('parent-1')),
        isNull,
      );
    },
  );

  testWidgets('standalone timer beams to the current entry route', (
    tester,
  ) async {
    final (ref, _) = await pumpRef(tester);
    final entry = makeEntry('entry-1');

    navigateToTimerTarget(current: entry, linkedFrom: null, ref: ref);

    verify(() => mockNavService.beamToNamed('/journal/entry-1')).called(1);
  });
}
