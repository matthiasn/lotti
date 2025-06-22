import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/state/checklist_suggestions_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockJournalRepository mockJournalRepository;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;
  late StreamController<Set<String>> updateStreamController;

  final testDateTime = DateTime(2023);

  setUpAll(() {
    registerFallbackValue(
      AiResponseEntry(
        meta: Metadata(
          id: 'test-id',
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
          type: AiResponseType.actionItemSuggestions,
        ),
      ),
    );
    registerFallbackValue(const AsyncValue<AiResponseEntry?>.data(null));
    registerFallbackValue(
      Metadata(
        id: 'test-id',
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

  group('ChecklistSuggestionsController Tests', () {
    test('returns suggestions on initial run', () async {
      // Arrange
      final aiResponseEntry = AiResponseEntry(
        data: const AiResponseData(
          model: 'test-model',
          systemMessage: 'test-system',
          prompt: 'test-prompt',
          thoughts: 'test-thoughts',
          response: 'test-response',
          type: AiResponseType.actionItemSuggestions,
          suggestedActionItems: [
            AiActionItem(title: 'Review code', completed: false),
            AiActionItem(title: 'Write tests', completed: true),
          ],
        ),
        meta: Metadata(
          id: 'ai-response-1',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: DateTime(2023),
          dateTo: DateTime(2023),
          starred: false,
          flag: EntryFlag.none,
        ),
      );

      when(() => mockJournalRepository.getLinkedEntities(
            linkedTo: 'test-task-id',
          )).thenAnswer((_) async => [aiResponseEntry]);

      // Act
      final result = await container.read(
        checklistSuggestionsControllerProvider(id: 'test-task-id').future,
      );

      // Assert
      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result.first.title, equals('Review code'));
      expect(result.first.isChecked, isFalse);
      expect(result.last.title, equals('Write tests'));
      expect(result.last.isChecked, isTrue);
    });

    test('returns empty suggestions when re-run after auto-checklist creation',
        () async {
      // Arrange - simulating the re-run after auto-checklist creation which produces empty suggestions
      final aiResponseEntry = AiResponseEntry(
        data: const AiResponseData(
          model: 'test-model',
          systemMessage: 'test-system',
          prompt: 'test-prompt',
          thoughts: 'test-thoughts',
          response: 'test-response',
          type: AiResponseType.actionItemSuggestions,
          suggestedActionItems: [], // Empty after re-run since items are now in checklist
        ),
        meta: Metadata(
          id: 'ai-response-1',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: DateTime(2023),
          dateTo: DateTime(2023),
          starred: false,
          flag: EntryFlag.none,
        ),
      );

      when(() => mockJournalRepository.getLinkedEntities(
            linkedTo: 'test-task-id',
          )).thenAnswer((_) async => [aiResponseEntry]);

      // Act
      final result = await container.read(
        checklistSuggestionsControllerProvider(id: 'test-task-id').future,
      );

      // Assert
      expect(result, isNotNull);
      expect(result!.length, equals(0)); // Empty suggestions after re-run
    });

    test(
        'returns suggestions when autoChecklistCreated is null (backward compatibility)',
        () async {
      // Arrange
      final aiResponseEntry = AiResponseEntry(
        data: const AiResponseData(
          model: 'test-model',
          systemMessage: 'test-system',
          prompt: 'test-prompt',
          thoughts: 'test-thoughts',
          response: 'test-response',
          type: AiResponseType.actionItemSuggestions,
          // autoChecklistCreated is null (not set)
          suggestedActionItems: [
            AiActionItem(title: 'Review code', completed: false),
          ],
        ),
        meta: Metadata(
          id: 'ai-response-1',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: DateTime(2023),
          dateTo: DateTime(2023),
          starred: false,
          flag: EntryFlag.none,
        ),
      );

      when(() => mockJournalRepository.getLinkedEntities(
            linkedTo: 'test-task-id',
          )).thenAnswer((_) async => [aiResponseEntry]);

      // Act
      final result = await container.read(
        checklistSuggestionsControllerProvider(id: 'test-task-id').future,
      );

      // Assert
      expect(result, isNotNull);
      expect(result!.length, equals(1));
      expect(result.first.title, equals('Review code'));
    });
  });
}
