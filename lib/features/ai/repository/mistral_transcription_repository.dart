import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/transcription_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for handling Mistral transcription via the dedicated
/// `/v1/audio/transcriptions` endpoint.
///
/// Mistral's Voxtral Transcribe 2 (released 2026-02-04) supports M4A, MP3,
/// WAV, FLAC, and OGG up to 1 GB / 3 hours per request via multipart/form-data.
/// This avoids the chat completions endpoint which doesn't accept M4A audio.
class MistralTranscriptionRepository extends TranscriptionRepository {
  MistralTranscriptionRepository({super.httpClient});

  static const _providerName = 'MistralTranscription';

  /// Checks if a model is a Mistral transcription model that requires
  /// the `/v1/audio/transcriptions` endpoint instead of chat completions.
  ///
  /// Uses a `voxtral-` prefix check. This is safe because the caller in
  /// `CloudInferenceRepository` also gates on `InferenceProviderType.mistral`,
  /// so local Voxtral models (which use a different provider type) won't match.
  static bool isMistralTranscriptionModel(String model) {
    return model.startsWith('voxtral-');
  }

  /// Transcribes audio using Mistral's transcription API.
  ///
  /// Sends audio data to Mistral's `/v1/audio/transcriptions` endpoint
  /// using multipart/form-data format.
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    String? prompt,
    Duration? timeout,
  }) {
    if (model.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (audioBase64.isEmpty) {
      throw ArgumentError('Audio data cannot be empty');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }
    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    return executeTranscription(
      providerName: _providerName,
      responseIdPrefix: 'mistral-transcription-',
      audioLengthForLog: audioBase64.length,
      timeout: timeout,
      sendRequest: (requestTimeout, timeoutErrorMessage) async {
        final audioBytes = base64Decode(audioBase64);

        // Build the transcription endpoint URL from the base URL.
        // baseUrl typically ends with '/v1', so we append '/audio/transcriptions'.
        final baseUri = Uri.parse(baseUrl);
        final transcriptionPath = '${baseUri.path}'
            "${baseUri.path.endsWith('/') ? '' : '/'}"
            'audio/transcriptions';
        final uri = baseUri.replace(path: transcriptionPath);

        final request = http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $apiKey'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              audioBytes,
              filename: 'audio.m4a',
            ),
          )
          ..fields['model'] = model;

        if (prompt != null && prompt.isNotEmpty) {
          request.fields['prompt'] = prompt;
        }

        final streamedResponse = await httpClient.send(request).timeout(
          requestTimeout,
          onTimeout: () {
            throw TranscriptionException(
              timeoutErrorMessage,
              provider: _providerName,
              statusCode: httpStatusRequestTimeout,
            );
          },
        );

        return http.Response.fromStream(streamedResponse);
      },
    );
  }
}
