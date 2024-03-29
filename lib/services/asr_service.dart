import 'dart:async';
import 'dart:collection';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AsrService {
  AsrService() {
    _loadSelectedModel();
  }

  Future<void> _start() async {
    while (queue.isNotEmpty) {
      await _transcribe(entry: queue.removeFirst());
    }
  }

  Future<void> _loadSelectedModel() async {
    final selectedModel = await getIt<SettingsDb>().itemByKey(whisperModelKey);

    if (selectedModel != null) {
      model = selectedModel;
    }
  }

  static const platform = MethodChannel('lotti/transcribe');
  String model = 'base';
  final queue = Queue<JournalAudio>();
  bool running = false;

  Future<void> _transcribe({required JournalAudio entry}) async {
    running = true;
    final audioFilePath = await AudioUtils.getFullAudioPath(entry);

    getIt<LoggingDb>().captureEvent(
      'transcribing $audioFilePath',
      domain: 'ASR',
      subDomain: 'transcribe',
    );

    final start = DateTime.now();
    final docDir = await getApplicationDocumentsDirectory();
    final modelFile = 'ggml-$model.bin';
    final modelPath = p.join(docDir.path, 'whisper', modelFile);

    final wavPath = audioFilePath.replaceAll('.aac', '.wav');
    final session = await FFmpegKit.execute(
      '-i $audioFilePath -y -ar 16000 -ac 1 -c:a pcm_s16le $wavPath',
    );

    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      try {
        final result = await platform.invokeMethod(
          'transcribe',
          {
            'audioFilePath': wavPath,
            'modelPath': modelPath,
          },
        );
        final finish = DateTime.now();

        if (result != null) {
          if (result is List<dynamic>) {
            final [language, model, text] = result.cast<String>();
            final transcript = AudioTranscript(
              created: DateTime.now(),
              library: 'WhisperKit',
              model: model,
              detectedLanguage: language,
              transcript: text.trim(),
              processingTime: finish.difference(start),
            );

            await getIt<PersistenceLogic>().addAudioTranscript(
              journalEntityId: entry.meta.id,
              transcript: transcript,
            );
          }
        }
      } on PlatformException catch (e) {
        debugPrint('transcribe exception: $e');
      }
    } else if (ReturnCode.isCancel(returnCode)) {
      debugPrint('FFmpegKit cancelled');
    } else {
      debugPrint('FFmpegKit errored');
    }
    running = false;
  }

  Future<void> enqueue({required JournalAudio entry}) async {
    queue.add(entry);
    if (!running) {
      unawaited(_start());
    }
  }
}
