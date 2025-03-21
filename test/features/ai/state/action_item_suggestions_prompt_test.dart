import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/action_item_suggestions_prompt.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  late ProviderContainer container;
  late MockAiInputRepository mockAiInputRepository;
  late MockJournalRepository mockJournalRepository;
  late MockUpdateNotifications mockUpdateNotifications;
  late Listener<AsyncValue<String?>> listener;
  late StreamController<Set<String>> updateStreamController;

  const testId = 'test-task-id';
  final linkedIds = ['linked-id-1', 'linked-id-2'];

  setUp(() {
    mockAiInputRepository = MockAiInputRepository();
    mockJournalRepository = MockJournalRepository();
    mockUpdateNotifications = MockUpdateNotifications();
    listener = Listener<AsyncValue<String?>>();

    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    when(() => mockJournalRepository.getLinksFromId(testId)).thenAnswer(
      (_) async => linkedIds
          .map(
            (id) => EntryLink.basic(
              id: 'link-$testId-$id',
              fromId: testId,
              toId: id,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
            ),
          )
          .toList(),
    );

    // Register before creating the container
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    container = ProviderContainer(
      overrides: [
        aiInputRepositoryProvider.overrideWithValue(mockAiInputRepository),
        journalRepositoryProvider.overrideWithValue(mockJournalRepository),
      ],
    );
  });

  tearDown(() async {
    // First, complete any pending futures
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    await updateStreamController.close();
    getIt.unregister<UpdateNotifications>();
  });

  group('ActionItemSuggestionsPromptController', () {
    test('initial state builds prompt with AI input data', () async {
      // Arrange
      final mockAiInput = AiInputTaskObject(
        title: 'Test Task',
        status: 'OPEN',
        creationDate: DateTime(2023),
        actionItems: [
          const AiActionItem(
            title: 'Existing action item',
            completed: false,
          ),
        ],
        logEntries: [
          AiInputLogEntryObject(
            creationTimestamp: DateTime(2023),
            loggedDuration: '00:30',
            text: 'Test log entry',
          ),
        ],
        estimatedDuration: '01:00',
        timeSpent: '00:30',
      );

      when(() => mockAiInputRepository.generate(testId))
          .thenAnswer((_) async => mockAiInput);

      // Act - Listen to the provider
      final future = container.read(
        actionItemSuggestionsPromptControllerProvider(id: testId).future,
      );

      container.listen(
        actionItemSuggestionsPromptControllerProvider(id: testId),
        (previous, next) => listener(previous, next),
        fireImmediately: true,
      );

      // Wait for the future to complete to ensure all async work is done
      await future;

      // Assert
      verify(() => mockJournalRepository.getLinksFromId(testId)).called(1);
      verify(() => mockAiInputRepository.generate(testId)).called(1);

      final state = container
          .read(actionItemSuggestionsPromptControllerProvider(id: testId));
      expect(state.hasValue, isTrue);
      expect(state.value, isNotNull);
      expect(state.value, contains('**Prompt:**'));
      expect(state.value, contains('"title": "Test Task"'));
      expect(state.value, contains('"title": "Existing action item"'));
    });

    test('returns null when AI input generation fails', () async {
      // Arrange
      when(() => mockAiInputRepository.generate(testId))
          .thenAnswer((_) async => null);

      // Act - Get the future first
      final future = container.read(
        actionItemSuggestionsPromptControllerProvider(id: testId).future,
      );

      container.listen(
        actionItemSuggestionsPromptControllerProvider(id: testId),
        (previous, next) => listener(previous, next),
        fireImmediately: true,
      );

      // Wait for the future to complete
      await future;

      // Assert
      verify(() => mockJournalRepository.getLinksFromId(testId)).called(1);
      verify(() => mockAiInputRepository.generate(testId)).called(1);

      final state = container
          .read(actionItemSuggestionsPromptControllerProvider(id: testId));
      expect(state.hasValue, isTrue);
      expect(state.value, isNull);
    });

    test('updates prompt when affected IDs are notified', () async {
      // Arrange
      final mockAiInput = AiInputTaskObject(
        title: 'Test Task',
        status: 'OPEN',
        creationDate: DateTime(2023),
        actionItems: [
          const AiActionItem(
            title: 'Initial action item',
            completed: false,
          ),
        ],
        logEntries: [],
        estimatedDuration: '01:00',
        timeSpent: '00:00',
      );

      final updatedMockAiInput = AiInputTaskObject(
        title: 'Test Task',
        status: 'OPEN',
        creationDate: DateTime(2023),
        actionItems: [
          const AiActionItem(
            title: 'Initial action item',
            completed: false,
          ),
          const AiActionItem(
            title: 'New action item',
            completed: false,
          ),
        ],
        logEntries: [],
        estimatedDuration: '01:00',
        timeSpent: '00:00',
      );

      // Set up the mock to return different values on consecutive calls
      when(() => mockAiInputRepository.generate(testId))
          .thenAnswer((_) async => mockAiInput);

      // Act - initial load with future first
      final future = container.read(
        actionItemSuggestionsPromptControllerProvider(id: testId).future,
      );

      container.listen(
        actionItemSuggestionsPromptControllerProvider(id: testId),
        (previous, next) => listener(previous, next),
        fireImmediately: true,
      );

      // Wait for the future to complete
      await future;

      // Verify initial state
      verify(() => mockJournalRepository.getLinksFromId(testId)).called(1);
      verify(() => mockAiInputRepository.generate(testId)).called(1);

      final initialState = container
          .read(actionItemSuggestionsPromptControllerProvider(id: testId));
      expect(initialState.value, contains('"title": "Initial action item"'));
      expect(initialState.value, isNot(contains('"title": "New action item"')));

      // Reset the verification counter for the next section
      clearInteractions(mockAiInputRepository);

      // Update mock to return a different value for the next call
      when(() => mockAiInputRepository.generate(testId))
          .thenAnswer((_) async => updatedMockAiInput);

      // Simulate a notification for the task ID
      updateStreamController.add({testId});

      // Allow async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify updated state
      verify(() => mockAiInputRepository.generate(testId)).called(1);

      final updatedState = container
          .read(actionItemSuggestionsPromptControllerProvider(id: testId));
      expect(updatedState.value, contains('"title": "Initial action item"'));
      expect(updatedState.value, contains('"title": "New action item"'));
    });

    test('updates prompt when linked ID is notified', () async {
      // Arrange
      final mockAiInput = AiInputTaskObject(
        title: 'Test Task',
        status: 'OPEN',
        creationDate: DateTime(2023),
        actionItems: [
          const AiActionItem(
            title: 'Initial action item',
            completed: false,
          ),
        ],
        logEntries: [],
        estimatedDuration: '01:00',
        timeSpent: '00:00',
      );

      final updatedMockAiInput = AiInputTaskObject(
        title: 'Test Task',
        status: 'OPEN',
        creationDate: DateTime(2023),
        actionItems: [
          const AiActionItem(
            title: 'Initial action item',
            completed: false,
          ),
          const AiActionItem(
            title: 'Linked action item',
            completed: false,
          ),
        ],
        logEntries: [],
        estimatedDuration: '01:00',
        timeSpent: '00:00',
      );

      // Set up the mock to return different values on consecutive calls
      when(() => mockAiInputRepository.generate(testId))
          .thenAnswer((_) async => mockAiInput);

      // Act - initial load with future first
      final future = container.read(
        actionItemSuggestionsPromptControllerProvider(id: testId).future,
      );

      container.listen(
        actionItemSuggestionsPromptControllerProvider(id: testId),
        (previous, next) => listener(previous, next),
        fireImmediately: true,
      );

      // Wait for the future to complete
      await future;

      // Verify initial state
      verify(() => mockJournalRepository.getLinksFromId(testId)).called(1);
      verify(() => mockAiInputRepository.generate(testId)).called(1);

      final initialState = container
          .read(actionItemSuggestionsPromptControllerProvider(id: testId));
      expect(initialState.value, contains('"title": "Initial action item"'));
      expect(
        initialState.value,
        isNot(contains('"title": "Linked action item"')),
      );

      // Reset the verification counter for the next section
      clearInteractions(mockAiInputRepository);

      // Update mock to return a different value for the next call
      when(() => mockAiInputRepository.generate(testId))
          .thenAnswer((_) async => updatedMockAiInput);

      // Simulate a notification for a linked ID
      updateStreamController.add({linkedIds[0]});

      // Allow async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify updated state
      verify(() => mockAiInputRepository.generate(testId)).called(1);

      final updatedState = container
          .read(actionItemSuggestionsPromptControllerProvider(id: testId));
      expect(updatedState.value, contains('"title": "Initial action item"'));
      expect(updatedState.value, contains('"title": "Linked action item"'));
    });

    test('properly disposes the update subscription', () async {
      // Setup mock for the dispose test
      final mockAiInput = AiInputTaskObject(
        title: 'Test Task',
        status: 'OPEN',
        creationDate: DateTime(2023),
        actionItems: [],
        logEntries: [],
        estimatedDuration: '01:00',
        timeSpent: '00:00',
      );

      when(() => mockAiInputRepository.generate(testId))
          .thenAnswer((_) async => mockAiInput);

      // Create a scope to allow for proper disposal testing
      {
        // Create a new container for this test
        final localContainer = ProviderContainer(
          overrides: [
            aiInputRepositoryProvider.overrideWithValue(mockAiInputRepository),
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        );

        // Initial read to activate the controller and wait for it to complete
        final future = localContainer.read(
          actionItemSuggestionsPromptControllerProvider(id: testId).future,
        );

        // Wait for the future to complete before disposing
        await future;

        // Dispose the container (which should trigger onDispose in the controller)
        localContainer.dispose();
      }

      // Wait a moment to ensure all async operations have completed
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Trigger an update notification and wait to ensure nothing happens
      updateStreamController.add({testId});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // No assertion needed - we're just verifying that no exception is thrown
      // after the container has been disposed
    });
  });
}
