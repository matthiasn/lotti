import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_error.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncMaintenanceRepository extends Mock
    implements SyncMaintenanceRepository {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late MockSyncMaintenanceRepository mockRepository;
  late MockLoggingService mockLoggingService;
  late ProviderContainer container;
  late SyncMaintenanceController controller;

  setUp(() async {
    mockRepository = MockSyncMaintenanceRepository();
    mockLoggingService = MockLoggingService();

    await getIt.reset();
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    container = ProviderContainer(
      overrides: [
        syncMaintenanceRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
    controller = container.read(syncControllerProvider.notifier);

    void stubSuccess(Invocation invocation) {
      final onProgress = invocation.namedArguments[const Symbol('onProgress')]
          as void Function(double)?;
      final onDetailedProgress =
          invocation.namedArguments[const Symbol('onDetailedProgress')] as void
              Function(int, int)?;
      onDetailedProgress?.call(0, 1);
      onDetailedProgress?.call(1, 1);
      onProgress?.call(1);
    }

    when(
      () => mockRepository.syncTags(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((invocation) async => stubSuccess(invocation));
    when(
      () => mockRepository.syncMeasurables(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((invocation) async => stubSuccess(invocation));
    when(
      () => mockRepository.syncCategories(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((invocation) async => stubSuccess(invocation));
    when(
      () => mockRepository.syncDashboards(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((invocation) async => stubSuccess(invocation));
    when(
      () => mockRepository.syncHabits(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((invocation) async => stubSuccess(invocation));
    when(
      () => mockRepository.syncAiSettings(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((invocation) async => stubSuccess(invocation));

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        stackTrace: any<dynamic>(named: 'stackTrace'),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    container.dispose();
    await getIt.reset();
  });

  group('SyncMaintenanceController', () {
    test('initial state is correct', () {
      expect(container.read(syncControllerProvider), const SyncState());
    });

    test('syncAll executes all steps successfully and updates state', () async {
      final states = <SyncState>[];
      final sub = container.listen<SyncState>(
        syncControllerProvider,
        (previous, next) => states.add(next),
        fireImmediately: true,
      );

      await controller.syncAll(selectedSteps: {
        SyncStep.tags,
        SyncStep.measurables,
        SyncStep.categories,
        SyncStep.dashboards,
        SyncStep.habits,
        SyncStep.aiSettings,
      });

      expect(states.first, const SyncState());
      expect(states.last.isSyncing, isFalse);
      expect(states.last.progress, 100);
      expect(states.last.currentStep, SyncStep.complete);
      expect(states.last.error, isNull);

      verify(
        () => mockRepository.syncTags(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncMeasurables(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncCategories(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncDashboards(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncHabits(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncAiSettings(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);

      final lastState = container.read(syncControllerProvider);
      for (final step in {
        SyncStep.tags,
        SyncStep.measurables,
        SyncStep.categories,
        SyncStep.dashboards,
        SyncStep.habits,
        SyncStep.aiSettings,
      }) {
        final progress = lastState.stepProgress[step];
        expect(progress?.processed, 1);
        expect(progress?.total, 1);
      }

      sub.close();
    });

    test('syncAll runs only selected steps', () async {
      await controller.syncAll(selectedSteps: {
        SyncStep.tags,
        SyncStep.aiSettings,
      });

      verify(
        () => mockRepository.syncTags(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncAiSettings(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);

      verifyNever(
        () => mockRepository.syncMeasurables(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      );
      verifyNever(
        () => mockRepository.syncCategories(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      );
      verifyNever(
        () => mockRepository.syncDashboards(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      );
      verifyNever(
        () => mockRepository.syncHabits(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      );

      final state = container.read(syncControllerProvider);
      expect(state.selectedSteps, {SyncStep.tags, SyncStep.aiSettings});
      expect(state.stepProgress.keys, {SyncStep.tags, SyncStep.aiSettings});
    });

    test('syncAll handles errors and updates state', () async {
      final exception = Exception('Sync failed');
      final expectedError = SyncError.fromException(
        exception,
        StackTrace.current,
        mockLoggingService,
      ).toString();

      when(
        () => mockRepository.syncCategories(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).thenThrow(exception);

      final states = <SyncState>[];
      final sub = container.listen<SyncState>(
        syncControllerProvider,
        (previous, next) => states.add(next),
      );

      await expectLater(
        controller.syncAll(selectedSteps: {
          SyncStep.tags,
          SyncStep.measurables,
          SyncStep.categories,
          SyncStep.dashboards,
          SyncStep.habits,
          SyncStep.aiSettings,
        }),
        throwsA(exception),
      );

      final lastState = container.read(syncControllerProvider);
      expect(lastState.isSyncing, isFalse);
      expect(lastState.error, expectedError);
      expect(lastState.currentStep, SyncStep.categories);

      verify(
        () => mockRepository.syncTags(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncMeasurables(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncCategories(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verifyNever(
        () => mockRepository.syncDashboards(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      );
      verifyNever(
        () => mockRepository.syncHabits(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      );
      verifyNever(
        () => mockRepository.syncAiSettings(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      );
      verify(
        () => mockLoggingService.captureException(
          exception,
          stackTrace: any<dynamic>(named: 'stackTrace'),
          domain: 'SYNC_CONTROLLER',
        ),
      ).called(2);

      sub.close();
    });

    test('reset sets state to initial', () async {
      await controller.syncAll(selectedSteps: {
        SyncStep.tags,
        SyncStep.measurables,
        SyncStep.categories,
        SyncStep.dashboards,
        SyncStep.habits,
        SyncStep.aiSettings,
      });
      expect(container.read(syncControllerProvider).progress, 100);

      controller.reset();

      expect(container.read(syncControllerProvider), const SyncState());
    });
  });
}
