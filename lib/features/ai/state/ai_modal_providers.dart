import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';

// Riverpod provider to fetch prompts filtered by AiResponseType, using a stream
final promptsForAiResponseTypeProvider =
    StreamProvider.family<List<AiConfigPrompt>, AiResponseType>(
  (ref, responseType) {
    final repository = ref.watch(aiConfigRepositoryProvider);
    return repository.watchConfigsByType(AiConfigType.prompt).map((configs) {
      return configs
          .whereType<AiConfigPrompt>()
          .where((prompt) => prompt.aiResponseType == responseType)
          .toList();
    });
  },
);

// Provider to fetch a list of AiConfigModel objects by their IDs
final modelsByIdsProvider =
    FutureProvider.family<List<AiConfigModel>, List<String>>(
  (ref, modelIds) async {
    if (modelIds.isEmpty) {
      return [];
    }
    final repository = ref.watch(aiConfigRepositoryProvider);
    return repository.getModelsByIds(modelIds);
  },
);
