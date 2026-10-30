import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';
import 'package:lotti/services/domain_logging.dart';

/// Why a Voxtral request failed, so the caller can choose between retrying,
/// asking for a new API key, and falling back to the on-device engine.
enum VoxtralTtsFailure {
  /// No connection, DNS failure, TLS failure. Retryable; fall back offline.
  network,

  /// No response within the request timeout. Retryable.
  timeout,

  /// HTTP 401/403 — the key is missing, revoked or lacks access. Not
  /// retryable until the user fixes the provider's key.
  unauthorized,

  /// HTTP 429. Retry no sooner than [VoxtralTtsException.retryAfter].
  rateLimited,

  /// HTTP 400/404/422 — the request itself was rejected (unknown voice,
  /// unknown model, text too long). Not retryable unchanged.
  rejected,

  /// HTTP 5xx. Retryable.
  server,

  /// A 200 whose body is not what the API documents.
  invalidResponse,

  /// The catalog has no voice for the text's language, so nothing was sent.
  noVoice,
}

class VoxtralTtsException implements Exception {
  const VoxtralTtsException(
    this.failure,
    this.message, {
    this.statusCode,
    this.retryAfter,
    this.apiError,
    this.requestId,
  });

  final VoxtralTtsFailure failure;

  /// Diagnostic text. Never contains the spoken text, the API key or the
  /// response body, so it is safe to log; [apiError] carries what the server
  /// said.
  final String message;

  final int? statusCode;

  /// The server's `Retry-After`, when it sent one with a 429.
  final Duration? retryAfter;

  /// The server's own explanation of a non-200 answer — its `message`, or
  /// each validation `detail` as `loc: msg` — so a 422 names the field it
  /// rejected. The `input` a validation detail echoes is never kept: it can
  /// quote the spoken text.
  final String? apiError;

  /// The server's request id for the failed call, for a support ticket.
  final String? requestId;

  bool get isRetryable => switch (failure) {
    VoxtralTtsFailure.network ||
    VoxtralTtsFailure.timeout ||
    VoxtralTtsFailure.rateLimited ||
    VoxtralTtsFailure.server => true,
    VoxtralTtsFailure.unauthorized ||
    VoxtralTtsFailure.rejected ||
    VoxtralTtsFailure.invalidResponse ||
    VoxtralTtsFailure.noVoice => false,
  };

  @override
  String toString() =>
      'VoxtralTtsException(${failure.name}'
      '${statusCode == null ? '' : ', HTTP $statusCode'}): $message'
      '${apiError == null ? '' : ' — server: $apiError'}'
      '${requestId == null ? '' : ' (request $requestId)'}';
}

/// Audio container returned by `POST /v1/audio/speech`.
enum VoxtralAudioFormat { wav, mp3, flac, opus, pcm }

/// Client for Mistral's Voxtral text-to-speech API.
///
/// Two calls, both against the Mistral provider's `baseUrl`
/// (`https://api.mistral.ai/v1`) with its API key:
///
/// - [synthesize]: `POST audio/speech` with `model`, `input`, `voice_id` and
///   `response_format`; the API answers `{"audio_data": "<base64>"}`.
/// - [fetchVoices]: `GET audio/voices`, paged, presets and the account's own
///   voices together.
///
/// The key and base URL are passed per call rather than held, the same way
/// the transcription repositories take them, so the key stays in the existing
/// inference-provider config and rotating it needs no re-wiring here.
///
/// Model and speed (researched 2026-10 against docs.mistral.ai, so it is not
/// re-investigated):
///
/// - There is no medium/large TTS tier to compare. Hosted TTS is one family,
///   Voxtral Mini TTS; [defaultModel] is its documented id. Mistral documents
///   no `-latest` alias for it, unlike the chat models, so the id is pinned and
///   moving it is a deliberate change.
/// - The speech request has no quality or "speed mode" parameter. Time to
///   first audio is dominated by the container and streaming: Mistral quotes
///   ~0.8 s for `pcm` against ~3 s for `mp3`, ~90 ms when streamed.
///   [VoxtralAudioFormat.wav] keeps the uncompressed latency, plays through
///   the existing `media_kit` path unchanged, and matches what the on-device
///   engine produces.
/// - The request has no speaking-rate field (only inline pace tags in the
///   text). Speed stays a playback rate, as for the on-device engine, so
///   changing it never costs a new request.
class VoxtralTtsService {
  VoxtralTtsService({
    required DomainLogger domainLogger,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 60),
  }) : _logger = domainLogger,
       _client = httpClient ?? http.Client();

  static const String defaultModel = 'voxtral-mini-tts-3-0';

  /// The API pages voices and rejects a `limit` above 100 with a 422 (checked
  /// live 2026-10-30, 66 voices then), so one request normally fetches the
  /// whole catalog and the loop below follows the rest.
  static const int voicesPageSize = 100;

  /// Stops a misbehaving `total_pages` from looping forever.
  static const int _maxVoicePages = 20;

  static const String _subDomain = 'VoxtralTts';

  final DomainLogger _logger;
  final http.Client _client;

  /// Per request, not per catalog fetch.
  final Duration timeout;

  /// Closes the underlying HTTP client.
  void close() => _client.close();

  /// Speaks [text] with [voiceId] and returns the encoded audio.
  ///
  /// Throws [ArgumentError] on empty arguments or a base URL that would send
  /// the key unencrypted, and [VoxtralTtsException] for every failure after
  /// the request is built.
  Future<Uint8List> synthesize({
    required String text,
    required String voiceId,
    required String baseUrl,
    required String apiKey,
    String model = defaultModel,
    VoxtralAudioFormat format = VoxtralAudioFormat.wav,
  }) async {
    if (text.trim().isEmpty) throw ArgumentError('Text cannot be empty');
    if (voiceId.isEmpty) throw ArgumentError('Voice id cannot be empty');
    _requireKey(apiKey);

    final request = http.Request('POST', _endpoint(baseUrl, 'audio/speech'))
      ..headers.addAll(_headers(apiKey))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(<String, dynamic>{
        'model': model,
        'input': text,
        'voice_id': voiceId,
        'response_format': format.name,
      });

    // Lengths and ids only: the text is the user's content.
    final description =
        'Speech request (${request.url.path}): ${text.length} chars, '
        'voice $voiceId, model $model, ${format.name}';
    _logger.log(LogDomain.speech, description, subDomain: _subDomain);
    final stopwatch = Stopwatch()..start();
    final decoded = await _send(request, description: description);
    final audio = decoded['audio_data'];
    if (audio is! String || audio.isEmpty) {
      throw _logged(
        const VoxtralTtsException(
          VoxtralTtsFailure.invalidResponse,
          'Speech response has no audio_data',
        ),
        description: description,
      );
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(audio);
    } on FormatException {
      throw _logged(
        const VoxtralTtsException(
          VoxtralTtsFailure.invalidResponse,
          'Speech response audio_data is not base64',
        ),
        description: description,
      );
    }
    _logger.log(
      LogDomain.speech,
      'Speech response: ${bytes.length} bytes in '
      '${stopwatch.elapsedMilliseconds} ms',
      subDomain: _subDomain,
    );
    return bytes;
  }

  /// Fetches every voice the account can use, following the API's pages.
  Future<VoxtralVoiceCatalog> fetchVoices({
    required String baseUrl,
    required String apiKey,
  }) async {
    _requireKey(apiKey);
    final voices = <VoxtralVoice>[];
    var skipped = 0;
    for (var page = 0; page < _maxVoicePages; page++) {
      final uri = _endpoint(baseUrl, 'audio/voices').replace(
        queryParameters: <String, String>{
          'type': 'all',
          'limit': '$voicesPageSize',
          'offset': '${page * voicesPageSize}',
        },
      );
      final description =
          'Voice catalog request (${uri.path}): page ${page + 1}';
      final decoded = await _send(
        http.Request('GET', uri)..headers.addAll(_headers(apiKey)),
        description: description,
      );
      final items = decoded['items'];
      if (items is! List) {
        throw _logged(
          const VoxtralTtsException(
            VoxtralTtsFailure.invalidResponse,
            'Voices response has no items list',
          ),
          description: description,
        );
      }
      for (final item in items) {
        try {
          voices.add(VoxtralVoice.fromJson(item as Map<String, dynamic>));
        } on Object {
          skipped++;
        }
      }
      // The documented example sends the page counters as strings.
      final totalPages = int.tryParse('${decoded['total_pages']}') ?? 1;
      if (items.length < voicesPageSize || page + 1 >= totalPages) break;
    }
    _logger.log(
      LogDomain.speech,
      'Voice catalog: ${voices.length} voices'
      '${skipped == 0 ? '' : ', $skipped malformed entries skipped'}',
      subDomain: _subDomain,
    );
    return VoxtralVoiceCatalog(voices: voices, fetchedAt: clock.now());
  }

  /// Sends [request]; every failure is logged with [description], which
  /// names the call without its content.
  Future<Map<String, dynamic>> _send(
    http.Request request, {
    required String description,
  }) async {
    // A redirect would carry the bearer token to another host.
    request.followRedirects = false;
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw _logged(
        VoxtralTtsException(
          VoxtralTtsFailure.timeout,
          'No response within ${timeout.inSeconds} s',
        ),
        description: description,
      );
    } on SocketException catch (error) {
      throw _logged(
        VoxtralTtsException(VoxtralTtsFailure.network, error.message),
        description: description,
      );
    } on http.ClientException catch (error) {
      throw _logged(
        VoxtralTtsException(VoxtralTtsFailure.network, error.message),
        description: description,
      );
    } on HandshakeException catch (error) {
      throw _logged(
        VoxtralTtsException(VoxtralTtsFailure.network, error.message),
        description: description,
      );
    }

    final status = response.statusCode;
    if (status != 200) {
      throw _logged(_httpFailure(response), description: description);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Reported below, without echoing the body.
    }
    throw _logged(
      const VoxtralTtsException(
        VoxtralTtsFailure.invalidResponse,
        'Response is not a JSON object',
      ),
      description: description,
    );
  }

  VoxtralTtsException _httpFailure(http.Response response) {
    final status = response.statusCode;
    final apiError = _apiError(response.body);
    final requestId =
        response.headers['x-request-id'] ??
        response.headers['mistral-correlation-id'];
    return switch (status) {
      401 || 403 => VoxtralTtsException(
        VoxtralTtsFailure.unauthorized,
        'The Mistral API key was rejected',
        statusCode: status,
        apiError: apiError,
        requestId: requestId,
      ),
      429 => VoxtralTtsException(
        VoxtralTtsFailure.rateLimited,
        'Rate limited by the Mistral API',
        statusCode: status,
        retryAfter: _retryAfter(response.headers['retry-after']),
        apiError: apiError,
        requestId: requestId,
      ),
      >= 500 => VoxtralTtsException(
        VoxtralTtsFailure.server,
        'Mistral API server error',
        statusCode: status,
        apiError: apiError,
        requestId: requestId,
      ),
      >= 300 && < 400 => VoxtralTtsException(
        VoxtralTtsFailure.invalidResponse,
        'Unexpected redirect, not followed',
        statusCode: status,
        requestId: requestId,
      ),
      _ => VoxtralTtsException(
        VoxtralTtsFailure.rejected,
        'Request rejected by the Mistral API',
        statusCode: status,
        apiError: apiError,
        requestId: requestId,
      ),
    };
  }

  /// Longest [VoxtralTtsException.apiError] kept; a validation answer lists
  /// one short detail per rejected field, well below this.
  static const int _maxApiErrorLength = 500;

  /// The server's explanation in a non-200 [body]: `{"message": ...}` (a
  /// string, or an object nesting the next form) or a validation answer,
  /// `{"detail": "..." | [{"loc": [...], "msg": "...", "input": ...}]}`.
  /// Only `loc` and `msg` are kept from a detail: its `input` echoes the
  /// rejected value, which for the speech body is the spoken text. A body
  /// that is not JSON (a proxy's error page) is not kept, as it is unknown
  /// what it quotes.
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

  /// `Retry-After` as delta-seconds; the HTTP-date form is not used by
  /// Mistral and reads as absent.
  static Duration? _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  /// Logs [error] under the [description] of the call that failed: the full
  /// log records both, the PII-safe log the description and the type.
  VoxtralTtsException _logged(
    VoxtralTtsException error, {
    required String description,
  }) {
    _logger.error(
      LogDomain.speech,
      error,
      subDomain: _subDomain,
      message: '$description failed',
    );
    return error;
  }

  static Map<String, String> _headers(String apiKey) => <String, String>{
    'Authorization': 'Bearer $apiKey',
    'Accept': 'application/json',
  };

  static void _requireKey(String apiKey) {
    if (apiKey.isEmpty) throw ArgumentError('API key cannot be empty');
  }

  /// Resolves [path] under [baseUrl], refusing plain HTTP except on loopback
  /// (a self-hosted vLLM-Omni server on the same machine).
  static Uri _endpoint(String baseUrl, String path) {
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
}
