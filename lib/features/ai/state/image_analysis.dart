import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_analysis.g.dart';

@riverpod
class AiImageAnalysisController extends _$AiImageAnalysisController {
  @override
  String build({
    required String id,
  }) {
    ref.cacheFor(entryCacheDuration);
    return '';
  }

  Future<void> analyzeImage() async {
    final provider = entryControllerProvider(id: id);
    final notifier = ref.read(provider.notifier);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage) {
      return;
    }

    final inferenceStatusProvider = inferenceStatusControllerProvider(
      id: id,
      aiResponseType: AiResponseType.imageAnalysis,
    );

    final inferenceStatusNotifier = ref.read(inferenceStatusProvider.notifier)
      ..setStatus(InferenceStatus.running);

    final capturedAt = entry.data.capturedAt.toIso8601String();
    await notifier.save();

    state = '';

    final prompt = '''
Describe the image from $capturedAt in detail, with particular focus on content,
and any relevant information that can be gathered from the image.
If the image is the screenshot of a website or app, then focus on the
content of the website, not the style of the website. Do not make up names.
        ''';

    final buffer = StringBuffer();
    final image = await getImage(entry);

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
        return;
      }

      final stream =
          ref.read(cloudInferenceRepositoryProvider).generateWithImages(
                prompt,
                model: model,
                temperature: temperature,
                images: [image],
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
        images: [image],
      );

      await for (final chunk in stream) {
        buffer.write(chunk.text);
        state = buffer.toString();
      }
    }

    inferenceStatusNotifier.setStatus(InferenceStatus.idle);

    final completeResponse = '''
```
Disclaimer: the image analysis was generated by $model and may contain inaccuracies or errors.
```


$state
    ''';

    await notifier.addTextToImage(completeResponse);
  }

  Future<String> getImage(JournalImage image) async {
    final fullPath = getFullImagePath(image);
    final bytes = await File(fullPath).readAsBytes();
    final base64String = base64Encode(bytes);

    return base64String;
  }
}
