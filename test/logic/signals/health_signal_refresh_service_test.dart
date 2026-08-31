import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/signals/health_signal_refresh_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  late MockHealthImport healthImport;

  setUp(() async {
    await setUpTestGetIt();
    healthImport = MockHealthImport();
    when(() => healthImport.fetchHealthDataDelta(any())).thenAnswer(
      (_) async {},
    );
  });

  tearDown(tearDownTestGetIt);

  test('maps only platform-owned types and collapses composite families', () {
    expect(
      HealthSignalRefreshService.importRequestsFor(const [
        'cumulative_step_count',
        'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
        'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
        'words-written',
      ]),
      {'cumulative_step_count', 'BLOOD_PRESSURE'},
    );
  });

  test('de-duplicates requests and continues after an import fails', () async {
    final loggingService = MockLoggingService();
    stubLoggingService(loggingService);
    when(
      () => healthImport.fetchHealthDataDelta('cumulative_step_count'),
    ).thenThrow(StateError('health store unavailable'));
    final service = HealthSignalRefreshService(
      healthImport,
      DomainLogger(loggingService: loggingService),
    );

    await service.refreshRequests(const [
      'cumulative_step_count',
      'cumulative_step_count',
      'HealthDataType.WEIGHT',
    ]);

    verify(
      () => healthImport.fetchHealthDataDelta('cumulative_step_count'),
    ).called(1);
    verify(
      () => healthImport.fetchHealthDataDelta('HealthDataType.WEIGHT'),
    ).called(1);
    verify(
      () => loggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: 'healthSignalRefresh',
        stackTrace: any<dynamic>(named: 'stackTrace'),
        level: any(named: 'level'),
        type: any(named: 'type'),
      ),
    ).called(1);
  });

  test('refreshWorkouts runs the workout delta', () async {
    when(
      healthImport.getWorkoutsHealthDataDelta,
    ).thenAnswer((_) async => const HealthImportResult.imported(0));

    await HealthSignalRefreshService(healthImport).refreshWorkouts();

    verify(healthImport.getWorkoutsHealthDataDelta).called(1);
  });

  test('refreshWorkouts contains and logs a failing delta', () async {
    final loggingService = MockLoggingService();
    stubLoggingService(loggingService);
    when(
      healthImport.getWorkoutsHealthDataDelta,
    ).thenThrow(StateError('health store unavailable'));
    final service = HealthSignalRefreshService(
      healthImport,
      DomainLogger(loggingService: loggingService),
    );

    await expectLater(service.refreshWorkouts(), completes);

    verify(
      () => loggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: 'healthSignalRefresh',
        stackTrace: any<dynamic>(named: 'stackTrace'),
        level: any(named: 'level'),
        type: any(named: 'type'),
      ),
    ).called(1);
  });

  test('refreshWorkouts without a logger swallows the failure', () async {
    when(
      healthImport.getWorkoutsHealthDataDelta,
    ).thenThrow(StateError('health store unavailable'));

    await expectLater(
      HealthSignalRefreshService(healthImport).refreshWorkouts(),
      completes,
    );
  });

  test('provider resolves only when the profile registers an importer', () {
    final absent = ProviderContainer();
    addTearDown(absent.dispose);
    expect(absent.read(healthSignalRefreshServiceProvider), isNull);

    getIt.registerSingleton<HealthImport>(healthImport);
    final present = ProviderContainer();
    addTearDown(present.dispose);
    expect(present.read(healthSignalRefreshServiceProvider), isNotNull);
  });
}
