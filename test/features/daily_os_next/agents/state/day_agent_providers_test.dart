import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
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
}
