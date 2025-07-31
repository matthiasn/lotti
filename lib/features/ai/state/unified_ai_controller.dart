import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
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
    // Start inference immediately
    Future<void>.delayed(const Duration(milliseconds: 10)).then((_) {
      runInference();
    });

    return '';
  }

  Future<void> runInference() async {
    final loggingService = getIt<LoggingService>()
      ..captureEvent(
        'Starting unified AI inference for $entityId',
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
      ref
          .read(
            inferenceStatusControllerProvider(
              id: entityId,
              aiResponseType: promptConfig.aiResponseType,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);

      // Clear any previous progress message
      state = '';

      await ref.read(unifiedAiInferenceRepositoryProvider).runInference(
            entityId: entityId,
            promptConfig: promptConfig,
            onProgress: (progress) {
              state = progress;
            },
            onStatusChange: (status) {
              ref
                  .read(
                    inferenceStatusControllerProvider(
                      id: entityId,
                      aiResponseType: promptConfig.aiResponseType,
                    ).notifier,
                  )
                  .setStatus(status);
            },
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
          ref
              .read(
                inferenceStatusControllerProvider(
                  id: entityId,
                  aiResponseType: config.aiResponseType,
                ).notifier,
              )
              .setStatus(InferenceStatus.error);
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

/// Provider to trigger a new inference run by invalidating the controller
@riverpod
Future<void> triggerNewInference(
  Ref ref, {
  required String entityId,
  required String promptId,
}) async {
  // Invalidate the controller to force a new instance and trigger inference
  ref.invalidate(
    unifiedAiControllerProvider(
      entityId: entityId,
      promptId: promptId,
    ),
  );
}
