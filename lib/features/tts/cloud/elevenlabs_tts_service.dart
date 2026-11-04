import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/tts/cloud/cloud_tts_client.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_http.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog.dart';
import 'package:lotti/services/domain_logging.dart';

/// Client for the ElevenLabs text-to-speech API.
///
/// Three calls against the ElevenLabs provider's `baseUrl`
/// (`https://api.elevenlabs.io/v1`), each authenticated by its API key in
/// the `xi-api-key` header (checked against the published OpenAPI document
/// on 2026-11-04):
///
/// - [synthesize]: `POST text-to-speech/{voice_id}?output_format=wav_24000`
///   with `text` and `model_id`; the answer is the audio itself.
/// - [fetchVoices]: `GET models`, for the languages the model speaks, then
///   `GET voices` — the premade voices and the account's own and saved ones,
///   in one unpaged list.
///
/// Every ElevenLabs voice speaks every language of a multilingual model in
/// its own timbre, so each voice is offered for all of the model's languages:
/// the per-language choice in Speech settings works as it does for Mistral.
///
/// The format is `wav_24000`: WAV plays through the shared `media_kit` path
/// as the on-device engine's output does, and 44.1 kHz WAV needs a Pro plan.
/// No `language_code` is sent, as `eleven_multilingual_v2` does not take it;
/// the multilingual models read the language from the text.
class ElevenLabsTtsService implements CloudTtsClient {
  ElevenLabsTtsService({
    required DomainLogger domainLogger,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 60),
  }) : _http = CloudTtsHttp(
         domainLogger: domainLogger,
         httpClient: httpClient,
         providerName: 'ElevenLabs',
         subDomain: 'ElevenLabsTts',
         requestIdHeaders: const ['request-id', 'x-request-id'],
         timeout: timeout,
       );

  /// The API's own default model, multilingual and the most natural of the
  /// stable ones.
  static const String defaultModel = 'eleven_multilingual_v2';

  /// 24 kHz WAV: available on every plan, unlike 44.1 kHz.
  static const String outputFormat = 'wav_24000';

  final CloudTtsHttp _http;

  @override
  void close() => _http.close();

  /// Speaks [text] with [voiceId] and returns the WAV bytes.
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
  }) async {
    if (text.trim().isEmpty) throw ArgumentError('Text cannot be empty');
    if (voiceId.isEmpty) throw ArgumentError('Voice id cannot be empty');
    CloudTtsHttp.requireKey(apiKey);

    final uri = CloudTtsHttp.endpoint(
      baseUrl,
      'text-to-speech/${Uri.encodeComponent(voiceId)}',
    ).replace(queryParameters: const {'output_format': outputFormat});
    final request = http.Request('POST', uri)
      ..headers.addAll(_headers(apiKey, accept: 'audio/wav'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(<String, dynamic>{'text': text, 'model_id': model});

    // Lengths and ids only: the text is the user's content.
    final description =
        'Speech request (${uri.path}): ${text.length} chars, '
        'voice $voiceId, model $model, $outputFormat';
    _http.log(description);
    final stopwatch = Stopwatch()..start();
    final response = await _http.send(request, description: description);
    final bytes = response.bodyBytes;
    if (!_isWav(bytes)) {
      throw _http.invalidResponse(
        'Speech response is not WAV audio',
        description: description,
      );
    }
    _http.log(
      'Speech response: ${bytes.length} bytes in '
      '${stopwatch.elapsedMilliseconds} ms',
    );
    return bytes;
  }

  /// Fetches every voice the account can use, each offered for the
  /// languages [model] speaks.
  ///
  /// A model the account's list does not name (a custom id) has no language
  /// list to go by; its voices are then offered for the languages ElevenLabs
  /// verified each of them for.
  @override
  Future<CloudVoiceCatalog> fetchVoices({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    CloudTtsHttp.requireKey(apiKey);
    final languages = await _modelLanguages(baseUrl, apiKey, model);

    final uri = CloudTtsHttp.endpoint(baseUrl, 'voices');
    final description = 'Voice catalog request (${uri.path})';
    final decoded = await _http.sendForJson(
      http.Request('GET', uri)..headers.addAll(_headers(apiKey)),
      description: description,
    );
    final items = decoded is Map<String, dynamic> ? decoded['voices'] : null;
    if (items is! List) {
      throw _http.invalidResponse(
        'Voices response has no voices list',
        description: description,
      );
    }
    final voices = <CloudVoice>[];
    var skipped = 0;
    for (final item in items) {
      final voice = item is Map<String, dynamic>
          ? _voiceFromJson(item, languages)
          : null;
      if (voice == null) {
        skipped++;
      } else {
        voices.add(voice);
      }
    }
    _http.log(
      'Voice catalog: ${voices.length} voices for $model in '
      '${languages.length} languages'
      '${skipped == 0 ? '' : ', $skipped malformed entries skipped'}',
    );
    return CloudVoiceCatalog(voices: voices, fetchedAt: clock.now());
  }

  /// The language ids `GET models` lists for [model]; empty when the list
  /// does not name it.
  Future<List<String>> _modelLanguages(
    String baseUrl,
    String apiKey,
    String model,
  ) async {
    final uri = CloudTtsHttp.endpoint(baseUrl, 'models');
    final description = 'Model list request (${uri.path})';
    final decoded = await _http.sendForJson(
      http.Request('GET', uri)..headers.addAll(_headers(apiKey)),
      description: description,
    );
    if (decoded is! List) {
      throw _http.invalidResponse(
        'Models response is not a list',
        description: description,
      );
    }
    final languages = decoded
        .whereType<Map<String, dynamic>>()
        .where((entry) => entry['model_id'] == model)
        .firstOrNull?['languages'];
    return [
      if (languages is List)
        for (final language in languages.whereType<Map<String, dynamic>>())
          if (language['language_id'] case final String id
              when id.trim().isNotEmpty)
            id,
    ];
  }

  /// One entry of `GET voices` as a [CloudVoice], or `null` when it lacks
  /// the id or the name.
  ///
  /// [modelLanguages] are the languages it is offered for; when empty, its
  /// own verified languages and its `language` label stand in. Its `gender`
  /// label groups it in the picker; its accent, character, age and use case
  /// labels become its tags, so voices can be told apart before a preview.
  static CloudVoice? _voiceFromJson(
    Map<String, dynamic> json,
    List<String> modelLanguages,
  ) {
    final id = json['voice_id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String) return null;
    final rawLabels = json['labels'];
    final labels = <String, String>{
      if (rawLabels is Map)
        for (final MapEntry(:key, :value) in rawLabels.entries)
          if (key is String && value is String && value.trim().isNotEmpty)
            key: value.trim(),
    };
    final verified = json['verified_languages'];
    final ownLanguages = <String>{
      if (verified is List)
        for (final entry in verified.whereType<Map<String, dynamic>>())
          if (entry['language'] case final String language
              when language.trim().isNotEmpty)
            language,
      ?labels['language'],
    };
    return CloudVoice(
      id: id,
      name: name,
      gender: labels['gender'],
      languages: modelLanguages.isNotEmpty
          ? modelLanguages
          : ownLanguages.toList(growable: false),
      tags: <String>{
        for (final key in _tagLabels)
          if (labels[key] case final value?) value.replaceAll('_', ' '),
      }.toList(growable: false),
      type: switch (json['category']) {
        'premade' => CloudVoiceType.preset,
        final String _ => CloudVoiceType.custom,
        _ => CloudVoiceType.unknown,
      },
    );
  }

  /// The labels shown as a voice's tags, in this order. ElevenLabs has used
  /// both `description` and `descriptive` for the voice's character.
  static const List<String> _tagLabels = [
    'accent',
    'descriptive',
    'description',
    'age',
    'use_case',
  ];

  /// Whether [bytes] open with a RIFF/WAVE header.
  static bool _isWav(Uint8List bytes) =>
      bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WAVE';

  static Map<String, String> _headers(
    String apiKey, {
    String accept = 'application/json',
  }) => <String, String>{'xi-api-key': apiKey, 'Accept': accept};
}
