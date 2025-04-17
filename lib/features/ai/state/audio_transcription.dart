import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/repository/gemini_cloud_inference_repository.dart';
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
  String build({
    required String id,
  }) {
    ref.cacheFor(entryCacheDuration);
    return '';
  }

  Future<void> transcribeAudioStream() async {
    await ref.read(geminiCloudInferenceRepositoryProvider).init();
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
Transcribe the attached audio exactly as it was recorded. Make sure to properly
separate words.
        ''';

    final buffer = StringBuffer();
    final base64 = await getAudioBase64(entry);
    const model = 'models/gemini-2.0-flash';
    //const model = 'models/gemini-2.5-pro-preview-03-25';

    final stream =
        ref.read(geminiCloudInferenceRepositoryProvider).transcribeAudioStream(
              prompt: prompt,
              model: model,
              audioBase64: base64,
            );

    await for (final candidates in stream) {
      final output = candidates?.output;

      if (output != null) {
        buffer.write(output);
        state = buffer.toString();
      }
    }

    state = state.replaceAll('  ', ' ');

    inferenceStatusNotifier.setStatus(InferenceStatus.idle);
    await notifier.addTextToAudio(state);
  }

  Future<void> transcribeAudio() async {
    await ref.read(geminiCloudInferenceRepositoryProvider).init();
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
Transcribe the attached audio as it was recorded. Only remove filler words.
        ''';

    final base64 = await getAudioBase64(entry);
    const model = 'models/gemini-2.0-flash';

    final candidates =
        await ref.read(geminiCloudInferenceRepositoryProvider).transcribeAudio(
              prompt: prompt,
              model: model,
              audioBase64: base64,
            );

    state = candidates?.output ?? '';
    inferenceStatusNotifier.setStatus(InferenceStatus.idle);
    await notifier.addTextToAudio(state);
  }

  Future<String> getAudioBase64(JournalAudio audio) async {
    final fullPath = await AudioUtils.getFullAudioPath(audio);
    final bytes = await File(fullPath).readAsBytes();
    final base64String = base64Encode(bytes);
    return base64String;
  }
}
