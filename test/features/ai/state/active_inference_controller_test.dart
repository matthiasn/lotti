import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';

enum _GeneratedActiveEntitySlot { primary, secondary }

enum _GeneratedActiveResponseSlot {
  imageAnalysis,
  audioTranscription,
  promptGeneration,
  imagePromptGeneration,
  imageGeneration,
}

enum _GeneratedActivePromptSlot { first, second, third }

enum _GeneratedActiveProgressSlot { queued, running, finalizing, done, empty }

enum _GeneratedActiveOperationKind { start, updateProgress, clear }

String _generatedActiveEntityId(_GeneratedActiveEntitySlot slot) =>
    'generated-active-${slot.name}';

String _generatedActivePromptId(_GeneratedActivePromptSlot slot) =>
    'generated-prompt-${slot.name}';

String _generatedActiveProgress(_GeneratedActiveProgressSlot slot) {
  return switch (slot) {
    _GeneratedActiveProgressSlot.queued => 'queued',
    _GeneratedActiveProgressSlot.running => 'running',
    _GeneratedActiveProgressSlot.finalizing => 'finalizing',
    _GeneratedActiveProgressSlot.done => 'done',
    _GeneratedActiveProgressSlot.empty => '',
  };
}

AiResponseType _generatedActiveResponseType(
  _GeneratedActiveResponseSlot slot,
) {
  return switch (slot) {
    _GeneratedActiveResponseSlot.imageAnalysis => AiResponseType.imageAnalysis,
    _GeneratedActiveResponseSlot.audioTranscription =>
      AiResponseType.audioTranscription,
    _GeneratedActiveResponseSlot.promptGeneration =>
      AiResponseType.promptGeneration,
    _GeneratedActiveResponseSlot.imagePromptGeneration =>
      AiResponseType.imagePromptGeneration,
    _GeneratedActiveResponseSlot.imageGeneration =>
      AiResponseType.imageGeneration,
  };
}

_GeneratedActiveEntitySlot _otherEntitySlot(_GeneratedActiveEntitySlot slot) {
  return switch (slot) {
    _GeneratedActiveEntitySlot.primary => _GeneratedActiveEntitySlot.secondary,
    _GeneratedActiveEntitySlot.secondary => _GeneratedActiveEntitySlot.primary,
  };
}

class _GeneratedActiveOperation {
  const _GeneratedActiveOperation({
    required this.kind,
    required this.entitySlot,
    required this.responseSlot,
    required this.promptSlot,
    required this.progressSlot,
    required this.linkOtherEntity,
  });

  final _GeneratedActiveOperationKind kind;
  final _GeneratedActiveEntitySlot entitySlot;
  final _GeneratedActiveResponseSlot responseSlot;
  final _GeneratedActivePromptSlot promptSlot;
  final _GeneratedActiveProgressSlot progressSlot;
  final bool linkOtherEntity;

  String get entityId => _generatedActiveEntityId(entitySlot);

  AiResponseType get responseType => _generatedActiveResponseType(responseSlot);

  String get promptId => _generatedActivePromptId(promptSlot);

  String get progressText => _generatedActiveProgress(progressSlot);

  String? get linkedEntityId => linkOtherEntity
      ? _generatedActiveEntityId(_otherEntitySlot(entitySlot))
      : null;

  @override
  String toString() {
    return '_GeneratedActiveOperation('
        'kind: $kind, entitySlot: $entitySlot, responseSlot: $responseSlot, '
        'promptSlot: $promptSlot, progressSlot: $progressSlot, '
        'linkOtherEntity: $linkOtherEntity)';
  }
}

class _GeneratedActiveScenario {
  const _GeneratedActiveScenario({
    required this.watchedEntitySlot,
    required this.operations,
  });

  final _GeneratedActiveEntitySlot watchedEntitySlot;
  final List<_GeneratedActiveOperation> operations;

  String get watchedEntityId => _generatedActiveEntityId(watchedEntitySlot);

  @override
  String toString() {
    return '_GeneratedActiveScenario('
        'watchedEntitySlot: $watchedEntitySlot, operations: $operations)';
  }
}

class _ExpectedActiveInference {
  const _ExpectedActiveInference({
    required this.entityId,
    required this.promptId,
    required this.aiResponseType,
    required this.linkedEntityId,
    required this.progressText,
  });

  final String entityId;
  final String promptId;
  final AiResponseType aiResponseType;
  final String? linkedEntityId;
  final String progressText;

  _ExpectedActiveInference copyWith({required String progressText}) {
    return _ExpectedActiveInference(
      entityId: entityId,
      promptId: promptId,
      aiResponseType: aiResponseType,
      linkedEntityId: linkedEntityId,
      progressText: progressText,
    );
  }

  List<Object?> get snapshot => [
    entityId,
    promptId,
    aiResponseType,
    linkedEntityId,
    progressText,
  ];
}

class _GeneratedActiveModel {
  final _entries = <String, _ExpectedActiveInference>{};

  void apply(_GeneratedActiveOperation operation) {
    final key = _activeInferenceKey(
      operation.entityId,
      operation.responseType,
    );

    switch (operation.kind) {
      case _GeneratedActiveOperationKind.start:
        _entries[key] = _ExpectedActiveInference(
          entityId: operation.entityId,
          promptId: operation.promptId,
          aiResponseType: operation.responseType,
          linkedEntityId: operation.linkedEntityId,
          progressText: '',
        );

      case _GeneratedActiveOperationKind.updateProgress:
        final current = _entries[key];
        if (current != null) {
          _entries[key] = current.copyWith(
            progressText: operation.progressText,
          );
        }

      case _GeneratedActiveOperationKind.clear:
        _entries.remove(key);
    }
  }

  List<Object?>? directSnapshot(
    String entityId,
    AiResponseType responseType,
  ) {
    return _entries[_activeInferenceKey(entityId, responseType)]?.snapshot;
  }

  List<Object?>? byEntitySnapshot(String entityId) {
    for (final responseType in AiResponseType.values) {
      final snapshot = directSnapshot(entityId, responseType);
      if (snapshot != null) {
        return snapshot;
      }
    }

    return null;
  }
}

extension _AnyGeneratedActiveScenario on glados.Any {
  glados.Generator<_GeneratedActiveEntitySlot> get activeEntitySlot =>
      glados.any.choose(_GeneratedActiveEntitySlot.values);

  glados.Generator<_GeneratedActiveResponseSlot> get activeResponseSlot =>
      glados.any.choose(_GeneratedActiveResponseSlot.values);

  glados.Generator<_GeneratedActivePromptSlot> get activePromptSlot =>
      glados.any.choose(_GeneratedActivePromptSlot.values);

  glados.Generator<_GeneratedActiveProgressSlot> get activeProgressSlot =>
      glados.any.choose(_GeneratedActiveProgressSlot.values);

  glados.Generator<_GeneratedActiveOperationKind> get activeOperationKind =>
      glados.any.choose(_GeneratedActiveOperationKind.values);

  glados.Generator<_GeneratedActiveOperation> get activeOperation =>
      glados.any.combine6(
        activeOperationKind,
        activeEntitySlot,
        activeResponseSlot,
        activePromptSlot,
        activeProgressSlot,
        glados.any.bool,
        (
          _GeneratedActiveOperationKind kind,
          _GeneratedActiveEntitySlot entitySlot,
          _GeneratedActiveResponseSlot responseSlot,
          _GeneratedActivePromptSlot promptSlot,
          _GeneratedActiveProgressSlot progressSlot,
          bool linkOtherEntity,
        ) => _GeneratedActiveOperation(
          kind: kind,
          entitySlot: entitySlot,
          responseSlot: responseSlot,
          promptSlot: promptSlot,
          progressSlot: progressSlot,
          linkOtherEntity: linkOtherEntity,
        ),
      );

  glados.Generator<_GeneratedActiveScenario> get activeInferenceScenario =>
      glados.any.combine2(
        activeEntitySlot,
        glados.any.listWithLengthInRange(
          0,
          55,
          activeOperation,
        ),
        (
          _GeneratedActiveEntitySlot watchedEntitySlot,
          List<_GeneratedActiveOperation> operations,
        ) => _GeneratedActiveScenario(
          watchedEntitySlot: watchedEntitySlot,
          operations: operations,
        ),
      );
}

String _activeInferenceKey(String entityId, AiResponseType responseType) =>
    '$entityId::${responseType.name}';

List<Object?>? _activeInferenceSnapshot(ActiveInferenceData? data) {
  if (data == null) {
    return null;
  }

  return [
    data.entityId,
    data.promptId,
    data.aiResponseType,
    data.linkedEntityId,
    data.progressText,
  ];
}

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
      // ignore: deprecated_member_use_from_same_package
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

    test('should update progress text and stream', () {
      const entityId = 'test-entity-id';
      const promptId = 'test-prompt-id';
      // ignore: deprecated_member_use_from_same_package
      const responseType = AiResponseType.taskSummary;

      fakeAsync((async) {
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
        async.flushMicrotasks();

        controller.updateProgress('Second update');
        async.flushMicrotasks();

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

        unawaited(subscription.cancel());
      });
    });

    test('should clear inference', () {
      const entityId = 'test-entity-id';
      const promptId = 'test-prompt-id';
      // ignore: deprecated_member_use_from_same_package
      const responseType = AiResponseType.taskSummary;

      final controller =
          container.read(
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
      // ignore: deprecated_member_use_from_same_package
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

    glados.Glados(
      glados.any.activeInferenceScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated active inference lifecycle semantics', (
      scenario,
    ) {
      fakeAsync((async) {
        final generatedContainer = ProviderContainer();
        final model = _GeneratedActiveModel();

        try {
          for (final operation in scenario.operations) {
            final controller = generatedContainer.read(
              activeInferenceControllerProvider(
                entityId: operation.entityId,
                aiResponseType: operation.responseType,
              ).notifier,
            );

            switch (operation.kind) {
              case _GeneratedActiveOperationKind.start:
                controller.startInference(
                  promptId: operation.promptId,
                  linkedEntityId: operation.linkedEntityId,
                );

              case _GeneratedActiveOperationKind.updateProgress:
                controller.updateProgress(operation.progressText);

              case _GeneratedActiveOperationKind.clear:
                controller.clearInference();
            }

            async.flushMicrotasks();
            model.apply(operation);

            expect(
              _activeInferenceSnapshot(
                generatedContainer.read(
                  activeInferenceControllerProvider(
                    entityId: operation.entityId,
                    aiResponseType: operation.responseType,
                  ),
                ),
              ),
              equals(
                model.directSnapshot(
                  operation.entityId,
                  operation.responseType,
                ),
              ),
              reason: '$scenario after $operation',
            );
            expect(
              _activeInferenceSnapshot(
                generatedContainer.read(
                  activeInferenceByEntityProvider(scenario.watchedEntityId),
                ),
              ),
              equals(model.byEntitySnapshot(scenario.watchedEntityId)),
              reason: '$scenario after $operation',
            );
          }

          if (scenario.operations.isEmpty) {
            expect(
              generatedContainer.read(
                activeInferenceByEntityProvider(scenario.watchedEntityId),
              ),
              isNull,
            );
          }
        } finally {
          generatedContainer.dispose();
        }
      });
    }, tags: 'glados');
  });
}
