import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/repository/cloud_inference_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_transcription.g.dart';

@riverpod
class AudioTranscriptionController extends _$AudioTranscriptionController {
  @override
  String build({required String id}) {
    ref.cacheFor(entryCacheDuration);
    return '';
  }

  Future<void> transcribeAudioStream() async {
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
    final start = DateTime.now();

    await notifier.save();

    state = '';

    const prompt = '''
Transcribe the attached audio exactly as it was recorded. Make sure to properly
separate words. Remove filler words and word repetitions.
        ''';

    final buffer = StringBuffer();
    final base64 = await getAudioBase64(entry);
    const model = 'models/gemini-2.5-flash-preview-04-17';

    final config =
        await ref.read(cloudInferenceConfigRepositoryProvider).getConfig();

    final stream = ref.read(cloudInferenceRepositoryProvider).generateWithAudio(
          prompt,
          model: model,
          audioBase64: base64,
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
          apiKey: config.geminiApiKey,
        );

    await for (final chunk in stream) {
      buffer.write(chunk.choices[0].delta.content);
      state = buffer.toString();
    }

    state = state.replaceAll('  ', ' ');
    inferenceStatusNotifier.setStatus(InferenceStatus.idle);
    final finish = DateTime.now();
    final text = state.trim();

    final transcript = AudioTranscript(
      created: DateTime.now(),
      library: 'Google Gemini',
      model: model,
      detectedLanguage: '-',
      transcript: text,
      processingTime: finish.difference(start),
    );
    await notifier.addTextToAudio(transcript: transcript);
  }

  Future<String> getAudioBase64(JournalAudio audio) async {
    final fullPath = await AudioUtils.getFullAudioPath(audio);
    final bytes = await File(fullPath).readAsBytes();
    final base64String = base64Encode(bytes);
    return base64String;
  }
}
