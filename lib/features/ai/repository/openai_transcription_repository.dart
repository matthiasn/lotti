import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/transcription_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for handling OpenAI transcription via the dedicated
/// `/v1/audio/transcriptions` endpoint.
///
/// OpenAI's gpt-4o-transcribe and gpt-4o-mini-transcribe models require
/// the transcription endpoint with multipart/form-data, not chat completions.
class OpenAiTranscriptionRepository extends TranscriptionRepository {
  OpenAiTranscriptionRepository({super.httpClient});

  static const _providerName = 'OpenAiTranscription';

  /// Checks if a model is an OpenAI transcription model that requires
  /// the transcriptions endpoint instead of chat completions.
  ///
  /// Supports exact model names and date/version snapshot aliases:
  /// - gpt-4o-mini-transcribe, gpt-4o-mini-transcribe-2025-01-15, etc.
  /// - gpt-4o-transcribe, gpt-4o-transcribe-2025-01-15, etc.
  /// - gpt-4o-transcribe-diarize (speaker diarization model)
  static bool isOpenAiTranscriptionModel(String model) {
    return model.startsWith('gpt-4o-mini-transcribe') ||
        model.startsWith('gpt-4o-transcribe-diarize') ||
        model.startsWith('gpt-4o-transcribe');
  }

  /// Transcribes audio using OpenAI's transcription API.
  ///
  /// Sends audio data to OpenAI's `/v1/audio/transcriptions`
  /// endpoint using multipart/form-data format.
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
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
    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    return executeTranscription(
      providerName: _providerName,
      responseIdPrefix: 'openai-transcription-',
      audioLengthForLog: audioBase64.length,
      timeout: timeout,
      sendRequest: (requestTimeout, timeoutErrorMessage) async {
        final audioBytes = base64Decode(audioBase64);
        final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
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
