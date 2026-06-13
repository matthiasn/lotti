// Supertonic ONNX inference pipeline.
//
// Ported from Supertone's open-source Supertonic Flutter example (MIT) and
// adapted to load the model + config from a filesystem directory (the
// downloaded model dir) rather than the asset bundle. The deterministic,
// correctness-sensitive stages (text normalization, tokenization, WAV
// encoding) live in their own unit-tested modules; this file is the ONNX
// orchestration and runs only with the native runtime.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:lotti/features/tts/engine/ort_tensor_utils.dart';
import 'package:lotti/features/tts/engine/text_chunker.dart';
import 'package:lotti/features/tts/engine/unicode_processor.dart';
import 'package:lotti/features/tts/engine/voice_style_loader.dart';

/// Result of a synthesis: mono float PCM samples + total duration in seconds.
class SynthesisResult {
  const SynthesisResult(this.samples, this.durationSeconds);

  final List<double> samples;
  final double durationSeconds;
}

/// A loaded Supertonic model — the four ONNX sessions, the tokenizer, and the
/// config — ready to synthesize. Build via [loadSupertonicSession].
class SupertonicTtsSession {
  SupertonicTtsSession({
    required Map<String, dynamic> cfgs,
    required this.textProcessor,
    required this.durationPredictor,
    required this.textEncoder,
    required this.vectorEstimator,
    required this.vocoder,
  }) : sampleRate = (cfgs['ae'] as Map)['sample_rate'] as int,
       _baseChunkSize = (cfgs['ae'] as Map)['base_chunk_size'] as int,
       _chunkCompressFactor =
           (cfgs['ttl'] as Map)['chunk_compress_factor'] as int,
       _latentDim = (cfgs['ttl'] as Map)['latent_dim'] as int;

  final UnicodeProcessor textProcessor;
  final OrtSession durationPredictor;
  final OrtSession textEncoder;
  final OrtSession vectorEstimator;
  final OrtSession vocoder;

  final int sampleRate;
  final int _baseChunkSize;
  final int _chunkCompressFactor;
  final int _latentDim;

  /// Synthesizes [text] in [language], concatenating per-chunk audio with a
  /// short silence between chunks. [totalStep] is the denoising step count
  /// (quality vs speed); [speed] scales duration (1.0 = the model's natural
  /// timing — playback rate handles the user's speed preference).
  Future<SynthesisResult> synthesize({
    required String text,
    required String language,
    required VoiceStyle style,
    required int totalStep,
    double speed = 1.0,
    double silenceDuration = 0.3,
  }) async {
    final chunks = chunkText(text, maxLen: maxChunkLenForLang(language));
    if (chunks.isEmpty) return const SynthesisResult(<double>[], 0);

    final samples = <double>[];
    var totalDuration = 0.0;
    final silenceSamples = (silenceDuration * sampleRate).floor();

    for (var i = 0; i < chunks.length; i++) {
      final chunk = await _inferChunk(
        chunks[i],
        language,
        style,
        totalStep,
        speed,
      );
      if (i == 0) {
        samples.addAll(chunk.samples);
        totalDuration = chunk.durationSeconds;
      } else {
        samples
          ..addAll(List<double>.filled(silenceSamples, 0))
          ..addAll(chunk.samples);
        totalDuration += chunk.durationSeconds + silenceDuration;
      }
    }
    return SynthesisResult(samples, totalDuration);
  }

  Future<SynthesisResult> _inferChunk(
    String text,
    String language,
    VoiceStyle style,
    int totalStep,
    double speed,
  ) async {
    const bsz = 1;
    final tokenized = textProcessor.call([text], [language]);
    final textIds = tokenized.textIds;
    final textMask = tokenized.textMask;

    final textIdsShape = [bsz, textIds[0].length];
    final textMaskShape = [bsz, 1, textMask[0][0].length];
    final textMaskTensor = await floatTensor(textMask, textMaskShape);

    final dpResult = await durationPredictor.run({
      'text_ids': await intTensor(textIds, textIdsShape),
      'style_dp': style.dp,
      'text_mask': textMaskTensor,
    });
    final rawDuration = safeCast<double>(await dpResult.values.first.asList());
    final scaledDuration = rawDuration.map((d) => d / speed).toList();

    final textEncResult = await textEncoder.run({
      'text_ids': await intTensor(textIds, textIdsShape),
      'style_ttl': style.ttl,
      'text_mask': textMaskTensor,
    });

    final latent = _sampleNoisyLatent(scaledDuration);
    final noisyLatent = latent.values;
    final latentMask = latent.mask;
    final latentShape = [
      bsz,
      noisyLatent[0].length,
      noisyLatent[0][0].length,
    ];
    final latentMaskTensor = await floatTensor(latentMask, [
      bsz,
      1,
      latentMask[0][0].length,
    ]);
    final totalStepTensor = await scalarTensor([totalStep.toDouble()], [bsz]);

    for (var step = 0; step < totalStep; step++) {
      final result = await vectorEstimator.run({
        'noisy_latent': await floatTensor(noisyLatent, latentShape),
        'text_emb': textEncResult.values.first,
        'style_ttl': style.ttl,
        'text_mask': textMaskTensor,
        'latent_mask': latentMaskTensor,
        'total_step': totalStepTensor,
        'current_step': await scalarTensor([step.toDouble()], [bsz]),
      });
      final denoised = safeCast<double>(await result.values.first.asList());
      var idx = 0;
      for (var b = 0; b < noisyLatent.length; b++) {
        for (var d = 0; d < noisyLatent[b].length; d++) {
          for (var t = 0; t < noisyLatent[b][d].length; t++) {
            noisyLatent[b][d][t] = denoised[idx++];
          }
        }
      }
    }

    final vocoderResult = await vocoder.run({
      'latent': await floatTensor(noisyLatent, latentShape),
    });
    final wav = safeCast<double>(await vocoderResult.values.first.asList());
    return SynthesisResult(wav, scaledDuration.first);
  }

  ({List<List<List<double>>> values, List<List<List<double>>> mask})
  _sampleNoisyLatent(List<double> duration) {
    final wavLenMax = duration.reduce(math.max) * sampleRate;
    final wavLengths = duration.map((d) => (d * sampleRate).floor()).toList();
    final chunkSize = _baseChunkSize * _chunkCompressFactor;
    final latentLen = ((wavLenMax + chunkSize - 1) / chunkSize).floor();
    final latentDim = _latentDim * _chunkCompressFactor;

    final random = math.Random();
    final values = List.generate(
      duration.length,
      (_) => List.generate(
        latentDim,
        (_) => List.generate(latentLen, (_) {
          final u1 = math.max(1e-10, random.nextDouble());
          final u2 = random.nextDouble();
          return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
        }),
      ),
    );

    final mask = _latentMask(wavLengths);
    for (var b = 0; b < values.length; b++) {
      for (var d = 0; d < values[b].length; d++) {
        for (var t = 0; t < values[b][d].length; t++) {
          values[b][d][t] *= mask[b][0][t];
        }
      }
    }
    return (values: values, mask: mask);
  }

  List<List<List<double>>> _latentMask(List<int> wavLengths) {
    final latentSize = _baseChunkSize * _chunkCompressFactor;
    final latentLengths = wavLengths
        .map((len) => ((len + latentSize - 1) / latentSize).floor())
        .toList();
    final maxLen = latentLengths.reduce(math.max);
    return latentLengths
        .map(
          (len) => [
            List.generate(maxLen, (i) => i < len ? 1.0 : 0.0),
          ],
        )
        .toList();
  }

  Future<void> dispose() async {
    await durationPredictor.close();
    await textEncoder.close();
    await vectorEstimator.close();
    await vocoder.close();
  }
}

/// Loads a [SupertonicTtsSession] from a local model directory containing the
/// four `*.onnx` files plus `tts.json` and `unicode_indexer.json`.
Future<SupertonicTtsSession> loadSupertonicSession(String modelDir) async {
  final cfgs =
      jsonDecode(await File('$modelDir/tts.json').readAsString())
          as Map<String, dynamic>;
  final textProcessor = await UnicodeProcessor.load(
    '$modelDir/unicode_indexer.json',
  );

  final ort = OnnxRuntime();
  final sessions = await Future.wait([
    ort.createSession('$modelDir/duration_predictor.onnx'),
    ort.createSession('$modelDir/text_encoder.onnx'),
    ort.createSession('$modelDir/vector_estimator.onnx'),
    ort.createSession('$modelDir/vocoder.onnx'),
  ]);

  return SupertonicTtsSession(
    cfgs: cfgs,
    textProcessor: textProcessor,
    durationPredictor: sessions[0],
    textEncoder: sessions[1],
    vectorEstimator: sessions[2],
    vocoder: sessions[3],
  );
}
