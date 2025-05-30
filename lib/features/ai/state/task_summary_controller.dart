import 'dart:async';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_summary_controller.g.dart';

@riverpod
class TaskSummaryController extends _$TaskSummaryController {
  @override
  String build({
    required String id,
  }) {
    Future<void>.delayed(const Duration(milliseconds: 10)).then((_) {
      getTaskSummary();
    });
    return '';
  }

  Future<void> getTaskSummary() async {
    final start = DateTime.now();
    final entry = await ref.read(aiInputRepositoryProvider).getEntity(id);

    if (entry is! Task) {
      return;
    }

    final inferenceStatusProvider = inferenceStatusControllerProvider(
      id: id,
      aiResponseType: AiResponseType.taskSummary,
    );

    final inferenceStatusNotifier = ref.read(inferenceStatusProvider.notifier);

    getIt<LoggingService>().captureEvent(
      'Starting task summary for $id',
      subDomain: 'getTaskSummary',
      domain: 'TaskSummaryController',
    );

    final isRunning =
        ref.read(inferenceStatusProvider) == InferenceStatus.running;

    if (isRunning) {
      return;
    }

    try {
      inferenceStatusNotifier.setStatus(InferenceStatus.running);

      final prompt = await ref
          .read(aiInputRepositoryProvider)
          .buildPrompt(id: id, aiResponseType: AiResponseType.taskSummary);

      if (prompt == null) {
        inferenceStatusNotifier.setStatus(InferenceStatus.idle);
        return;
      }

      final buffer = StringBuffer();

      final useCloudInference =
          await getIt<JournalDb>().getConfigFlag(useCloudInferenceFlag);

      final model =
          useCloudInference ? 'google/gemma-3-27b-it-fast' : 'gemma3:12b';

      const temperature = 0.6;

      if (useCloudInference) {
        final configs = await ref
            .read(aiConfigRepositoryProvider)
            .getConfigsByType(AiConfigType.inferenceProvider);

        final apiKeyConfig = configs
            .whereType<AiConfigInferenceProvider>()
            .where(
              (config) =>
                  config.inferenceProviderType ==
                  InferenceProviderType.nebiusAiStudio,
            )
            .firstOrNull;

        if (apiKeyConfig == null) {
          state = 'No Nebius AI Studio API key found';
          inferenceStatusNotifier.setStatus(InferenceStatus.error);
          return;
        }
        final stream = ref.read(cloudInferenceRepositoryProvider).generate(
              prompt,
              model: model,
              temperature: temperature,
              baseUrl: apiKeyConfig.baseUrl,
              apiKey: apiKeyConfig.apiKey,
            );

        await for (final chunk in stream) {
          buffer.write(chunk.choices[0].delta.content);
          state = buffer.toString();
        }
      } else {
        final stream = ref.read(ollamaRepositoryProvider).generate(
              prompt,
              model: model,
              temperature: temperature,
            );

        await for (final chunk in stream) {
          buffer.write(chunk.text);
          state = buffer.toString();
        }
      }

      final completeResponse = buffer.toString();

      final data = AiResponseData(
        model: model,
        temperature: temperature,
        systemMessage: '',
        prompt: prompt,
        thoughts: '',
        response: completeResponse,
        type: AiResponseType.taskSummary,
      );

      await ref.read(aiInputRepositoryProvider).createAiResponseEntry(
            data: data,
            start: start,
            linkedId: id,
            categoryId: entry.categoryId,
          );
      inferenceStatusNotifier.setStatus(InferenceStatus.idle);
    } catch (e, stackTrace) {
      inferenceStatusNotifier.setStatus(InferenceStatus.error);
      state = AiErrorUtils.extractDetailedErrorMessage(
        e,
        defaultMessage: e.toString(),
      );

      getIt<LoggingService>().captureException(
        e,
        domain: 'TaskSummaryController',
        subDomain: 'getTaskSummary',
        stackTrace: stackTrace,
      );
    }
  }
}
