import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';

void main() {
  group('ActiveInferenceController Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should start and track inference', () {
      const entityId = 'test-entity-id';
      const promptId = 'test-prompt-id';
      const responseType = AiResponseType.taskSummary;

      final controller = container.read(
        activeInferenceControllerProvider(
          entityId: entityId,
          aiResponseType: responseType,
        ).notifier,
      );

      // Initially should be null
      var state = container.read(
        activeInferenceControllerProvider(
          entityId: entityId,
          aiResponseType: responseType,
        ),
      );
      expect(state, isNull);

      // Start inference
      controller.startInference(
        promptId: promptId,
        linkedEntityId: 'linked-entity',
      );

      // Should now have active inference data
      state = container.read(
        activeInferenceControllerProvider(
          entityId: entityId,
          aiResponseType: responseType,
        ),
      );
      expect(state, isNotNull);
      expect(state!.entityId, equals(entityId));
      expect(state.promptId, equals(promptId));
      expect(state.linkedEntityId, equals('linked-entity'));
      expect(state.progressText, isEmpty);
    });

    test('should update progress text and stream', () async {
      const entityId = 'test-entity-id';
      const promptId = 'test-prompt-id';
      const responseType = AiResponseType.taskSummary;

      final controller = container.read(
        activeInferenceControllerProvider(
          entityId: entityId,
          aiResponseType: responseType,
        ).notifier,
      )..startInference(promptId: promptId);

      final state = container.read(
        activeInferenceControllerProvider(
          entityId: entityId,
          aiResponseType: responseType,
        ),
      );

      // Set up stream listener
      final progressUpdates = <String>[];
      final subscription = state!.progressStream.listen(progressUpdates.add);

      // Update progress
      controller.updateProgress('First update');

      // Allow stream to process
      await Future<void>.delayed(const Duration(milliseconds: 10));

      controller.updateProgress('Second update');

      // Allow stream to process
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Check stream received updates
      expect(progressUpdates, equals(['First update', 'Second update']));

      // Check state was updated
      final updatedState = container.read(
        activeInferenceControllerProvider(
          entityId: entityId,
          aiResponseType: responseType,
        ),
      );
      expect(updatedState!.progressText, equals('Second update'));

      await subscription.cancel();
    });

    test('should clear inference', () {
      const entityId = 'test-entity-id';
      const promptId = 'test-prompt-id';
      const responseType = AiResponseType.taskSummary;

      final controller = container.read(
        activeInferenceControllerProvider(
          entityId: entityId,
          aiResponseType: responseType,
        ).notifier,
      )

        // Start inference
        ..startInference(promptId: promptId);

      // Verify it exists
      var state = container.read(
        activeInferenceControllerProvider(
          entityId: entityId,
          aiResponseType: responseType,
        ),
      );
      expect(state, isNotNull);

      // Clear inference
      controller.clearInference();

      // Should be null again
      state = container.read(
        activeInferenceControllerProvider(
          entityId: entityId,
          aiResponseType: responseType,
        ),
      );
      expect(state, isNull);
    });

    test('ActiveInferenceByEntity should find active inference', () {
      const entityId = 'test-entity-id';
      const promptId = 'test-prompt-id';
      const responseType = AiResponseType.taskSummary;

      // Initially no active inference
      var activeInference = container.read(
        activeInferenceByEntityProvider(entityId),
      );
      expect(activeInference, isNull);

      // Start an inference
      container
          .read(
            activeInferenceControllerProvider(
              entityId: entityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .startInference(promptId: promptId);

      // Should now find the active inference
      activeInference = container.read(
        activeInferenceByEntityProvider(entityId),
      );
      expect(activeInference, isNotNull);
      expect(activeInference!.entityId, equals(entityId));
      expect(activeInference.promptId, equals(promptId));
    });

    test('ActiveInferenceByEntity should find inference for linked entity', () {
      const audioEntityId = 'audio-123';
      const taskEntityId = 'task-456';
      const promptId = 'asr-prompt';
      const responseType = AiResponseType.audioTranscription;

      // Initially no active inference for either entity
      expect(
        container.read(activeInferenceByEntityProvider(audioEntityId)),
        isNull,
      );
      expect(
        container.read(activeInferenceByEntityProvider(taskEntityId)),
        isNull,
      );

      // Simulate what unified_ai_controller does: start inference for BOTH entities
      // This mimics the _startActiveInference helper method behavior

      // 1. Start for primary entity (audio)
      container
          .read(
            activeInferenceControllerProvider(
              entityId: audioEntityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .startInference(
            promptId: promptId,
            linkedEntityId: taskEntityId,
          );

      // 2. Also start for linked entity (task) - this is what makes it work!
      container
          .read(
            activeInferenceControllerProvider(
              entityId: taskEntityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .startInference(
            promptId: promptId,
            linkedEntityId: audioEntityId,
          );

      // Now BOTH entities should find the active inference
      final audioInference = container.read(
        activeInferenceByEntityProvider(audioEntityId),
      );
      expect(audioInference, isNotNull);
      expect(audioInference!.entityId, equals(audioEntityId));
      expect(audioInference.linkedEntityId, equals(taskEntityId));
      expect(audioInference.aiResponseType, equals(responseType));

      final taskInference = container.read(
        activeInferenceByEntityProvider(taskEntityId),
      );
      expect(taskInference, isNotNull);
      expect(taskInference!.entityId, equals(taskEntityId));
      expect(taskInference.linkedEntityId, equals(audioEntityId));
      expect(taskInference.aiResponseType, equals(responseType));
    });
  });
}
