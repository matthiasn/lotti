import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import 'project_providers_test_helpers.dart';

void main() {
  late MockProjectRepository mockRepo;
  late StreamController<Set<String>> updateStreamController;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockProjectRepository();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(
      () => mockRepo.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);

    container = ProviderContainer(
      overrides: withServiceOverrides([
        projectRepositoryProvider.overrideWithValue(mockRepo),
      ]),
    );
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
  });

  group('projectAgentOverviewUpdateStreamProvider', () {
    test(
      'refreshes when a hard-deleted project agent loses its identity',
      () async {
        final notifications = MockUpdateNotifications();
        final agentRepository = MockAgentRepository();
        final controller = StreamController<Set<String>>.broadcast();
        addTearDown(controller.close);
        when(
          () => notifications.updateStream,
        ).thenAnswer((_) => controller.stream);

        final scopedContainer = ProviderContainer(
          overrides: withServiceOverrides([
            updateNotificationsProvider.overrideWithValue(notifications),
            agentRepositoryProvider.overrideWithValue(agentRepository),
          ]),
        );
        addTearDown(scopedContainer.dispose);
        final updateCompleter = Completer<Set<String>>();
        final subscription = scopedContainer.listen(
          projectAgentOverviewUpdateStreamProvider,
          (_, next) {
            next.whenData((ids) {
              if (!updateCompleter.isCompleted) updateCompleter.complete(ids);
            });
          },
        );
        addTearDown(subscription.close);
        await pumpEventQueue();

        controller.add({
          agentNotification,
          AgentNotificationScopes.projectOverview,
          'project-1',
        });

        await expectLater(
          updateCompleter.future,
          completion(
            containsAll({
              agentNotification,
              AgentNotificationScopes.projectOverview,
              'project-1',
            }),
          ),
        );
        verifyNever(() => agentRepository.getEntitiesByIds(any()));
      },
    );
  });

  group('projectHealthMetricsProvider', () {
    const projectId = 'proj-health';
    const agentId = 'agent-health';

    test(
      'returns null without reading the report provider when no project agent exists',
      () async {
        var reportRead = false;
        final scopedContainer = ProviderContainer(
          overrides: withServiceOverrides([
            projectRepositoryProvider.overrideWithValue(mockRepo),
            projectAgentProvider(projectId).overrideWith((ref) async => null),
            agentReportProvider(agentId).overrideWith((ref) async {
              reportRead = true;
              throw StateError('report provider should not be read');
            }),
          ]),
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          projectHealthMetricsProvider(projectId).future,
        );

        expect(result, isNull);
        expect(reportRead, isFalse);
      },
    );

    test('returns null when the project agent has no report yet', () async {
      final scopedContainer = ProviderContainer(
        overrides: withServiceOverrides([
          projectRepositoryProvider.overrideWithValue(mockRepo),
          projectAgentProvider(projectId).overrideWith(
            (ref) async => hMakeProjectAgent(agentId),
          ),
          agentReportProvider(agentId).overrideWith((ref) async => null),
        ]),
      );
      addTearDown(scopedContainer.dispose);

      final result = await scopedContainer.read(
        projectHealthMetricsProvider(projectId).future,
      );

      expect(result, isNull);
    });

    test(
      'reads the health band from the latest project-agent report',
      () async {
        final scopedContainer = ProviderContainer(
          overrides: withServiceOverrides([
            projectRepositoryProvider.overrideWithValue(mockRepo),
            projectAgentProvider(projectId).overrideWith(
              (ref) async => hMakeProjectAgent(agentId),
            ),
            agentReportProvider(agentId).overrideWith(
              (ref) async => AgentDomainEntity.agentReport(
                id: 'report-1',
                agentId: agentId,
                scope: 'current',
                createdAt: DateTime(2026, 4, 2, 9),
                vectorClock: null,
                content: '# Status Report',
                provenance: const {
                  'project_health_band': 'blocked',
                  'project_health_rationale':
                      'A dependency is still blocking the next step.',
                  'project_health_confidence': 0.91,
                },
              ),
            ),
          ]),
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          projectHealthMetricsProvider(projectId).future,
        );

        expect(result, isNotNull);
        expect(result!.band, ProjectHealthBand.blocked);
        expect(
          result.rationale,
          'A dependency is still blocking the next step.',
        );
        expect(result.confidence, 0.91);
      },
    );
  });
}
