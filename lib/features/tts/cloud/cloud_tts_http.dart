import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/services/domain_logging.dart';

/// The HTTP transport every cloud speech client shares: one request at a
/// time under a timeout, every failure typed as a [CloudTtsException] and
/// logged without the spoken text, the key or the response body.
///
/// It refuses redirects, which would carry the credential to another host,
/// and plain HTTP anywhere but loopback.
class CloudTtsHttp {
  CloudTtsHttp({
    required DomainLogger domainLogger,
    required this.providerName,
    required this.subDomain,
    required this.requestIdHeaders,
    required this.timeout,
    http.Client? httpClient,
  }) : _logger = domainLogger,
       _client = httpClient ?? http.Client();

  final DomainLogger _logger;
  final http.Client _client;

  /// The provider as failure messages name it (`Mistral`, `ElevenLabs`).
  final String providerName;

  /// The log sub-domain the client's lines go under.
  final String subDomain;

  /// Response headers that carry the server's request id, first match wins.
  final List<String> requestIdHeaders;

  /// Per request.
  final Duration timeout;

  /// Closes the underlying HTTP client.
  void close() => _client.close();

  /// Logs a progress line under [subDomain].
  void log(String message) =>
      _logger.log(LogDomain.speech, message, subDomain: subDomain);

  /// Sends [request] and returns its 200 response; every failure is logged
  /// with [description], which names the call without its content.
  Future<http.Response> send(
    http.Request request, {
    required String description,
  }) async {
    final abort = Completer<void>();
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(_abortable(request, abort.future)).timeout(timeout),
      ).timeout(timeout);
    } on Object catch (error) {
      // A timeout does not end the request by itself: it is let go of here.
      _complete(abort);
      final failure = _transportFailure(error);
      if (failure == null) rethrow;
      throw logged(failure, description: description);
    }
    if (response.statusCode != 200) {
      throw logged(_httpFailure(response), description: description);
    }
    return response;
  }

  /// Sends [request] and returns the body of its 200 response as it
  /// arrives, for an answer that is read while it is still being sent.
  /// [timeout] bounds the wait for the response and for each further piece
  /// of it. Every failure — while waiting for the answer or along its body —
  /// is a [CloudTtsException] logged with [description], as in [send].
  ///
  /// Cancelling the subscription aborts the request at once, also while it
  /// still waits for the answer, so a stop never waits on the provider; the
  /// request is aborted too when it times out or fails.
  Stream<List<int>> sendStreamed(
    http.Request request, {
    required String description,
  }) {
    final abort = Completer<void>();
    var cancelled = false;
    late final StreamController<List<int>> controller;

    Future<void> run() async {
      try {
        final response = await _client
            .send(_abortable(request, abort.future))
            .timeout(timeout);
        if (response.statusCode != 200) {
          throw _httpFailure(
            await http.Response.fromStream(response).timeout(timeout),
          );
        }
        await for (final chunk in response.stream.timeout(timeout)) {
          if (cancelled) return;
          controller.add(chunk);
        }
      } on Object catch (error, stackTrace) {
        if (cancelled) return;
        final failure = error is CloudTtsException
            ? error
            : _transportFailure(error);
        controller.addError(
          failure == null ? error : logged(failure, description: description),
          stackTrace,
        );
      } finally {
        _complete(abort);
        if (!cancelled) await controller.close();
      }
    }

    controller = StreamController<List<int>>(
      onListen: () => run().ignore(),
      onCancel: () {
        cancelled = true;
        _complete(abort);
      },
    );
    return controller.stream;
  }

  /// [request] as one [abortTrigger] can end, redirects refused.
  static http.AbortableRequest _abortable(
    http.Request request,
    Future<void> abortTrigger,
  ) =>
      http.AbortableRequest(
          request.method,
          request.url,
          abortTrigger: abortTrigger,
        )
        ..headers.addAll(request.headers)
        ..followRedirects = false
        ..bodyBytes = request.bodyBytes;

  static void _complete(Completer<void> completer) {
    if (!completer.isCompleted) completer.complete();
  }

  /// [error] as the failure of a request that never got an answer, or null
  /// when it is not one of those.
  CloudTtsException? _transportFailure(Object error) => switch (error) {
    TimeoutException() => CloudTtsException(
      CloudTtsFailure.timeout,
      'No response within ${timeout.inSeconds} s',
    ),
    SocketException(:final message) ||
    http.ClientException(:final message) ||
    HandshakeException(:final message) => CloudTtsException(
      CloudTtsFailure.network,
      message,
    ),
    _ => null,
  };

  /// Sends [request] and decodes its body as JSON; a body that is not JSON
  /// is an [CloudTtsFailure.invalidResponse], reported without echoing it.
  Future<Object?> sendForJson(
    http.Request request, {
    required String description,
  }) async {
    final response = await send(request, description: description);
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw invalidResponse('Response is not JSON', description: description);
    }
  }

  /// A logged [CloudTtsFailure.invalidResponse] for a 200 whose body is not
  /// what the API documents.
  CloudTtsException invalidResponse(
    String message, {
    required String description,
  }) => logged(
    CloudTtsException(CloudTtsFailure.invalidResponse, message),
    description: description,
  );

  /// Logs [error] under the [description] of the call that failed: the full
  /// log records both, the PII-safe log the description and the type.
  CloudTtsException logged(
    CloudTtsException error, {
    required String description,
  }) {
    _logger.error(
      LogDomain.speech,
      error,
      subDomain: subDomain,
      message: '$description failed',
    );
    return error;
  }

  CloudTtsException _httpFailure(http.Response response) {
    final status = response.statusCode;
    final apiError = _apiError(response.body);
    final requestId = requestIdHeaders
        .map((header) => response.headers[header])
        .nonNulls
        .firstOrNull;
    return switch (status) {
      401 || 403 => CloudTtsException(
        CloudTtsFailure.unauthorized,
        'The $providerName API key was rejected',
        statusCode: status,
        apiError: apiError,
        requestId: requestId,
      ),
      429 => CloudTtsException(
        CloudTtsFailure.rateLimited,
        'Rate limited by the $providerName API',
        statusCode: status,
        retryAfter: _retryAfter(response.headers['retry-after']),
        apiError: apiError,
        requestId: requestId,
      ),
      >= 500 => CloudTtsException(
        CloudTtsFailure.server,
        '$providerName API server error',
        statusCode: status,
        apiError: apiError,
        requestId: requestId,
      ),
      >= 300 && < 400 => CloudTtsException(
        CloudTtsFailure.invalidResponse,
        'Unexpected redirect, not followed',
        statusCode: status,
        requestId: requestId,
      ),
      _ => CloudTtsException(
        CloudTtsFailure.rejected,
        'Request rejected by the $providerName API',
        statusCode: status,
        apiError: apiError,
        requestId: requestId,
      ),
    };
  }

  /// Longest [CloudTtsException.apiError] kept; a validation answer lists
  /// one short detail per rejected field, well below this.
  static const int _maxApiErrorLength = 500;

  /// The server's explanation in a non-200 [body]: `{"message": ...}` (a
  /// string, or an object nesting the next form) or a validation answer,
  /// `{"detail": "..." | {"message": ...} | [{"loc": [...], "msg": "...",
  /// "input": ...}]}` — ElevenLabs nests its `status` and `message` in
  /// `detail`. Only `loc` and `msg` are kept from a validation detail: its
  /// `input` echoes the rejected value, which for a speech body is the
  /// spoken text. A body that is not JSON (a proxy's error page) is not
  /// kept, as it is unknown what it quotes.
  static String? _apiError(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    final text = _errorText(decoded)?.trim();
    if (text == null || text.isEmpty) return null;
    return text.length <= _maxApiErrorLength
        ? text
        : '${text.substring(0, _maxApiErrorLength)}…';
  }

  static String? _errorText(Object? node) => switch (node) {
    final String text => text,
    final List<Object?> details =>
      details.map(_detailText).whereType<String>().join('; '),
    final Map<String, dynamic> map =>
      _errorText(map['message']) ?? _errorText(map['detail']),
    _ => null,
  };

  /// One validation detail as `query.limit: Input should be …`.
  static String? _detailText(Object? detail) {
    if (detail is! Map<String, dynamic>) return null;
    final msg = detail['msg'];
    if (msg is! String) return null;
    final loc = detail['loc'];
    return loc is List && loc.isNotEmpty ? '${loc.join('.')}: $msg' : msg;
  }

  /// `Retry-After` as delta-seconds; the HTTP-date form reads as absent.
  static Duration? _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  /// Resolves [path] under [baseUrl], refusing plain HTTP except on loopback
  /// (a self-hosted server on the same machine).
  ///
  /// Throws [ArgumentError] for an empty base URL or one that would send the
  /// key unencrypted.
  static Uri endpoint(String baseUrl, String path) {
    if (baseUrl.isEmpty) throw ArgumentError('Base URL cannot be empty');
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    final loopback =
        base.host == 'localhost' ||
        (InternetAddress.tryParse(base.host)?.isLoopback ?? false);
    if (base.scheme != 'https' && !(base.scheme == 'http' && loopback)) {
      throw ArgumentError.value(base.scheme, 'baseUrl', 'must use HTTPS');
    }
    return base.resolve(path);
  }

  /// Throws [ArgumentError] for an empty [apiKey].
  static void requireKey(String apiKey) {
    if (apiKey.isEmpty) throw ArgumentError('API key cannot be empty');
  }
}
