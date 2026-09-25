part of 'goal_spec_revision_service_test.dart';

// Model conformance: goal specs are `Kind = "goal"` in
// `specs/tla/VersionHeads.tla` — a revision supersedes every version still
// active (`SupersedeAll`, ADR 0068) and mints the next ordinal, and the head
// resolver prefers the higher ordinal. A revision refuses while the head's
// version has not synced in. The trace itself is
// `version_heads_conformance.dart`.

class _GoalSpecDocument implements VersionedDocument {
  static const _agentId = 'goal-conformance';

  static const _criteria = GoalCriterion.metric(
    criterionId: 'steps',
    dataType: 'cumulative_step_count',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    target: 10000,
  );

  @override
  String get documentId => _agentId;

  @override
  bool get rollsBack => false;

  /// What `GoalAgentService.createGoalAgent` writes: the identity, spec v1
  /// and the head that names it.
  @override
  Future<void> create(AgentReplica author) async {
    final now = clock.now();
    const versionId = '$_agentId:spec-v1';
    await author.syncService.runInTransaction(() async {
      await author.syncService.upsertEntity(
        AgentDomainEntity.agent(
          id: _agentId,
          agentId: _agentId,
          kind: AgentKinds.goalAgent,
          displayName: 'Steps',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: '$_agentId:state',
          config: const AgentConfig(),
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );
      await author.syncService.upsertEntity(
        AgentDomainEntity.goalSpecVersion(
          id: versionId,
          agentId: _agentId,
          version: 1,
          status: GoalSpecVersionStatus.active,
          authoredBy: AgentAuthors.user,
          title: 'Goal 0',
          statement: 'Walk every day.',
          criteria: _criteria,
          createdAt: now,
          vectorClock: null,
        ),
      );
      await author.syncService.upsertEntity(
        AgentDomainEntity.goalSpecHead(
          id: goalSpecHeadId(_agentId),
          agentId: _agentId,
          versionId: versionId,
          updatedAt: now,
          vectorClock: null,
        ),
      );
    });
  }

  @override
  Future<void> edit(AgentReplica device, int serial) async {
    final head = await headVersionId(device);
    if (head == null) return;
    await GoalSpecRevisionService(
      repository: device.repository,
      syncService: device.syncService,
    ).reviseFromOwner(
      agentId: _agentId,
      baseVersionId: head,
      displayName: 'Steps',
      title: 'Goal $serial',
      statement: 'Walk every day.',
      criteria: _criteria,
    );
  }

  @override
  Future<void> rollback(AgentReplica device, String versionId) =>
      throw UnsupportedError('goal specs have no rollback');

  @override
  Future<String?> headVersionId(AgentReplica device) async {
    final head = await device.repository.getEntity(goalSpecHeadId(_agentId));
    return head is GoalSpecHeadEntity ? head.versionId : null;
  }

  @override
  Future<Map<String, String>> versionStatuses(AgentReplica device) async {
    final versions =
        (await device.repository.getEntitiesByAgentId(
          _agentId,
          type: AgentEntityTypes.goalSpecVersion,
        )).whereType<GoalSpecVersionEntity>().toList()..sort(
          (a, b) => a.version != b.version
              ? a.version.compareTo(b.version)
              : a.createdAt.compareTo(b.createdAt),
        );
    return {for (final version in versions) version.id: version.status.name};
  }

  /// The goal's reads (Phase A, the workflow, the revision fences) resolve
  /// the head's version by id.
  @override
  Future<String?> activeVersionId(AgentReplica device) async {
    final head = await headVersionId(device);
    if (head == null) return null;
    final version = await device.repository.getEntity(head);
    return version is GoalSpecVersionEntity ? version.id : null;
  }

  @override
  bool isActive(String status) => status == GoalSpecVersionStatus.active.name;
}

void _registerGoalSpecVersionHeadsConformance() {
  group('model conformance with specs/tla/VersionHeads.tla', () {
    registerVersionHeadsConformance('goal specs', _GoalSpecDocument.new);
  });
}
