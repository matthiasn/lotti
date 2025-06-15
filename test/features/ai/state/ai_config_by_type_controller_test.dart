import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

// Generic listener class to track when providers notify their listeners
class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  // Setup for all tests
  setUpAll(() {
    // Create a fallback AiConfig instance that Mocktail can use
    final fallbackConfig = AiConfig.inferenceProvider(
      id: 'fallback-id',
      baseUrl: 'https://fallback.example.com',
      apiKey: 'fallback-key',
      name: 'Fallback API',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.genericOpenAi,
    );

    // Register fallback values for the types we'll be using with matchers
    registerFallbackValue(fallbackConfig);
    registerFallbackValue(const Stream<List<AiConfig>>.empty());
    registerFallbackValue(<AiConfig>[]);
    registerFallbackValue(const AsyncData<List<AiConfig>>(<AiConfig>[]));
    registerFallbackValue(const AsyncLoading<List<AiConfig>>());
    registerFallbackValue(
      AsyncError<List<AiConfig>>(
        Exception('fallback error'),
        StackTrace.empty,
      ),
    );
  });

  // Helper function to create a ProviderContainer with mocked dependencies
  ProviderContainer createContainer({
    List<Override> overrides = const [],
  }) {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }

  // Helper to clean up stream subscriptions
  void Function()? subscription;

  tearDown(() {
    subscription?.call();
  });

  group('AiConfigByTypeController Tests', () {
    late MockAiConfigRepository mockRepository;
    final testApiConfig = AiConfig.inferenceProvider(
      id: 'test-id',
      baseUrl: 'https://api.example.com',
      apiKey: 'test-api-key',
      name: 'Test API',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.genericOpenAi,
    );

    setUp(() {
      mockRepository = MockAiConfigRepository();
    });

    test('should return configs of the specified type', () async {
      // Arrange
      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.value([testApiConfig]));

      final container = createContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Act & Assert
      final listener = Listener<AsyncValue<List<AiConfig>>>();
      subscription = container
          .listen(
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ),
            listener.call,
            fireImmediately: true,
          )
          .close;

      // Wait for the stream to emit a value
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Verify data state with the correct data
      verify(
        () => listener(
          any(that: isA<AsyncLoading<List<AiConfig>>>()),
          any(that: isA<AsyncData<List<AiConfig>>>()),
        ),
      ).called(1);

      // Verify the repository method was called with the correct type
      verify(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).called(1);
    });
  });

  group('aiConfigById Tests', () {
    late MockAiConfigRepository mockRepository;
    final testApiConfig = AiConfig.inferenceProvider(
      id: 'test-id',
      baseUrl: 'https://api.example.com',
      apiKey: 'test-api-key',
      name: 'Test API',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.genericOpenAi,
    );

    setUp(() {
      mockRepository = MockAiConfigRepository();
    });

    test('should return a config by ID', () async {
      // Arrange
      when(() => mockRepository.getConfigById('test-id')).thenAnswer(
        (_) async => testApiConfig,
      );

      final container = createContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Act
      final result =
          await container.read(aiConfigByIdProvider('test-id').future);

      // Assert
      expect(result, equals(testApiConfig));
      verify(() => mockRepository.getConfigById('test-id')).called(1);
    });

    test('should return null for non-existent ID', () async {
      // Arrange
      when(() => mockRepository.getConfigById('non-existent')).thenAnswer(
        (_) async => null,
      );

      final container = createContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Act
      final result =
          await container.read(aiConfigByIdProvider('non-existent').future);

      // Assert
      expect(result, isNull);
      verify(() => mockRepository.getConfigById('non-existent')).called(1);
    });
  });
}
