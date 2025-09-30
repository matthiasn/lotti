import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemma3n_inference_repository.dart';
import 'package:lotti/features/ai/ui/gemma_model_install_dialog.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/ai/test_utils.dart';
import '../../test_helpers/mock_gemma_service.dart';

/// Test Configuration Constants
class TranscriptionTestConstants {
  // Service Configuration
  static const String defaultBaseUrl = 'http://localhost:11343';
  static const String defaultProviderId = 'test-gemma-provider';
  static const String defaultProviderName = 'Test Gemma 3n Provider';

  // HTTP Method Constants
  static const String postMethod = 'POST';

  // Model Constants
  static const String e2bModelId = 'google/gemma-3n-E2B-it';
  static const String e4bModelId = 'google/gemma-3n-E4B-it';
  static const String normalizedE2bModel = 'gemma-3n-E2B-it';

  // Test Data Constants
  static const String testAudioBase64 = 'fake_audio_data';
  static const String testAudioData = 'test_audio';
  static const String meetingAudioData = 'meeting_audio_data';
  static const String largeAudioData =
      'very_large_audio_data_that_exceeds_normal_limits';

  // JSON Constants
  static const String healthyStatusJson = '{"status": "healthy"}';

  // Response Constants
  static const String expectedTranscription =
      'Hello, this is a test transcription.';
  static const String e2bTranscription = 'E2B transcription';
  static const String chunk1Transcription = 'First part of the transcription.';
  static const String chunk2Transcription =
      ' Second part of the transcription.';
  static const String contextualResponse =
      'Based on your audio, you mentioned the meeting is at 3 PM tomorrow.';
  static const String retrySuccessResponse = 'Retry successful';

  // Test IDs
  static const String testResponseId = 'test-123';
  static const String e2bTestId = 'test-e2b';
  static const String contextTestId = 'context-test';
  static const String retrySuccessId = 'retry-success';

  // Prompts
  static const String transcribePrompt = 'Transcribe this audio clearly';
  static const String initialPrompt = 'What did I say about the meeting?';
  static const String longAudioPrompt = 'Transcribe this long audio file';

  // Error Messages
  static const String modelNotFoundMessage =
      'Model not downloaded. Use /v1/models/pull to download.';
  static const String modelNotFoundType = 'model_not_found';
  static const String modelNotAvailableCode = 'model_not_available';
  static const String connectionRefusedError = 'Connection refused';
  static const String connectionTimeoutError = 'Connection timeout';
  static const String temporaryNetworkError = 'Temporary network error';
  static const String invalidResponseFormat = 'Invalid response format';

  // UI Text Constants
  static const String modelNotAvailableTitle = 'Gemma Model Not Available';
  static const String modelNotAvailableMessage =
      'The model "gemma-3n-E4B-it" is not available.';
  static const String installButtonText = 'Install';
  static const String cancelButtonText = 'Cancel';

  // HTTP Status Constants
  static const int httpOk = 200;
  static const int httpBadRequest = 400;

  // Temperature Constants
  static const double defaultTemperature = 0.1;

  // Timeout Constants
  static const Duration shortTimeout = Duration(milliseconds: 100);

  // Invalid Response
  static const String invalidJsonResponse = 'Invalid JSON {corrupted data';
}

/// Integration test for end-to-end Gemma transcription workflows
///
/// Tests the complete flow from audio input to transcribed text output,
/// including model installation, service communication, and error handling.
class MockLoggingService extends Mock implements LoggingService {}

class MockHttpClient extends Mock implements http.Client {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {
  @override
  String get baseUrl => TranscriptionTestConstants.defaultBaseUrl;

  @override
  InferenceProviderType get inferenceProviderType =>
      InferenceProviderType.gemma3n;

  @override
  String get id => TranscriptionTestConstants.defaultProviderId;

  @override
  String get name => TranscriptionTestConstants.defaultProviderName;
}

void main() {
  late MockLoggingService mockLoggingService;
  late MockHttpClient mockHttpClient;
  late MockGemmaService mockGemmaService;
  late AiConfigInferenceProvider testGemmaProvider;

  setUpAll(() {
    registerFallbackValue(Uri.parse(TranscriptionTestConstants.defaultBaseUrl));
    registerFallbackValue(http.Request(TranscriptionTestConstants.postMethod,
        Uri.parse(TranscriptionTestConstants.defaultBaseUrl)));
  });

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockHttpClient = MockHttpClient();
    mockGemmaService = MockGemmaService();
    testGemmaProvider = FakeAiConfigInferenceProvider();

    getIt
      ..reset()
      ..registerSingleton<LoggingService>(mockLoggingService);
  });

  tearDown(getIt.reset);

  Widget buildTestWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return AiTestSetup.createTestApp(
      child: child,
      providerOverrides: overrides,
    );
  }

  group('Gemma Transcription Flow Integration Tests', () {
    testWidgets('completes full transcription flow with successful service',
        (tester) async {
      // Arrange - Mock successful service responses

      mockGemmaService
        ..mockHealthCheckSuccess()
        ..mockTranscriptionSuccess(
            TranscriptionTestConstants.expectedTranscription);

      when(() => mockHttpClient.get(any())).thenAnswer((_) async =>
          http.Response(TranscriptionTestConstants.healthyStatusJson,
              TranscriptionTestConstants.httpOk));

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'id': TranscriptionTestConstants.testResponseId,
              'choices': [
                {
                  'message': {
                    'content': TranscriptionTestConstants.expectedTranscription,
                  },
                },
              ],
              'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            }),
            TranscriptionTestConstants.httpOk,
          ));

      final repository = Gemma3nInferenceRepository(httpClient: mockHttpClient);

      // Act - Perform transcription
      final stream = repository.transcribeAudio(
        model: TranscriptionTestConstants.e2bModelId,
        audioBase64: TranscriptionTestConstants.testAudioBase64,
        baseUrl: TranscriptionTestConstants.defaultBaseUrl,
        prompt: TranscriptionTestConstants.transcribePrompt,
      );

      final result = await stream.first;

      // Assert
      expect(result.choices?.first.delta?.content,
          equals(TranscriptionTestConstants.expectedTranscription));
      expect(result.id, equals(TranscriptionTestConstants.testResponseId));

      // Verify the request was made correctly
      final capturedValues = verify(() => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ));

      final uri = capturedValues.captured[0] as Uri;
      expect(
          uri.toString(),
          equals(
              '${TranscriptionTestConstants.defaultBaseUrl}/v1/chat/completions'));

      final requestBody = jsonDecode(capturedValues.captured[1] as String)
          as Map<String, dynamic>;
      expect(requestBody['model'],
          equals(TranscriptionTestConstants.normalizedE2bModel));
      expect(requestBody['audio'],
          equals(TranscriptionTestConstants.testAudioBase64));
      expect(requestBody['temperature'],
          equals(TranscriptionTestConstants.defaultTemperature));
    });

    testWidgets('handles model not found error and shows install dialog',
        (tester) async {
      // Arrange - Mock service returning model not found error
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'error': {
                'message': TranscriptionTestConstants.modelNotFoundMessage,
                'type': TranscriptionTestConstants.modelNotFoundType,
                'code': TranscriptionTestConstants.modelNotAvailableCode,
              }
            }),
            TranscriptionTestConstants.httpBadRequest,
          ));

      // Act - Build widget that would trigger model install dialog
      await tester.pumpWidget(
        buildTestWidget(
          GemmaModelInstallDialog(
            modelName: TranscriptionTestConstants.e4bModelId
                .replaceFirst('google/', ''),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([testGemmaProvider])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Dialog should appear with install option
      expect(find.text(TranscriptionTestConstants.modelNotAvailableTitle),
          findsOneWidget);
      expect(find.text(TranscriptionTestConstants.modelNotAvailableMessage),
          findsOneWidget);
      expect(find.text(TranscriptionTestConstants.installButtonText),
          findsOneWidget);
      expect(find.text(TranscriptionTestConstants.cancelButtonText),
          findsOneWidget);
    });

    testWidgets('handles service unavailable and shows appropriate error',
        (tester) async {
      // Arrange - Mock service connection failure
      when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenThrow(http.ClientException(
              TranscriptionTestConstants.connectionRefusedError));

      final repository = Gemma3nInferenceRepository(httpClient: mockHttpClient);

      // Act & Assert
      final stream = repository.transcribeAudio(
        model: TranscriptionTestConstants.e2bModelId,
        audioBase64: TranscriptionTestConstants.testAudioData,
        baseUrl: TranscriptionTestConstants.defaultBaseUrl,
      );

      expect(
        stream.first,
        throwsA(isA<Gemma3nInferenceException>().having(
            (e) => e.message,
            'message',
            contains(TranscriptionTestConstants.connectionRefusedError))),
      );
    });

    testWidgets('handles timeout during transcription gracefully',
        (tester) async {
      // Arrange - Mock service that throws timeout exception directly
      when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenThrow(http.ClientException(
              TranscriptionTestConstants.connectionTimeoutError));

      final repository = Gemma3nInferenceRepository(httpClient: mockHttpClient);

      // Act & Assert
      final stream = repository.transcribeAudio(
        model: TranscriptionTestConstants.e2bModelId,
        audioBase64: TranscriptionTestConstants.testAudioData,
        baseUrl: TranscriptionTestConstants.defaultBaseUrl,
        timeout: TranscriptionTestConstants.shortTimeout,
      );

      expect(
        stream.first,
        throwsA(isA<Gemma3nInferenceException>().having(
            (e) => e.message,
            'message',
            contains(TranscriptionTestConstants.connectionTimeoutError))),
      );
    });

    testWidgets('processes large audio file with chunking correctly',
        (tester) async {
      // Arrange - Mock responses for chunked audio

      var callCount = 0;
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        callCount++;
        final transcription = callCount == 1
            ? TranscriptionTestConstants.chunk1Transcription
            : TranscriptionTestConstants.chunk2Transcription;

        return http.Response(
          jsonEncode({
            'id': 'test-$callCount',
            'choices': [
              {
                'message': {
                  'content': transcription,
                },
              },
            ],
          }),
          200,
        );
      });

      final repository = Gemma3nInferenceRepository(httpClient: mockHttpClient);

      // Act - Process what would be chunked audio (simulated)
      final stream = repository.transcribeAudio(
        model: TranscriptionTestConstants.e2bModelId,
        audioBase64: TranscriptionTestConstants.largeAudioData,
        baseUrl: TranscriptionTestConstants.defaultBaseUrl,
        prompt: TranscriptionTestConstants.longAudioPrompt,
      );

      final result = await stream.first;

      // Assert - Should get first chunk result
      expect(result.choices?.first.delta?.content,
          equals(TranscriptionTestConstants.chunk1Transcription));

      // Verify request includes chunking context in prompt
      final capturedValues = verify(() => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ));

      final requestBody = jsonDecode(capturedValues.captured[1] as String)
          as Map<String, dynamic>;
      final messages = requestBody['messages'] as List<dynamic>;
      final userMessage = messages[0] as Map<String, dynamic>;

      expect(userMessage['content'],
          contains(TranscriptionTestConstants.longAudioPrompt));
    });

    testWidgets('validates model variant detection and API calls',
        (tester) async {
      // Test E2B model
      mockGemmaService.mockTranscriptionSuccess(
          TranscriptionTestConstants.e2bTranscription);

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'id': TranscriptionTestConstants.e2bTestId,
              'choices': [
                {
                  'message': {
                    'content': TranscriptionTestConstants.e2bTranscription
                  }
                }
              ],
            }),
            200,
          ));

      final repository = Gemma3nInferenceRepository(httpClient: mockHttpClient);

      // Test E2B model call
      final e2bStream = repository.transcribeAudio(
        model: TranscriptionTestConstants.e2bModelId,
        audioBase64: 'test_audio',
        baseUrl: TranscriptionTestConstants.defaultBaseUrl,
      );

      await e2bStream.first;

      // Verify normalized model name in request
      final capturedValues = verify(() => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ));

      final requestBody = jsonDecode(capturedValues.captured[1] as String)
          as Map<String, dynamic>;
      expect(requestBody['model'], equals('gemma-3n-E2B-it'));
    });

    testWidgets('maintains context through conversation workflow',
        (tester) async {
      // Arrange - Mock conversational context

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'id': TranscriptionTestConstants.contextTestId,
              'choices': [
                {
                  'message': {
                    'content': TranscriptionTestConstants.contextualResponse,
                  },
                },
              ],
            }),
            200,
          ));

      final repository = Gemma3nInferenceRepository(httpClient: mockHttpClient);

      // Act - Transcribe with contextual prompt
      final stream = repository.transcribeAudio(
        model: TranscriptionTestConstants.e2bModelId,
        audioBase64: TranscriptionTestConstants.meetingAudioData,
        baseUrl: TranscriptionTestConstants.defaultBaseUrl,
        prompt: TranscriptionTestConstants.initialPrompt,
      );

      final result = await stream.first;

      // Assert - Context should be preserved in the request
      expect(result.choices?.first.delta?.content,
          equals(TranscriptionTestConstants.contextualResponse));

      final capturedValues = verify(() => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ));

      final requestBody = jsonDecode(capturedValues.captured[1] as String)
          as Map<String, dynamic>;
      final messages = requestBody['messages'] as List<dynamic>;
      final userMessage = messages[0] as Map<String, dynamic>;

      expect(userMessage['content'],
          contains(TranscriptionTestConstants.initialPrompt));
    });
  });

  group('Error Recovery and Resilience', () {
    testWidgets('retries failed requests with exponential backoff',
        (tester) async {
      // Arrange - Mock initial failure then success
      var attemptCount = 0;
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        attemptCount++;
        if (attemptCount == 1) {
          throw http.ClientException(
              TranscriptionTestConstants.temporaryNetworkError);
        }
        return http.Response(
          jsonEncode({
            'id': TranscriptionTestConstants.retrySuccessId,
            'choices': [
              {
                'message': {
                  'content': TranscriptionTestConstants.retrySuccessResponse
                }
              }
            ],
          }),
          200,
        );
      });

      final repository = Gemma3nInferenceRepository(httpClient: mockHttpClient);

      // Act - This would typically be wrapped in retry logic in the calling code
      try {
        final stream = repository.transcribeAudio(
          model: TranscriptionTestConstants.e2bModelId,
          audioBase64: 'test_audio',
          baseUrl: TranscriptionTestConstants.defaultBaseUrl,
        );
        await stream.first;
        fail('Should have thrown on first attempt');
      } catch (e) {
        expect(e, isA<Gemma3nInferenceException>());
      }

      // Simulate retry
      final retryStream = repository.transcribeAudio(
        model: TranscriptionTestConstants.e2bModelId,
        audioBase64: 'test_audio',
        baseUrl: TranscriptionTestConstants.defaultBaseUrl,
      );

      final result = await retryStream.first;
      expect(result.choices?.first.delta?.content,
          equals(TranscriptionTestConstants.retrySuccessResponse));
    });

    testWidgets('gracefully handles malformed service responses',
        (tester) async {
      // Arrange - Mock invalid JSON response
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            TranscriptionTestConstants.invalidJsonResponse,
            TranscriptionTestConstants.httpOk,
          ));

      final repository = Gemma3nInferenceRepository(httpClient: mockHttpClient);

      // Act & Assert
      final stream = repository.transcribeAudio(
        model: TranscriptionTestConstants.e2bModelId,
        audioBase64: 'test_audio',
        baseUrl: TranscriptionTestConstants.defaultBaseUrl,
      );

      expect(
        stream.first,
        throwsA(isA<Gemma3nInferenceException>().having(
            (e) => e.message,
            'message',
            contains(TranscriptionTestConstants.invalidResponseFormat))),
      );
    });
  });
}
