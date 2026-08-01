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

class _GeneratedActiveOperation {
  const _GeneratedActiveOperation({
    required this.kind,
    required this.entitySlot,
    required this.responseSlot,
    required this.promptSlot,
    required this.progressSlot,
  });

  final _GeneratedActiveOperationKind kind;
  final _GeneratedActiveEntitySlot entitySlot;
  final _GeneratedActiveResponseSlot responseSlot;
  final _GeneratedActivePromptSlot promptSlot;
  final _GeneratedActiveProgressSlot progressSlot;

  String get entityId => _generatedActiveEntityId(entitySlot);

  AiResponseType get responseType => _generatedActiveResponseType(responseSlot);

  String get promptId => _generatedActivePromptId(promptSlot);

  String get progressText => _generatedActiveProgress(progressSlot);

  @override
  String toString() {
    return '_GeneratedActiveOperation('
        'kind: $kind, entitySlot: $entitySlot, responseSlot: $responseSlot, '
        'promptSlot: $promptSlot, progressSlot: $progressSlot)';
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
    required this.progressText,
  });

  final String entityId;
  final String promptId;
  final String progressText;

  _ExpectedActiveInference copyWith({required String progressText}) {
    return _ExpectedActiveInference(
      entityId: entityId,
      promptId: promptId,
      progressText: progressText,
    );
  }

  List<Object?> get snapshot => [
    entityId,
    promptId,
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
      glados.any.combine5(
        activeOperationKind,
        activeEntitySlot,
        activeResponseSlot,
        activePromptSlot,
        activeProgressSlot,
        (
          _GeneratedActiveOperationKind kind,
          _GeneratedActiveEntitySlot entitySlot,
          _GeneratedActiveResponseSlot responseSlot,
          _GeneratedActivePromptSlot promptSlot,
          _GeneratedActiveProgressSlot progressSlot,
        ) => _GeneratedActiveOperation(
          kind: kind,
          entitySlot: entitySlot,
          responseSlot: responseSlot,
          promptSlot: promptSlot,
          progressSlot: progressSlot,
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
        activeInferenceControllerProvider((
          entityId: entityId,
          aiResponseType: responseType,
        )).notifier,
      );

      // Initially should be null
      var state = container.read(
        activeInferenceControllerProvider((
          entityId: entityId,
          aiResponseType: responseType,
        )),
      );
      expect(state, isNull);

      // Start inference
      controller.startInference(promptId: promptId);

      // Should now have active inference data
      state = container.read(
        activeInferenceControllerProvider((
          entityId: entityId,
          aiResponseType: responseType,
        )),
      );
      expect(state, isNotNull);
      expect(state!.entityId, equals(entityId));
      expect(state.promptId, equals(promptId));
      expect(state.progressText, isEmpty);
    });

    test('should update progress text and stream', () {
      const entityId = 'test-entity-id';
      const promptId = 'test-prompt-id';
      // ignore: deprecated_member_use_from_same_package
      const responseType = AiResponseType.taskSummary;

      fakeAsync((async) {
        final controller = container.read(
          activeInferenceControllerProvider((
            entityId: entityId,
            aiResponseType: responseType,
          )).notifier,
        )..startInference(promptId: promptId);

        final state = container.read(
          activeInferenceControllerProvider((
            entityId: entityId,
            aiResponseType: responseType,
          )),
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
          activeInferenceControllerProvider((
            entityId: entityId,
            aiResponseType: responseType,
          )),
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
              activeInferenceControllerProvider((
                entityId: entityId,
                aiResponseType: responseType,
              )).notifier,
            )
            // Start inference
            ..startInference(promptId: promptId);

      // Verify it exists
      var state = container.read(
        activeInferenceControllerProvider((
          entityId: entityId,
          aiResponseType: responseType,
        )),
      );
      expect(state, isNotNull);

      // Clear inference
      controller.clearInference();

      // Should be null again
      state = container.read(
        activeInferenceControllerProvider((
          entityId: entityId,
          aiResponseType: responseType,
        )),
      );
      expect(state, isNull);
    });

    glados.Glados(
      glados.any.activeInferenceScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test('matches generated active inference lifecycle semantics', (
      scenario,
    ) {
      fakeAsync((async) {
        final generatedContainer = ProviderContainer();
        final model = _GeneratedActiveModel();

        try {
          for (final operation in scenario.operations) {
            final controller = generatedContainer.read(
              activeInferenceControllerProvider((
                entityId: operation.entityId,
                aiResponseType: operation.responseType,
              )).notifier,
            );

            switch (operation.kind) {
              case _GeneratedActiveOperationKind.start:
                controller.startInference(
                  promptId: operation.promptId,
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
                  activeInferenceControllerProvider((
                    entityId: operation.entityId,
                    aiResponseType: operation.responseType,
                  )),
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
          }
        } finally {
          generatedContainer.dispose();
        }
      });
    }, tags: 'glados');
  });
}
