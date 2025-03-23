import 'dart:async';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
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

    final inferenceStatusNotifier = ref.read(
      inferenceStatusControllerProvider(
        id: id,
        aiResponseType: taskSummary,
      ).notifier,
    );

    getIt<LoggingService>().captureEvent(
      'Starting task summary for $id',
      subDomain: 'getTaskSummary',
      domain: 'TaskSummaryController',
    );

    if (entry is! Task) {
      return;
    }

    try {
      inferenceStatusNotifier.setStatus(InferenceStatus.running);

      final prompt = await ref
          .read(aiInputRepositoryProvider)
          .buildPrompt(id: id, aiResponseType: taskSummary);

      if (prompt == null) {
        return;
      }

      final buffer = StringBuffer();

      const model = 'deepseek-r1:14b'; // TODO: make configurable
      const temperature = 0.6;

      final useCloudInference =
          await getIt<JournalDb>().getConfigFlag(useCloudInferenceFlag);

      if (useCloudInference) {
        final config =
            await ref.read(cloudInferenceRepositoryProvider).getConfig();

        final stream = ref.read(cloudInferenceRepositoryProvider).generate(
              prompt,
              model: model,
              temperature: temperature,
              config: config,
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
      final [thoughts, response] = completeResponse.split('</think>');

      final data = AiResponseData(
        model: model,
        temperature: temperature,
        systemMessage: '',
        prompt: prompt,
        thoughts: thoughts,
        response: response,
        type: 'TaskSummary',
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
      getIt<LoggingService>().captureException(
        e,
        domain: 'TaskSummaryController',
        subDomain: 'getTaskSummary',
        stackTrace: stackTrace,
      );
    }
  }
}
