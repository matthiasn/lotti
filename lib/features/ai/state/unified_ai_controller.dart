import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/cache_extension.dart';
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
    ref.cacheFor(entryCacheDuration);

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
      final errorMessage = AiErrorUtils.extractDetailedErrorMessage(
        e,
        defaultMessage: e.toString(),
      );

      state = errorMessage;

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
        e,
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
