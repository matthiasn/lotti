import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';

class AsrService {
  AsrService() {
    _loadSelectedModel();
    eventChannel.receiveBroadcastStream().listen(
          _onEvent,
          onError: _onError,
        );
  }

  final progressMap = <String, String>{};
  final progressController =
      StreamController<(String, TranscriptionStatus)>.broadcast();

  void _onEvent(Object? event) {
    if (event != null && event is List<dynamic>) {
      if (event.length == 2) {
        final [text, pipelineStart] = event.cast<String>();

        if (pipelineStart.isEmpty) {
          progressController.add((text, TranscriptionStatus.initializing));
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
    progressController.add((text, TranscriptionStatus.inProgress));
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

  String model = 'small';
  final queue = Queue<JournalAudio>();
  bool running = false;

  Future<void> _transcribe({required JournalAudio entry}) async {
    running = true;
    final audioFilePath = await AudioUtils.getFullAudioPath(entry);
    final audioFileExists = File(audioFilePath).existsSync();

    if (!audioFileExists) {
      await Future<void>.delayed(const Duration(seconds: 1));
      progressController.add(
        ('File does not exist.', TranscriptionStatus.error),
      );
      running = false;
      return;
    }

    getIt<LoggingService>().captureEvent(
      'transcribing $audioFilePath',
      domain: 'ASR',
      subDomain: 'transcribe',
    );

    final start = DateTime.now();

    try {
      final result = await methodChannel.invokeMethod(
        'transcribe',
        {
          'audioFilePath': audioFilePath,
          'model': model,
          'language': entry.data.language ?? '',
        },
      );
      final finish = DateTime.now();

      if (result != null && result is List<dynamic>) {
        if (result.length == 3) {
          final [language, model, text] = result.cast<String?>();

          if (text == null) {
            return;
          }

          final transcript = AudioTranscript(
            created: DateTime.now(),
            library: 'WhisperKit',
            model: model ?? '-',
            detectedLanguage: language ?? '-',
            transcript: text.trim(),
            processingTime: finish.difference(start),
          );

          await SpeechRepository.addAudioTranscript(
            journalEntityId: entry.meta.id,
            transcript: transcript,
          );

          progressController.add((text, TranscriptionStatus.done));
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

    running = false;
  }

  Future<bool> enqueue({required JournalAudio entry}) async {
    final isQueueEmpty = queue.isEmpty;
    queue.add(entry);
    if (!running) {
      unawaited(_start());
    }
    return isQueueEmpty;
  }

  void captureException(
    dynamic exception, {
    String subdomain = 'transcribe',
  }) {
    getIt<LoggingService>().captureException(
      exception,
      domain: 'ASR',
      subDomain: subdomain,
    );
  }
}

enum TranscriptionStatus {
  initializing,
  inProgress,
  done,
  error,
}
