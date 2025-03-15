import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  late ProviderContainer container;
  late MockJournalRepository mockJournalRepository;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;
  late Listener<AsyncValue<AiResponseEntry?>> listener;
  late StreamController<Set<String>> updateStreamController;

  const testId = 'test-id';
  const testAiResponseType = 'TestSummary';
  final testDateTime = DateTime(2023);

  setUpAll(() {
    registerFallbackValue(
      AiResponseEntry(
        meta: Metadata(
          id: testId,
          dateFrom: testDateTime,
          dateTo: testDateTime,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        ),
        data: const AiResponseData(
          model: 'test-model',
          temperature: 0.5,
          systemMessage: 'test-system-message',
          prompt: 'test-prompt',
          thoughts: 'test-thoughts',
          response: 'test-response',
          type: testAiResponseType,
        ),
      ),
    );
    registerFallbackValue(const AsyncValue<AiResponseEntry?>.data(null));
    registerFallbackValue(
      Metadata(
        id: testId,
        dateFrom: testDateTime,
        dateTo: testDateTime,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      ),
    );
  });

  setUp(() {
    mockJournalRepository = MockJournalRepository();
    mockPersistenceLogic = MockPersistenceLogic();
    mockUpdateNotifications = MockUpdateNotifications();
    listener = Listener<AsyncValue<AiResponseEntry?>>();

    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    getIt
      ..reset()
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    container = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(mockJournalRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
    getIt.reset();
  });

  test('initial state loads latest AI response entry', () async {
    // Arrange
    final testEntry = AiResponseEntry(
      meta: Metadata(
        id: testId,
        dateFrom: testDateTime,
        dateTo: testDateTime,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      ),
      data: const AiResponseData(
        model: 'test-model',
        temperature: 0.5,
        systemMessage: 'test-system-message',
        prompt: 'test-prompt',
        thoughts: 'test-thoughts',
        response: 'test-response',
        type: testAiResponseType,
      ),
    );

    when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
        .thenAnswer((_) async => [testEntry]);

    // Act
    container.listen(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ),
      listener.call,
      fireImmediately: true,
    );

    // Wait for the future to complete
    await container.read(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ).future,
    );

    // Assert
    verify(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
        .called(1);
    verify(() => listener.call(any(), any())).called(2);

    final state = container.read(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ),
    );
    expect(state.value, equals(testEntry));
  });

  test('updates state when relevant update notifications are received',
      () async {
    // Arrange
    final initialEntry = AiResponseEntry(
      meta: Metadata(
        id: testId,
        dateFrom: testDateTime,
        dateTo: testDateTime,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      ),
      data: const AiResponseData(
        model: 'test-model',
        temperature: 0.5,
        systemMessage: 'test-system-message',
        prompt: 'test-prompt',
        thoughts: 'test-thoughts',
        response: 'test-response',
        type: testAiResponseType,
      ),
    );

    final updatedEntry = AiResponseEntry(
      meta: Metadata(
        id: testId,
        dateFrom: testDateTime,
        dateTo: testDateTime,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      ),
      data: const AiResponseData(
        model: 'test-model',
        temperature: 0.5,
        systemMessage: 'test-system-message',
        prompt: 'test-prompt',
        thoughts: 'updated-thoughts',
        response: 'updated-response',
        type: testAiResponseType,
      ),
    );

    when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
        .thenAnswer((_) async => [initialEntry]);

    // Act
    container.listen(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ),
      listener.call,
      fireImmediately: true,
    );

    // Wait for initial state
    await container.read(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ).future,
    );

    // Update mock to return new entry
    when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
        .thenAnswer((_) async => [updatedEntry]);

    // Trigger update notification
    updateStreamController.add({testId});

    // Wait for the state to update with verification
    var stateUpdated = false;
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final currentState = container.read(
        latestSummaryControllerProvider(
          id: testId,
          aiResponseType: testAiResponseType,
        ),
      );
      if (currentState.value?.data.thoughts == 'updated-thoughts') {
        stateUpdated = true;
        break;
      }
    }

    expect(stateUpdated, isTrue, reason: 'State did not update within timeout');

    // Assert
    verify(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
        .called(2);
    verify(() => listener.call(any(), any())).called(3);

    final state = container.read(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ),
    );
    expect(state.value, equals(updatedEntry));
  });

  test('removeActionItem updates state and persists changes', () async {
    // Arrange
    final testEntry = AiResponseEntry(
      meta: Metadata(
        id: testId,
        dateFrom: testDateTime,
        dateTo: testDateTime,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      ),
      data: const AiResponseData(
        model: 'test-model',
        temperature: 0.5,
        systemMessage: 'test-system-message',
        prompt: 'test-prompt',
        thoughts: 'test-thoughts',
        response: 'test-response',
        type: testAiResponseType,
        suggestedActionItems: [
          AiActionItem(
            title: 'Test Action 1',
            completed: false,
          ),
          AiActionItem(
            title: 'Test Action 2',
            completed: false,
          ),
        ],
      ),
    );

    when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
        .thenAnswer((_) async => [testEntry]);

    when(() => mockJournalRepository.updateJournalEntity(any()))
        .thenAnswer((_) async => true);

    // Act
    container.listen(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ),
      listener.call,
      fireImmediately: true,
    );

    // Wait for initial state
    await container.read(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ).future,
    );

    // Remove action item
    final notifier = container.read(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ).notifier,
    );
    await notifier.removeActionItem(title: 'Test Action 1');

    // Assert
    verify(() => mockJournalRepository.updateJournalEntity(any())).called(1);
    verify(() => listener.call(any(), any())).called(3);

    final state = container.read(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ),
    );
    expect(state.value?.data.suggestedActionItems?.length, equals(1));
    expect(
      state.value?.data.suggestedActionItems?.first.title,
      equals('Test Action 2'),
    );
  });

  test('disposes subscriptions when disposed', () async {
    // Arrange
    final testEntry = AiResponseEntry(
      meta: Metadata(
        id: testId,
        dateFrom: testDateTime,
        dateTo: testDateTime,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      ),
      data: const AiResponseData(
        model: 'test-model',
        temperature: 0.5,
        systemMessage: 'test-system-message',
        prompt: 'test-prompt',
        thoughts: 'test-thoughts',
        response: 'test-response',
        type: testAiResponseType,
      ),
    );

    when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
        .thenAnswer((_) async => [testEntry]);

    // Act
    container.listen(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ),
      listener.call,
      fireImmediately: true,
    );

    // Wait for initial state
    await container.read(
      latestSummaryControllerProvider(
        id: testId,
        aiResponseType: testAiResponseType,
      ).future,
    );

    // Dispose the container
    container.dispose();

    // Trigger update notification
    updateStreamController.add({testId});

    // Wait for any pending operations
    await Future<void>.delayed(Duration.zero);

    // Assert
    verify(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
        .called(1);
    verify(() => listener.call(any(), any())).called(2);
  });
}
