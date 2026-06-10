import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

import 'tool_call_record_mapper.dart';

void main() {
  test('maps task and planner action payload shapes in created order', () {
    final base = DateTime(2026, 6, 10, 9);
    final taskPayload =
        AgentDomainEntity.agentMessagePayload(
              id: 'payload-task',
              agentId: 'agent',
              createdAt: base,
              vectorClock: null,
              content: <String, Object?>{
                'text': jsonEncode(<String, Object?>{'status': 'OPEN'}),
              },
            )
            as AgentMessagePayloadEntity;
    final plannerPayload =
        AgentDomainEntity.agentMessagePayload(
              id: 'payload-planner',
              agentId: 'agent',
              createdAt: base,
              vectorClock: null,
              content: <String, Object?>{'captureId': 'capture-1'},
            )
            as AgentMessagePayloadEntity;
    final laterAction =
        AgentDomainEntity.agentMessage(
              id: 'action-2',
              agentId: 'agent',
              threadId: 'thread',
              kind: AgentMessageKind.action,
              createdAt: base.add(const Duration(seconds: 1)),
              vectorClock: null,
              contentEntryId: 'payload-planner',
              metadata: const AgentMessageMetadata(
                runKey: 'run',
                toolName: 'parse_capture_to_items',
              ),
            )
            as AgentMessageEntity;
    final earlierAction =
        AgentDomainEntity.agentMessage(
              id: 'action-1',
              agentId: 'agent',
              threadId: 'thread',
              kind: AgentMessageKind.action,
              createdAt: base,
              vectorClock: null,
              contentEntryId: 'payload-task',
              metadata: const AgentMessageMetadata(
                runKey: 'run',
                toolName: 'set_task_status',
              ),
            )
            as AgentMessageEntity;

    final records = toolCallRecordsFromPersistedActions([
      laterAction,
      plannerPayload,
      taskPayload,
      earlierAction,
    ]);

    expect(records.map((record) => record.name), [
      'set_task_status',
      'parse_capture_to_items',
    ]);
    expect(records.first.args, {'status': 'OPEN'});
    expect(records.last.args, {'captureId': 'capture-1'});
  });
}
