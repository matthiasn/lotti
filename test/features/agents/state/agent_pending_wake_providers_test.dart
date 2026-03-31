import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(<String>[]);
  });

  test(
    'batches agent state reads when building pending wake records',
    () async {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();
      final firstIdentity = makeTestIdentity(
        agentId: 'agent-a',
        displayName: 'First',
      );
      final secondIdentity = makeTestIdentity(
        agentId: 'agent-b',
        displayName: 'Second',
      );
      final firstState = makeTestState(
        agentId: 'agent-a',
        nextWakeAt: kAgentTestDate.add(const Duration(minutes: 5)),
      );
      final secondState = makeTestState(
        agentId: 'agent-b',
        nextWakeAt: kAgentTestDate.add(const Duration(minutes: 15)),
        scheduledWakeAt: kAgentTestDate.add(const Duration(minutes: 10)),
      );

      when(
        () => mockAgentService.listAgents(),
      ).thenAnswer((_) => Future.value([firstIdentity, secondIdentity]));
      when(
        () => mockRepository.getAgentStatesByAgentIds(any()),
      ).thenAnswer(
        (_) async => {
          'agent-a': firstState,
          'agent-b': secondState,
        },
      );

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final records = await container.read(pendingWakeRecordsProvider.future);

      expect(records, hasLength(3));
      expect(records.first.type, PendingWakeType.pending);
      expect(records.first.agent.agentId, 'agent-a');
      expect(records[1].type, PendingWakeType.scheduled);
      expect(records[1].agent.agentId, 'agent-b');
      expect(records[2].type, PendingWakeType.pending);
      expect(records[2].agent.agentId, 'agent-b');
      final capturedAgentIds =
          verify(
                () => mockRepository.getAgentStatesByAgentIds(captureAny()),
              ).captured.single
              as List<String>;
      expect(capturedAgentIds, ['agent-a', 'agent-b']);
      verifyNever(() => mockRepository.getAgentState(any()));
    },
  );
}
