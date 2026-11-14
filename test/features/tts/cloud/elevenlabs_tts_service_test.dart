import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog.dart';
import 'package:lotti/features/tts/cloud/elevenlabs_tts_service.dart';
import 'package:lotti/features/tts/engine/wav_writer.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart' show MockDomainLogger;

const _baseUrl = 'https://api.elevenlabs.io/v1';
const _apiKey = 'xi-secret';
const _text = 'Grüß Gott — „Äpfel“ kosten 3,50 €.';

/// A minimal RIFF/WAVE header followed by a few sample bytes.
final Uint8List _wav = Uint8List.fromList([
  ...ascii.encode('RIFF'),
  0x24, 0, 0, 0, //
  ...ascii.encode('WAVE'),
  1, 2, 3, 4,
]);

final List<Map<String, dynamic>> _models = [
  {
    'model_id': 'eleven_flash_v2_5',
    'languages': [
      {'language_id': 'en', 'name': 'English'},
    ],
  },
  {
    'model_id': 'eleven_multilingual_v2',
    'languages': [
      {'language_id': 'en', 'name': 'English'},
      {'language_id': 'de', 'name': 'German'},
      {'language_id': ' ', 'name': 'Blank'},
      'not a map',
    ],
  },
];

Map<String, dynamic> _voice(
  String id, {
  String? category = 'premade',
  Map<String, dynamic> labels = const {},
  List<Object?>? verified,
}) => {
  'voice_id': id,
  'name': 'Voice $id',
  'category': ?category,
  'labels': labels,
  'verified_languages': ?verified,
};

void main() {
  setUpAll(registerAllFallbackValues);

  late MockDomainLogger logger;
  late List<http.Request> requests;

  setUp(() {
    logger = MockDomainLogger();
    requests = [];
  });

  ElevenLabsTtsService service(
    FutureOr<http.Response> Function(http.Request request) handler,
  ) => ElevenLabsTtsService(
    domainLogger: logger,
    httpClient: MockClient((request) async {
      requests.add(request);
      return handler(request);
    }),
  );

  Future<CloudTtsException> failure(Future<Object?> call) async {
    try {
      await call;
    } on CloudTtsException catch (error) {
      return error;
    }
    fail('expected a CloudTtsException');
  }

  List<String> loggedText() => [
    for (final call in verify(
      () => logger.log(any(), captureAny(), subDomain: 'ElevenLabsTts'),
    ).captured)
      call as String,
  ];

  group('synthesizeStream', () {
    Stream<Uint8List> stream(
      List<List<int>> pieces, {
      int status = 200,
      String model = 'eleven_v4_turbo',
    }) =>
        ElevenLabsTtsService(
          domainLogger: logger,
          httpClient: MockClient.streaming((request, _) async {
            requests.add(request as http.Request);
            return http.StreamedResponse(Stream.fromIterable(pieces), status);
          }),
        ).synthesizeStream(
          text: _text,
          voiceId: 'voice 1',
          baseUrl: _baseUrl,
          apiKey: _apiKey,
          model: model,
        );

    test('asks the stream endpoint for 24 kHz PCM and emits it as a WAV: '
        'a header of unknown length, then each piece in order', () async {
      final chunks = await stream([
        [1, 2, 3],
        [],
        [4, 5],
      ]).toList();

      expect(chunks, [
        wavHeader(24000),
        [1, 2, 3],
        [4, 5],
      ]);
      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://api.elevenlabs.io/v1/text-to-speech/voice%201/stream'
        '?output_format=pcm_24000',
      );
      expect(request.headers['xi-api-key'], _apiKey);
      expect(request.headers['Accept'], 'audio/pcm');
      expect(jsonDecode(request.body), {
        'text': _text,
        'model_id': 'eleven_v4_turbo',
      });
      // Lengths and ids are logged, never the text.
      final logged = loggedText();
      expect(logged, contains(startsWith('Streamed speech request')));
      expect(logged, isNot(contains(contains(_text))));
    });

    test(
      'a stream without audio emits nothing, not even the header',
      () async {
        expect(await stream([[], []]).toList(), isEmpty);
      },
    );

    test('a refused request fails as the unstreamed one does', () async {
      final error = await failure(
        stream([utf8.encode('{}')], status: 429).drain<void>(),
      );
      expect(error.failure, CloudTtsFailure.rateLimited);
    });

    test('nothing is sent for empty text, a missing voice or no key', () async {
      final eleven = service((_) => http.Response('', 200));
      Stream<Uint8List> ask({
        String text = 'Hi',
        String voiceId = 'v',
        String apiKey = _apiKey,
      }) => eleven.synthesizeStream(
        text: text,
        voiceId: voiceId,
        baseUrl: _baseUrl,
        apiKey: apiKey,
      );

      await expectLater(ask(text: '  ').drain<void>(), throwsArgumentError);
      await expectLater(ask(voiceId: '').drain<void>(), throwsArgumentError);
      await expectLater(ask(apiKey: '').drain<void>(), throwsArgumentError);
      expect(requests, isEmpty);
    });
  });

  group('synthesize', () {
    test('posts the text to the voice as 24 kHz WAV with the key in '
        'xi-api-key, and returns the audio', () async {
      final bytes =
          await service(
            (_) => http.Response.bytes(_wav, 200),
          ).synthesize(
            text: _text,
            voiceId: 'voice-1',
            baseUrl: _baseUrl,
            apiKey: _apiKey,
            model: 'eleven_flash_v2_5',
          );

      expect(bytes, _wav);
      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://api.elevenlabs.io/v1/text-to-speech/voice-1'
        '?output_format=wav_24000',
      );
      expect(request.headers['xi-api-key'], _apiKey);
      expect(request.headers['Accept'], 'audio/wav');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(request.body), {
        'text': _text,
        'model_id': 'eleven_flash_v2_5',
      });
    });

    test('speaks with the multilingual model unless told otherwise', () async {
      await service((_) => http.Response.bytes(_wav, 200)).synthesize(
        text: 'Hi',
        voiceId: 'v',
        baseUrl: _baseUrl,
        apiKey: _apiKey,
      );

      expect(
        (jsonDecode(requests.single.body) as Map)['model_id'],
        ElevenLabsTtsService.defaultModel,
      );
    });

    test('escapes the voice id in the path', () async {
      await service((_) => http.Response.bytes(_wav, 200)).synthesize(
        text: 'Hi',
        voiceId: 'a/b c',
        baseUrl: _baseUrl,
        apiKey: _apiKey,
      );

      expect(requests.single.url.path, '/v1/text-to-speech/a%2Fb%20c');
    });

    test('logs lengths and ids, never the text or the key', () async {
      await service((_) => http.Response.bytes(_wav, 200)).synthesize(
        text: _text,
        voiceId: 'voice-1',
        baseUrl: _baseUrl,
        apiKey: _apiKey,
      );

      final logged = loggedText();
      expect(logged.first, contains('${_text.length} chars'));
      expect(logged.first, contains('voice voice-1'));
      expect(logged.last, startsWith('Speech response: ${_wav.length} bytes'));
      for (final line in logged) {
        expect(line, isNot(contains('Grüß')));
        expect(line, isNot(contains(_apiKey)));
      }
    });

    test('an answer that is not WAV audio is an invalid response', () async {
      for (final body in [
        Uint8List(0),
        ascii.encode('RIFF'),
        ascii.encode('{"audio": "nope"}'),
        Uint8List.fromList([
          ...ascii.encode('RIFF'),
          0,
          0,
          0,
          0,
          ...ascii.encode('AVI '),
        ]),
      ]) {
        final error = await failure(
          service((_) => http.Response.bytes(body, 200)).synthesize(
            text: 'Hi',
            voiceId: 'v',
            baseUrl: _baseUrl,
            apiKey: _apiKey,
          ),
        );
        expect(error.failure, CloudTtsFailure.invalidResponse);
        expect(error.message, 'Speech response is not WAV audio');
      }
    });

    test(
      "a rejected key names ElevenLabs and keeps the server's reason",
      () async {
        final error = await failure(
          service(
            (_) => http.Response(
              jsonEncode({
                'detail': {
                  'status': 'quota_exceeded',
                  'message': 'This request exceeds your quota.',
                },
              }),
              401,
              headers: {'request-id': 'req-9'},
            ),
          ).synthesize(
            text: 'Hi',
            voiceId: 'v',
            baseUrl: _baseUrl,
            apiKey: _apiKey,
          ),
        );

        expect(error.failure, CloudTtsFailure.unauthorized);
        expect(error.message, 'The ElevenLabs API key was rejected');
        expect(error.apiError, 'This request exceeds your quota.');
        expect(error.requestId, 'req-9');
        verify(
          () => logger.error(
            LogDomain.speech,
            error,
            subDomain: 'ElevenLabsTts',
            message: any(named: 'message', that: endsWith('failed')),
          ),
        ).called(1);
      },
    );

    test('refuses empty arguments and plain HTTP before any request', () {
      final client = service((_) => http.Response.bytes(_wav, 200));
      for (final call in <Future<Uint8List> Function()>[
        () => client.synthesize(
          text: '  ',
          voiceId: 'v',
          baseUrl: _baseUrl,
          apiKey: _apiKey,
        ),
        () => client.synthesize(
          text: 'Hi',
          voiceId: '',
          baseUrl: _baseUrl,
          apiKey: _apiKey,
        ),
        () => client.synthesize(
          text: 'Hi',
          voiceId: 'v',
          baseUrl: _baseUrl,
          apiKey: '',
        ),
        () => client.synthesize(
          text: 'Hi',
          voiceId: 'v',
          baseUrl: 'http://api.elevenlabs.io/v1',
          apiKey: _apiKey,
        ),
      ]) {
        expect(call, throwsArgumentError);
      }
      expect(requests, isEmpty);
    });
  });

  group('fetchVoices', () {
    final fetchedAt = DateTime.utc(2026, 11, 4, 9);

    ElevenLabsTtsService catalogService({
      Object? models,
      Object? voices,
    }) => service(
      (request) => http.Response(
        jsonEncode(
          request.url.path.endsWith('/models')
              ? models ?? _models
              : voices ?? {'voices': <Object>[]},
        ),
        200,
      ),
    );

    Future<CloudVoiceCatalog> fetch(
      ElevenLabsTtsService client, {
      String model = 'eleven_multilingual_v2',
    }) => withClock(
      Clock.fixed(fetchedAt),
      () =>
          client.fetchVoices(baseUrl: _baseUrl, apiKey: _apiKey, model: model),
    );

    test("asks for the models and the voices with the account's key", () async {
      final catalog = await fetch(catalogService());

      expect(catalog.voices, isEmpty);
      expect(catalog.fetchedAt, fetchedAt);
      expect(
        [for (final r in requests) '${r.method} ${r.url}'],
        [
          'GET https://api.elevenlabs.io/v1/models',
          'GET https://api.elevenlabs.io/v1/voices',
        ],
      );
      for (final request in requests) {
        expect(request.headers['xi-api-key'], _apiKey);
        expect(request.headers['Accept'], 'application/json');
      }
    });

    test('offers every voice for every language of the model, with its '
        'gender, its labels as tags and its kind', () async {
      final catalog = await fetch(
        catalogService(
          voices: {
            'voices': [
              _voice(
                'rachel',
                labels: {
                  'gender': 'female',
                  'accent': 'american',
                  'descriptive': 'calm',
                  'age': 'middle_aged',
                  'use_case': 'social_media',
                  'language': 'en',
                  'empty': ' ',
                  'number': 3,
                },
              ),
              _voice('mine', category: 'cloned'),
              _voice('odd', category: null),
            ],
          },
        ),
      );

      expect(catalog.voices, [
        const CloudVoice(
          id: 'rachel',
          name: 'Voice rachel',
          gender: 'female',
          languages: ['en', 'de'],
          tags: ['american', 'calm', 'middle aged', 'social media'],
          type: CloudVoiceType.preset,
        ),
        const CloudVoice(
          id: 'mine',
          name: 'Voice mine',
          languages: ['en', 'de'],
          type: CloudVoiceType.custom,
        ),
        const CloudVoice(id: 'odd', name: 'Voice odd', languages: ['en', 'de']),
      ]);
      expect(catalog.resolve(languageCode: 'de')?.id, 'rachel');
    });

    test('a repeated label is one tag', () async {
      final catalog = await fetch(
        catalogService(
          voices: {
            'voices': [
              _voice(
                'v',
                labels: {'description': 'warm', 'descriptive': 'warm'},
              ),
            ],
          },
        ),
      );

      expect(catalog.voices.single.tags, ['warm']);
    });

    test('a model the account does not list offers each voice for the '
        'languages it was verified for', () async {
      final catalog = await fetch(
        catalogService(
          voices: {
            'voices': [
              _voice(
                'v',
                labels: {'language': 'fr'},
                verified: [
                  {'language': 'de', 'model_id': 'eleven_v3'},
                  {'language': ' '},
                  {'language': 7},
                  'not a map',
                ],
              ),
            ],
          },
        ),
        model: 'custom_model',
      );

      expect(catalog.voices.single.languages, ['de', 'fr']);
    });

    test('skips voices it cannot send or show, and says how many', () async {
      final catalog = await fetch(
        catalogService(
          voices: {
            'voices': [
              _voice('good'),
              {'name': 'No id'},
              {'voice_id': '', 'name': 'Empty id'},
              {'voice_id': 'no-name'},
              'not a map',
            ],
          },
        ),
      );

      expect(catalog.voices.map((v) => v.id), ['good']);
      expect(
        loggedText().last,
        'Voice catalog: 1 voices for eleven_multilingual_v2 in 2 languages, '
        '4 malformed entries skipped',
      );
    });

    test('bodies of the wrong shape are invalid responses', () async {
      final cases = <String, ElevenLabsTtsService>{
        'Models response is not a list': catalogService(
          models: {'models': _models},
        ),
        'Voices response has no voices list': catalogService(
          voices: {'voices': 'none'},
        ),
      };
      for (final MapEntry(key: message, value: client) in cases.entries) {
        final error = await failure(fetch(client));
        expect(error.failure, CloudTtsFailure.invalidResponse);
        expect(error.message, message);
      }
      final notAnObject = await failure(fetch(catalogService(voices: [1])));
      expect(notAnObject.message, 'Voices response has no voices list');
    });

    test('a failed model list fails the catalog before voices are asked '
        'for', () async {
      final error = await failure(
        fetch(service((_) => http.Response('', 503))),
      );

      expect(error.failure, CloudTtsFailure.server);
      expect(requests, hasLength(1));
    });

    test('rejects an empty key before any request', () {
      expect(
        () => catalogService().fetchVoices(
          baseUrl: _baseUrl,
          apiKey: '',
          model: 'eleven_multilingual_v2',
        ),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });
  });

  test('close closes the injected client', () {
    var closed = false;
    ElevenLabsTtsService(
      domainLogger: logger,
      httpClient: _ClosingClient(() => closed = true),
    ).close();
    expect(closed, isTrue);
  });
}

class _ClosingClient extends http.BaseClient {
  _ClosingClient(this.onClose);

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() => onClose();
}
