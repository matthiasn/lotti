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
    ChangeSetStatus status = ChangeSetStatus.pending,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) =>
      AgentDomainEntity.changeSet(
            id: id,
            agentId: 'agent-1',
            taskId: targetId,
            threadId: 'thread-1',
            runKey: 'run-1',
            status: status,
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

  ChangeDecisionEntity decision({
    required String id,
    required String changeSetId,
    required ChangeDecisionVerdict verdict,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) =>
      AgentDomainEntity.changeDecision(
            id: id,
            agentId: 'agent-1',
            changeSetId: changeSetId,
            itemIndex: 0,
            toolName: 'add_checklist_item',
            verdict: verdict,
            taskId: 'task-1',
            createdAt: createdAt ?? now,
            vectorClock: null,
            deletedAt: deletedAt,
          )
          as ChangeDecisionEntity;

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

  test('filters resolved parent rows with stale embedded pending items', () {
    final staleResolved = changeSet(
      id: 'cs-stale',
      targetId: 'task-1',
      status: ChangeSetStatus.resolved,
      items: [
        item(toolName: 'add_checklist_item', title: 'Stale pending title'),
      ],
    );
    final expired = changeSet(
      id: 'cs-expired',
      targetId: 'task-1',
      status: ChangeSetStatus.expired,
      items: [item(toolName: 'add_checklist_item', title: 'Expired title')],
    );
    final active = changeSet(
      id: 'cs-active',
      targetId: 'task-1',
      items: [item(toolName: 'add_checklist_item', title: 'Open title')],
    );

    final records = proposalRecordsFromPersisted([
      staleResolved,
      expired,
      active,
    ]);

    expect(records, hasLength(1));
    expect(records.single.changeSetId, 'cs-active');
    expect(records.single.args['title'], 'Open title');
  });

  test('derives stale pending item status from the newest decision', () {
    final resolved = changeSet(
      id: 'cs-resolved',
      targetId: 'task-1',
      status: ChangeSetStatus.resolved,
      items: [
        item(toolName: 'add_checklist_item', title: 'Decision title'),
      ],
    );
    final oldDecision = decision(
      id: 'decision-old',
      changeSetId: resolved.id,
      verdict: ChangeDecisionVerdict.confirmed,
      createdAt: now,
    );
    final newestDecision = decision(
      id: 'decision-new',
      changeSetId: resolved.id,
      verdict: ChangeDecisionVerdict.rejected,
      createdAt: now.add(const Duration(minutes: 1)),
    );

    final records = proposalRecordsFromPersisted([
      oldDecision,
      resolved,
      newestDecision,
    ]);

    expect(records, hasLength(1));
    expect(records.single.changeSetId, resolved.id);
    expect(records.single.changeSetStatus, 'resolved');
    expect(records.single.status, 'rejected');
    expect(records.single.args['title'], 'Decision title');
  });

  test('keeps active confirmed items pending for dispatch retry', () {
    final pending = changeSet(
      id: 'cs-pending',
      targetId: 'task-1',
      items: [
        item(toolName: 'add_checklist_item', title: 'Retryable title'),
      ],
    );
    final confirmed = decision(
      id: 'decision-confirmed',
      changeSetId: pending.id,
      verdict: ChangeDecisionVerdict.confirmed,
    );

    final records = proposalRecordsFromPersisted([confirmed, pending]);

    expect(records, hasLength(1));
    expect(records.single.status, 'pending');
    expect(records.single.args['title'], 'Retryable title');
  });
}
