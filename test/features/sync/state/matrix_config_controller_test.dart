import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_config_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixService extends Mock implements MatrixService {}

// Custom listener class for testing Riverpod state changes
class StateListener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockMatrixService mockMatrixService;
  late StateListener<AsyncValue<MatrixConfig?>> listener;

  const testConfig = MatrixConfig(
    homeServer: 'https://matrix.org',
    user: 'testuser',
    password: 'testpassword',
  );

  setUpAll(() {
    // Register fallback values for Mocktail
    registerFallbackValue(const AsyncLoading<MatrixConfig?>());
    registerFallbackValue(const AsyncData<MatrixConfig?>(testConfig));
    registerFallbackValue(testConfig);
  });

  setUp(() {
    mockMatrixService = MockMatrixService();

    // Set up default behavior for loadConfig
    when(() => mockMatrixService.loadConfig())
        .thenAnswer((_) => Future<MatrixConfig?>.value(testConfig));

    // Set up default behavior for the other methods
    when(() => mockMatrixService.setConfig(any()))
        .thenAnswer((_) => Future<void>.value());
    when(() => mockMatrixService.deleteConfig())
        .thenAnswer((_) => Future<void>.value());

    listener = StateListener<AsyncValue<MatrixConfig?>>();

    // Override GetIt to use our mock
    getIt.allowReassignment = true;
    getIt.registerSingleton<MatrixService>(mockMatrixService);

    // Create a provider container
    container = ProviderContainer()
      ..listen(
        matrixConfigControllerProvider,
        listener.call,
        fireImmediately: true,
      );
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
  });

  group('MatrixConfigController', () {
    test('initial state contains test config', () {
      // The state should contain the test config since we mocked the service to return it
      final initialState = container.read(matrixConfigControllerProvider);
      expect(initialState, isA<AsyncData<MatrixConfig?>>());
      expect(
        initialState.value,
        equals(testConfig),
      );
    });

    test('build loads config from MatrixService', () async {
      // Setup mock behavior
      when(() => mockMatrixService.loadConfig())
          .thenAnswer((_) => Future<MatrixConfig?>.value(testConfig));

      // Wait for the provider to resolve
      final config =
          await container.read(matrixConfigControllerProvider.future);

      // Verify the result
      expect(config, equals(testConfig));

      // Verify loadConfig was called
      verify(() => mockMatrixService.loadConfig()).called(1);
    });

    test('setConfig calls MatrixService.setConfig', () async {
      // Call setConfig on the controller
      final controller =
          container.read(matrixConfigControllerProvider.notifier);
      await controller.setConfig(testConfig);

      // Verify that MatrixService.setConfig was called with the correct arguments
      verify(() => mockMatrixService.setConfig(testConfig)).called(1);
    });

    test('deleteConfig calls MatrixService.deleteConfig', () async {
      // Call deleteConfig on the controller
      final controller =
          container.read(matrixConfigControllerProvider.notifier);
      await controller.deleteConfig();

      // Verify that MatrixService.deleteConfig was called
      verify(() => mockMatrixService.deleteConfig()).called(1);
    });

    test('returns null when no config exists', () async {
      // Create a new container to avoid verification issues
      final mockService = MockMatrixService();
      when(mockService.loadConfig)
          .thenAnswer((_) => Future<MatrixConfig?>.value());

      // Re-register the service
      getIt.registerSingleton<MatrixService>(mockService, dispose: (_) {});

      final localContainer = ProviderContainer();

      // Verify we initially get loading state
      final initialState = localContainer.read(matrixConfigControllerProvider);
      expect(initialState, isA<AsyncLoading<MatrixConfig?>>());

      // Wait for the provider to resolve
      final config =
          await localContainer.read(matrixConfigControllerProvider.future);

      // Verify the result is null
      expect(config, isNull);

      // Cleanup
      localContainer.dispose();
    });
  });
}
