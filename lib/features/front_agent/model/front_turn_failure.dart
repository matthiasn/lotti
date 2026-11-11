import 'dart:async';

import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';

/// Why a front-agent turn did not go through, as far as the user can act on
/// it — what the chat says instead of a bare "that didn't send".
///
/// It crosses the wake boundary as the failed wake's bounded error string
/// ([wakeError]), because a wake reports an exception by type only: its
/// message can carry a provider's response body (see `WakeResult.failed`).
enum FrontTurnFailure {
  /// The provider is rate-limiting requests (HTTP 429).
  rateLimit,

  /// The provider stopped answering mid-turn, or the turn ran out of time.
  timeout,

  /// The provider could not be reached.
  network,

  /// The provider refused the API key.
  authentication,

  /// The provider account is out of credit or over its spend limit.
  outOfCredit,

  /// The provider answered with an error of its own (4xx/5xx).
  provider,

  /// No model is set up for her.
  noModel,

  /// The model answered without finishing the turn: no dispatch, question
  /// or reply within the call budget.
  noAnswer,

  /// Anything else.
  unknown;

  /// The failure an inference [error] amounts to.
  static FrontTurnFailure ofInference(Object error) =>
      switch (AiErrorUtils.categorizeError(error).type) {
        InferenceErrorType.rateLimit => rateLimit,
        InferenceErrorType.timeout => timeout,
        InferenceErrorType.networkConnection => network,
        InferenceErrorType.authentication => authentication,
        InferenceErrorType.outOfCredit => outOfCredit,
        InferenceErrorType.invalidRequest ||
        InferenceErrorType.serverError => provider,
        InferenceErrorType.unknown => unknown,
      };

  /// The failed wake's error: this cause and [error]'s type, never its
  /// message.
  String wakeError([Object? error]) =>
      '$_prefix$name${error == null ? '' : ' (${error.runtimeType})'}';

  /// Reads [wakeError] back off a failed run's completion [error], which
  /// carries it inside the wake's own exception text. The orchestrator's
  /// run cap ends a run with a [TimeoutException] instead — `'timeout'`,
  /// where a user's stop is `'cancelled'`.
  static FrontTurnFailure fromWakeError(Object? error) {
    if (error is TimeoutException && error.message == 'timeout') {
      return timeout;
    }
    final text = error?.toString() ?? '';
    final at = text.indexOf(_prefix);
    if (at < 0) return unknown;
    final name = RegExp(
      '[A-Za-z]+',
    ).matchAsPrefix(text, at + _prefix.length)?.group(0);
    return values.asNameMap()[name] ?? unknown;
  }

  static const _prefix = 'front turn failed: ';
}
