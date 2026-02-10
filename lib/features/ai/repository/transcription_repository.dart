import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

export 'transcription_exception.dart';

/// Base class for transcription repositories that share the same
/// request → parse → wrap-as-stream pattern.
///
/// Subclasses implement provider-specific HTTP request construction
/// (multipart, JSON POST, etc.) and call [executeTranscription] with
/// a closure that sends the request.
class TranscriptionRepository {
  TranscriptionRepository({http.Client? httpClient})
      : httpClient = httpClient ?? http.Client();

  final http.Client httpClient;

  static const _uuid = Uuid();

  /// Shared transcription template.
  ///
  /// Handles timeout calculation, developer logging, response parsing,
  /// `CreateChatCompletionStreamResponse` wrapping, and the full error
  /// catch cascade.
  ///
  /// [providerName] is used for logging and exception diagnostics.
  /// [responseIdPrefix] is prepended to the generated response ID.
  /// [sendRequest] performs the provider-specific HTTP call and returns
  /// the raw response. It receives the computed timeout and a
  /// pre-formatted timeout error message so it can throw
  /// [TranscriptionException] from its own `onTimeout` callback.
  Stream<CreateChatCompletionStreamResponse> executeTranscription({
    required String providerName,
    required String responseIdPrefix,
    required Future<http.Response> Function(
      Duration timeout,
      String timeoutErrorMessage,
    ) sendRequest,
    required int audioLengthForLog,
    Duration? timeout,
  }) {
    final requestTimeout =
        timeout ?? const Duration(seconds: whisperTranscriptionTimeoutSeconds);

    final timeoutDisplay = _formatTimeoutDisplay(requestTimeout);

    final timeoutErrorMessage = 'Transcription request timed out after '
        '$timeoutDisplay. '
        'This can happen with very long audio files or slow processing. '
        'Please try with a shorter recording.';

    return Stream.fromFuture(
      () async {
        try {
          developer.log(
            'Sending audio transcription request to $providerName - '
            'audioLength: $audioLengthForLog, timeout: $timeoutDisplay',
            name: providerName,
          );

          final response =
              await sendRequest(requestTimeout, timeoutErrorMessage);

          if (response.statusCode != 200) {
            developer.log(
              'Failed to transcribe audio: HTTP ${response.statusCode}',
              name: providerName,
              error: response.body,
            );

            final errorMessage = _parseErrorMessage(response);
            throw TranscriptionException(
              errorMessage,
              provider: providerName,
              statusCode: response.statusCode,
            );
          }

          final result = jsonDecode(response.body) as Map<String, dynamic>;

          if (!result.containsKey('text')) {
            developer.log(
              'Invalid response from $providerName: missing text field',
              name: providerName,
              error: result,
            );
            throw TranscriptionException(
              'Invalid response from transcription service: '
              'missing text field',
              provider: providerName,
            );
          }

          final text = result['text'] as String;

          developer.log(
            'Successfully transcribed audio - '
            'transcriptionLength: ${text.length}',
            name: providerName,
          );

          return CreateChatCompletionStreamResponse(
            id: '$responseIdPrefix${_uuid.v4()}',
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
            name: providerName,
            error: e,
          );
          throw TranscriptionException(
            timeoutErrorMessage,
            provider: providerName,
            statusCode: httpStatusRequestTimeout,
            originalError: e,
          );
        } on FormatException catch (e) {
          developer.log(
            'Failed to parse response from $providerName',
            name: providerName,
            error: e,
          );
          throw TranscriptionException(
            'Invalid response format from transcription service',
            provider: providerName,
            originalError: e,
          );
        } catch (e) {
          developer.log(
            'Unexpected error during audio transcription',
            name: providerName,
            error: e,
          );
          throw TranscriptionException(
            'Failed to transcribe audio: $e',
            provider: providerName,
            originalError: e,
          );
        }
      }(),
    ).asBroadcastStream();
  }

  /// Builds a human-readable timeout duration string.
  static String _formatTimeoutDisplay(Duration timeout) {
    if (timeout.inMinutes == 0) {
      final seconds = timeout.inSeconds;
      return seconds == 1 ? '1 second' : '$seconds seconds';
    }
    final minutes = timeout.inMinutes;
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }

  /// Attempts to extract a structured error message from an HTTP response.
  ///
  /// Tries to parse the response body as JSON and extract
  /// `error.message`. Falls back to a generic message.
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
