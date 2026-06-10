// Maps durable ChangeSetEntity rows to eval proposal records.
//
// Eval traces should expose the final persisted proposal state, not every
// intermediate upsert produced while a workflow consolidates, retracts, or
// resolves change sets.

import 'package:lotti/features/agents/model/agent_domain_entity.dart';

import 'eval_models.dart';

List<ProposalRecord> proposalRecordsFromPersisted(
  Iterable<AgentDomainEntity> entities,
) {
  final latestById = <String, ChangeSetEntity>{};
  for (final entity in entities.whereType<ChangeSetEntity>()) {
    latestById[entity.id] = entity;
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
        ProposalRecord(
          changeSetId: changeSet.id,
          changeSetStatus: changeSet.status.name,
          targetId: changeSet.taskId,
          itemIndex: i,
          toolName: changeSet.items[i].toolName,
          args: changeSet.items[i].args,
          humanSummary: changeSet.items[i].humanSummary,
          status: changeSet.items[i].status.name,
        ),
  ];
}
