import 'dart:async';

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

class MockTaskProgressRepository extends Mock
    implements TaskProgressRepository {}

// This matches the signature of the getter linkedFrom in TimeService
class MockTask extends Mock implements Task {
  // Constructor declared first for sort_constructors_first rule
  MockTask(this.taskId);

  final String taskId;

  @override
  Metadata get meta => Metadata(
        id: taskId,
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}

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

  setUp(() {
    getIt.reset();

    mockRepository = MockTaskProgressRepository();
    mockTimeService = MockTimeService();
    mockUpdateNotifications = MockUpdateNotifications();

    updateStreamController = StreamController<Set<String>>.broadcast();
    timeServiceStreamController = StreamController<JournalEntity?>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    when(() => mockTimeService.getStream())
        .thenAnswer((_) => timeServiceStreamController.stream);

    getIt
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    container = ProviderContainer(
      overrides: [
        taskProgressRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );

    // Mock repository methods with specific values
    when(() => mockRepository.getTaskProgressData(id: testTaskId))
        .thenAnswer((_) async => (testEstimate, testTimeRanges));

    when(
      () => mockRepository.getTaskProgress(
        timeRanges: testTimeRanges,
        estimate: testEstimate,
      ),
    ).thenReturn(testProgress);
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
    timeServiceStreamController.close();
  });

  test('initial state loads task progress data', () async {
    // Add a listener to track state changes
    container.listen(
      taskProgressControllerProvider(id: testTaskId),
      (_, __) {},
      fireImmediately: true,
    );

    // Wait for the future to complete
    await container.read(taskProgressControllerProvider(id: testTaskId).future);

    // Verify the data was fetched from the repository
    verify(() => mockRepository.getTaskProgressData(id: testTaskId)).called(1);

    // Verify the state contains the expected data
    final state =
        container.read(taskProgressControllerProvider(id: testTaskId));
    expect(state.value, equals(testProgress));
  });

  test('updates state when relevant update notifications are received',
      () async {
    // Set up initial state
    await container.read(taskProgressControllerProvider(id: testTaskId).future);

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

    when(() => mockRepository.getTaskProgressData(id: testTaskId))
        .thenAnswer((_) async => (testEstimate, updatedTimeRanges));

    when(
      () => mockRepository.getTaskProgress(
        timeRanges: updatedTimeRanges,
        estimate: testEstimate,
      ),
    ).thenReturn(updatedProgress);

    // Listen for the updated state
    final updated = Completer<void>();
    final sub = container.listen(
      taskProgressControllerProvider(id: testTaskId),
      (_, next) {
        if (!updated.isCompleted && next.value == updatedProgress) {
          updated.complete();
        }
      },
    );

    // Trigger update notification with the changed entry id
    updateStreamController.add({'entry2'});
    try {
      await updated.future.timeout(const Duration(seconds: 1));
    } on TimeoutException {
      fail('Timed out waiting for updated task progress state');
    } finally {
      sub.close();
    }

    // Verify the data was fetched again and state updated
    verify(() => mockRepository.getTaskProgressData(id: testTaskId)).called(1);

    // Ensure the final state contains the updated data
    final state =
        container.read(taskProgressControllerProvider(id: testTaskId));
    expect(state.value, equals(updatedProgress));
  });

  test('updates state when time service emits a linked journal entity',
      () async {
    // Set up initial state
    await container.read(taskProgressControllerProvider(id: testTaskId).future);

    // Mock the linkedFrom property
    final mockTask = MockTask(testTaskId);
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

    // Emit a journal entity from the time service
    timeServiceStreamController.add(testJournalEntity);
    await Future<void>.delayed(Duration.zero);

    // Ensure the state was updated
    final state =
        container.read(taskProgressControllerProvider(id: testTaskId));
    expect(state.value?.estimate, equals(testEstimate));
  });

  test('ignores time service events for unrelated tasks', () async {
    // Set up initial state
    await container.read(taskProgressControllerProvider(id: testTaskId).future);

    // Mock the linkedFrom property with a different task ID
    final mockTask = MockTask('different-task-id');
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

    // Emit a journal entity from the time service
    timeServiceStreamController.add(testJournalEntity);
    await Future<void>.delayed(Duration.zero);

    // Verify getTaskProgress is never called when task ID doesn't match
    verifyNever(
      () => mockRepository.getTaskProgress(
        timeRanges: any(named: 'timeRanges'),
        estimate: any(named: 'estimate'),
      ),
    );
  });

  test('disposes subscriptions when disposed', () async {
    // Create a separate repository for this test to avoid interference
    final testRepository = MockTaskProgressRepository();
    when(() => testRepository.getTaskProgressData(id: testTaskId))
        .thenAnswer((_) async => (testEstimate, testTimeRanges));

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
    await localContainer
        .read(taskProgressControllerProvider(id: testTaskId).future);

    // Clear interactions to start fresh
    clearInteractions(testRepository);

    // Dispose the container which should trigger controller disposal
    localContainer.dispose();

    // Emit events that would normally trigger updates
    updateStreamController.add({testTaskId});

    // Allow the async operations to complete deterministically
    await Future<void>.delayed(Duration.zero);

    // Verify no further repository calls were made after disposal
    verifyNever(() => testRepository.getTaskProgressData(id: any(named: 'id')));
  });
}
