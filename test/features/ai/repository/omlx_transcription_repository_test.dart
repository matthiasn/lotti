import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/repository/omlx_transcription_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/util/known_models.dart';

({http.Client client, http.BaseRequest? Function() captured})
_stubStreamingOk() {
  http.BaseRequest? captured;
  final client = MockClient.streaming((request, _) async {
    captured = request;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'text': 'local transcript'}))),
      200,
    );
  });
  return (client: client, captured: () => captured);
}

void main() {
  group('OmlxTranscriptionRepository', () {
    const baseUrl = 'http://127.0.0.1:8003/v1';
    const apiKey = 'omlx-local-key';
    final audioBase64 = base64Encode([1, 2, 3, 4]);

    group('isOmlxTranscriptionModel', () {
      test('matches Whisper and ASR model names', () {
        expect(
          OmlxTranscriptionRepository.isOmlxTranscriptionModel(
            omlxWhisperLargeV3ModelId,
          ),
          isTrue,
        );
        expect(
          OmlxTranscriptionRepository.isOmlxTranscriptionModel(
            'Whisper-large-v3-MLX',
          ),
          isTrue,
        );
        expect(
          OmlxTranscriptionRepository.isOmlxTranscriptionModel('qwen3-asr'),
          isTrue,
        );
      });

      test('does not match regular oMLX chat or vision models', () {
        expect(
          OmlxTranscriptionRepository.isOmlxTranscriptionModel(
            omlxQwen36A35bA3b4BitModelId,
          ),
          isFalse,
        );
        expect(
          OmlxTranscriptionRepository.isOmlxTranscriptionModel(
            omlxGemma426BA4BItQatMlx4BitModelId,
          ),
          isFalse,
        );
      });
    });

    test('throws ArgumentError for empty required fields', () {
      final repo = OmlxTranscriptionRepository();

      expect(
        () => repo.transcribeAudio(
          model: '',
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          apiKey: apiKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.transcribeAudio(
          model: omlxWhisperLargeV3ModelId,
          audioBase64: '',
          baseUrl: baseUrl,
          apiKey: apiKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.transcribeAudio(
          model: omlxWhisperLargeV3ModelId,
          audioBase64: audioBase64,
          baseUrl: '',
          apiKey: apiKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.transcribeAudio(
          model: omlxWhisperLargeV3ModelId,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          apiKey: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'sends multipart request to configured oMLX transcription endpoint',
      () async {
        final stub = _stubStreamingOk();
        final repo = OmlxTranscriptionRepository(httpClient: stub.client);
        addTearDown(repo.close);

        final chunks = await repo
            .transcribeAudio(
              model: omlxWhisperLargeV3ModelId,
              audioBase64: audioBase64,
              baseUrl: baseUrl,
              apiKey: apiKey,
              prompt: 'Use these vocabulary hints.',
            )
            .toList();

        expect(chunks, hasLength(1));
        expect(chunks.single.id, startsWith('omlx-transcription-'));
        expect(
          chunks.single.choices?.single.delta?.content,
          equals('local transcript'),
        );

        expect(stub.captured(), isA<http.MultipartRequest>());
        final request = stub.captured()! as http.MultipartRequest;
        expect(request.method, equals('POST'));
        expect(
          request.url.toString(),
          equals('$baseUrl/audio/transcriptions'),
        );
        expect(request.headers['Authorization'], equals('Bearer $apiKey'));
        expect(request.fields['model'], equals(omlxWhisperLargeV3ModelId));
        expect(request.fields['response_format'], equals('json'));
        expect(request.fields['prompt'], equals('Use these vocabulary hints.'));
        expect(request.files, hasLength(1));
        expect(request.files.single.field, equals('file'));
        expect(request.files.single.filename, equals('audio.m4a'));
      },
    );

    test('does not send blank prompt field', () async {
      final stub = _stubStreamingOk();
      final repo = OmlxTranscriptionRepository(httpClient: stub.client);
      addTearDown(repo.close);

      await repo
          .transcribeAudio(
            model: omlxWhisperLargeV3ModelId,
            audioBase64: audioBase64,
            baseUrl: '$baseUrl/',
            apiKey: apiKey,
            prompt: '   ',
          )
          .toList();

      expect(stub.captured(), isA<http.MultipartRequest>());
      final request = stub.captured()! as http.MultipartRequest;
      expect(request.url.toString(), '$baseUrl/audio/transcriptions');
      expect(request.fields.containsKey('prompt'), isFalse);
    });

    test('trims non-blank prompt field', () async {
      final stub = _stubStreamingOk();
      final repo = OmlxTranscriptionRepository(httpClient: stub.client);
      addTearDown(repo.close);

      await repo
          .transcribeAudio(
            model: omlxWhisperLargeV3ModelId,
            audioBase64: audioBase64,
            baseUrl: baseUrl,
            apiKey: apiKey,
            prompt: '  domain vocabulary  ',
          )
          .toList();

      expect(stub.captured(), isA<http.MultipartRequest>());
      final request = stub.captured()! as http.MultipartRequest;
      expect(request.fields['prompt'], 'domain vocabulary');
    });

    test('surfaces structured provider errors', () async {
      final repo = OmlxTranscriptionRepository(
        httpClient: MockClient.streaming((_, _) async {
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'error': {'message': 'API key required'},
                }),
              ),
            ),
            401,
          );
        }),
      );
      addTearDown(repo.close);

      await expectLater(
        repo
            .transcribeAudio(
              model: omlxWhisperLargeV3ModelId,
              audioBase64: audioBase64,
              baseUrl: baseUrl,
              apiKey: apiKey,
            )
            .toList(),
        throwsA(
          isA<TranscriptionException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'API key required'),
        ),
      );
    });
  });
}
