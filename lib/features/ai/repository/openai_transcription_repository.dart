import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for handling OpenAI transcription-specific inference operations.
///
/// OpenAI's gpt-4o-transcribe and gpt-4o-mini-transcribe models require
/// the `/v1/audio/transcriptions` endpoint with multipart/form-data format,
/// not the chat completions endpoint.
/// Detected audio format with extension and MIME type
class AudioFormat {
  const AudioFormat({
    required this.extension,
    required this.mimeType,
  });

  final String extension;
  final String mimeType;

  static const wav = AudioFormat(extension: 'wav', mimeType: 'audio/wav');
  static const mp3 = AudioFormat(extension: 'mp3', mimeType: 'audio/mpeg');
  static const m4a = AudioFormat(extension: 'm4a', mimeType: 'audio/mp4');
  static const webm = AudioFormat(extension: 'webm', mimeType: 'audio/webm');
  static const ogg = AudioFormat(extension: 'ogg', mimeType: 'audio/ogg');
  static const flac = AudioFormat(extension: 'flac', mimeType: 'audio/flac');

  /// Default to WAV if format cannot be determined
  static const AudioFormat unknown = wav;
}

class OpenAiTranscriptionRepository {
  OpenAiTranscriptionRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Detects audio format from magic bytes in the audio data.
  ///
  /// Inspects the header bytes to determine the actual audio format:
  /// - RIFF....WAVE -> WAV
  /// - ID3 or 0xFF 0xFB/0xFA/0xF3/0xF2 -> MP3
  /// - ftyp with M4A/mp4a/isom -> M4A/AAC
  /// - 0x1A 0x45 0xDF 0xA3 -> WebM
  /// - OggS -> OGG
  /// - fLaC -> FLAC
  static AudioFormat detectAudioFormat(List<int> bytes) {
    if (bytes.length < 12) return AudioFormat.unknown;

    // WAV: starts with "RIFF" and contains "WAVE"
    if (bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x41 && // A
        bytes[10] == 0x56 && // V
        bytes[11] == 0x45) {
      // E
      return AudioFormat.wav;
    }

    // MP3: ID3 tag or frame sync
    if ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) || // ID3
        (bytes[0] == 0xFF &&
            (bytes[1] == 0xFB ||
                bytes[1] == 0xFA ||
                bytes[1] == 0xF3 ||
                bytes[1] == 0xF2 ||
                bytes[1] == 0xE3))) {
      // Frame sync
      return AudioFormat.mp3;
    }

    // M4A/AAC: ftyp box with compatible brands
    if (bytes[4] == 0x66 && // f
        bytes[5] == 0x74 && // t
        bytes[6] == 0x79 && // y
        bytes[7] == 0x70) {
      // p
      return AudioFormat.m4a;
    }

    // WebM: EBML header
    if (bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      return AudioFormat.webm;
    }

    // OGG: OggS magic
    if (bytes[0] == 0x4F && // O
        bytes[1] == 0x67 && // g
        bytes[2] == 0x67 && // g
        bytes[3] == 0x53) {
      // S
      return AudioFormat.ogg;
    }

    // FLAC: fLaC magic
    if (bytes[0] == 0x66 && // f
        bytes[1] == 0x4C && // L
        bytes[2] == 0x61 && // a
        bytes[3] == 0x43) {
      // C
      return AudioFormat.flac;
    }

    return AudioFormat.unknown;
  }

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
  /// This method sends audio data to OpenAI's `/v1/audio/transcriptions`
  /// endpoint using multipart/form-data format.
  ///
  /// Args:
  ///   model: The OpenAI transcription model to use (e.g., 'gpt-4o-mini-transcribe')
  ///   audioBase64: Base64 encoded audio data (WAV format)
  ///   apiKey: The OpenAI API key for authentication
  ///   prompt: Optional text prompt for context to improve transcription accuracy
  ///   timeout: Optional timeout override (defaults to whisperTranscriptionTimeoutSeconds)
  ///
  /// Returns:
  ///   Stream of chat completion responses containing the transcribed text
  ///
  /// Throws:
  ///   ArgumentError if required parameters are empty
  ///   OpenAiTranscriptionException if transcription fails
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String apiKey,
    String? prompt,
    Duration? timeout,
  }) {
    // Validate required inputs
    if (model.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (audioBase64.isEmpty) {
      throw ArgumentError('Audio data cannot be empty');
    }
    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    // Use provided timeout or default
    final requestTimeout =
        timeout ?? const Duration(seconds: whisperTranscriptionTimeoutSeconds);

    // Define timeout error message once
    final timeoutMinutes = requestTimeout.inMinutes;
    final timeoutErrorMessage = 'Transcription request timed out after '
        '${timeoutMinutes == 1 ? '1 minute' : '$timeoutMinutes minutes'}. '
        'This can happen with very long audio files or slow processing. '
        'Please try with a shorter recording.';

    return Stream.fromFuture(
      () async {
        try {
          developer.log(
            'Sending audio transcription request to OpenAI - '
            'model: $model, audioLength: ${audioBase64.length}, '
            'timeout: ${requestTimeout.inMinutes} minutes',
            name: 'OpenAiTranscriptionRepository',
          );

          // Decode base64 audio to bytes
          final audioBytes = base64Decode(audioBase64);

          // Detect audio format from magic bytes
          final format = detectAudioFormat(audioBytes);
          developer.log(
            'Detected audio format: ${format.extension} (${format.mimeType})',
            name: 'OpenAiTranscriptionRepository',
          );

          // Create multipart request
          final uri =
              Uri.parse('https://api.openai.com/v1/audio/transcriptions');
          final request = http.MultipartRequest('POST', uri);

          // Add headers
          request.headers['Authorization'] = 'Bearer $apiKey';

          // Add file with detected format
          // OpenAI detects the format from the filename extension
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              audioBytes,
              filename: 'audio.${format.extension}',
            ),
          );

          // Add model
          request.fields['model'] = model;

          // Add optional prompt for context
          if (prompt != null && prompt.isNotEmpty) {
            request.fields['prompt'] = prompt;
          }

          // Send request
          final streamedResponse = await _httpClient.send(request).timeout(
            requestTimeout,
            onTimeout: () {
              throw OpenAiTranscriptionException(
                timeoutErrorMessage,
                statusCode: httpStatusRequestTimeout,
              );
            },
          );

          // Read response
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode != 200) {
            developer.log(
              'Failed to transcribe audio: HTTP ${response.statusCode}',
              name: 'OpenAiTranscriptionRepository',
              error: response.body,
            );

            // Try to parse error message from response
            var errorMessage =
                'Failed to transcribe audio (HTTP ${response.statusCode})';
            try {
              final errorJson =
                  jsonDecode(response.body) as Map<String, dynamic>;
              if (errorJson['error'] != null) {
                final error = errorJson['error'] as Map<String, dynamic>;
                errorMessage = error['message'] as String? ?? errorMessage;
              }
            } catch (_) {
              // Use default error message if parsing fails
            }

            throw OpenAiTranscriptionException(
              errorMessage,
              statusCode: response.statusCode,
            );
          }

          final result = jsonDecode(response.body) as Map<String, dynamic>;

          // Validate response structure
          if (!result.containsKey('text')) {
            developer.log(
              'Invalid response from OpenAI transcription: missing text field',
              name: 'OpenAiTranscriptionRepository',
              error: result,
            );
            throw OpenAiTranscriptionException(
              'Invalid response from transcription service: missing text field',
            );
          }

          final text = result['text'] as String;

          developer.log(
            'Successfully transcribed audio - transcriptionLength: ${text.length}',
            name: 'OpenAiTranscriptionRepository',
          );

          // Create a mock stream response to match the expected format
          return CreateChatCompletionStreamResponse(
            id: 'openai-transcription-${DateTime.now().millisecondsSinceEpoch}',
            choices: [
              ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: text,
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
        } on OpenAiTranscriptionException {
          rethrow;
        } on TimeoutException catch (e) {
          developer.log(
            'Transcription request timed out',
            name: 'OpenAiTranscriptionRepository',
            error: e,
          );
          throw OpenAiTranscriptionException(
            timeoutErrorMessage,
            statusCode: httpStatusRequestTimeout,
            originalError: e,
          );
        } on FormatException catch (e) {
          developer.log(
            'Failed to parse response from OpenAI transcription',
            name: 'OpenAiTranscriptionRepository',
            error: e,
          );
          throw OpenAiTranscriptionException(
            'Invalid response format from transcription service',
            originalError: e,
          );
        } catch (e) {
          developer.log(
            'Unexpected error during audio transcription',
            name: 'OpenAiTranscriptionRepository',
            error: e,
          );
          throw OpenAiTranscriptionException(
            'Failed to transcribe audio: $e',
            originalError: e,
          );
        }
      }(),
    ).asBroadcastStream();
  }
}

/// Exception thrown when OpenAI transcription fails
class OpenAiTranscriptionException implements Exception {
  OpenAiTranscriptionException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'OpenAiTranscriptionException: $message';
}
