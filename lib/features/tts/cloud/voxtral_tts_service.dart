import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/tts/cloud/cloud_tts_client.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_http.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog.dart';
import 'package:lotti/services/domain_logging.dart';

/// Audio container returned by `POST /v1/audio/speech`.
enum VoxtralAudioFormat { wav, mp3, flac, opus, pcm }

/// Client for Mistral's Voxtral text-to-speech API.
///
/// Two calls, both against the Mistral provider's `baseUrl`
/// (`https://api.mistral.ai/v1`) with its API key as a bearer token:
///
/// - [synthesize]: `POST audio/speech` with `model`, `input`, `voice_id` and
///   `response_format`; the API answers `{"audio_data": "<base64>"}`.
/// - [fetchVoices]: `GET audio/voices`, paged, presets and the account's own
///   voices together.
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
class VoxtralTtsService implements StreamingCloudTtsClient {
  VoxtralTtsService({
    required DomainLogger domainLogger,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 60),
  }) : _http = CloudTtsHttp(
         domainLogger: domainLogger,
         httpClient: httpClient,
         providerName: 'Mistral',
         subDomain: 'VoxtralTts',
         requestIdHeaders: const ['x-request-id', 'mistral-correlation-id'],
         timeout: timeout,
       );

  static const String defaultModel = 'voxtral-mini-tts-3-0';

  /// The API pages voices and rejects a `limit` above 100 with a 422 (checked
  /// live 2026-10-30, 66 voices then), so one request normally fetches the
  /// whole catalog and the loop below follows the rest.
  static const int voicesPageSize = 100;

  /// Stops a misbehaving `total_pages` from looping forever.
  static const int _maxVoicePages = 20;

  final CloudTtsHttp _http;

  @override
  void close() => _http.close();

  /// Speaks [text] with [voiceId] and returns the encoded audio.
  ///
  /// Throws [ArgumentError] on empty arguments or a base URL that would send
  /// the key unencrypted, and [CloudTtsException] for every failure after
  /// the request is built.
  @override
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
    CloudTtsHttp.requireKey(apiKey);

    final request =
        http.Request('POST', CloudTtsHttp.endpoint(baseUrl, 'audio/speech'))
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
    _http.log(description);
    final stopwatch = Stopwatch()..start();
    final decoded = await _sendForObject(request, description: description);
    final audio = decoded['audio_data'];
    if (audio is! String || audio.isEmpty) {
      throw _http.invalidResponse(
        'Speech response has no audio_data',
        description: description,
      );
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(audio);
    } on FormatException {
      throw _http.invalidResponse(
        'Speech response audio_data is not base64',
        description: description,
      );
    }
    _http.log(
      'Speech response: ${bytes.length} bytes in '
      '${stopwatch.elapsedMilliseconds} ms',
    );
    return bytes;
  }

  /// Speaks [text] with [voiceId] as one synthesis and emits its WAV bytes
  /// as the API sends them: `POST audio/speech` with `stream: true` answers
  /// with server-sent events, `speech.audio.delta` carrying base64 audio
  /// and `speech.audio.done` ending it.
  ///
  /// Checked live 2026-11-12: the first delta 0.3 s after the request, 12.8 s
  /// of audio within 2 s; the WAV header comes in the first delta with its
  /// length fields at 0xFFFFFFFF; a text of one short word ("Yes.") gets
  /// `done` and no audio.
  ///
  /// Throws as [synthesize] does, on the first listen or along the stream.
  @override
  Stream<Uint8List> synthesizeStream({
    required String text,
    required String voiceId,
    required String baseUrl,
    required String apiKey,
    String model = defaultModel,
  }) async* {
    if (text.trim().isEmpty) throw ArgumentError('Text cannot be empty');
    if (voiceId.isEmpty) throw ArgumentError('Voice id cannot be empty');
    CloudTtsHttp.requireKey(apiKey);

    final request =
        http.Request('POST', CloudTtsHttp.endpoint(baseUrl, 'audio/speech'))
          ..headers['Authorization'] = 'Bearer $apiKey'
          ..headers['Accept'] = 'text/event-stream'
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(<String, dynamic>{
            'model': model,
            'input': text,
            'voice_id': voiceId,
            'response_format': VoxtralAudioFormat.wav.name,
            'stream': true,
          });

    // Lengths and ids only: the text is the user's content.
    final description =
        'Streamed speech request (${request.url.path}): ${text.length} '
        'chars, voice $voiceId, model $model';
    _http.log(description);
    final stopwatch = Stopwatch()..start();
    var bytes = 0;
    var done = false;
    final lines = _http
        .sendStreamed(request, description: description)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final Object? event;
      try {
        event = jsonDecode(line.substring(5));
      } on FormatException {
        throw _http.invalidResponse(
          'Speech stream event is not JSON',
          description: description,
        );
      }
      if (event is! Map<String, dynamic>) continue;
      if (event['type'] == 'speech.audio.done') {
        done = true;
        break;
      }
      final audio = event['audio_data'];
      if (event['type'] != 'speech.audio.delta' || audio is! String) continue;
      final Uint8List chunk;
      try {
        chunk = base64Decode(audio);
      } on FormatException {
        throw _http.invalidResponse(
          'Speech stream audio_data is not base64',
          description: description,
        );
      }
      if (bytes == 0) {
        _http.log('First audio after ${stopwatch.elapsedMilliseconds} ms');
      }
      bytes += chunk.length;
      yield chunk;
    }
    // Only `done` says the speech is all there: an answer that just stops
    // is a cut-off clip, which must not be taken for a whole one.
    if (!done) {
      throw _http.invalidResponse(
        'Speech stream ended before speech.audio.done',
        description: description,
      );
    }
    _http.log(
      'Speech stream: $bytes bytes in ${stopwatch.elapsedMilliseconds} ms',
    );
  }

  /// Fetches every voice the account can use, following the API's pages.
  ///
  /// The catalog is the account's, whatever the model: [model] is accepted
  /// for the [CloudTtsClient] contract and not sent.
  @override
  Future<CloudVoiceCatalog> fetchVoices({
    required String baseUrl,
    required String apiKey,
    String? model,
  }) async {
    CloudTtsHttp.requireKey(apiKey);
    final voices = <CloudVoice>[];
    var skipped = 0;
    for (var page = 0; page < _maxVoicePages; page++) {
      final uri = CloudTtsHttp.endpoint(baseUrl, 'audio/voices').replace(
        queryParameters: <String, String>{
          'type': 'all',
          'limit': '$voicesPageSize',
          'offset': '${page * voicesPageSize}',
        },
      );
      final description =
          'Voice catalog request (${uri.path}): page ${page + 1}';
      final decoded = await _sendForObject(
        http.Request('GET', uri)..headers.addAll(_headers(apiKey)),
        description: description,
      );
      final items = decoded['items'];
      if (items is! List) {
        throw _http.invalidResponse(
          'Voices response has no items list',
          description: description,
        );
      }
      for (final item in items) {
        try {
          voices.add(CloudVoice.fromJson(item as Map<String, dynamic>));
        } on Object {
          skipped++;
        }
      }
      // The documented example sends the page counters as strings.
      final totalPages = int.tryParse('${decoded['total_pages']}') ?? 1;
      if (items.length < voicesPageSize || page + 1 >= totalPages) break;
    }
    _http.log(
      'Voice catalog: ${voices.length} voices'
      '${skipped == 0 ? '' : ', $skipped malformed entries skipped'}',
    );
    return CloudVoiceCatalog(voices: voices, fetchedAt: clock.now());
  }

  /// Sends [request] and returns its body as a JSON object.
  Future<Map<String, dynamic>> _sendForObject(
    http.Request request, {
    required String description,
  }) async {
    final decoded = await _http.sendForJson(request, description: description);
    if (decoded is Map<String, dynamic>) return decoded;
    throw _http.invalidResponse(
      'Response is not a JSON object',
      description: description,
    );
  }

  static Map<String, String> _headers(String apiKey) => <String, String>{
    'Authorization': 'Bearer $apiKey',
    'Accept': 'application/json',
  };
}
