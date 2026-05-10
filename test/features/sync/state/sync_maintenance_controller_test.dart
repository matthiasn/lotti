import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/models/sync_error.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockSyncMaintenanceRepository extends Mock
    implements SyncMaintenanceRepository {}

const _generatedSyncStepOrder = <SyncStep>[
  SyncStep.measurables,
  SyncStep.labels,
  SyncStep.categories,
  SyncStep.dashboards,
  SyncStep.habits,
  SyncStep.aiSettings,
  SyncStep.backfillAgentEntityClocks,
  SyncStep.backfillAgentLinkClocks,
  SyncStep.agentEntities,
  SyncStep.agentLinks,
];

class _GeneratedSyncMaintenanceScenario {
  const _GeneratedSyncMaintenanceScenario({
    required this.selectionFlags,
    required this.fail,
    required this.failureSlot,
    required this.totalSeed,
  });

  final List<bool> selectionFlags;
  final bool fail;
  final int failureSlot;
  final int totalSeed;

  Set<SyncStep> get selectedSteps => {
    for (var i = 0; i < _generatedSyncStepOrder.length; i++)
      if (selectionFlags[i]) _generatedSyncStepOrder[i],
  };

  List<SyncStep> get orderedSteps =>
      _generatedSyncStepOrder.where(selectedSteps.contains).toList();

  int? get failureIndex {
    if (!fail || orderedSteps.isEmpty) return null;
    return failureSlot % orderedSteps.length;
  }

  SyncStep? get failureStep {
    final index = failureIndex;
    return index == null ? null : orderedSteps[index];
  }

  bool get shouldFail => failureStep != null;

  int totalFor(SyncStep step) => ((totalSeed + step.index) % 5) + 1;

  List<SyncStep> get expectedCalls {
    final index = failureIndex;
    if (index == null) return orderedSteps;
    return orderedSteps.take(index + 1).toList();
  }

  @override
  String toString() {
    return '_GeneratedSyncMaintenanceScenario('
        'selectionFlags: $selectionFlags, '
        'fail: $fail, '
        'failureSlot: $failureSlot, '
        'totalSeed: $totalSeed'
        ')';
  }
}

extension _AnyGeneratedSyncMaintenanceScenario on glados.Any {
  glados.Generator<_GeneratedSyncMaintenanceScenario>
  get syncMaintenanceScenario => glados.CombinableAny(this).combine4(
    glados.ListAnys(this).listWithLengthInRange(
      _generatedSyncStepOrder.length,
      _generatedSyncStepOrder.length,
      glados.BoolAny(this).bool,
    ),
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, _generatedSyncStepOrder.length),
    glados.IntAnys(this).intInRange(0, 20),
    (
      List<bool> selectionFlags,
      bool fail,
      int failureSlot,
      int totalSeed,
    ) => _GeneratedSyncMaintenanceScenario(
      selectionFlags: selectionFlags,
      fail: fail,
      failureSlot: failureSlot,
      totalSeed: totalSeed,
    ),
  );
}

void main() {
  late MockSyncMaintenanceRepository mockRepository;
  late MockLoggingService mockLoggingService;
  late ProviderContainer container;
  late SyncMaintenanceController controller;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(<SyncStep>{});
  });

  setUp(() {
    mockRepository = MockSyncMaintenanceRepository();
    mockLoggingService = MockLoggingService();

    container = ProviderContainer(
      overrides: [
        syncMaintenanceRepositoryProvider.overrideWithValue(mockRepository),
        syncLoggingServiceProvider.overrideWithValue(mockLoggingService),
      ],
    );
    controller = container.read(syncControllerProvider.notifier);

    void stubSuccess(Invocation invocation) {
      final onProgress =
          invocation.namedArguments[const Symbol('onProgress')]
              as void Function(double)?;
      final onDetailedProgress =
          invocation.namedArguments[const Symbol('onDetailedProgress')]
              as void Function(int, int)?;
      onDetailedProgress?.call(0, 1);
      onDetailedProgress?.call(1, 1);
      onProgress?.call(1);
    }

    when(
      () => mockRepository.syncMeasurables(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((invocation) async => stubSuccess(invocation));
    when(
      () => mockRepository.syncLabels(
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
      () => mockRepository.fetchTotalsForSteps(any()),
    ).thenAnswer((invocation) async {
      final steps = invocation.positionalArguments.first as Set<SyncStep>;
      return {
        for (final step in steps) step: 1,
      };
    });

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        stackTrace: any<dynamic>(named: 'stackTrace'),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    container.dispose();
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

      await controller.syncAll(
        selectedSteps: {
          SyncStep.measurables,
          SyncStep.labels,
          SyncStep.categories,
          SyncStep.dashboards,
          SyncStep.habits,
          SyncStep.aiSettings,
        },
      );

      expect(states.first, const SyncState());
      expect(states.last.isSyncing, isFalse);
      expect(states.last.progress, 100);
      expect(states.last.currentStep, SyncStep.complete);
      expect(states.last.error, isNull);

      verify(
        () => mockRepository.syncMeasurables(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncLabels(
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
        SyncStep.measurables,
        SyncStep.labels,
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
      await controller.syncAll(
        selectedSteps: {
          SyncStep.aiSettings,
        },
      );

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

      final _ = container.read(syncControllerProvider);
    });

    glados.Glados(
      glados.any.syncMaintenanceScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated selected step sets run in canonical order, preserve totals, '
      'and stop at the injected failure',
      (scenario) async {
        controller.reset();
        final calls = <SyncStep>[];
        var totalsCalls = 0;
        final failure = StateError(
          'generated sync failure at ${scenario.failureStep}',
        );

        when(
          () => mockRepository.fetchTotalsForSteps(any()),
        ).thenAnswer((invocation) async {
          totalsCalls++;
          final steps = invocation.positionalArguments.first as Set<SyncStep>;
          expect(steps, scenario.orderedSteps.toSet(), reason: '$scenario');
          return {
            for (final step in steps) step: scenario.totalFor(step),
          };
        });

        Future<void> runStep(Invocation invocation, SyncStep step) {
          calls.add(step);
          final total = scenario.totalFor(step);
          final onProgress =
              invocation.namedArguments[#onProgress] as void Function(double)?;
          final onDetailedProgress =
              invocation.namedArguments[#onDetailedProgress]
                  as void Function(int, int)?;
          onDetailedProgress?.call(0, total);
          onDetailedProgress?.call(total, total);
          onProgress?.call(1);
          if (scenario.failureStep == step) {
            return Future<void>.error(failure);
          }
          return Future<void>.value();
        }

        when(
          () => mockRepository.syncMeasurables(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer((invocation) => runStep(invocation, SyncStep.measurables));
        when(
          () => mockRepository.syncLabels(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer((invocation) => runStep(invocation, SyncStep.labels));
        when(
          () => mockRepository.syncCategories(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer((invocation) => runStep(invocation, SyncStep.categories));
        when(
          () => mockRepository.syncDashboards(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer((invocation) => runStep(invocation, SyncStep.dashboards));
        when(
          () => mockRepository.syncHabits(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer((invocation) => runStep(invocation, SyncStep.habits));
        when(
          () => mockRepository.syncAiSettings(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer((invocation) => runStep(invocation, SyncStep.aiSettings));
        when(
          () => mockRepository.backfillAgentEntityClocks(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer(
          (invocation) =>
              runStep(invocation, SyncStep.backfillAgentEntityClocks),
        );
        when(
          () => mockRepository.backfillAgentLinkClocks(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer(
          (invocation) => runStep(invocation, SyncStep.backfillAgentLinkClocks),
        );
        when(
          () => mockRepository.syncAgentEntities(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer(
          (invocation) => runStep(invocation, SyncStep.agentEntities),
        );
        when(
          () => mockRepository.syncAgentLinks(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer(
          (invocation) => runStep(invocation, SyncStep.agentLinks),
        );

        if (scenario.shouldFail) {
          await expectLater(
            controller.syncAll(selectedSteps: scenario.selectedSteps),
            throwsA(same(failure)),
          );
        } else {
          await controller.syncAll(selectedSteps: scenario.selectedSteps);
        }

        expect(
          totalsCalls,
          scenario.orderedSteps.isEmpty ? 0 : 1,
          reason: '$scenario',
        );
        expect(calls, scenario.expectedCalls, reason: '$scenario');

        final state = container.read(syncControllerProvider);
        if (scenario.orderedSteps.isEmpty) {
          expect(state.isSyncing, isFalse);
          expect(state.progress, 0);
          expect(state.currentStep, SyncStep.measurables);
          expect(state.error, isNull);
          expect(state.stepProgress, isEmpty);
          expect(state.selectedSteps, isEmpty);
          return;
        }

        expect(state.isSyncing, isFalse);
        expect(state.selectedSteps, scenario.selectedSteps);
        expect(state.stepProgress.keys.toSet(), scenario.orderedSteps.toSet());

        for (final step in scenario.orderedSteps) {
          final progress = state.stepProgress[step];
          expect(progress?.total, scenario.totalFor(step));
          expect(
            progress?.processed,
            scenario.expectedCalls.contains(step) ? scenario.totalFor(step) : 0,
            reason: '$scenario step=$step',
          );
        }

        if (scenario.shouldFail) {
          expect(state.currentStep, scenario.failureStep);
          expect(state.error, isNotNull);
          expect(state.progress, lessThanOrEqualTo(100));
        } else {
          expect(state.currentStep, SyncStep.complete);
          expect(state.error, isNull);
          expect(state.progress, 100);
        }
      },
    );

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
        controller.syncAll(
          selectedSteps: {
            SyncStep.measurables,
            SyncStep.labels,
            SyncStep.categories,
            SyncStep.dashboards,
            SyncStep.habits,
            SyncStep.aiSettings,
          },
        ),
        throwsA(exception),
      );

      final lastState = container.read(syncControllerProvider);
      expect(lastState.isSyncing, isFalse);
      expect(lastState.error, expectedError);
      expect(lastState.currentStep, SyncStep.categories);

      verify(
        () => mockRepository.syncMeasurables(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => mockRepository.syncLabels(
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
      await controller.syncAll(
        selectedSteps: {
          SyncStep.measurables,
          SyncStep.labels,
          SyncStep.categories,
          SyncStep.dashboards,
          SyncStep.habits,
          SyncStep.aiSettings,
        },
      );
      expect(container.read(syncControllerProvider).progress, 100);

      controller.reset();

      expect(container.read(syncControllerProvider), const SyncState());
    });
  });
}
