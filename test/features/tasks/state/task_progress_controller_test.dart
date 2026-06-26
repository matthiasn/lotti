import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/util/time_range_utils.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

// This matches the signature of the getter linkedFrom in TimeService
// Create a fake TaskProgressState for registerFallbackValue
@immutable // Adding @immutable for equals and hashCode methods
class FakeTaskProgressState implements TaskProgressState {
  @override
  Duration get progress => Duration.zero;

  @override
  Duration get estimate => Duration.zero;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  bool operator ==(Object other) => false;

  @override
  int get hashCode => 0;
}

void main() {
  late ProviderContainer container;
  late MockTaskProgressRepository mockRepository;
  late MockTimeService mockTimeService;
  late MockUpdateNotifications mockUpdateNotifications;
  late StreamController<Set<String>> updateStreamController;
  late StreamController<JournalEntity?> timeServiceStreamController;

  const testTaskId = 'test-task-id';
  const testEstimate = Duration(hours: 2);
  final testTimeRanges = <String, TimeRange>{
    'entry1': TimeRange(
      start: DateTime(2022, 7, 7, 9),
      end: DateTime(2022, 7, 7, 9, 30), // 30 min
    ),
    'entry2': TimeRange(
      start: DateTime(2022, 7, 7, 14),
      end: DateTime(2022, 7, 7, 14, 45), // 45 min
    ),
  };
  const testProgress = TaskProgressState(
    progress: Duration(minutes: 75),
    estimate: testEstimate,
  );

  setUpAll(() {
    // Register fallback values for Mocktail matchers
    registerFallbackValue(const AsyncValue<TaskProgressState?>.loading());
    registerFallbackValue(const AsyncValue<TaskProgressState?>.data(null));
    registerFallbackValue(FakeTaskProgressState());
    registerFallbackValue(<String, TimeRange>{});
  });

  setUp(() async {
    mockRepository = MockTaskProgressRepository();
    mockTimeService = MockTimeService();
    mockUpdateNotifications = MockUpdateNotifications();

    updateStreamController = StreamController<Set<String>>.broadcast();
    timeServiceStreamController = StreamController<JournalEntity?>.broadcast();

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);

    when(
      () => mockTimeService.getStream(),
    ).thenAnswer((_) => timeServiceStreamController.stream);

    // setUpTestGetIt resets GetIt and registers the common mocks (including a
    // no-op UpdateNotifications). Swap in our stream-backed UpdateNotifications
    // and register the TimeService the controller resolves via GetIt.
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
          ..registerSingleton<TimeService>(mockTimeService);
      },
    );

    container = ProviderContainer(
      overrides: [
        taskProgressRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );

    // Mock repository methods with specific values
    when(
      () => mockRepository.getTaskProgressData(id: testTaskId),
    ).thenAnswer((_) async => (testEstimate, testTimeRanges));

    when(
      () => mockRepository.getTaskProgress(
        timeRanges: testTimeRanges,
        estimate: testEstimate,
      ),
    ).thenReturn(testProgress);
  });

  tearDown(() async {
    container.dispose();
    await updateStreamController.close();
    await timeServiceStreamController.close();
    await tearDownTestGetIt();
  });

  test('initial state loads task progress data', () async {
    // Add a listener to track state changes
    container.listen(
      taskProgressControllerProvider(testTaskId),
      (_, _) {},
      fireImmediately: true,
    );

    // Wait for the future to complete
    await container.read(taskProgressControllerProvider(testTaskId).future);

    // Verify the data was fetched from the repository
    verify(() => mockRepository.getTaskProgressData(id: testTaskId)).called(1);

    // Verify the state contains the expected data
    final state = container.read(
      taskProgressControllerProvider(testTaskId),
    );
    expect(state.value, equals(testProgress));
  });

  test(
    'updates state when relevant update notifications are received',
    () async {
      // Set up initial state
      await container.read(
        taskProgressControllerProvider(testTaskId).future,
      );

      // Clear previous invocations
      clearInteractions(mockRepository);

      // Create updated data for the second fetch
      final updatedTimeRanges = <String, TimeRange>{
        'entry1': TimeRange(
          start: DateTime(2022, 7, 7, 9),
          end: DateTime(2022, 7, 7, 9, 30), // 30 min
        ),
        'entry2': TimeRange(
          start: DateTime(2022, 7, 7, 14),
          end: DateTime(2022, 7, 7, 15), // 60 min
        ),
      };
      const updatedProgress = TaskProgressState(
        progress: Duration(minutes: 90),
        estimate: testEstimate,
      );

      when(
        () => mockRepository.getTaskProgressData(id: testTaskId),
      ).thenAnswer((_) async => (testEstimate, updatedTimeRanges));

      when(
        () => mockRepository.getTaskProgress(
          timeRanges: updatedTimeRanges,
          estimate: testEstimate,
        ),
      ).thenReturn(updatedProgress);

      // Listen for the updated state
      final updated = Completer<void>();
      final sub = container.listen(
        taskProgressControllerProvider(testTaskId),
        (_, next) {
          if (!updated.isCompleted && next.value == updatedProgress) {
            updated.complete();
          }
        },
      );

      // Trigger update notification with the changed entry id. Completion
      // is deterministic: the notification triggers _fetch (mocked,
      // microtask-only) and the listener completes the completer when the
      // updated state lands — no wall-clock timeout (fake-time policy).
      updateStreamController.add({'entry2'});
      await updated.future;
      sub.close();

      // Verify the data was fetched again and state updated
      verify(
        () => mockRepository.getTaskProgressData(id: testTaskId),
      ).called(1);

      // Ensure the final state contains the updated data
      final state = container.read(
        taskProgressControllerProvider(testTaskId),
      );
      expect(state.value, equals(updatedProgress));
    },
  );

  test('updates state when time service emits a linked journal entity', () async {
    // Set up initial state
    await container.read(taskProgressControllerProvider(testTaskId).future);

    // Mock the linkedFrom property
    final mockTask = MockTask(date: DateTime(2022, 7, 7));
    when(() => mockTimeService.linkedFrom).thenReturn(mockTask);

    // Create a test journal entity
    final testDateTime = DateTime(2022, 7, 7, 16);
    final testJournalEntity = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'entry3',
        createdAt: testDateTime,
        updatedAt: testDateTime,
        dateFrom: testDateTime,
        dateTo: testDateTime.add(const Duration(minutes: 20)),
      ),
    );

    // Prepare updated time ranges and progress
    final expectedTimeRanges = Map<String, TimeRange>.from(testTimeRanges);
    expectedTimeRanges['entry3'] = TimeRange(
      start: testDateTime,
      end: testDateTime.add(const Duration(minutes: 20)),
    );

    final updatedProgress = TaskProgressState(
      progress: const Duration(minutes: 75) + const Duration(minutes: 20),
      estimate: testEstimate,
    );

    // Set up repository to return expected values when called with expectedTimeRanges
    when(
      () => mockRepository.getTaskProgress(
        timeRanges: expectedTimeRanges,
        estimate: testEstimate,
      ),
    ).thenReturn(updatedProgress);

    fakeAsync((async) {
      // Emit a journal entity from the time service
      timeServiceStreamController.add(testJournalEntity);
      async.flushMicrotasks();

      // Ensure the state was updated
      final state = container.read(
        taskProgressControllerProvider(testTaskId),
      );
      expect(state.value?.estimate, equals(testEstimate));
    });
  });

  test('ignores time service events for unrelated tasks', () async {
    // Set up initial state
    await container.read(taskProgressControllerProvider(testTaskId).future);

    // Mock the linkedFrom property with a different task ID
    final mockTask = MockTask(
      id: 'different-task-id',
      date: DateTime(2022, 7, 7),
    );
    when(() => mockTimeService.linkedFrom).thenReturn(mockTask);

    // Create a test journal entity
    final testDateTime = DateTime(2022, 7, 7, 16);
    final testJournalEntity = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'entry3',
        createdAt: testDateTime,
        updatedAt: testDateTime,
        dateFrom: testDateTime,
        dateTo: testDateTime.add(const Duration(minutes: 20)),
      ),
    );

    // Clear previous invocations
    clearInteractions(mockRepository);

    fakeAsync((async) {
      // Emit a journal entity from the time service
      timeServiceStreamController.add(testJournalEntity);
      async.flushMicrotasks();

      // Verify getTaskProgress is never called when task ID doesn't match
      verifyNever(
        () => mockRepository.getTaskProgress(
          timeRanges: any(named: 'timeRanges'),
          estimate: any(named: 'estimate'),
        ),
      );
    });
  });

  test(
    'preserves the in-memory live timer range across an UpdateNotification '
    're-fetch — checklist item toggle no longer "resets" the running timer',
    () async {
      // Arrange: bootstrap the controller with the initial DB ranges.
      await container.read(
        taskProgressControllerProvider(testTaskId).future,
      );

      // The timer is running, linked to this task. Its DB row reflects the
      // creation snapshot (dateTo == dateFrom) since no save has flushed a
      // fresh dateTo yet — this is the realistic shape of the bug.
      const liveEntryId = 'live-timer';
      final dateFrom = DateTime(2022, 7, 7, 16);
      final live = JournalEntity.journalEntry(
        meta: Metadata(
          id: liveEntryId,
          createdAt: dateFrom,
          updatedAt: dateFrom,
          dateFrom: dateFrom,
          dateTo: dateFrom,
        ),
      );
      final mockTask = MockTask(date: DateTime(2022, 7, 7));
      when(() => mockTimeService.linkedFrom).thenReturn(mockTask);
      when(() => mockTimeService.getCurrent()).thenReturn(live);

      // The 1Hz ticker has been running for 60s, so the in-memory range
      // for the live entry has dateTo = dateFrom + 60s.
      final livenessTick = JournalEntity.journalEntry(
        meta: Metadata(
          id: liveEntryId,
          createdAt: dateFrom,
          updatedAt: dateFrom,
          dateFrom: dateFrom,
          dateTo: dateFrom.add(const Duration(seconds: 60)),
        ),
      );
      final tickedRange = TimeRange(
        start: dateFrom,
        end: dateFrom.add(const Duration(seconds: 60)),
      );

      // The DB-snapshot ranges that a re-fetch would return: same as initial
      // ranges + the live entry's stale (dateFrom, dateFrom) snapshot.
      final dbRanges = <String, TimeRange>{
        ...testTimeRanges,
        liveEntryId: TimeRange(start: dateFrom, end: dateFrom),
      };

      // The expected ranges after _fetch must keep the live range from the
      // ticker, not the DB snapshot. We seed both `getTaskProgress`
      // responses so the test fails loudly if the controller calls through
      // with the wrong map.
      when(
        () => mockRepository.getTaskProgressData(id: testTaskId),
      ).thenAnswer((_) async => (testEstimate, dbRanges));

      const preservedProgress = TaskProgressState(
        progress: Duration(minutes: 76),
        estimate: testEstimate,
      );
      const stalebackProgress = TaskProgressState(
        progress: Duration(minutes: 75),
        estimate: testEstimate,
      );
      when(
        () => mockRepository.getTaskProgress(
          timeRanges: {
            ...testTimeRanges,
            liveEntryId: tickedRange,
          },
          estimate: testEstimate,
        ),
      ).thenReturn(preservedProgress);
      when(
        () => mockRepository.getTaskProgress(
          timeRanges: dbRanges,
          estimate: testEstimate,
        ),
      ).thenReturn(stalebackProgress);

      // Drive a single ticker emission so the in-memory range gets seeded
      // to the (dateFrom, dateFrom + 60s) window.
      final tickerSeen = Completer<void>();
      final tickerSub = container.listen(
        taskProgressControllerProvider(testTaskId),
        (_, next) {
          if (!tickerSeen.isCompleted && next.value == preservedProgress) {
            tickerSeen.complete();
          }
        },
      );
      timeServiceStreamController.add(livenessTick);
      // Deterministic: the ticker listener synchronously recomputes
      // progress and sets state, completing the completer on a microtask —
      // no wall-clock timeout (fake-time policy).
      await tickerSeen.future;
      tickerSub.close();
      clearInteractions(mockRepository);

      // Re-stub `getTaskProgressData` after the clear so the post-update
      // _fetch still sees the DB-stale snapshot.
      when(
        () => mockRepository.getTaskProgressData(id: testTaskId),
      ).thenAnswer((_) async => (testEstimate, dbRanges));

      // Act: a checklist toggle puts the parent taskId into the
      // UpdateNotifications batch, which kicks the controller's _fetch.
      updateStreamController.add({testTaskId});
      // Drain the event queue deterministically so the async _fetch
      // completes — no wall-clock delay (fake-time policy).
      await pumpEventQueue();

      // Assert: the controller computed progress against the *preserved*
      // map (live range intact), not the DB-stale map. Without the fix
      // this verify() would fail because `getTaskProgress` would be
      // called with `dbRanges` (live entry's dateTo == dateFrom).
      verify(
        () => mockRepository.getTaskProgress(
          timeRanges: {
            ...testTimeRanges,
            liveEntryId: tickedRange,
          },
          estimate: testEstimate,
        ),
      ).called(1);
      verifyNever(
        () => mockRepository.getTaskProgress(
          timeRanges: dbRanges,
          estimate: testEstimate,
        ),
      );

      // And the published state still reads the cumulative-with-live value.
      final state = container.read(
        taskProgressControllerProvider(testTaskId),
      );
      expect(state.value, equals(preservedProgress));
    },
  );

  test('disposes subscriptions when disposed', () async {
    // Create a separate repository for this test to avoid interference
    final testRepository = MockTaskProgressRepository();
    when(
      () => testRepository.getTaskProgressData(id: testTaskId),
    ).thenAnswer((_) async => (testEstimate, testTimeRanges));

    // Important: We need to mock the getTaskProgress method as well
    when(
      () => testRepository.getTaskProgress(
        timeRanges: any(named: 'timeRanges'),
        estimate: any(named: 'estimate'),
      ),
    ).thenReturn(testProgress);

    // Create and use a local container that we'll dispose
    final localContainer = ProviderContainer(
      overrides: [
        taskProgressRepositoryProvider.overrideWithValue(testRepository),
      ],
    );

    // Initialize the controller
    await localContainer.read(
      taskProgressControllerProvider(testTaskId).future,
    );

    // Clear interactions to start fresh
    clearInteractions(testRepository);

    // Dispose the container which should trigger controller disposal
    localContainer.dispose();

    fakeAsync((async) {
      // Emit events that would normally trigger updates
      updateStreamController.add({testTaskId});

      // Allow the async operations to complete deterministically
      async.flushMicrotasks();

      // Verify no further repository calls were made after disposal
      verifyNever(
        () => testRepository.getTaskProgressData(id: any(named: 'id')),
      );
    });
  });
}
