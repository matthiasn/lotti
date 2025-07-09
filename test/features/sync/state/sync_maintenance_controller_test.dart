import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_error.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/lotti_logger.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockSyncMaintenanceRepository extends Mock
    implements SyncMaintenanceRepository {}

class MockLottiLogger extends Mock implements LottiLogger {}

void main() {
  late MockSyncMaintenanceRepository mockRepository;
  late MockLottiLogger mockLottiLogger;
  late SyncMaintenanceController controller;
  late ProviderContainer container;

  setUpAll(() {
    // Register a fallback value for StackTrace if it's captured by mockLoggingService
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockRepository = MockSyncMaintenanceRepository();
    mockLottiLogger = MockLottiLogger();

    // Unregister and register singletons to ensure a fresh state for each test
    if (getIt.isRegistered<LottiLogger>()) {
      getIt.unregister<LottiLogger>();
    }
    getIt.registerSingleton<LottiLogger>(mockLottiLogger);

    // Initialize the controller and provider container
    controller = SyncMaintenanceController(mockRepository);
    container = ProviderContainer(
      overrides: [
        syncControllerProvider.overrideWith((ref) => controller),
      ],
    );

    // Mock all repository methods to return a successful Future by default
    when(() => mockRepository.syncTags(onProgress: any(named: 'onProgress')))
        .thenAnswer((_) => Future<void>.value());
    when(
      () => mockRepository.syncMeasurables(
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockRepository.syncCategories(onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockRepository.syncDashboards(onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) => Future<void>.value());
    when(() => mockRepository.syncHabits(onProgress: any(named: 'onProgress')))
        .thenAnswer((_) => Future<void>.value());
    // Mock logging service
    when(
      () => mockLottiLogger.exception(
        any<dynamic>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    container.dispose();
    // Reset GetIt after each test if necessary for other tests,
    // or ensure singletons are handled if they persist across tests.
    // For this setup, unregistering and re-registering in setUp is preferred.
  });

  group('SyncMaintenanceController', () {
    test('initial state is correct', () {
      expect(controller.state, const SyncState());
    });

    test('syncAll executes all steps successfully and updates state', () async {
      final actualStates = <SyncState>[];
      final subscription = controller.stream.listen(actualStates.add);

      final expectedStateMatchers = [
        // 1. Initial sync start
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 0)
            .having((s) => s.currentStep, 'currentStep', SyncStep.tags)
            .having((s) => s.error, 'error', isNull),
        // 2. Before Tags operation (currentStep is already tags)
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 0)
            .having((s) => s.currentStep, 'currentStep', SyncStep.tags)
            .having((s) => s.error, 'error', isNull),
        // 3. After Tags operation
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 20)
            .having((s) => s.currentStep, 'currentStep', SyncStep.tags)
            .having((s) => s.error, 'error', isNull),
        // 4. Before Measurables operation
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 20)
            .having((s) => s.currentStep, 'currentStep', SyncStep.measurables)
            .having((s) => s.error, 'error', isNull),
        // 5. After Measurables operation
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 40)
            .having((s) => s.currentStep, 'currentStep', SyncStep.measurables)
            .having((s) => s.error, 'error', isNull),
        // 6. Before Categories operation
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 40)
            .having((s) => s.currentStep, 'currentStep', SyncStep.categories)
            .having((s) => s.error, 'error', isNull),
        // 7. After Categories operation
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 60)
            .having((s) => s.currentStep, 'currentStep', SyncStep.categories)
            .having((s) => s.error, 'error', isNull),
        // 8. Before Dashboards operation
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 60)
            .having((s) => s.currentStep, 'currentStep', SyncStep.dashboards)
            .having((s) => s.error, 'error', isNull),
        // 9. After Dashboards operation
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 80)
            .having((s) => s.currentStep, 'currentStep', SyncStep.dashboards)
            .having((s) => s.error, 'error', isNull),
        // 10. Before Habits operation
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 80)
            .having((s) => s.currentStep, 'currentStep', SyncStep.habits)
            .having((s) => s.error, 'error', isNull),
        // 11. After Habits operation
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.progress, 'progress', 100)
            .having((s) => s.currentStep, 'currentStep', SyncStep.habits)
            .having((s) => s.error, 'error', isNull),
        // 12. Sync complete
        isA<SyncState>()
            .having((s) => s.isSyncing, 'isSyncing', false)
            .having((s) => s.progress, 'progress', 100)
            .having((s) => s.currentStep, 'currentStep', SyncStep.complete)
            .having((s) => s.error, 'error', isNull),
      ];

      await controller.syncAll();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(actualStates.length, expectedStateMatchers.length);
      for (var i = 0; i < actualStates.length; i++) {
        expect(
          actualStates[i],
          expectedStateMatchers[i],
          reason: 'State at index $i did not match',
        );
      }

      expect(controller.state.isSyncing, isFalse);
      expect(controller.state.progress, 100);
      expect(controller.state.currentStep, SyncStep.complete);
      expect(controller.state.error, isNull);

      verify(
        () => mockRepository.syncTags(onProgress: any(named: 'onProgress')),
      ).called(1);
      verify(
        () => mockRepository.syncMeasurables(
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncCategories(
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncDashboards(
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncHabits(onProgress: any(named: 'onProgress')),
      ).called(1);
    });

    test('syncAll handles errors and updates state', () async {
      final exception = Exception('Sync failed');
      final expectedErrorString = SyncError.fromException(
        exception,
        StackTrace.current,
        mockLottiLogger,
      ).toString();
      when(
        () => mockRepository.syncCategories(
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(exception);

      final actualStates = <SyncState>[];
      final subscription = controller.stream.listen(actualStates.add);

      try {
        await controller.syncAll();
      } catch (e) {
        expect(e, exception);
      }
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      // Instead of matching all states by index, just check the last state for error and isSyncing: false
      expect(actualStates.last.isSyncing, isFalse);
      expect(actualStates.last.error, expectedErrorString);
      expect(actualStates.last.currentStep, SyncStep.categories);

      verify(
        () => mockRepository.syncTags(
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncMeasurables(
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncCategories(
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verifyNever(
        () =>
            mockRepository.syncDashboards(onProgress: any(named: 'onProgress')),
      );
      verifyNever(
        () => mockRepository.syncHabits(onProgress: any(named: 'onProgress')),
      );
      verify(
        () => mockLottiLogger.exception(
          exception,
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          domain: 'SYNC_CONTROLLER',
        ),
      ).called(2);
    });

    test('reset sets state to initial', () async {
      // First, change the state
      await controller.syncAll(); // Assuming this changes the state
      expect(controller.state.isSyncing, isFalse); // Sanity check

      // Then, reset
      controller.reset();

      // Verify state is reset
      expect(controller.state, const SyncState());
    });
  });
}
