import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

class MockTaskProgressRepository extends Mock
    implements TaskProgressRepository {}

class MockTimeService extends Mock implements TimeService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

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

// Create fake implementations for registerFallbackValue
// Ignoring sealed class warnings as these are for testing purposes only
// ignore: subtype_of_sealed_class
class FakeAsyncLoading extends AsyncLoading<TaskProgressState?> {
  const FakeAsyncLoading() : super();
}

// ignore: subtype_of_sealed_class
class FakeAsyncData extends AsyncData<TaskProgressState?> {
  // ignore: prefer_const_constructors_in_immutables
  FakeAsyncData() : super(null);
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
  final testDurations = <String, Duration>{
    'entry1': const Duration(minutes: 30),
    'entry2': const Duration(minutes: 45),
  };
  const testProgress = TaskProgressState(
    progress: Duration(minutes: 75),
    estimate: testEstimate,
  );

  setUpAll(() {
    // Register fallback values for Mocktail matchers
    registerFallbackValue(const FakeAsyncLoading());
    registerFallbackValue(FakeAsyncData());
    registerFallbackValue(FakeTaskProgressState());
    registerFallbackValue(<String, Duration>{});
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
        .thenAnswer((_) async => (testEstimate, testDurations));

    when(
      () => mockRepository.getTaskProgress(
        durations: testDurations,
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
    final updatedDurations = <String, Duration>{
      'entry1': const Duration(minutes: 30),
      'entry2': const Duration(minutes: 60),
    };
    const updatedProgress = TaskProgressState(
      progress: Duration(minutes: 90),
      estimate: testEstimate,
    );

    when(() => mockRepository.getTaskProgressData(id: testTaskId))
        .thenAnswer((_) async => (testEstimate, updatedDurations));

    when(
      () => mockRepository.getTaskProgress(
        durations: updatedDurations,
        estimate: testEstimate,
      ),
    ).thenReturn(updatedProgress);

    // Trigger update notification with the test task ID
    updateStreamController.add({'entry2'});

    // Allow the async operations to complete
    await Future<void>.delayed(Duration.zero);

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
    final testDateTime = DateTime.now();
    final testJournalEntity = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'entry3',
        createdAt: testDateTime,
        updatedAt: testDateTime,
        dateFrom: testDateTime,
        dateTo: testDateTime.add(const Duration(minutes: 20)),
      ),
    );

    // Calculate actual duration of the journal entity
    final entryDurationValue = entryDuration(testJournalEntity);

    // Prepare updated durations and progress
    final expectedDurations = Map<String, Duration>.from(testDurations);
    expectedDurations['entry3'] = entryDurationValue;

    final updatedProgress = TaskProgressState(
      progress: const Duration(minutes: 75) + entryDurationValue,
      estimate: testEstimate,
    );

    // Set up repository to return expected values when called with expectedDurations
    when(
      () => mockRepository.getTaskProgress(
        durations: expectedDurations,
        estimate: testEstimate,
      ),
    ).thenReturn(updatedProgress);

    // Emit a journal entity from the time service
    timeServiceStreamController.add(testJournalEntity);

    // Allow the async operations to complete
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
    final testDateTime = DateTime.now();
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

    // Allow the async operations to complete
    await Future<void>.delayed(Duration.zero);

    // Verify getTaskProgress is never called when task ID doesn't match
    verifyNever(
      () => mockRepository.getTaskProgress(
        durations: any(named: 'durations'),
        estimate: any(named: 'estimate'),
      ),
    );
  });

  test('disposes subscriptions when disposed', () async {
    // Create a separate repository for this test to avoid interference
    final testRepository = MockTaskProgressRepository();
    when(() => testRepository.getTaskProgressData(id: testTaskId))
        .thenAnswer((_) async => (testEstimate, testDurations));

    // Important: We need to mock the getTaskProgress method as well
    when(
      () => testRepository.getTaskProgress(
        durations: any(named: 'durations'),
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

    // Allow the async operations to complete
    await Future<void>.delayed(Duration.zero);

    // Verify no further repository calls were made after disposal
    verifyNever(() => testRepository.getTaskProgressData(id: any(named: 'id')));
  });
}
