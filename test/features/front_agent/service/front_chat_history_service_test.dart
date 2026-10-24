import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/service/front_chat_history_service.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  late MockAgentRepository repository;
  late FrontChatHistoryService service;

  AgentMessageEntity user(String id, int hour, {String? payload = 'p'}) =>
      makeTestMessage(
        id: id,
        agentId: frontAgentId,
        kind: AgentMessageKind.user,
        contentEntryId: payload,
        createdAt: DateTime(2026, 10, 24, hour),
      );

  AgentMessageEntity answer(
    String id,
    String toolName, {
    String? operationId,
    DateTime? deletedAt,
  }) => makeTestMessage(
    id: id,
    agentId: frontAgentId,
    kind: AgentMessageKind.action,
    metadata: AgentMessageMetadata(
      runKey: 'run-$id',
      toolName: toolName,
      operationId: operationId,
    ),
    contentEntryId: 'p-$id',
    createdAt: DateTime(2026, 10, 24, 12),
  ).copyWith(deletedAt: deletedAt);

  setUp(() {
    repository = MockAgentRepository();
    service = FrontChatHistoryService(repository: repository);
  });

  test('a turn is answered by a dispatch, a question or a reply — and only '
      'by a record that names it', () async {
    when(() => repository.getAgentMessages(frontAgentId)).thenAnswer(
      (_) async => [
        user('u-dispatched', 9),
        user('u-asked', 10),
        user('u-replied', 11),
        user('u-open', 8),
        answer('d', FrontAgentToolNames.dispatch, operationId: 'u-dispatched'),
        answer('a', FrontAgentToolNames.askUser, operationId: 'u-asked'),
        answer('r', FrontAgentToolNames.replyToUser, operationId: 'u-replied'),
        // The strategy's tool-call log: same tool name, no operationId.
        answer('log', FrontAgentToolNames.dispatch),
      ],
    );

    expect(await service.pendingMessageIds(), ['u-open']);
    expect(await service.oldestPendingMessageId(), 'u-open');
  });

  test('pending turns come oldest first, by time then id', () async {
    when(() => repository.getAgentMessages(frontAgentId)).thenAnswer(
      (_) async => [user('b', 9), user('a', 9), user('c', 8)],
    );
    expect(await service.pendingMessageIds(), ['c', 'a', 'b']);
  });

  test('a user row a wake wrote, one without a payload, or a deleted one is '
      'not a turn to answer', () async {
    when(() => repository.getAgentMessages(frontAgentId)).thenAnswer(
      (_) async => [
        makeTestMessage(
          id: 'wake-user',
          agentId: frontAgentId,
          kind: AgentMessageKind.user,
          runKey: 'run-1',
          contentEntryId: 'p',
        ),
        user('no-payload', 9, payload: null),
        user('deleted', 9).copyWith(deletedAt: DateTime(2026, 10, 24, 13)),
        user('real', 10),
      ],
    );
    expect(await service.pendingMessageIds(), ['real']);
  });

  test('a deleted answer does not answer', () async {
    when(() => repository.getAgentMessages(frontAgentId)).thenAnswer(
      (_) async => [
        user('u', 9),
        answer(
          'r',
          FrontAgentToolNames.replyToUser,
          operationId: 'u',
          deletedAt: DateTime(2026, 10, 24, 13),
        ),
      ],
    );
    expect(await service.pendingMessageIds(), ['u']);
  });

  test('nothing pending reads as null', () async {
    when(
      () => repository.getAgentMessages(frontAgentId),
    ).thenAnswer((_) async => const []);
    expect(await service.oldestPendingMessageId(), isNull);
  });
}
