import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('dayAgentServiceProvider', () {
    test('wires dependencies and persisted-state notifications', () {
      final agentService = MockAgentService();
      final repository = MockAgentRepository();
      final orchestrator = MockWakeOrchestrator();
      final syncService = MockAgentSyncService();
      final templateService = MockAgentTemplateService();
      final domainLogger = MockDomainLogger();
      final notifications = MockUpdateNotifications();
      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(agentService),
          agentRepositoryProvider.overrideWithValue(repository),
          wakeOrchestratorProvider.overrideWithValue(orchestrator),
          agentSyncServiceProvider.overrideWithValue(syncService),
          agentTemplateServiceProvider.overrideWithValue(templateService),
          domainLoggerProvider.overrideWithValue(domainLogger),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(dayAgentServiceProvider);

      expect(service.agentService, same(agentService));
      expect(service.repository, same(repository));
      expect(service.orchestrator, same(orchestrator));
      expect(service.syncService, same(syncService));
      expect(service.templateService, same(templateService));
      expect(service.domainLogger, same(domainLogger));

      service.onPersistedStateChanged?.call('day-agent-001');

      verify(
        () => notifications.notifyUiOnly({
          'day-agent-001',
          agentNotification,
        }),
      ).called(1);
    });
  });

  group('dayAgentPlanServiceProvider', () {
    test('wires dependencies and persisted-state notifications', () {
      final repository = MockAgentRepository();
      final syncService = MockAgentSyncService();
      final journalDb = MockJournalDb();
      final domainLogger = MockDomainLogger();
      final notifications = MockUpdateNotifications();
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          agentSyncServiceProvider.overrideWithValue(syncService),
          journalDbProvider.overrideWithValue(journalDb),
          domainLoggerProvider.overrideWithValue(domainLogger),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(dayAgentPlanServiceProvider);

      expect(service.agentRepository, same(repository));
      expect(service.syncService, same(syncService));
      expect(service.journalDb, same(journalDb));
      expect(service.domainLogger, same(domainLogger));

      service.onPersistedStateChanged?.call('dayplan-2026-05-25');

      verify(
        () => notifications.notifyUiOnly({
          'dayplan-2026-05-25',
          agentNotification,
        }),
      ).called(1);
    });
  });

  group('dayAgentProvider', () {
    test('fetches the day agent for the normalized local day', () async {
      final service = MockDayAgentService();
      final notifications = UpdateNotifications();
      final requestedDate = DateTime(2026, 5, 25, 9, 30);
      final identity = makeTestIdentity(
        id: 'day-agent-001',
        agentId: 'day-agent-001',
        kind: AgentKinds.dayAgent,
      );
      when(
        () => service.getDayAgentForDate(requestedDate),
      ).thenAnswer((_) async => identity);
      final container = ProviderContainer(
        overrides: [
          dayAgentServiceProvider.overrideWithValue(service),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        dayAgentProvider(requestedDate).future,
      );

      expect(result, identity);
      verify(() => service.getDayAgentForDate(requestedDate)).called(1);
    });
  });

  group('parsedItemsForCaptureProvider', () {
    test(
      'loads capture-scoped parsed items through the capture service',
      () async {
        final captureService = MockDayAgentCaptureService();
        final notifications = UpdateNotifications();
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-001',
                  agentId: 'day-agent-001',
                  transcript: 'prep demo',
                  capturedAt: DateTime(2026, 5, 25, 8),
                  createdAt: DateTime(2026, 5, 25, 8),
                  vectorClock: null,
                )
                as CaptureEntity;
        final parsed =
            AgentDomainEntity.parsedItem(
                  id: 'parsed-001',
                  agentId: 'day-agent-001',
                  captureId: 'capture-001',
                  kind: ParsedItemKind.newTask,
                  title: 'Prep demo',
                  categoryId: 'work',
                  confidence: ParsedItemConfidence.low,
                  confidenceScore: 0.3,
                  createdAt: DateTime(2026, 5, 25, 8),
                  vectorClock: null,
                )
                as ParsedItemEntity;
        when(
          () => captureService.getCapture('capture-001'),
        ).thenAnswer((_) async => capture);
        when(
          () => captureService.parsedItemsForCapture('capture-001'),
        ).thenAnswer((_) async => [parsed]);
        final container = ProviderContainer(
          overrides: [
            dayAgentCaptureServiceProvider.overrideWithValue(captureService),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          parsedItemsForCaptureProvider('capture-001').future,
        );

        expect(result, [parsed]);
        verify(() => captureService.getCapture('capture-001')).called(1);
        verify(
          () => captureService.parsedItemsForCapture('capture-001'),
        ).called(1);
      },
    );
  });

  group('pendingDecisionsForDateProvider', () {
    test('returns no decisions when no day agent exists', () async {
      final service = MockDayAgentService();
      final captureService = MockDayAgentCaptureService();
      final notifications = UpdateNotifications();
      final date = DateTime(2026, 5, 25, 9);
      when(
        () => service.getDayAgentForDate(date),
      ).thenAnswer((_) async => null);
      final container = ProviderContainer(
        overrides: [
          dayAgentServiceProvider.overrideWithValue(service),
          dayAgentCaptureServiceProvider.overrideWithValue(captureService),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingDecisionsForDateProvider(date).future,
      );

      expect(result, isEmpty);
      verifyNever(
        () => captureService.surfacePendingDecisions(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      );
    });

    test('loads pending decisions for the active day agent', () async {
      final service = MockDayAgentService();
      final captureService = MockDayAgentCaptureService();
      final notifications = UpdateNotifications();
      final date = DateTime(2026, 5, 25, 9);
      final agent = makeTestIdentity(
        id: 'day-agent-001',
        agentId: 'day-agent-001',
        kind: AgentKinds.dayAgent,
      );
      const pending = DayAgentPendingItem(
        taskId: 'task-001',
        title: 'Prep demo',
        kind: DayAgentPendingKind.dueToday,
        status: 'OPEN',
        categoryId: 'work',
      );
      when(
        () => service.getDayAgentForDate(date),
      ).thenAnswer((_) async => agent);
      when(
        () => captureService.surfacePendingDecisions(
          agentId: 'day-agent-001',
          dayId: 'dayplan-2026-05-25',
        ),
      ).thenAnswer((_) async => const [pending]);
      final container = ProviderContainer(
        overrides: [
          dayAgentServiceProvider.overrideWithValue(service),
          dayAgentCaptureServiceProvider.overrideWithValue(captureService),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingDecisionsForDateProvider(date).future,
      );

      expect(result, const [pending]);
      verify(
        () => captureService.surfacePendingDecisions(
          agentId: 'day-agent-001',
          dayId: 'dayplan-2026-05-25',
        ),
      ).called(1);
    });
  });
}
