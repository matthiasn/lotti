import 'dart:convert';

import 'package:lotti/features/ai/repository/transcription_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for handling Whisper-specific inference operations.
///
/// This repository handles audio transcription using a locally running
/// Whisper instance via JSON POST to `/v1/audio/transcriptions`.
class WhisperInferenceRepository extends TranscriptionRepository {
  WhisperInferenceRepository({super.httpClient});

  static const _providerName = 'WhisperInference';

  /// Transcribes audio using a locally running Whisper instance.
  ///
  /// Sends audio data as base64 in a JSON POST body (not multipart).
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    String? prompt,
    int? maxCompletionTokens,
    Duration? timeout,
  }) {
    if (model.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }

    return executeTranscription(
      providerName: _providerName,
      responseIdPrefix: 'whisper-',
      audioLengthForLog: audioBase64.length,
      timeout: timeout,
      sendRequest: (requestTimeout, timeoutErrorMessage) async {
        return httpClient
            .post(
          Uri.parse(baseUrl).resolve('/v1/audio/transcriptions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'audio': audioBase64,
          }),
        )
            .timeout(
          requestTimeout,
          onTimeout: () {
            throw TranscriptionException(
              timeoutErrorMessage,
              provider: _providerName,
              statusCode: httpStatusRequestTimeout,
            );
          },
        );
      },
    );
  }
}
