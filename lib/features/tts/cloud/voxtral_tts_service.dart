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
}

class VoxtralTtsException implements Exception {
  const VoxtralTtsException(
    this.failure,
    this.message, {
    this.statusCode,
    this.retryAfter,
  });

  final VoxtralTtsFailure failure;

  /// Diagnostic text. Never contains the spoken text, the API key or the
  /// response body, so it is safe to log.
  final String message;

  final int? statusCode;

  /// The server's `Retry-After`, when it sent one with a 429.
  final Duration? retryAfter;

  bool get isRetryable => switch (failure) {
    VoxtralTtsFailure.network ||
    VoxtralTtsFailure.timeout ||
    VoxtralTtsFailure.rateLimited ||
    VoxtralTtsFailure.server => true,
    VoxtralTtsFailure.unauthorized ||
    VoxtralTtsFailure.rejected ||
    VoxtralTtsFailure.invalidResponse => false,
  };

  @override
  String toString() =>
      'VoxtralTtsException(${failure.name}'
      '${statusCode == null ? '' : ', HTTP $statusCode'}): $message';
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

  /// The API pages voices; this is the page size the API itself answers with
  /// by default, so one request normally fetches the whole catalog.
  static const int voicesPageSize = 1000;

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
    _logger.log(
      LogDomain.speech,
      'Speech request: ${text.length} chars, voice $voiceId, '
      'model $model, ${format.name}',
      subDomain: _subDomain,
    );
    final stopwatch = Stopwatch()..start();
    final decoded = await _send(request);
    final audio = decoded['audio_data'];
    if (audio is! String || audio.isEmpty) {
      throw const VoxtralTtsException(
        VoxtralTtsFailure.invalidResponse,
        'Speech response has no audio_data',
      );
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(audio);
    } on FormatException {
      throw const VoxtralTtsException(
        VoxtralTtsFailure.invalidResponse,
        'Speech response audio_data is not base64',
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
      final decoded = await _send(
        http.Request('GET', uri)..headers.addAll(_headers(apiKey)),
      );
      final items = decoded['items'];
      if (items is! List) {
        throw const VoxtralTtsException(
          VoxtralTtsFailure.invalidResponse,
          'Voices response has no items list',
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

  Future<Map<String, dynamic>> _send(http.Request request) async {
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
      );
    } on SocketException catch (error) {
      throw _logged(
        VoxtralTtsException(VoxtralTtsFailure.network, error.message),
      );
    } on http.ClientException catch (error) {
      throw _logged(
        VoxtralTtsException(VoxtralTtsFailure.network, error.message),
      );
    } on HandshakeException catch (error) {
      throw _logged(
        VoxtralTtsException(VoxtralTtsFailure.network, error.message),
      );
    }

    final status = response.statusCode;
    if (status != 200) throw _logged(_httpFailure(response));
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
    );
  }

  VoxtralTtsException _httpFailure(http.Response response) {
    final status = response.statusCode;
    return switch (status) {
      401 || 403 => VoxtralTtsException(
        VoxtralTtsFailure.unauthorized,
        'The Mistral API key was rejected',
        statusCode: status,
      ),
      429 => VoxtralTtsException(
        VoxtralTtsFailure.rateLimited,
        'Rate limited by the Mistral API',
        statusCode: status,
        retryAfter: _retryAfter(response.headers['retry-after']),
      ),
      >= 500 => VoxtralTtsException(
        VoxtralTtsFailure.server,
        'Mistral API server error',
        statusCode: status,
      ),
      >= 300 && < 400 => VoxtralTtsException(
        VoxtralTtsFailure.invalidResponse,
        'Unexpected redirect, not followed',
        statusCode: status,
      ),
      _ => VoxtralTtsException(
        VoxtralTtsFailure.rejected,
        'Request rejected by the Mistral API',
        statusCode: status,
      ),
    };
  }

  /// `Retry-After` as delta-seconds; the HTTP-date form is not used by
  /// Mistral and reads as absent.
  static Duration? _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  VoxtralTtsException _logged(VoxtralTtsException error) {
    _logger.error(LogDomain.speech, error, subDomain: _subDomain);
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
