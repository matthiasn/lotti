import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ollama/ollama.dart';

class MockOllama extends Mock implements Ollama {}

void main() {
  final createdAt = DateTime.now();
  const model = 'deepseek-r1:8b';

  group('OllamaRepository', () {
    late MockOllama mockOllama;
    late OllamaRepository repository;

    setUp(() {
      mockOllama = MockOllama();
      repository = OllamaRepository(ollama: mockOllama);
    });

    test('generate calls Ollama.generate with correct parameters', () {
      // Arrange
      const prompt = 'test prompt';
      const system = 'test system';
      const temperature = 0.7;
      final images = ['image1.jpg', 'image2.jpg'];

      when(
        () => mockOllama.generate(
          any(),
          model: any(named: 'model'),
          system: any(named: 'system'),
          options: any(named: 'options'),
          images: any(named: 'images'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CompletionChunk(
            text: 'test',
            model: model,
            createdAt: createdAt,
          ),
        ]),
      );

      // Act
      repository.generate(
        prompt,
        model: model,
        system: system,
        temperature: temperature,
        images: images,
      );

      // Assert
      verify(
        () => mockOllama.generate(
          prompt,
          model: model,
          system: system,
          options: any(named: 'options'),
          images: images,
        ),
      ).called(1);
    });

    test('generate returns stream from Ollama.generate', () async {
      // Arrange
      final expectedChunks = [
        CompletionChunk(
          text: 'Hello',
          createdAt: createdAt,
          model: model,
        ),
        CompletionChunk(
          text: 'World',
          createdAt: createdAt,
          model: model,
        ),
      ];

      when(
        () => mockOllama.generate(
          any(),
          model: any(named: 'model'),
          system: any(named: 'system'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) => Stream.fromIterable(expectedChunks));

      // Act
      final stream = repository.generate(
        'prompt',
        model: 'model',
        system: 'system',
        temperature: 0.5,
      );

      // Assert
      expect(stream, emitsInOrder(expectedChunks));
    });

    test('ollamaRepository provider creates instance without parameters', () {
      final container = ProviderContainer();
      final repository = container.read(ollamaRepositoryProvider);

      expect(repository, isA<OllamaRepository>());
    });
  });
}
