import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:lotti/features/ai/speech/sherpa_worker.dart';
import 'package:lotti/features/ai/util/audio_converter_channel.dart';
import 'package:uuid/uuid.dart';

/// Adapts embedded recognition to the same stream used by HTTP transcription.
/// Audio stays on this device; a missing model fails without downloading or
/// selecting another provider. The archived recording is never modified.
class SherpaTranscriptionRepository {
  SherpaTranscriptionRepository({
    required this.models,
    this.decode = runSherpaWorker,
    this.convert = convertM4aBytesToTemporaryWav,
    Directory? temporaryDirectory,
  }) : temporaryDirectory = temporaryDirectory ?? Directory.systemTemp;

  final SherpaModelRepository models;
  final Stream<String> Function(SherpaWorkerRequest) decode;
  final Future<Uint8List> Function(Uint8List) convert;
  final Directory temporaryDirectory;

  Stream<LottiInferenceChunk> transcribeAudio({
    required String model,
    required String audioBase64,
  }) async* {
    if (!await models.isInstalled(model)) {
      throw TranscriptionException(
        'Download this speech model on this device before transcribing.',
        provider: 'sherpa-onnx',
      );
    }
    final bytes = base64Decode(audioBase64);
    if (bytes.isEmpty) {
      throw const FormatException('Audio data cannot be empty');
    }
    final isWav =
        bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WAVE';
    final wav = isWav ? bytes : await convert(bytes);
    final scratch = await temporaryDirectory.createTemp('lotti_sherpa_');
    try {
      final file = File('${scratch.path}/audio.wav');
      await file.writeAsBytes(wav, flush: true);
      final id = 'sherpa-${const Uuid().v4()}';
      var hasText = false;
      await for (final text in decode(
        SherpaWorkerRequest(
          wavPath: file.path,
          modelDirectory: await models.modelDirectory(model),
          modelId: model,
        ),
      )) {
        if (text.trim().isEmpty) continue;
        yield LottiInferenceChunk(
          id: id,
          created: 0,
          model: model,
          choices: [
            LottiChunkChoice(
              index: 0,
              delta: LottiDelta(content: '${hasText ? ' ' : ''}${text.trim()}'),
            ),
          ],
        );
        hasText = true;
      }
      if (!hasText) {
        throw TranscriptionException(
          'No speech was recognized in this recording.',
          provider: 'sherpa-onnx',
        );
      }
    } finally {
      await scratch.delete(recursive: true);
    }
  }
}

final sherpaTranscriptionRepositoryProvider =
    Provider<SherpaTranscriptionRepository>((ref) {
      return SherpaTranscriptionRepository(
        models: ref.watch(sherpaModelRepositoryProvider),
      );
    });
