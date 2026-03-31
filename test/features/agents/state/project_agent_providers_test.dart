import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  group('projectAgentServiceProvider', () {
    test('creates service and wires persisted-state notifications', () {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final mockOrchestrator = MockWakeOrchestrator();
      final mockSyncService = MockAgentSyncService();
      final mockDomainLogger = MockDomainLogger();
      final mockNotifications = MockUpdateNotifications();
      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          domainLoggerProvider.overrideWithValue(mockDomainLogger),
          updateNotificationsProvider.overrideWithValue(mockNotifications),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(projectAgentServiceProvider);

      expect(service, isA<ProjectAgentService>());
      expect(service.agentService, same(mockAgentService));
      expect(service.repository, same(mockRepository));
      expect(service.orchestrator, same(mockOrchestrator));
      expect(service.syncService, same(mockSyncService));
      expect(service.domainLogger, same(mockDomainLogger));

      service.onPersistedStateChanged?.call('agent-project-1');

      verify(
        () => mockNotifications.notifyUiOnly({
          'agent-project-1',
          agentNotification,
        }),
      ).called(1);
    });
  });

  group('ProjectAgentSummaryState', () {
    test(
      'isSummaryOutdated is true when report exists and activity is pending',
      () {
        final state = ProjectAgentSummaryState(
          agentId: 'agent-1',
          hasReport: true,
          pendingProjectActivityAt: DateTime(2026, 3, 22, 12),
        );

        expect(state.isSummaryOutdated, isTrue);
      },
    );

    test('isSummaryOutdated is false when no pending activity', () {
      const state = ProjectAgentSummaryState(
        agentId: 'agent-1',
        hasReport: true,
      );

      expect(state.isSummaryOutdated, isFalse);
    });

    test('isSummaryOutdated is false when no report', () {
      final state = ProjectAgentSummaryState(
        agentId: 'agent-1',
        hasReport: false,
        pendingProjectActivityAt: DateTime(2026, 3, 22, 12),
      );

      expect(state.isSummaryOutdated, isFalse);
    });

    test(
      'isSummaryOutdated is false when both report and activity are absent',
      () {
        const state = ProjectAgentSummaryState(
          agentId: 'agent-1',
          hasReport: false,
        );

        expect(state.isSummaryOutdated, isFalse);
      },
    );

    test('exposes all constructor fields', () {
      final wake = DateTime(2026, 3, 23, 6);
      final pending = DateTime(2026, 3, 22, 12);
      final state = ProjectAgentSummaryState(
        agentId: 'agent-42',
        hasReport: true,
        pendingProjectActivityAt: pending,
        scheduledWakeAt: wake,
      );

      expect(state.agentId, 'agent-42');
      expect(state.hasReport, isTrue);
      expect(state.pendingProjectActivityAt, pending);
      expect(state.scheduledWakeAt, wake);
    });
  });

  group('projectAgentSummaryProvider', () {
    const projectId = 'project-1';
    const agentId = 'agent-project-1';

    test('returns null when no project agent exists', () async {
      final container = ProviderContainer(
        overrides: [
          projectAgentProvider(projectId).overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        projectAgentSummaryProvider(projectId).future,
      );

      expect(result, isNull);
    });

    test(
      'returns null when projectAgent resolves to a non-agent entity',
      () async {
        final container = ProviderContainer(
          overrides: [
            projectAgentProvider(
              projectId,
            ).overrideWith((ref) async => makeTestState(agentId: agentId)),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          projectAgentSummaryProvider(projectId).future,
        );

        expect(result, isNull);
      },
    );

    test('builds summary with stale metadata and non-empty report', () async {
      final scheduledWakeAt = DateTime(2026, 3, 23, 6);
      final pendingProjectActivityAt = DateTime(2026, 3, 22, 12);
      final container = ProviderContainer(
        overrides: [
          projectAgentProvider(
            projectId,
          ).overrideWith((ref) async => makeTestIdentity(agentId: agentId)),
          agentStateProvider(
            agentId,
          ).overrideWith(
            (ref) async => makeTestState(
              agentId: agentId,
              slots: AgentSlots(
                pendingProjectActivityAt: pendingProjectActivityAt,
              ),
              scheduledWakeAt: scheduledWakeAt,
            ),
          ),
          agentReportProvider(
            agentId,
          ).overrideWith(
            (ref) async => makeTestReport(
              agentId: agentId,
              content: 'Fresh enough to count.',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        projectAgentSummaryProvider(projectId).future,
      );

      expect(result, isNotNull);
      expect(result!.agentId, agentId);
      expect(result.hasReport, isTrue);
      expect(result.pendingProjectActivityAt, pendingProjectActivityAt);
      expect(result.scheduledWakeAt, scheduledWakeAt);
      expect(result.isSummaryOutdated, isTrue);
    });

    test('treats whitespace-only report content as missing', () async {
      final container = ProviderContainer(
        overrides: [
          projectAgentProvider(
            projectId,
          ).overrideWith((ref) async => makeTestIdentity(agentId: agentId)),
          agentStateProvider(
            agentId,
          ).overrideWith((ref) async => makeTestState(agentId: agentId)),
          agentReportProvider(
            agentId,
          ).overrideWith(
            (ref) async => makeTestReport(
              agentId: agentId,
              content: '   \n  ',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        projectAgentSummaryProvider(projectId).future,
      );

      expect(result, isNotNull);
      expect(result!.agentId, agentId);
      expect(result.hasReport, isFalse);
      expect(result.isSummaryOutdated, isFalse);
    });
  });
}
