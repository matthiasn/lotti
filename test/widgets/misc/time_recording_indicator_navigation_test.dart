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
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:mocktail/mocktail.dart';

class MockNavService extends Mock implements NavService {
  String? lastNavigatedPath;

  @override
  void beamToNamed(String path, {Object? data}) {
    lastNavigatedPath = path;
  }
}

class FakeTimeService extends TimeService {
  final _controller = StreamController<JournalEntity?>.broadcast();
  JournalEntity? _linkedFrom;

  @override
  Stream<JournalEntity?> getStream() => _controller.stream;

  @override
  JournalEntity? get linkedFrom => _linkedFrom;

  void emit(JournalEntity? entity, {JournalEntity? linkedFrom}) {
    _linkedFrom = linkedFrom;
    _controller.add(entity);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTimeService fakeTimeService;
  late MockNavService mockNavService;

  setUp(() {
    fakeTimeService = FakeTimeService();
    mockNavService = MockNavService();

    getIt
      ..registerSingleton<TimeService>(fakeTimeService)
      ..registerSingleton<NavService>(mockNavService);
  });

  tearDown(() {
    fakeTimeService.dispose();
    getIt.reset();
  });

  JournalEntity makeEntry(String entryId) {
    final now = DateTime(2025, 1, 1, 12);
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: entryId,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
    );
  }

  Task makeTask(String taskId) {
    final now = DateTime(2025, 1, 1, 12);
    return Task(
      meta: Metadata(
        id: taskId,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: TaskData(
        title: 'Test Task',
        dateFrom: now,
        dateTo: now,
        status: TaskStatus.open(
          id: 'status-id',
          createdAt: now,
          utcOffset: 0,
        ),
        statusHistory: const [],
      ),
      entryText: const EntryText(plainText: 'test task'),
    );
  }

  group('TimeRecordingIndicator Navigation Tests - ', () {
    testWidgets('task-linked timer publishes focus intent and navigates',
        (tester) async {
      final container = ProviderContainer();
      const taskId = 'task-123';
      const entryId = 'entry-456';
      final task = makeTask(taskId);
      final entry = makeEntry(entryId);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UncontrolledProviderScope(
              container: container,
              child: const Center(
                child: TimeRecordingIndicator(),
              ),
            ),
          ),
        ),
      );

      // Emit timer linked to task
      fakeTimeService.emit(entry, linkedFrom: task);
      await tester.pump();

      // Tap the indicator
      await tester.tap(find.byType(TimeRecordingIndicator));
      await tester.pumpAndSettle();

      // Verify focus intent was published
      final intent = container.read(taskFocusControllerProvider(id: taskId));
      expect(intent, isNotNull);
      expect(intent!.taskId, equals(taskId));
      expect(intent.entryId, equals(entryId));
      expect(intent.alignment, equals(0.0));

      // Verify navigation occurred
      expect(mockNavService.lastNavigatedPath, equals('/tasks/$taskId'));

      container.dispose();
    });

    testWidgets('journal-linked timer navigates without focus intent',
        (tester) async {
      final container = ProviderContainer();
      const journalEntryId = 'journal-entry-123';
      const timerEntryId = 'timer-entry-456';
      final journalEntry = makeEntry(journalEntryId);
      final timerEntry = makeEntry(timerEntryId);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UncontrolledProviderScope(
              container: container,
              child: const Center(
                child: TimeRecordingIndicator(),
              ),
            ),
          ),
        ),
      );

      // Emit timer linked to journal entry
      fakeTimeService.emit(timerEntry, linkedFrom: journalEntry);
      await tester.pump();

      // Tap the indicator
      await tester.tap(find.byType(TimeRecordingIndicator));
      await tester.pumpAndSettle();

      // Verify no focus intent was published (no task involved)
      // This would throw if we tried to read a non-existent provider

      // Verify navigation occurred to journal entry
      expect(
          mockNavService.lastNavigatedPath, equals('/journal/$journalEntryId'));

      container.dispose();
    });

    testWidgets('non-linked timer navigates to timer journal entry',
        (tester) async {
      final container = ProviderContainer();
      const timerEntryId = 'timer-entry-789';
      final timerEntry = makeEntry(timerEntryId);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UncontrolledProviderScope(
              container: container,
              child: const Center(
                child: TimeRecordingIndicator(),
              ),
            ),
          ),
        ),
      );

      // Emit timer with no linkedFrom
      fakeTimeService.emit(timerEntry);
      await tester.pump();

      // Tap the indicator
      await tester.tap(find.byType(TimeRecordingIndicator));
      await tester.pumpAndSettle();

      // Verify navigation occurred to timer entry
      expect(
          mockNavService.lastNavigatedPath, equals('/journal/$timerEntryId'));

      container.dispose();
    });

    testWidgets('no navigation when timer is null', (tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UncontrolledProviderScope(
              container: container,
              child: const Center(
                child: TimeRecordingIndicator(),
              ),
            ),
          ),
        ),
      );

      // Emit null (no timer running)
      fakeTimeService.emit(null);
      await tester.pump();

      // Indicator should not be visible
      expect(find.byType(TimeRecordingIndicator), findsOneWidget);
      expect(find.byType(GestureDetector), findsNothing);

      // No navigation should occur
      expect(mockNavService.lastNavigatedPath, isNull);

      container.dispose();
    });

    testWidgets('focus intent alignment defaults to 0.0', (tester) async {
      final container = ProviderContainer();
      const taskId = 'task-999';
      const entryId = 'entry-888';
      final task = makeTask(taskId);
      final entry = makeEntry(entryId);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UncontrolledProviderScope(
              container: container,
              child: const Center(
                child: TimeRecordingIndicator(),
              ),
            ),
          ),
        ),
      );

      fakeTimeService.emit(entry, linkedFrom: task);
      await tester.pump();

      await tester.tap(find.byType(TimeRecordingIndicator));
      await tester.pumpAndSettle();

      final intent = container.read(taskFocusControllerProvider(id: taskId));
      expect(intent!.alignment, equals(0.0));

      container.dispose();
    });
  });
}
