import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/gemma_inference_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late GemmaInferenceRepository repository;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = GemmaInferenceRepository(httpClient: mockHttpClient);
  });

  tearDown(() {
    mockHttpClient.close();
  });

  group('GemmaInferenceRepository Basic Tests', () {
    const baseUrl = 'http://localhost:11343';


    group('Model Availability', () {
      test('isModelAvailable returns true when models exist', () async {
        // Arrange
        when(() => mockHttpClient.get(
              Uri.parse('$baseUrl/v1/models'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({
                'data': [
                  {'id': 'google/gemma-2b-it', 'object': 'model'},
                ]
              }),
              200,
            ));

        // Act
        final result = await repository.isModelAvailable(baseUrl);

        // Assert
        expect(result, isTrue);
        verify(() => mockHttpClient.get(Uri.parse('$baseUrl/v1/models')))
            .called(1);
      });

      test('isModelAvailable returns false when no models available', () async {
        // Arrange
        when(() => mockHttpClient.get(
              Uri.parse('$baseUrl/v1/models'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'data': <dynamic>[]}),
              200,
            ));

        // Act
        final result = await repository.isModelAvailable(baseUrl);

        // Assert
        expect(result, isFalse);
      });

      test('isModelAvailable returns false on network error', () async {
        // Arrange
        when(() => mockHttpClient.get(any()))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await repository.isModelAvailable(baseUrl);

        // Assert
        expect(result, isFalse);
      });
    });

    group('Model Warm-up', () {
      test('warmUpModel completes successfully', () async {
        // Arrange
        when(() => mockHttpClient.post(
                  Uri.parse('$baseUrl/v1/models/load'),
                  headers: {'Content-Type': 'application/json'},
                ))
            .thenAnswer(
                (_) async => http.Response('{"status": "loaded"}', 200));

        // Act & Assert - Should not throw
        await repository.warmUpModel(baseUrl);

        verify(() => mockHttpClient.post(
              Uri.parse('$baseUrl/v1/models/load'),
              headers: {'Content-Type': 'application/json'},
            )).called(1);
      });

      test('warmUpModel handles errors gracefully', () async {
        // Arrange
        when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('Server error'));

        // Act & Assert - Should not throw, just log warning internally
        await repository.warmUpModel(baseUrl);
      });
    });

    group('Model Classes', () {
      test('ModelNotInstalledException creates correct error message', () {
        // Arrange
        const modelName = 'google/gemma-2b-it';
        const exception = ModelNotInstalledException(modelName);

        // Assert
        expect(exception.modelName, equals(modelName));
        expect(
            exception.toString(),
            equals(
                'Gemma model "$modelName" is not downloaded. Please install it first.'));
      });

      test('GemmaPullProgress calculates progress correctly', () {
        // Arrange
        const progress = GemmaPullProgress(
          status: 'downloading',
          total: 1000,
          completed: 750,
          progress: 0.75,
        );

        // Assert
        expect(progress.status, equals('downloading'));
        expect(progress.total, equals(1000));
        expect(progress.completed, equals(750));
        expect(progress.progress, equals(0.75));
        expect(progress.progressPercentage, equals('75.0%'));
      });

      test('GemmaPullProgress formats download progress correctly', () {
        // Arrange - 1MB total, 512KB completed
        const progress = GemmaPullProgress(
          status: 'downloading',
          total: 1048576, // 1MB in bytes
          completed: 524288, // 512KB in bytes
          progress: 0.5,
        );

        // Assert
        final downloadProgress = progress.downloadProgress;
        expect(downloadProgress, contains('downloading'));
        expect(downloadProgress, contains('0.5 MB / 1.0 MB'));
        expect(downloadProgress, contains('50.0%'));
      });

      test('GemmaPullProgress handles zero total correctly', () {
        // Arrange
        const progress = GemmaPullProgress(
          status: 'initializing',
          total: 0,
          completed: 0,
          progress: 0,
        );

        // Assert
        expect(progress.downloadProgress, equals('initializing'));
      });
    });

    group('Repository Creation', () {
      test('repository can be created with custom HTTP client', () {
        // Act
        final customRepository =
            GemmaInferenceRepository(httpClient: mockHttpClient);

        // Assert
        expect(customRepository, isNotNull);
      });

      test('repository can be created with default HTTP client', () {
        // Act
        final defaultRepository = GemmaInferenceRepository();

        // Assert
        expect(defaultRepository, isNotNull);
      });
    });
  });
}
