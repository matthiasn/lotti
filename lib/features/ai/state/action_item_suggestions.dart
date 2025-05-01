import 'dart:async';
import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
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

      final useCloudInference =
          await getIt<JournalDb>().getConfigFlag(useCloudInferenceFlag);

      final model = useCloudInference
          ? 'deepseek-ai/DeepSeek-R1-fast'
          : 'deepseek-r1:14b';

      //final model = 'models/gemini-2.5-pro-preview-03-25';

      const temperature = 0.6;

      if (useCloudInference) {
        final configs = await ref
            .read(aiConfigRepositoryProvider)
            .getConfigsByType('apiKey');

        final apiKeyConfig = configs
            .whereType<AiConfigApiKey>()
            .where(
              (config) =>
                  config.inferenceProviderType ==
                  InferenceProviderType.nebiusAiStudio,
            )
            .firstOrNull;

        if (apiKeyConfig == null) {
          state = 'No Nebius AI Studio API key found';
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

      var thoughts = '';
      var response = completeResponse;

      if (completeResponse.contains('</think>')) {
        final [part1, part2] = completeResponse.split('</think>');
        thoughts = part1;
        response = part2;
      }

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
