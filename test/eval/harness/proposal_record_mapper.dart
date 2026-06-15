// Maps durable ChangeSetEntity rows to eval proposal records.
//
// Eval traces should expose the final persisted proposal state, not every
// intermediate upsert produced while a workflow consolidates, retracts, or
// resolves change sets.

import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';

import 'eval_models.dart';

List<ProposalRecord> proposalRecordsFromPersisted(
  Iterable<AgentDomainEntity> entities,
) {
  final latestById = <String, ChangeSetEntity>{};
  for (final entity in entities.whereType<ChangeSetEntity>()) {
    latestById[entity.id] = entity;
  }
  final decisionRows =
      entities
          .whereType<ChangeDecisionEntity>()
          .where((decision) => decision.deletedAt == null)
          .toList()
        ..sort((a, b) {
          final byCreatedAt = b.createdAt.compareTo(a.createdAt);
          if (byCreatedAt != 0) return byCreatedAt;
          return b.id.compareTo(a.id);
        });
  final decisionsByKey = <String, ChangeDecisionEntity>{};
  for (final decision in decisionRows) {
    decisionsByKey.putIfAbsent(
      '${decision.changeSetId}:${decision.itemIndex}',
      () => decision,
    );
  }

  final changeSets =
      latestById.values
          .where((changeSet) => changeSet.deletedAt == null)
          .toList()
        ..sort((a, b) {
          final byCreatedAt = a.createdAt.compareTo(b.createdAt);
          if (byCreatedAt != 0) return byCreatedAt;
          return a.id.compareTo(b.id);
        });

  return [
    for (final changeSet in changeSets)
      for (var i = 0; i < changeSet.items.length; i++)
        if (!_isStaleResolvedPendingItem(
          changeSet: changeSet,
          item: changeSet.items[i],
          itemIndex: i,
          decisionsByKey: decisionsByKey,
        ))
          ProposalRecord(
            changeSetId: changeSet.id,
            changeSetStatus: changeSet.status.name,
            targetId: changeSet.taskId,
            itemIndex: i,
            toolName: changeSet.items[i].toolName,
            args: changeSet.items[i].args,
            humanSummary: changeSet.items[i].humanSummary,
            status: _effectiveProposalStatus(
              setStatus: changeSet.status,
              itemStatus: changeSet.items[i].status,
              decision: decisionsByKey['${changeSet.id}:$i']?.verdict,
            ).name,
          ),
  ];
}

bool _isStaleResolvedPendingItem({
  required ChangeSetEntity changeSet,
  required ChangeItem item,
  required int itemIndex,
  required Map<String, ChangeDecisionEntity> decisionsByKey,
}) {
  return !_isPendingLike(changeSet.status) &&
      item.status == ChangeItemStatus.pending &&
      !decisionsByKey.containsKey('${changeSet.id}:$itemIndex');
}

ChangeItemStatus _effectiveProposalStatus({
  required ChangeSetStatus setStatus,
  required ChangeItemStatus itemStatus,
  required ChangeDecisionVerdict? decision,
}) {
  if (itemStatus != ChangeItemStatus.pending) return itemStatus;
  if (decision == null) return itemStatus;
  if (_isPendingLike(setStatus) &&
      decision == ChangeDecisionVerdict.confirmed) {
    return itemStatus;
  }
  return switch (decision) {
    ChangeDecisionVerdict.confirmed => ChangeItemStatus.confirmed,
    ChangeDecisionVerdict.rejected => ChangeItemStatus.rejected,
    ChangeDecisionVerdict.deferred => ChangeItemStatus.deferred,
    ChangeDecisionVerdict.retracted => ChangeItemStatus.retracted,
  };
}

bool _isPendingLike(ChangeSetStatus status) =>
    status == ChangeSetStatus.pending ||
    status == ChangeSetStatus.partiallyResolved;
