import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/repository/temporary_mp3_chat_audio_transcriber.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';

void main() {
  late Directory temporaryDirectory;
  var fileIndex = 0;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'lotti_chat_audio_test_',
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  File temporaryMp3([List<int> bytes = const [0x49, 0x44, 0x33, 1]]) {
    return File(
      '${temporaryDirectory.path}/temporary_${fileIndex++}.mp3',
    )..writeAsBytesSync(bytes);
  }

  const sourceBytes = [1, 2, 3, 4];
  const model = 'voxtral-small-2507';
  const baseUrl = 'https://api.example.com/v1';
  const apiKey = 'secret-key';
  const prompt = 'Transcribe this recording.';
  const mistralProvider = TemporaryMp3ChatAudioProvider(
    repositoryName: 'MistralInferenceRepository',
    displayName: 'Mistral',
    requestIdPrefix: 'mistral-audio-',
    payloadDialect: ChatAudioPayloadDialect.mistral,
  );

  final dialectCases =
      <
        ({
          ChatAudioPayloadDialect dialect,
          bool includeRequestId,
          Object expectedAudio,
          String name,
        })
      >[
        (
          dialect: ChatAudioPayloadDialect.openAi,
          includeRequestId: true,
          expectedAudio: {
            'data': base64Encode(const [0x49, 0x44, 0x33, 1]),
            'format': 'mp3',
          },
          name: 'OpenAI-compatible',
        ),
        (
          dialect: ChatAudioPayloadDialect.mistral,
          includeRequestId: false,
          expectedAudio: base64Encode(const [0x49, 0x44, 0x33, 1]),
          name: 'Mistral',
        ),
      ];

  for (final testCase in dialectCases) {
    test('${testCase.name} payload sends MP3 and cleans it up', () async {
      late http.Request capturedRequest;
      late File encodedFile;
      Uint8List? encoderInput;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'id': 'response-id',
            'created': 42,
            'model': model,
            'choices': [
              {
                'message': {'content': 'the transcript'},
              },
            ],
            'usage': {
              'prompt_tokens': 7,
              'completion_tokens': 3,
              'total_tokens': 10,
            },
          }),
          200,
        );
      });
      addTearDown(client.close);

      final chunks = await transcribeTemporaryMp3ChatAudio(
        httpClient: client,
        provider: TemporaryMp3ChatAudioProvider(
          repositoryName: '${testCase.name}Repository',
          displayName: testCase.name,
          requestIdPrefix: 'audio-request-',
          payloadDialect: testCase.dialect,
          includeRequestIdInBody: testCase.includeRequestId,
        ),
        model: model,
        audioBase64: base64Encode(sourceBytes),
        baseUrl: baseUrl,
        apiKey: apiKey,
        prompt: prompt,
        maxCompletionTokens: 512,
        audioToTemporaryMp3Encoder: (bytes) async {
          encoderInput = bytes;
          return encodedFile = temporaryMp3();
        },
      ).toList();

      expect(encoderInput, sourceBytes);
      expect(encodedFile.existsSync(), isFalse);
      expect(capturedRequest.url, Uri.parse('$baseUrl/chat/completions'));
      expect(capturedRequest.headers['authorization'], 'Bearer $apiKey');

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['model'], model);
      expect(body['stream'], isFalse);
      expect(body['temperature'], 0.0);
      expect(body['max_tokens'], 512);
      expect(body.containsKey('request_id'), testCase.includeRequestId);
      final messages = body['messages']! as List<dynamic>;
      final message = messages.single as Map<String, dynamic>;
      final content = message['content']! as List<dynamic>;
      final audioPart = content.first as Map<String, dynamic>;
      expect(audioPart['type'], 'input_audio');
      expect(audioPart['input_audio'], testCase.expectedAudio);
      expect(content.last, {'type': 'text', 'text': prompt});

      final chunk = chunks.single;
      expect(chunk.id, 'response-id');
      expect(chunk.choices?.single.delta?.content, 'the transcript');
      expect(chunk.usage?.promptTokens, 7);
      expect(chunk.usage?.completionTokens, 3);
      expect(chunk.usage?.totalTokens, 10);
    });
  }

  test('joins Mistral text content parts from a buffered response', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': [
                  {'type': 'text', 'text': 'first '},
                  {'type': 'text', 'text': 'second'},
                ],
              },
            },
          ],
        }),
        200,
      ),
    );
    addTearDown(client.close);

    final chunks = await transcribeTemporaryMp3ChatAudio(
      httpClient: client,
      provider: mistralProvider,
      model: model,
      audioBase64: base64Encode(sourceBytes),
      baseUrl: baseUrl,
      apiKey: apiKey,
      prompt: prompt,
      audioToTemporaryMp3Encoder: (_) async => temporaryMp3(),
    ).toList();

    expect(chunks.single.choices?.single.delta?.content, 'first second');
  });

  test('provider failures preserve detail and remove the MP3', () async {
    late File encodedFile;
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {'message': 'audio input rejected'},
        }),
        422,
      ),
    );
    addTearDown(client.close);

    await expectLater(
      transcribeTemporaryMp3ChatAudio(
        httpClient: client,
        provider: mistralProvider,
        model: model,
        audioBase64: base64Encode(sourceBytes),
        baseUrl: baseUrl,
        apiKey: apiKey,
        prompt: prompt,
        audioToTemporaryMp3Encoder: (_) async {
          return encodedFile = temporaryMp3();
        },
      ).toList(),
      throwsA(
        isA<TranscriptionException>()
            .having((error) => error.statusCode, 'statusCode', 422)
            .having(
              (error) => error.message,
              'message',
              allOf(
                contains('HTTP 422: audio input rejected'),
                contains('request mistral-audio-'),
              ),
            ),
      ),
    );

    expect(encodedFile.existsSync(), isFalse);
  });

  final longRawErrorBody = List.filled(250, 'x').join();
  final errorResponseCases = <({String body, String expected, String name})>[
    (
      body: jsonEncode({'error': 'plain provider error'}),
      expected: 'plain provider error',
      name: 'a string error',
    ),
    (
      body: jsonEncode({'message': 'top-level provider message'}),
      expected: 'top-level provider message',
      name: 'a top-level message',
    ),
    (
      body: longRawErrorBody,
      expected: '${longRawErrorBody.substring(0, 240)}...',
      name: 'a clipped raw body',
    ),
  ];

  for (final testCase in errorResponseCases) {
    test('provider failures preserve ${testCase.name}', () async {
      late File encodedFile;
      final client = MockClient(
        (_) async => http.Response(testCase.body, 400),
      );
      addTearDown(client.close);

      await expectLater(
        transcribeTemporaryMp3ChatAudio(
          httpClient: client,
          provider: mistralProvider,
          model: model,
          audioBase64: base64Encode(sourceBytes),
          baseUrl: baseUrl,
          apiKey: apiKey,
          prompt: prompt,
          audioToTemporaryMp3Encoder: (_) async {
            return encodedFile = temporaryMp3();
          },
        ).toList(),
        throwsA(
          isA<TranscriptionException>().having(
            (error) => error.message,
            'message',
            contains(testCase.expected),
          ),
        ),
      );

      expect(encodedFile.existsSync(), isFalse);
    });
  }

  test('cleanup failure does not mask a successful transcription', () async {
    late File encodedFile;
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'the transcript'},
            },
          ],
        }),
        200,
      ),
    );
    addTearDown(client.close);

    final chunks = await transcribeTemporaryMp3ChatAudio(
      httpClient: client,
      provider: mistralProvider,
      model: model,
      audioBase64: base64Encode(sourceBytes),
      baseUrl: baseUrl,
      apiKey: apiKey,
      prompt: prompt,
      audioToTemporaryMp3Encoder: (_) async {
        return encodedFile = temporaryMp3();
      },
      temporaryFileDeleter: (_) {
        throw const FileSystemException('delete failed');
      },
    ).toList();

    expect(chunks.single.choices?.single.delta?.content, 'the transcript');
    expect(encodedFile.existsSync(), isTrue);
  });

  test('request timeout signals HTTP abortion and removes the MP3', () {
    fakeAsync((async) {
      http.AbortableRequest? capturedRequest;
      final client = MockClient.streaming((request, _) {
        capturedRequest = request as http.AbortableRequest;
        return Completer<http.StreamedResponse>().future;
      });
      late File encodedFile;
      Object? failure;
      var completed = false;
      var aborted = false;

      transcribeTemporaryMp3ChatAudio(
        httpClient: client,
        provider: mistralProvider,
        model: model,
        audioBase64: base64Encode(sourceBytes),
        baseUrl: baseUrl,
        apiKey: apiKey,
        prompt: prompt,
        timeout: const Duration(seconds: 1),
        audioToTemporaryMp3Encoder: (_) async {
          return encodedFile = temporaryMp3();
        },
        temporaryFileReader: (_) async => Uint8List.fromList([1, 2, 3]),
      ).toList().then<void>(
        (_) {
          completed = true;
        },
        onError: (Object error, StackTrace _) {
          failure = error;
          completed = true;
        },
      );

      async.flushMicrotasks();
      capturedRequest!.abortTrigger!.then((_) => aborted = true);
      async.flushMicrotasks();
      expect(aborted, isFalse);
      expect(completed, isFalse);

      async
        ..elapse(const Duration(seconds: 1))
        ..flushMicrotasks();

      expect(aborted, isTrue);
      expect(completed, isTrue);
      expect(
        failure,
        isA<TranscriptionException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('timed out'),
            contains('waiting for the Voxtral response'),
          ),
        ),
      );
      expect(encodedFile.existsSync(), isFalse);
      client.close();
    });
  });

  test('stream cancellation aborts the request and removes the MP3', () async {
    final requestStarted = Completer<http.AbortableRequest>();
    final responseCompleter = Completer<http.StreamedResponse>();
    final cleanupCompleted = Completer<void>();
    final client = MockClient.streaming((request, _) {
      final abortableRequest = request as http.AbortableRequest;
      requestStarted.complete(abortableRequest);
      abortableRequest.abortTrigger!.then((_) {
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(
            http.RequestAbortedException(request.url),
          );
        }
      });
      return responseCompleter.future;
    });
    addTearDown(client.close);
    late File encodedFile;
    Object? failure;

    final subscription = transcribeTemporaryMp3ChatAudio(
      httpClient: client,
      provider: mistralProvider,
      model: model,
      audioBase64: base64Encode(sourceBytes),
      baseUrl: baseUrl,
      apiKey: apiKey,
      prompt: prompt,
      audioToTemporaryMp3Encoder: (_) async {
        return encodedFile = temporaryMp3();
      },
      temporaryFileReader: (_) async => Uint8List.fromList([1, 2, 3]),
      temporaryFileDeleter: (file) {
        file.deleteSync();
        cleanupCompleted.complete();
      },
    ).listen((_) {}, onError: (Object error) => failure = error);

    final request = await requestStarted.future;
    expect(request.abortTrigger, isNotNull);

    await subscription.cancel();
    await request.abortTrigger;
    await cleanupCompleted.future;

    expect(failure, isNull);
    expect(encodedFile.existsSync(), isFalse);
  });

  test('rejects malformed input audio before MP3 encoding', () async {
    var encoderCalled = false;
    final client = MockClient((_) async => http.Response('', 200));
    addTearDown(client.close);

    await expectLater(
      transcribeTemporaryMp3ChatAudio(
        httpClient: client,
        provider: mistralProvider,
        model: model,
        audioBase64: '%%%',
        baseUrl: baseUrl,
        apiKey: apiKey,
        prompt: prompt,
        audioToTemporaryMp3Encoder: (_) async {
          encoderCalled = true;
          return temporaryMp3();
        },
      ).toList(),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Audio data must be valid base64'),
        ),
      ),
    );

    expect(encoderCalled, isFalse);
  });
}
