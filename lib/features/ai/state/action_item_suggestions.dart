import 'dart:async';
import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'action_item_suggestions.g.dart';

@riverpod
class ActionItemSuggestionsController
    extends _$ActionItemSuggestionsController {
  @override
  String build({
    required String id,
  }) {
    //ref.cacheFor(inferenceStateCacheDuration);
    Future<void>.delayed(const Duration(milliseconds: 10)).then((_) {
      getActionItemSuggestion();
    });

    return '';
  }

  Future<void> getActionItemSuggestion() async {
    final repository = ref.read(aiInputRepositoryProvider);
    const aiResponseType = actionItemSuggestions;
    final suggestionsStatusNotifier = ref.read(
      inferenceStatusControllerProvider(
        id: id,
        aiResponseType: aiResponseType,
      ).notifier,
    );

    getIt<LoggingService>().captureEvent(
      'Starting action item suggestions for $id',
      subDomain: 'getActionItemSuggestion',
      domain: 'SuggestionsStatusController',
    );

    try {
      final start = DateTime.now();
      suggestionsStatusNotifier.setStatus(InferenceStatus.running);
      final entry = await repository.getEntity(id);

      final prompt = await ref
          .read(aiInputRepositoryProvider)
          .buildPrompt(id: id, aiResponseType: aiResponseType);

      if (entry is! Task || prompt == null) {
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

      final exp = RegExp(r'\[(.|\n)*\]', multiLine: true);
      final match = exp.firstMatch(response)?.group(0) ?? '[]';
      final actionItemsJson = '{"items": $match}';
      final decoded = jsonDecode(actionItemsJson) as Map<String, dynamic>;
      final suggestedActionItems =
          AiInputActionItemsList.fromJson(decoded).items;

      final data = AiResponseData(
        model: model,
        temperature: temperature,
        systemMessage: '',
        prompt: prompt,
        thoughts: thoughts,
        response: response,
        suggestedActionItems: suggestedActionItems,
        type: actionItemSuggestions,
      );

      await repository.createAiResponseEntry(
        data: data,
        start: start,
        linkedId: id,
        categoryId: entry.categoryId,
      );

      suggestionsStatusNotifier.setStatus(InferenceStatus.idle);
    } catch (e, stackTrace) {
      suggestionsStatusNotifier.setStatus(InferenceStatus.error);
      getIt<LoggingService>().captureException(
        e,
        domain: 'SuggestionsStatusController',
        subDomain: 'getActionItemSuggestion',
        stackTrace: stackTrace,
      );
    }
  }
}
