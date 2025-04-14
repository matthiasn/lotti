import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_transcription.g.dart';

@riverpod
class AiAudioTranscriptionController extends _$AiAudioTranscriptionController {
  @override
  String build({
    required String id,
  }) {
    ref.cacheFor(entryCacheDuration);
    return '';
  }

  Future<void> transcribeAudio() async {
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

    await notifier.save();

    state = '';

    const prompt = '''
Transcribe the audio file accurately and fully, no summarization, and not 
adding any additional information.
        ''';

    final buffer = StringBuffer();
    final audioBase64 = await getAudio(entry);

//    const model = 'google/gemini-2.0-flash-001';
    const model = 'openai/gpt-4o-2024-11-20';
    // const model = 'meta-llama/llama-4-maverick';

    const temperature = 0.6;

    final config = await ref.read(cloudInferenceRepositoryProvider).getConfig();

    final stream = ref.read(cloudInferenceRepositoryProvider).generateWithAudio(
          prompt,
          model: model,
          temperature: temperature,
          audioBase64: audioBase64,
          config: config,
        );

    await for (final chunk in stream) {
      buffer.write(chunk.choices[0].delta.content);
      print(chunk.choices[0].delta.content);
      state = buffer.toString();
    }

    inferenceStatusNotifier.setStatus(InferenceStatus.idle);

    final completeResponse = '''
$state
    ''';

    await notifier.addTextToImage(completeResponse);
  }

  Future<String> getAudio(JournalAudio audio) async {
    final fullPath = await AudioUtils.getFullAudioPath(audio);
    final bytes = await File(fullPath.replaceFirst('m4a', 'wav')).readAsBytes();
    final base64String = base64Encode(bytes);
    print('base64String: $base64String');

    return base64String;
  }
}
