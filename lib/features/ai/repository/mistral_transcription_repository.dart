import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/transcription_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Repository for handling Mistral transcription via the dedicated
/// `/v1/audio/transcriptions` endpoint.
///
/// Mistral's Voxtral Transcribe 2 (released 2026-02-04) supports M4A, MP3,
/// WAV, FLAC, and OGG up to 1 GB / 3 hours per request via multipart/form-data.
/// This avoids the chat completions endpoint which doesn't accept M4A audio.
///
/// Diarization is always enabled (`diarize=true`), providing speaker
/// attribution in the response segments. When multiple speakers are detected,
/// the transcription is formatted with `[Speaker N]` labels.
class MistralTranscriptionRepository extends TranscriptionRepository {
  MistralTranscriptionRepository({super.httpClient});

  static const _providerName = 'MistralTranscription';
  static const _uuid = Uuid();

  /// Checks if a model is a Mistral transcription model that requires
  /// the `/v1/audio/transcriptions` endpoint instead of chat completions.
  ///
  /// Uses a `voxtral-` prefix check. This is safe because the caller in
  /// `CloudInferenceRepository` also gates on `InferenceProviderType.mistral`,
  /// so local Voxtral models (which use a different provider type) won't match.
  static bool isMistralTranscriptionModel(String model) {
    return model.startsWith('voxtral-');
  }

  /// Transcribes audio using Mistral's transcription API with diarization.
  ///
  /// Sends audio data to Mistral's `/v1/audio/transcriptions` endpoint
  /// using multipart/form-data format with `diarize=true` enabled.
  /// When multiple speakers are detected, the response is formatted with
  /// speaker labels (e.g., `[Speaker 1]`, `[Speaker 2]`).
  ///
  /// [contextBias] is a list of words/phrases (up to 100) that the model
  /// should pay special attention to. Sent as comma-separated single-word
  /// terms in the `context_bias` multipart form field.
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    List<String>? contextBias,
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

    final requestTimeout =
        timeout ?? const Duration(seconds: whisperTranscriptionTimeoutSeconds);
    final timeoutDisplay = _formatTimeout(requestTimeout);
    final timeoutErrorMessage = 'Transcription request timed out after '
        '$timeoutDisplay. '
        'This can happen with very long audio files or slow processing. '
        'Please try with a shorter recording.';

    return Stream.fromFuture(
      () async {
        try {
          developer.log(
            'Sending audio transcription request to $_providerName - '
            'audioLength: ${audioBase64.length}, timeout: $timeoutDisplay',
            name: _providerName,
          );

          final audioBytes = base64Decode(audioBase64);

          // Build the transcription endpoint URL from the base URL.
          // Ensures that 'audio/transcriptions' is correctly appended.
          final baseUri = Uri.parse(
            baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
          );
          final uri = baseUri.resolve('audio/transcriptions');

          final request = http.MultipartRequest('POST', uri)
            ..headers['Authorization'] = 'Bearer $apiKey'
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                audioBytes,
                filename: 'audio.m4a',
              ),
            )
            ..fields['model'] = model
            ..fields['diarize'] = 'true'
            // Mistral requires timestamp_granularities=['segment'] when
            // diarize is enabled.
            ..fields['timestamp_granularities'] = 'segment';

          if (contextBias != null && contextBias.isNotEmpty) {
            // Mistral requires each context_bias term to be a single word
            // (pattern: ^[^,\s]+$). Split multi-word terms and deduplicate.
            // Sent as comma-separated values — Mistral's multipart form
            // parser splits on commas to build the array.
            final singleWordTerms = contextBias
                .expand((term) => term.split(RegExp(r'\s+')))
                .where((word) => word.isNotEmpty)
                .toSet()
                .toList();
            if (singleWordTerms.isNotEmpty) {
              request.fields['context_bias'] = singleWordTerms.join(',');
            }
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

          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode != 200) {
            developer.log(
              'Failed to transcribe audio: HTTP ${response.statusCode}',
              name: _providerName,
              error: response.body,
            );
            throw TranscriptionException(
              _parseErrorMessage(response),
              provider: _providerName,
              statusCode: response.statusCode,
            );
          }

          final result = jsonDecode(response.body) as Map<String, dynamic>;

          // Log response structure for diarization diagnostics
          final segments = result['segments'] as List<dynamic>?;
          final segmentCount = segments?.length ?? 0;
          final speakerKeys = segments
                  ?.where(
                    (s) =>
                        s is Map<String, dynamic> &&
                        s.containsKey('speaker_id'),
                  )
                  .length ??
              0;
          final uniqueSpeakers = segments
                  ?.where(
                    (s) =>
                        s is Map<String, dynamic> &&
                        s.containsKey('speaker_id'),
                  )
                  .map((s) => (s as Map<String, dynamic>)['speaker_id'])
                  .toSet()
                  .length ??
              0;
          developer.log(
            'Response keys: ${result.keys.toList()}, '
            'segments: $segmentCount, '
            'withSpeaker: $speakerKeys, '
            'uniqueSpeakers: $uniqueSpeakers',
            name: _providerName,
          );
          if (segments != null && segments.isNotEmpty) {
            developer.log(
              'First segment keys: '
              '${(segments.first as Map<String, dynamic>).keys.toList()}',
              name: _providerName,
            );
          }

          if (!result.containsKey('text')) {
            developer.log(
              'Invalid response from $_providerName: missing text field',
              name: _providerName,
              error: result,
            );
            throw TranscriptionException(
              'Invalid response from transcription service: '
              'missing text field',
              provider: _providerName,
            );
          }

          final text = _extractText(result);

          developer.log(
            'Successfully transcribed audio - '
            'transcriptionLength: ${text.length}',
            name: _providerName,
          );

          return CreateChatCompletionStreamResponse(
            id: 'mistral-transcription-${_uuid.v4()}',
            choices: [
              ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: text,
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: 0,
          );
        } on TranscriptionException {
          rethrow;
        } on TimeoutException catch (e) {
          developer.log(
            'Transcription request timed out',
            name: _providerName,
            error: e,
          );
          throw TranscriptionException(
            timeoutErrorMessage,
            provider: _providerName,
            statusCode: httpStatusRequestTimeout,
            originalError: e,
          );
        } on FormatException catch (e) {
          developer.log(
            'Failed to parse response from $_providerName',
            name: _providerName,
            error: e,
          );
          throw TranscriptionException(
            'Invalid response format from transcription service',
            provider: _providerName,
            originalError: e,
          );
        } catch (e) {
          developer.log(
            'Unexpected error during audio transcription',
            name: _providerName,
            error: e,
          );
          throw TranscriptionException(
            'Failed to transcribe audio: $e',
            provider: _providerName,
            originalError: e,
          );
        }
      }(),
    ).asBroadcastStream();
  }

  /// Extracts text from the response, formatting diarized segments
  /// with speaker labels when multiple speakers are detected.
  ///
  /// Falls back to the plain `text` field when segments are absent,
  /// lack speaker info, or contain only a single speaker.
  static String _extractText(Map<String, dynamic> result) {
    final text = result['text'] as String;
    final segments = result['segments'] as List<dynamic>?;

    if (segments == null || segments.isEmpty) {
      return text;
    }

    // All segments must have speaker info for diarization formatting.
    // Mistral uses 'speaker_id' as the key name.
    final hasSpeakerInfo = segments.every(
      (s) => s is Map<String, dynamic> && s.containsKey('speaker_id'),
    );
    if (!hasSpeakerInfo) {
      return text;
    }

    // Only format with speaker labels when multiple speakers are present
    final speakers =
        segments.map((s) => (s as Map<String, dynamic>)['speaker_id']).toSet();
    if (speakers.length <= 1) {
      return text;
    }

    return _formatDiarizedSegments(segments);
  }

  /// Formats diarized segments as speaker-attributed paragraphs.
  ///
  /// Groups consecutive segments from the same speaker and formats as:
  /// ```text
  /// [Speaker 1]
  /// First speaker's text here.
  ///
  /// [Speaker 2]
  /// Second speaker's text here.
  /// ```
  ///
  /// Assigns 1-based display numbers in order of first appearance.
  static String _formatDiarizedSegments(List<dynamic> segments) {
    final buffer = StringBuffer();
    String? currentSpeaker;
    // Map raw speaker IDs to 1-based display numbers in appearance order.
    final speakerDisplayNumbers = <String, int>{};

    for (final segment in segments) {
      final map = segment as Map<String, dynamic>;
      final speaker = '${map['speaker_id']}';
      final segmentText = (map['text'] as String).trim();

      if (segmentText.isEmpty) continue;

      speakerDisplayNumbers.putIfAbsent(
        speaker,
        () => speakerDisplayNumbers.length + 1,
      );

      if (speaker != currentSpeaker) {
        if (currentSpeaker != null) {
          buffer
            ..writeln()
            ..writeln();
        }
        buffer.writeln('[Speaker ${speakerDisplayNumbers[speaker]}]');
        currentSpeaker = speaker;
      } else {
        buffer.write(' ');
      }

      buffer.write(segmentText);
    }

    return buffer.toString();
  }

  /// Builds a human-readable timeout duration string.
  static String _formatTimeout(Duration timeout) {
    if (timeout.inMinutes == 0) {
      final seconds = timeout.inSeconds;
      return seconds == 1 ? '1 second' : '$seconds seconds';
    }
    final minutes = timeout.inMinutes;
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }

  /// Attempts to extract a structured error message from an HTTP response.
  static String _parseErrorMessage(http.Response response) {
    final fallback = 'Failed to transcribe audio (HTTP ${response.statusCode})';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['error'] != null) {
        final error = json['error'] as Map<String, dynamic>;
        return error['message'] as String? ?? fallback;
      }
    } catch (_) {
      // Response body is not JSON — use fallback
    }
    return fallback;
  }
}
