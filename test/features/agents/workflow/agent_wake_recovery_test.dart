import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/agent_wake_recovery.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/constants.dart';

typedef _LoggedError = ({String message, Object? error});

void main() {
  setUpAll(registerAllFallbackValues);

  group('isInteractiveReplyCommitted', () {
    late MockAgentRepository repository;

    setUp(() => repository = MockAgentRepository());

    AgentMessageEntity carrier({
      String agentId = 'agent-1',
      String runKey = 'run-1',
      String? toolName = AgentConversationToolNames.replyToUser,
    }) =>
        AgentDomainEntity.agentMessage(
              id: 'reply:agent-1:run-1',
              agentId: agentId,
              threadId: 'thread-1',
              kind: AgentMessageKind.action,
              createdAt: kAgentTestDate,
              vectorClock: null,
              metadata: AgentMessageMetadata(
                runKey: runKey,
                toolName: toolName,
              ),
            )
            as AgentMessageEntity;

    Future<bool> committed(AgentDomainEntity? stored) {
      when(
        () => repository.getEntity('reply:agent-1:run-1'),
      ).thenAnswer((_) async => stored);
      return isInteractiveReplyCommitted(
        repository: repository,
        replyMessageId: 'reply:agent-1:run-1',
        agentId: 'agent-1',
        runKey: 'run-1',
      );
    }

    test("is true for this run's reply_to_user carrier", () async {
      expect(await committed(carrier()), isTrue);
    });

    test('is false when nothing was written', () async {
      expect(await committed(null), isFalse);
    });

    test('is false for a carrier of another agent', () async {
      expect(await committed(carrier(agentId: 'agent-2')), isFalse);
    });

    test('is false for a carrier written by another run', () async {
      expect(await committed(carrier(runKey: 'run-0')), isFalse);
    });

    test('is false for a message that is not a reply', () async {
      expect(await committed(carrier(toolName: null)), isFalse);
      expect(await committed(carrier(toolName: 'update_report')), isFalse);
    });

    test('is false for an entity that is not a message', () async {
      expect(
        await committed(
          AgentDomainEntity.agentMessagePayload(
            id: 'reply:agent-1:run-1',
            agentId: 'agent-1',
            createdAt: kAgentTestDate,
            vectorClock: null,
            content: const {'text': 'hi'},
          ),
        ),
        isFalse,
      );
    });
  });

  group('rearmConsumedEscalation', () {
    late MockAgentSyncService syncService;
    late List<_LoggedError> logged;

    setUp(() {
      syncService = MockAgentSyncService();
      logged = [];
      when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    });

    final now = DateTime(2026, 8, 9, 12);

    Future<void> rearm({DateTime? scheduledAt}) => rearmConsumedEscalation(
      syncService: syncService,
      agentId: 'agent-1',
      workspaceKey: 'goal_escalation:2026-W32',
      triggerTokens: {'baseline:onTrack', 'period:2026-W32'},
      scheduledAt: scheduledAt ?? now,
      updatedAt: now,
      logError: (message, {error, stackTrace}) =>
          logged.add((message: message, error: error)),
    );

    test('rewrites the consumed record as a pending scheduled wake', () async {
      await rearm();

      final wake =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as ScheduledWakeEntity;
      expect(
        wake.id,
        scheduledWakeRecordId(
          'agent-1',
          workspaceKey: 'goal_escalation:2026-W32',
        ),
      );
      expect(wake.agentId, 'agent-1');
      expect(wake.status, ScheduledWakeStatus.pending);
      expect(wake.reason, WakeReason.scheduled.name);
      expect(wake.workspaceKey, 'goal_escalation:2026-W32');
      expect(
        wake.triggerTokens,
        unorderedEquals(
          ['baseline:onTrack', 'period:2026-W32'],
        ),
      );
      expect(wake.scheduledAt, now.toUtc());
      expect(wake.scheduledAt.isUtc, isTrue);
      expect(wake.vectorClock, isNull);
      expect(logged, isEmpty);
    });

    test(
      'a deferred retry keeps updatedAt at the moment of the re-arm',
      () async {
        final later = now.add(const Duration(hours: 6));

        await rearm(scheduledAt: later);

        final wake =
            verify(
                  () => syncService.upsertEntity(captureAny()),
                ).captured.single
                as ScheduledWakeEntity;
        expect(wake.scheduledAt, later.toUtc());
        expect(wake.updatedAt, now);
      },
    );

    test('a failed write is logged, never thrown', () async {
      final failure = StateError('outbox closed');
      when(() => syncService.upsertEntity(any())).thenThrow(failure);

      await expectLater(rearm(), completes);

      expect(logged, hasLength(1));
      expect(
        logged.single.message,
        'failed to re-arm escalation after wake failure',
      );
      expect(logged.single.error, same(failure));
    });
  });
}
