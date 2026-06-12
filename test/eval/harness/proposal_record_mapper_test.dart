import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';

import 'proposal_record_mapper.dart';

void main() {
  final now = DateTime(2026, 6, 9, 9);

  ChangeSetEntity changeSet({
    required String id,
    required String targetId,
    required List<ChangeItem> items,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) =>
      AgentDomainEntity.changeSet(
            id: id,
            agentId: 'agent-1',
            taskId: targetId,
            threadId: 'thread-1',
            runKey: 'run-1',
            status: ChangeSetStatus.pending,
            items: items,
            createdAt: createdAt ?? now,
            vectorClock: null,
            deletedAt: deletedAt,
          )
          as ChangeSetEntity;

  ChangeItem item({
    required String toolName,
    required String title,
    ChangeItemStatus status = ChangeItemStatus.pending,
  }) => ChangeItem(
    toolName: toolName,
    args: {'title': title},
    humanSummary: 'Add: "$title"',
    status: status,
  );

  test('uses the final non-deleted change-set row per id', () {
    final stale = changeSet(
      id: 'cs-1',
      targetId: 'task-1',
      items: [item(toolName: 'add_checklist_item', title: 'Old title')],
    );
    final finalRow = changeSet(
      id: 'cs-1',
      targetId: 'task-1',
      items: [
        item(
          toolName: 'add_checklist_item',
          title: 'Final title',
          status: ChangeItemStatus.confirmed,
        ),
      ],
    );
    final deleted = changeSet(
      id: 'cs-2',
      targetId: 'task-2',
      items: [item(toolName: 'add_checklist_item', title: 'Deleted title')],
      deletedAt: now,
    );

    final records = proposalRecordsFromPersisted([stale, deleted, finalRow]);

    expect(records, hasLength(1));
    expect(records.single.changeSetId, 'cs-1');
    expect(records.single.changeSetStatus, 'pending');
    expect(records.single.targetId, 'task-1');
    expect(records.single.itemIndex, 0);
    expect(records.single.args['title'], 'Final title');
    expect(records.single.status, 'confirmed');
  });
}
