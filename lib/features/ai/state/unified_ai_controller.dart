import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_ai_controller.g.dart';

/// Controller for running unified AI inference with configurable prompts
@riverpod
class UnifiedAiController extends _$UnifiedAiController {
  @override
  String build({
    required String entityId,
    required String promptId,
  }) {
    return '';
  }

  // Helper method to update inference status for both entities
  void _updateInferenceStatus(
    InferenceStatus status,
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          inferenceStatusControllerProvider(
            id: entityId,
            aiResponseType: responseType,
          ).notifier,
        )
        .setStatus(status);

    if (linkedEntityId != null) {
      ref
          .read(
            inferenceStatusControllerProvider(
              id: linkedEntityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .setStatus(status);
    }
  }

  // Helper method to start active inference for both entities
  void _startActiveInference(
    String promptId,
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          activeInferenceControllerProvider(
            entityId: entityId,
            aiResponseType: responseType,
          ).notifier,
        )
        .startInference(
          promptId: promptId,
          linkedEntityId: linkedEntityId,
        );

    if (linkedEntityId != null) {
      ref
          .read(
            activeInferenceControllerProvider(
              entityId: linkedEntityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .startInference(
            promptId: promptId,
            linkedEntityId: entityId,
          );
    }
  }

  // Helper method to update progress for both entities
  void _updateActiveInferenceProgress(
    String progress,
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          activeInferenceControllerProvider(
            entityId: entityId,
            aiResponseType: responseType,
          ).notifier,
        )
        .updateProgress(progress);

    if (linkedEntityId != null) {
      ref
          .read(
            activeInferenceControllerProvider(
              entityId: linkedEntityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .updateProgress(progress);
    }
  }

  // Helper method to clear active inference for both entities
  void _clearActiveInference(
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          activeInferenceControllerProvider(
            entityId: entityId,
            aiResponseType: responseType,
          ).notifier,
        )
        .clearInference();

    if (linkedEntityId != null) {
      ref
          .read(
            activeInferenceControllerProvider(
              entityId: linkedEntityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .clearInference();
    }
  }

  Future<void> runInference({String? linkedEntityId}) async {
    final loggingService = getIt<LoggingService>()
      ..captureEvent(
        'Starting unified AI inference for $entityId (linked: $linkedEntityId)',
        subDomain: 'runInference',
        domain: 'UnifiedAiController',
      );

    try {
      // Fetch the prompt config
      final config = await ref.read(aiConfigByIdProvider(promptId).future);
      if (config == null || config is! AiConfigPrompt) {
        throw Exception('Invalid prompt configuration for ID: $promptId');
      }
      final promptConfig = config;

      // Reset the inference status to idle before starting
      _updateInferenceStatus(
        InferenceStatus.idle,
        promptConfig.aiResponseType,
        linkedEntityId: linkedEntityId,
      );

      // Clear any previous progress message
      state = '';

      // Start tracking this inference
      _startActiveInference(
        promptId,
        promptConfig.aiResponseType,
        linkedEntityId: linkedEntityId,
      );

      await ref.read(unifiedAiInferenceRepositoryProvider).runInference(
            entityId: entityId,
            promptConfig: promptConfig,
            onProgress: (progress) {
              state = progress;

              // Update active inference progress for both entities
              _updateActiveInferenceProgress(
                progress,
                promptConfig.aiResponseType,
                linkedEntityId: linkedEntityId,
              );
            },
            onStatusChange: (status) {
              // Update status for both entities
              _updateInferenceStatus(
                status,
                promptConfig.aiResponseType,
                linkedEntityId: linkedEntityId,
              );

              // Clear active inference when done
              if (status != InferenceStatus.running) {
                _clearActiveInference(
                  promptConfig.aiResponseType,
                  linkedEntityId: linkedEntityId,
                );
              }
            },
            useConversationApproach: true, // Enable new conversation approach
          );
    } catch (e, stackTrace) {
      // Categorize the error for better user feedback
      final inferenceError =
          AiErrorUtils.categorizeError(e, stackTrace: stackTrace);

      // Set the error message to display
      state = inferenceError.message;

      // Try to set error status if we have prompt config
      try {
        final config = await ref.read(aiConfigByIdProvider(promptId).future);
        if (config != null && config is AiConfigPrompt) {
          _updateInferenceStatus(
            InferenceStatus.error,
            config.aiResponseType,
            linkedEntityId: linkedEntityId,
          );
        }
      } catch (_) {
        // Ignore errors when setting status
      }

      loggingService.captureException(
        inferenceError.originalError ?? e,
        domain: 'UnifiedAiController',
        subDomain: 'runInference',
        stackTrace: stackTrace,
      );
    }
  }
}

/// Provider to get available prompts for a given entity
@riverpod
Future<List<AiConfigPrompt>> availablePrompts(
  Ref ref, {
  required JournalEntity entity,
}) async {
  // Watch for changes in AI prompt configurations
  // This will trigger a rebuild when any prompt configuration changes
  await ref.watch(
    aiConfigByTypeControllerProvider(configType: AiConfigType.prompt).future,
  );

  // If the entity has a category, watch for changes to that specific category
  final categoryId = entity.meta.categoryId;
  if (categoryId != null) {
    // Watch the category - this will trigger rebuilds when the category changes
    await ref.watch(categoryChangesProvider(categoryId).future);
  }

  final repository = ref.watch(unifiedAiInferenceRepositoryProvider);
  return repository.getActivePromptsForContext(entity: entity);
}

/// Provider to check if there are any prompts available for an entity
@riverpod
Future<bool> hasAvailablePrompts(
  Ref ref, {
  required JournalEntity entity,
}) async {
  final prompts = await ref.watch(
    availablePromptsProvider(entity: entity).future,
  );
  return prompts.isNotEmpty;
}

/// Provider to watch category changes
@riverpod
Stream<void> categoryChanges(Ref ref, String categoryId) {
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  return categoryRepo.watchCategory(categoryId).map((_) {});
}

/// Provider to trigger a new inference run
@riverpod
Future<void> triggerNewInference(
  Ref ref, {
  required String entityId,
  required String promptId,
  String? linkedEntityId,
}) async {
  // Get the controller instance (this will create it if it doesn't exist)
  final controller = ref.read(
    unifiedAiControllerProvider(
      entityId: entityId,
      promptId: promptId,
    ).notifier,
  );

  // Wait for the inference to complete, passing the linked entity ID
  await controller.runInference(linkedEntityId: linkedEntityId);
}
