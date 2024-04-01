import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
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
    eventChannel.receiveBroadcastStream().listen(
          _onEvent,
          onError: _onError,
        );
  }

  final progressMap = <String, String>{};
  final progressController = StreamController<String>.broadcast();

  void _onEvent(Object? event) {
    if (event != null && event is List<dynamic>) {
      if (event.length == 2) {
        final [text, pipelineStart] = event.cast<String>();

        if (pipelineStart.isEmpty) {
          progressController.add(text);
        } else {
          final cleaned = text.replaceAll(RegExp('<.*?>+'), '');
          progressMap[pipelineStart] = cleaned;
          _publishProgress();
        }
      }
    }
  }

  void _publishProgress() {
    final text = progressMap.entries
        .sorted((e1, e2) => e1.key.compareTo(e2.key))
        .map((e) => e.value)
        .join();
    progressController.add(text);
  }

  void _onError(Object error) {
    debugPrint(error.toString());
    captureException(
      error,
      subdomain: 'Progress Channel',
    );
  }

  Future<void> _start() async {
    while (queue.isNotEmpty) {
      progressMap.clear();
      await _transcribe(entry: queue.removeFirst());
    }
  }

  Future<void> _loadSelectedModel() async {
    final selectedModel = await getIt<SettingsDb>().itemByKey(whisperModelKey);

    if (selectedModel != null) {
      model = selectedModel;
    }
  }

  static const MethodChannel methodChannel = MethodChannel('lotti/transcribe');
  static const EventChannel eventChannel =
      EventChannel('lotti/transcribe-progress');

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
        final result = await methodChannel.invokeMethod(
          'transcribe',
          {
            'audioFilePath': wavPath,
            'modelPath': modelPath,
          },
        );
        final finish = DateTime.now();

        if (result != null && result is List<dynamic>) {
          if (result.length == 3) {
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

            progressController.add('ASR_COMPLETED');
          } else {
            captureException(
              result,
              subdomain: 'Parse response length',
            );
          }
        }
      } on PlatformException catch (e) {
        captureException(e);
      }
    } else if (ReturnCode.isCancel(returnCode)) {
      captureException(
        returnCode,
        subdomain: 'FFmpegKit cancelled',
      );
    } else {
      captureException(
        returnCode,
        subdomain: 'FFmpegKit error',
      );
    }
    running = false;
  }

  Future<void> enqueue({required JournalAudio entry}) async {
    queue.add(entry);
    if (!running) {
      unawaited(_start());
    }
  }

  void captureException(
    dynamic exception, {
    String subdomain = 'transcribe',
  }) {
    getIt<LoggingDb>().captureException(
      exception,
      domain: 'ASR',
      subDomain: subdomain,
    );
  }
}
