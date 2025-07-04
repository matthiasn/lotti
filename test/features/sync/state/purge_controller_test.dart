import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/state/purge_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/lotti_logger.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockLottiLogger extends Mock implements LottiLogger {}

void main() {
  late MockJournalDb mockDb;
  late MockLottiLogger mockLottiLogger;
  late PurgeController controller;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(Exception('Test exception'));
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockLottiLogger = MockLottiLogger();

    // Register mock LottiLogger
    getIt.registerSingleton<LottiLogger>(mockLottiLogger);

    controller = PurgeController(mockDb);
  });

  tearDown(() {
    getIt.unregister<LottiLogger>();
  });

  group('PurgeController', () {
    test('initial state should be correct', () {
      expect(controller.state.progress, 0);
      expect(controller.state.isPurging, false);
    });

    test('purgeDeleted should update state correctly', () async {
      // Setup mock stream
      when(() => mockDb.purgeDeleted()).thenAnswer(
        (_) => Stream.fromIterable([0.25, 0.5, 0.75, 1.0]),
      );

      // Start purge operation
      final purgeFuture = controller.purgeDeleted();

      // Verify initial state
      expect(controller.state.isPurging, true);
      expect(controller.state.progress, 0);

      // Wait for operation to complete
      await purgeFuture;

      // Verify final state
      expect(controller.state.isPurging, false);
      expect(controller.state.progress, 1.0);
    });

    test('purgeDeleted should handle errors gracefully', () async {
      const testError = 'Test error';

      // Setup mock to throw error
      when(() => mockDb.purgeDeleted()).thenAnswer(
        (_) => Stream.error(Exception(testError)),
      );

      // Start purge operation
      final purgeFuture = controller.purgeDeleted();

      // Verify initial state
      expect(controller.state.isPurging, true);
      expect(controller.state.progress, 0);

      // Wait for operation to complete (should not throw)
      await purgeFuture;

      // Verify final state
      expect(controller.state.isPurging, false);
      expect(controller.state.progress, 0);
      expect(controller.state.error, contains(testError));

      // Verify logging was called with correct parameters
      verify(
        () => mockLottiLogger.exception(
          any<Exception>(),
          domain: 'PurgeController',
          subDomain: 'purgeDeleted',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('purgeDeleted should update progress incrementally', () async {
      // Setup mock stream with specific progress values
      when(() => mockDb.purgeDeleted()).thenAnswer(
        (_) => Stream.fromIterable([0.25, 0.5, 0.75, 1.0]),
      );

      // Track state changes
      final states = <PurgeState>[];
      controller.addListener(states.add);

      // Start purge operation
      await controller.purgeDeleted();

      // Verify state progression
      expect(states.length, 7);
      expect(states[0].progress, 0);
      expect(states[0].isPurging, false);
      expect(states[1].progress, 0);
      expect(states[1].isPurging, true);
      expect(states[2].progress, 0.25);
      expect(states[3].progress, 0.5);
      expect(states[4].progress, 0.75);
      expect(states[5].progress, 1.0);
      expect(states[5].isPurging, true);
      expect(states[6].progress, 1.0);
      expect(states[6].isPurging, false);
    });
  });
}
