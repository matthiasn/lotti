import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../projects/test_utils.dart';

void main() {
  group('projectAgentServiceProvider', () {
    test(
      'creates service and wires project validation and notifications',
      () async {
        final mockAgentService = MockAgentService();
        final mockRepository = MockAgentRepository();
        final mockOrchestrator = MockWakeOrchestrator();
        final mockSyncService = MockAgentSyncService();
        final mockDomainLogger = MockDomainLogger();
        final mockNotifications = MockUpdateNotifications();
        final mockProjectRepository = MockProjectRepository();
        when(
          () => mockProjectRepository.getProjectById('missing-project'),
        ).thenAnswer((_) async => null);
        when(
          () => mockProjectRepository.getProjectById('current-project'),
        ).thenAnswer(
          (_) async => makeTestProject(
            id: 'current-project',
            categoryId: 'current-category',
          ),
        );
        final container = ProviderContainer(
          overrides: [
            agentServiceProvider.overrideWithValue(mockAgentService),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
            agentSyncServiceProvider.overrideWithValue(mockSyncService),
            domainLoggerProvider.overrideWithValue(mockDomainLogger),
            updateNotificationsProvider.overrideWithValue(mockNotifications),
            projectRepositoryProvider.overrideWithValue(mockProjectRepository),
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
        expect(
          await service.projectScopeIsCurrent('missing-project', const {}),
          isFalse,
        );
        expect(
          await service.projectScopeIsCurrent(
            'current-project',
            const {'current-category'},
          ),
          isTrue,
        );
        expect(
          await service.projectScopeIsCurrent(
            'current-project',
            const {'stale-category'},
          ),
          isFalse,
        );

        service.onPersistedStateChanged?.call('agent-project-1');

        verify(
          () => mockNotifications.notifyUiOnly({
            'agent-project-1',
            agentNotification,
          }),
        ).called(1);
      },
    );
  });
}
