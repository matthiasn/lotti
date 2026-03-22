import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final now = DateTime(2026, 3, 22, 14, 5);
  late MockUpdateNotifications notifications;
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late StreamController<Set<String>> updateController;
  late ProjectActivityMonitor monitor;

  setUp(() {
    notifications = MockUpdateNotifications();
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    updateController = StreamController<Set<String>>.broadcast();

    when(() => notifications.localUpdateStream).thenAnswer(
      (_) => updateController.stream,
    );
    when(
      () => notifications.notify(
        any(),
        fromSync: any(named: 'fromSync'),
      ),
    ).thenReturn(null);
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});

    monitor = ProjectActivityMonitor(
      notifications: notifications,
      agentRepository: repository,
      syncService: syncService,
      clock: Clock.fixed(now),
    );
  });

  tearDown(() async {
    await monitor.stop();
    await updateController.close();
  });

  group('ProjectActivityMonitor', () {
    test('marks pending activity for linked project agents', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );
      final state = makeTestState(
        agentId: 'agent-1',
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );

      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => state);

      monitor.start();

      updateController.add({'project-1'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final captured =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentStateEntity;
      expect(captured.slots.activeProjectId, 'project-1');
      expect(captured.slots.pendingProjectActivityAt, now);
      expect(captured.revision, state.revision + 1);

      verify(
        () => notifications.notify(
          {'agent-1', agentNotification},
          fromSync: true,
        ),
      ).called(1);
    });

    test('ignores affected ids that do not map to project agents', () async {
      when(
        () => repository.getLinksTo(
          'PROJECT',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => []);

      monitor.start();

      updateController.add({projectNotification});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => syncService.upsertEntity(any()));
      verifyNever(
        () => notifications.notify(
          any(),
          fromSync: any(named: 'fromSync'),
        ),
      );
    });
  });
}
