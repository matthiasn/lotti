import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/transcription_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for oMLX speech-to-text models served through the local
/// OpenAI-compatible API.
///
/// oMLX itself is a localhost provider, but deployments can still require a
/// bearer token. The configured provider base URL is therefore used for the
/// endpoint and the saved API key is forwarded when transcribing.
class OmlxTranscriptionRepository extends TranscriptionRepository {
  OmlxTranscriptionRepository({super.httpClient});

  static const _providerName = 'OmlxTranscription';

  /// Heuristic for routing oMLX speech-to-text models to
  /// `/audio/transcriptions` instead of chat completions.
  ///
  /// The caller also gates on `InferenceProviderType.omlx`, so this can stay
  /// intentionally broad without affecting MLX Audio, Whisper, or cloud
  /// providers.
  static bool isOmlxTranscriptionModel(String model) {
    final normalized = model.toLowerCase();
    return normalized.contains('whisper') ||
        normalized.contains('transcribe') ||
        normalized.contains('transcription') ||
        normalized.contains('asr') ||
        normalized.contains('stt');
  }

  /// Transcribes audio through oMLX's OpenAI-compatible
  /// `/audio/transcriptions` endpoint.
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    String? prompt,
    String responseFormat = 'json',
    Duration? timeout,
  }) {
    final normalizedBaseUrl = baseUrl.trim();
    final normalizedApiKey = apiKey.trim();
    if (model.trim().isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (audioBase64.isEmpty) {
      throw ArgumentError('Audio data cannot be empty');
    }
    if (normalizedBaseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }
    if (normalizedApiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    return executeTranscription(
      providerName: _providerName,
      responseIdPrefix: 'omlx-transcription-',
      audioLengthForLog: audioBase64.length,
      timeout: timeout,
      sendRequest: (requestTimeout, timeoutErrorMessage) async {
        final request =
            http.MultipartRequest(
                'POST',
                _buildEndpointUri(normalizedBaseUrl, 'audio/transcriptions'),
              )
              ..headers['Authorization'] = 'Bearer $normalizedApiKey'
              ..files.add(
                http.MultipartFile.fromBytes(
                  'file',
                  base64Decode(audioBase64),
                  filename: 'audio.m4a',
                ),
              )
              ..fields['model'] = model
              ..fields['response_format'] = responseFormat;

        if (prompt != null && prompt.trim().isNotEmpty) {
          request.fields['prompt'] = prompt.trim();
        }

        final streamedResponse = await httpClient
            .send(request)
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

        return http.Response.fromStream(streamedResponse);
      },
    );
  }

  static Uri _buildEndpointUri(String baseUrl, String endpointPath) {
    final baseUri = Uri.parse(baseUrl.trim());
    final basePath = baseUri.path.replaceAll(RegExp(r'/+$'), '');
    final normalizedEndpoint = endpointPath.replaceAll(RegExp('^/+'), '');

    return baseUri.replace(path: '$basePath/$normalizedEndpoint');
  }
}
