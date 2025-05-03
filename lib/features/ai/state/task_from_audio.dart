import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_from_audio.g.dart';

@riverpod
class TaskFromAudioController extends _$TaskFromAudioController {
  @override
  String build({required String id}) {
    ref.cacheFor(entryCacheDuration);
    return '';
  }

  Future<void> transcribeAudioStream() async {
    try {
      final provider = entryControllerProvider(id: id);
      final notifier = ref.read(provider.notifier);
      final entry = ref.watch(provider).value?.entry;

      if (entry is! JournalAudio) {
        return;
      }

      final inferenceStatusProvider = inferenceStatusControllerProvider(
        id: id,
        aiResponseType: audioTranscription,
      );

      final inferenceStatusNotifier = ref.read(inferenceStatusProvider.notifier)
        ..setStatus(InferenceStatus.running);

      state = '';

      const prompt = '''
Create a task from the attached audio, including action items, a summary, and a 
time estimate. Look for an estimate given in the audio, otherwise make an
educated guess. Assume that action items mentioned are not completed, unless
they are explicitly mentioned as completed in the audio. Use a status of 
"GROOMED" for the task unless specifically mentioned otherwise. Other task 
statuses are "OPEN", "IN PROGRESS", "BLOCKED", "ON HOLD", "DONE", "REJECTED".

Output should be in JSON format, adhering to the following structure:

```json
{
  "title": "Task Title",
  "status": "GROOMED",
  "actionItems": [
    {
      "title": "Action Item 1",
      "completed": false
    },
    {
      "title": "Action Item 2",
      "completed": true
    }
  ],
  "summary": "Task Summary",
  "estimate": "PT1H30M"
}
```
        ''';

      final buffer = StringBuffer();
      final base64 = await getAudioBase64(entry);
      const model = 'models/gemini-2.5-pro-preview-03-25';

      final configs =
          await ref.read(aiConfigRepositoryProvider).getConfigsByType('apiKey');
      final apiKeyConfig = configs
          .whereType<AiConfigInferenceProvider>()
          .where(
            (config) =>
                config.inferenceProviderType == InferenceProviderType.gemini,
          )
          .firstOrNull;

      if (apiKeyConfig == null) {
        state = 'No Gemini API key found';
        return;
      }

      final stream =
          ref.read(cloudInferenceRepositoryProvider).generateWithAudio(
                prompt,
                model: model,
                audioBase64: base64,
                baseUrl: apiKeyConfig.baseUrl,
                apiKey: apiKeyConfig.apiKey,
              );

      await for (final chunk in stream) {
        buffer.write(chunk.choices[0].delta.content);
        state = buffer.toString();
      }

      state = state.replaceAll('  ', ' ');
      inferenceStatusNotifier.setStatus(InferenceStatus.idle);
      final text = state.trim();
      print(text);
    } on OpenAIClientException catch (e) {
      state = 'Error: ${e.body}';
    } catch (e) {
      state = 'Error: $e';
    }
  }

  Future<String> getAudioBase64(JournalAudio audio) async {
    final fullPath = await AudioUtils.getFullAudioPath(audio);
    final bytes = await File(fullPath).readAsBytes();
    final base64String = base64Encode(bytes);
    return base64String;
  }
}
