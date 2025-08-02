import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/sequential_inference_runner.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';

class FakeJournalEntity extends Fake implements JournalEntity {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {
  FakeAiConfigPrompt({
    required this.id,
    required this.aiResponseType,
    this.archived = false,
  });

  @override
  final String id;

  @override
  final AiResponseType aiResponseType;

  @override
  final bool archived;
}

void main() {
  group('SequentialInferenceRunner', () {
    late List<AiConfigPrompt> activePrompts;
    late JournalEntity testEntity;
    late List<String> progressMessages;
    late List<String> inferenceLog;

    setUp(() {
      progressMessages = [];
      inferenceLog = [];
      testEntity = FakeJournalEntity();

      activePrompts = [
        _createPrompt(
          id: 'transcription',
          aiResponseType: AiResponseType.audioTranscription,
        ),
        _createPrompt(
          id: 'checklist',
          aiResponseType: AiResponseType.checklistUpdates,
        ),
        _createPrompt(
          id: 'summary',
          aiResponseType: AiResponseType.taskSummary,
        ),
        _createPrompt(
          id: 'image',
          aiResponseType: AiResponseType.imageAnalysis,
        ),
      ];
    });

    group('runSingleInferenceStep', () {
      test('successfully runs inference when prompt exists', () async {
        final result = await SequentialInferenceRunner.runSingleInferenceStep(
          responseType: AiResponseType.audioTranscription,
          activePrompts: activePrompts,
          entityId: 'test-entity',
          entity: testEntity,
          getEntity: (_) async => testEntity,
          runInference: (entityId, promptConfig, {entity}) async {
            inferenceLog.add('Ran inference: ${promptConfig.id}');
          },
          onProgress: (message) => progressMessages.add(message),
        );

        expect(result, isTrue);
        expect(progressMessages, contains('Transcribing audio...'));
        expect(inferenceLog, contains('Ran inference: transcription'));
      });

      test('returns false when no matching prompt found', () async {
        // Using a response type that's not in our activePrompts
        final emptyPrompts = <AiConfigPrompt>[];
        final result = await SequentialInferenceRunner.runSingleInferenceStep(
          responseType: AiResponseType.taskSummary,
          activePrompts: emptyPrompts,
          entityId: 'test-entity',
          entity: testEntity,
          getEntity: (_) async => testEntity,
          runInference: (entityId, promptConfig, {entity}) async {
            inferenceLog.add('Ran inference: ${promptConfig.id}');
          },
          onProgress: (message) => progressMessages.add(message),
        );

        expect(result, isFalse);
        expect(progressMessages, isEmpty);
        expect(inferenceLog, isEmpty);
      });

      test('returns false and handles exception when inference fails',
          () async {
        final result = await SequentialInferenceRunner.runSingleInferenceStep(
          responseType: AiResponseType.taskSummary,
          activePrompts: activePrompts,
          entityId: 'test-entity',
          entity: testEntity,
          getEntity: (_) async => testEntity,
          runInference: (entityId, promptConfig, {entity}) async {
            throw Exception('Inference failed');
          },
          onProgress: (message) => progressMessages.add(message),
        );

        expect(result, isFalse);
        expect(progressMessages, contains('Generating summary...'));
      });

      test('sends correct progress message for each response type', () async {
        final responseTypesAndMessages = {
          AiResponseType.audioTranscription: 'Transcribing audio...',
          AiResponseType.checklistUpdates: 'Updating checklists...',
          AiResponseType.taskSummary: 'Generating summary...',
          AiResponseType.imageAnalysis: 'Analyzing image...',
        };

        for (final entry in responseTypesAndMessages.entries) {
          progressMessages.clear();

          await SequentialInferenceRunner.runSingleInferenceStep(
            responseType: entry.key,
            activePrompts: activePrompts,
            entityId: 'test-entity',
            entity: testEntity,
            getEntity: (_) async => testEntity,
            runInference: (entityId, promptConfig, {entity}) async {},
            onProgress: (message) => progressMessages.add(message),
          );

          expect(progressMessages, contains(entry.value));
        }
      });

      test(
          'does not send progress message for deprecated action item suggestions',
          () async {
        // Create a prompt for action item suggestions
        final promptWithActionItems = [
          _createPrompt(
            id: 'action-items',
            // ignore: deprecated_member_use_from_same_package
            aiResponseType: AiResponseType.actionItemSuggestions,
          ),
        ];

        await SequentialInferenceRunner.runSingleInferenceStep(
          // ignore: deprecated_member_use_from_same_package
          responseType: AiResponseType.actionItemSuggestions,
          activePrompts: promptWithActionItems,
          entityId: 'test-entity',
          entity: testEntity,
          getEntity: (_) async => testEntity,
          runInference: (entityId, promptConfig, {entity}) async {},
          onProgress: (message) => progressMessages.add(message),
        );

        expect(progressMessages, isEmpty);
      });

      test('passes entity to runInference to avoid redundant fetch', () async {
        JournalEntity? capturedEntity;

        await SequentialInferenceRunner.runSingleInferenceStep(
          responseType: AiResponseType.taskSummary,
          activePrompts: activePrompts,
          entityId: 'test-entity',
          entity: testEntity,
          getEntity: (_) async => testEntity,
          runInference: (entityId, promptConfig, {entity}) async {
            capturedEntity = entity;
          },
          onProgress: (_) {},
        );

        expect(capturedEntity, equals(testEntity));
      });
    });

    group('determineInferenceSequence', () {
      test('returns correct sequence with all types enabled', () {
        final sequence = SequentialInferenceRunner.determineInferenceSequence(
          activePrompts: activePrompts,
          entity: testEntity,
        );

        expect(sequence, [
          AiResponseType.audioTranscription,
          AiResponseType.checklistUpdates,
          AiResponseType.taskSummary,
          AiResponseType.imageAnalysis,
        ]);
      });

      test('excludes transcription when disabled', () {
        final sequence = SequentialInferenceRunner.determineInferenceSequence(
          activePrompts: activePrompts,
          entity: testEntity,
          includeTranscription: false,
        );

        expect(sequence, [
          AiResponseType.checklistUpdates,
          AiResponseType.taskSummary,
          AiResponseType.imageAnalysis,
        ]);
      });

      test('excludes checklist updates when disabled', () {
        final sequence = SequentialInferenceRunner.determineInferenceSequence(
          activePrompts: activePrompts,
          entity: testEntity,
          includeChecklistUpdates: false,
        );

        expect(sequence, [
          AiResponseType.audioTranscription,
          AiResponseType.taskSummary,
          AiResponseType.imageAnalysis,
        ]);
      });

      test('excludes task summary when disabled', () {
        final sequence = SequentialInferenceRunner.determineInferenceSequence(
          activePrompts: activePrompts,
          entity: testEntity,
          includeTaskSummary: false,
        );

        expect(sequence, [
          AiResponseType.audioTranscription,
          AiResponseType.checklistUpdates,
          AiResponseType.imageAnalysis,
        ]);
      });

      test('only includes types that have active prompts', () {
        final limitedPrompts = [
          _createPrompt(
            id: 'transcription',
            aiResponseType: AiResponseType.audioTranscription,
          ),
          _createPrompt(
            id: 'summary',
            aiResponseType: AiResponseType.taskSummary,
          ),
        ];

        final sequence = SequentialInferenceRunner.determineInferenceSequence(
          activePrompts: limitedPrompts,
          entity: testEntity,
        );

        expect(sequence, [
          AiResponseType.audioTranscription,
          AiResponseType.taskSummary,
        ]);
      });

      test('returns empty sequence when no prompts available', () {
        final sequence = SequentialInferenceRunner.determineInferenceSequence(
          activePrompts: [],
          entity: testEntity,
        );

        expect(sequence, isEmpty);
      });

      test('maintains correct order regardless of prompt list order', () {
        // Reverse the order of prompts
        final reversedPrompts = [
          _createPrompt(
            id: 'summary',
            aiResponseType: AiResponseType.taskSummary,
          ),
          _createPrompt(
            id: 'checklist',
            aiResponseType: AiResponseType.checklistUpdates,
          ),
          _createPrompt(
            id: 'transcription',
            aiResponseType: AiResponseType.audioTranscription,
          ),
        ];

        final sequence = SequentialInferenceRunner.determineInferenceSequence(
          activePrompts: reversedPrompts,
          entity: testEntity,
        );

        // Should still be in the correct order
        expect(sequence, [
          AiResponseType.audioTranscription,
          AiResponseType.checklistUpdates,
          AiResponseType.taskSummary,
        ]);
      });
    });

    group('validatePromptsAvailable', () {
      test('returns true when all required prompts are available', () {
        final result = SequentialInferenceRunner.validatePromptsAvailable(
          activePrompts: activePrompts,
          requiredTypes: [
            AiResponseType.audioTranscription,
            AiResponseType.taskSummary,
          ],
        );

        expect(result, isTrue);
      });

      test('returns false when a required prompt is missing', () {
        final result = SequentialInferenceRunner.validatePromptsAvailable(
          activePrompts: activePrompts,
          requiredTypes: [
            AiResponseType.audioTranscription,
            // ignore: deprecated_member_use_from_same_package
            AiResponseType.actionItemSuggestions, // Not in activePrompts
          ],
        );

        expect(result, isFalse);
      });

      test('returns true for empty required types', () {
        final result = SequentialInferenceRunner.validatePromptsAvailable(
          activePrompts: activePrompts,
          requiredTypes: [],
        );

        expect(result, isTrue);
      });

      test('returns false when no prompts available but types required', () {
        final result = SequentialInferenceRunner.validatePromptsAvailable(
          activePrompts: [],
          requiredTypes: [AiResponseType.taskSummary],
        );

        expect(result, isFalse);
      });
    });

    group('Edge cases and error handling', () {
      test('handles null entity gracefully', () async {
        final result = await SequentialInferenceRunner.runSingleInferenceStep(
          responseType: AiResponseType.taskSummary,
          activePrompts: activePrompts,
          entityId: 'test-entity',
          entity: testEntity,
          getEntity: (_) async => null,
          runInference: (entityId, promptConfig, {entity}) async {
            inferenceLog.add('Ran inference');
          },
          onProgress: (_) {},
        );

        expect(result, isTrue);
        expect(inferenceLog, contains('Ran inference'));
      });

      test('handles empty activePrompts list', () async {
        final result = await SequentialInferenceRunner.runSingleInferenceStep(
          responseType: AiResponseType.taskSummary,
          activePrompts: [],
          entityId: 'test-entity',
          entity: testEntity,
          getEntity: (_) async => testEntity,
          runInference: (entityId, promptConfig, {entity}) async {
            inferenceLog.add('Should not be called');
          },
          onProgress: (_) {},
        );

        expect(result, isFalse);
        expect(inferenceLog, isEmpty);
      });

      test('handles duplicate response types in prompts', () {
        final duplicatePrompts = [
          _createPrompt(
            id: 'summary1',
            aiResponseType: AiResponseType.taskSummary,
          ),
          _createPrompt(
            id: 'summary2',
            aiResponseType: AiResponseType.taskSummary,
          ),
        ];

        final sequence = SequentialInferenceRunner.determineInferenceSequence(
          activePrompts: duplicatePrompts,
          entity: testEntity,
        );

        // Should only include one instance of each type
        expect(sequence, [AiResponseType.taskSummary]);
        expect(sequence.length, 1);
      });
    });

    group('Performance and optimization', () {
      test('does not call getEntity unnecessarily', () async {
        var getEntityCallCount = 0;

        await SequentialInferenceRunner.runSingleInferenceStep(
          responseType: AiResponseType.taskSummary,
          activePrompts: activePrompts,
          entityId: 'test-entity',
          entity: testEntity, // Entity is provided
          getEntity: (_) async {
            getEntityCallCount++;
            return testEntity;
          },
          runInference: (entityId, promptConfig, {entity}) async {},
          onProgress: (_) {},
        );

        // getEntity should not be called since entity was provided
        expect(getEntityCallCount, 0);
      });

      test('efficiently filters prompts without multiple iterations', () {
        final largePromptList = List.generate(
          100,
          (i) => _createPrompt(
            id: 'prompt$i',
            aiResponseType: i % 5 == 0
                ? AiResponseType.taskSummary
                : AiResponseType.audioTranscription,
          ),
        );

        final stopwatch = Stopwatch()..start();

        final sequence = SequentialInferenceRunner.determineInferenceSequence(
          activePrompts: largePromptList,
          entity: testEntity,
        );

        stopwatch.stop();

        // Should complete quickly even with large prompt list
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(sequence, isNotEmpty);
      });
    });
  });
}

// Helper function to create test prompts
AiConfigPrompt _createPrompt({
  required String id,
  required AiResponseType aiResponseType,
}) {
  return FakeAiConfigPrompt(
    id: id,
    aiResponseType: aiResponseType,
  );
}
