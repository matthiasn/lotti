import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/state/daily_os_runtime_maintenance.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  late MockDayAgentService dayAgents;
  late MockDomainLogger logger;
  late DailyOsRuntimeMaintenance maintenance;

  setUp(() {
    dayAgents = MockDayAgentService();
    logger = MockDomainLogger();
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        message: any<String?>(named: 'message'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) {});
    maintenance = DailyOsRuntimeMaintenance(
      dayAgents: dayAgents,
      domainLogger: logger,
    );
  });

  group('beforeWakeScan', () {
    test('runs retirement and the digest repair, in that order', () async {
      when(dayAgents.retirePastDayAgents).thenAnswer((_) async => 2);
      when(dayAgents.ensureCoordinatorDigestWake).thenAnswer((_) async {});

      await maintenance.beforeWakeScan();

      // Order matters: retirement decides which agents may still wake, so it
      // must settle before the digest repair arms a record.
      verifyInOrder([
        dayAgents.retirePastDayAgents,
        dayAgents.ensureCoordinatorDigestWake,
      ]);
      verifyNever(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          message: any<String?>(named: 'message'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      );
    });

    test(
      'contains a retirement failure and still repairs the digest',
      () async {
        // The whole point of the containment: one broken repair must not stop
        // the other, nor abort the scan that finds already-due wakes.
        when(
          dayAgents.retirePastDayAgents,
        ).thenThrow(StateError('retire boom'));
        when(dayAgents.ensureCoordinatorDigestWake).thenAnswer((_) async {});

        await maintenance.beforeWakeScan();

        verify(dayAgents.ensureCoordinatorDigestWake).called(1);
        verify(
          () => logger.error(
            LogDomain.agentRuntime,
            any<Object>(),
            message: 'failed to retire past day agents before wake scan',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test(
      'contains a digest-repair failure after a successful retirement',
      () async {
        when(dayAgents.retirePastDayAgents).thenAnswer((_) async => 0);
        when(
          dayAgents.ensureCoordinatorDigestWake,
        ).thenThrow(StateError('digest boom'));

        await maintenance.beforeWakeScan();

        verify(
          () => logger.error(
            LogDomain.agentRuntime,
            any<Object>(),
            message: 'failed to repair coordinator digest before wake scan',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test('contains both failures without rethrowing', () async {
      when(dayAgents.retirePastDayAgents).thenThrow(StateError('a'));
      when(dayAgents.ensureCoordinatorDigestWake).thenThrow(StateError('b'));

      await expectLater(maintenance.beforeWakeScan(), completes);

      verify(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          message: any<String?>(named: 'message'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(2);
    });

    test('works without a logger', () async {
      // The logger is optional, so containment must not depend on it.
      when(dayAgents.retirePastDayAgents).thenThrow(StateError('boom'));
      when(dayAgents.ensureCoordinatorDigestWake).thenAnswer((_) async {});

      await expectLater(
        DailyOsRuntimeMaintenance(dayAgents: dayAgents).beforeWakeScan(),
        completes,
      );
      verify(dayAgents.ensureCoordinatorDigestWake).called(1);
    });
  });

  group('restoreSubscriptions', () {
    test('delegates to the day-agent service', () async {
      when(dayAgents.restoreSubscriptions).thenAnswer((_) async {});

      await maintenance.restoreSubscriptions();

      verify(dayAgents.restoreSubscriptions).called(1);
    });

    test('propagates a failure so the restoration pass can abort', () async {
      // Unlike the pre-scan repairs, restoration failure is fatal to the pass:
      // the runtime wraps it and rethrows so Riverpod can retry.
      //
      // A rejected future rather than `thenThrow`, because the real service is
      // `async` — it never throws synchronously, and asserting on the shape a
      // mock invents would not exercise the path production takes.
      when(dayAgents.restoreSubscriptions).thenAnswer(
        (_) async => throw StateError('boom'),
      );

      await expectLater(
        maintenance.restoreSubscriptions(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('dailyOsRuntimeMaintenanceProvider', () {
    test('contributes a single entry wired to the resolved service', () {
      final container = ProviderContainer(
        overrides: [
          dayAgentServiceProvider.overrideWithValue(dayAgents),
          domainLoggerProvider.overrideWithValue(logger),
        ],
      );
      addTearDown(container.dispose);

      final entries = container.read(dailyOsRuntimeMaintenanceProvider);

      expect(entries, hasLength(1));
      final entry = entries.single as DailyOsRuntimeMaintenance;
      expect(entry.dayAgents, same(dayAgents));
      expect(entry.domainLogger, same(logger));
    });

    test('rebuilds against the current service when it changes', () {
      // The reason the provider watches rather than reads: the day-agent
      // service is not a leaf, so it genuinely rebuilds. A captured instance
      // would leave the pre-scan repairs running against a stale orchestrator.
      var service = dayAgents;
      final container = ProviderContainer(
        overrides: [
          dayAgentServiceProvider.overrideWith((ref) => service),
          domainLoggerProvider.overrideWithValue(logger),
        ],
      );
      addTearDown(container.dispose);

      final before =
          container.read(dailyOsRuntimeMaintenanceProvider).single
              as DailyOsRuntimeMaintenance;
      expect(before.dayAgents, same(dayAgents));

      final replacement = MockDayAgentService();
      service = replacement;
      container.invalidate(dayAgentServiceProvider);

      final after =
          container.read(dailyOsRuntimeMaintenanceProvider).single
              as DailyOsRuntimeMaintenance;
      expect(
        after.dayAgents,
        same(replacement),
        reason: 'a rebuilt service must propagate to the next wake scan',
      );
    });
  });
}
