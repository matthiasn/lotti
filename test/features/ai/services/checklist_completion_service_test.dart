import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();

    // Register fallback values
    registerFallbackValue(
      const CreateChatCompletionRequest(
        messages: [],
        model: ChatCompletionModel.modelId('gpt-4'),
      ),
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ChecklistCompletionService', () {
    test('initial state is empty list', () async {
      // Wait for the provider to build
      await container.read(checklistCompletionServiceProvider.future);

      final service = container.read(checklistCompletionServiceProvider);
      expect(service.hasValue, isTrue);
      expect(service.value, isEmpty);
    });

    test('addSuggestions updates state with new suggestions', () async {
      final notifier =
          container.read(checklistCompletionServiceProvider.notifier);

      final suggestions = [
        const ChecklistCompletionSuggestion(
          checklistItemId: 'item-1',
          reason: 'Task completed as mentioned in context',
          confidence: ChecklistCompletionConfidence.high,
        ),
        const ChecklistCompletionSuggestion(
          checklistItemId: 'item-2',
          reason: 'Likely completed based on evidence',
          confidence: ChecklistCompletionConfidence.medium,
        ),
      ];

      notifier.addSuggestions(suggestions);

      final state = container.read(checklistCompletionServiceProvider);
      expect(state.value, equals(suggestions));
    });

    test('clearSuggestion removes specific suggestion', () async {
      final notifier =
          container.read(checklistCompletionServiceProvider.notifier);

      final suggestions = [
        const ChecklistCompletionSuggestion(
          checklistItemId: 'item-1',
          reason: 'Task completed',
          confidence: ChecklistCompletionConfidence.high,
        ),
        const ChecklistCompletionSuggestion(
          checklistItemId: 'item-2',
          reason: 'Another task completed',
          confidence: ChecklistCompletionConfidence.medium,
        ),
      ];

      notifier
        ..addSuggestions(suggestions)
        ..clearSuggestion('item-1');

      final state = container.read(checklistCompletionServiceProvider);
      expect(state.value?.length, equals(1));
      expect(state.value?.first.checklistItemId, equals('item-2'));
    });

    test('getSuggestionForItem returns correct suggestion', () async {
      final notifier =
          container.read(checklistCompletionServiceProvider.notifier);

      const targetSuggestion = ChecklistCompletionSuggestion(
        checklistItemId: 'item-1',
        reason: 'Task completed',
        confidence: ChecklistCompletionConfidence.high,
      );

      final suggestions = [
        targetSuggestion,
        const ChecklistCompletionSuggestion(
          checklistItemId: 'item-2',
          reason: 'Another task',
          confidence: ChecklistCompletionConfidence.low,
        ),
      ];

      notifier.addSuggestions(suggestions);

      final found = notifier.getSuggestionForItem('item-1');
      expect(found, equals(targetSuggestion));

      final notFound = notifier.getSuggestionForItem('item-3');
      expect(notFound, isNull);
    });

    test('confidence enum parsing handles invalid values', () {
      // Test the confidence parsing logic
      const validConfidences = ['high', 'medium', 'low'];

      for (final confidence in validConfidences) {
        final parsed = ChecklistCompletionConfidence.values.firstWhere(
          (e) => e.name == confidence,
          orElse: () => ChecklistCompletionConfidence.low,
        );
        expect(parsed.name, equals(confidence));
      }

      // Test invalid confidence defaults to low
      final invalid = ChecklistCompletionConfidence.values.firstWhere(
        (e) => e.name == 'invalid-confidence',
        orElse: () => ChecklistCompletionConfidence.low,
      );
      expect(invalid, equals(ChecklistCompletionConfidence.low));
    });

    test('multiple addSuggestions calls replace previous suggestions',
        () async {
      final notifier =
          container.read(checklistCompletionServiceProvider.notifier);

      final firstBatch = [
        const ChecklistCompletionSuggestion(
          checklistItemId: 'item-1',
          reason: 'First batch',
          confidence: ChecklistCompletionConfidence.high,
        ),
      ];

      final secondBatch = [
        const ChecklistCompletionSuggestion(
          checklistItemId: 'item-2',
          reason: 'Second batch',
          confidence: ChecklistCompletionConfidence.medium,
        ),
        const ChecklistCompletionSuggestion(
          checklistItemId: 'item-3',
          reason: 'Second batch',
          confidence: ChecklistCompletionConfidence.low,
        ),
      ];

      notifier.addSuggestions(firstBatch);
      var state = container.read(checklistCompletionServiceProvider);
      expect(state.value, equals(firstBatch));

      notifier.addSuggestions(secondBatch);
      state = container.read(checklistCompletionServiceProvider);
      expect(state.value, equals(secondBatch));
    });

    test('clearSuggestion handles non-existent items gracefully', () async {
      final notifier =
          container.read(checklistCompletionServiceProvider.notifier);

      final suggestions = [
        const ChecklistCompletionSuggestion(
          checklistItemId: 'item-1',
          reason: 'Task completed',
          confidence: ChecklistCompletionConfidence.high,
        ),
      ];

      notifier
        ..addSuggestions(suggestions)
        ..clearSuggestion('non-existent-item'); // Should not throw

      final state = container.read(checklistCompletionServiceProvider);
      expect(
          state.value, equals(suggestions)); // Original suggestions unchanged
    });
  });
}
