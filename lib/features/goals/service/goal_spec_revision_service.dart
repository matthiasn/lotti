import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_spec_validator.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/goals/service/goal_revision_apply.dart';

/// The outcome of a user-approved goal revision.
sealed class GoalSpecRevisionOutcome {
  const GoalSpecRevisionOutcome();
}

class GoalSpecRevisionMinted extends GoalSpecRevisionOutcome {
  const GoalSpecRevisionMinted({
    required this.version,
    required this.changeSummaries,
  });

  /// The freshly minted ACTIVE spec version.
  final GoalSpecVersionEntity version;
  final List<String> changeSummaries;
}

class GoalSpecRevisionRefused extends GoalSpecRevisionOutcome {
  const GoalSpecRevisionRefused(this.reason);

  final String reason;
}

/// Mints a new goal spec version from an APPROVED `propose_goal_revision`
/// ChangeSet item and moves the head — the ONLY path that ever changes a
/// goal after creation (ADR 0053: the coach never quietly moves its own
/// goalposts; the user's approval is what runs this).
///
/// The soul-version-ops pattern: everything in one transaction — supersede
/// the current version, mint `version + 1` with full provenance
/// (`authoredBy: goal_agent`, `diffFromVersionId`, the proposal's
/// rationale), move the deterministic head. Grace history resets
/// naturally: Phase A's prior-row collection breaks at the version change.
class GoalSpecRevisionService {
  GoalSpecRevisionService({
    required this._repository,
    required this._syncService,
  });

  final AgentRepository _repository;
  final AgentSyncService _syncService;

  Future<GoalSpecRevisionOutcome> reviseFromProposal({
    required String agentId,
    required Map<String, dynamic> changes,
    required String rationale,
    String? sourceThreadId,
  }) async {
    final head = await _repository.getEntity(goalSpecHeadId(agentId));
    if (head is! GoalSpecHeadEntity) {
      return const GoalSpecRevisionRefused(
        'the goal no longer exists (no spec head)',
      );
    }
    final current = await _repository.getEntity(head.versionId);
    if (current is! GoalSpecVersionEntity) {
      return GoalSpecRevisionRefused(
        'spec head ${head.versionId} points at nothing',
      );
    }

    final applied = applyGoalRevisionChanges(
      criteria: current.criteria,
      changes: changes,
    );
    if (applied is GoalRevisionRejected) {
      return GoalSpecRevisionRefused(applied.reason);
    }
    final revised = (applied as GoalRevisionApplied).criteria;
    final issues = GoalSpecValidator.criterionIssues(revised);
    if (issues.isNotEmpty) {
      return GoalSpecRevisionRefused(
        'the revised criteria fail validation: ${issues.join('; ')}',
      );
    }

    final now = clock.now();
    final nextVersion = current.version + 1;
    final versionId = '$agentId:spec-v$nextVersion';
    final minted =
        AgentDomainEntity.goalSpecVersion(
              id: versionId,
              agentId: agentId,
              version: nextVersion,
              status: GoalSpecVersionStatus.active,
              authoredBy: AgentKinds.goalAgent,
              title: current.title,
              statement: current.statement,
              criteria: revised,
              createdAt: now,
              vectorClock: null,
              sourceSessionId: sourceThreadId,
              diffFromVersionId: current.id,
              startDate: current.startDate,
              targetDate: current.targetDate,
              rationale: rationale,
            )
            as GoalSpecVersionEntity;

    await _syncService.runInTransaction(() async {
      await _syncService.upsertEntity(
        current.copyWith(status: GoalSpecVersionStatus.superseded),
      );
      await _syncService.upsertEntity(minted);
      await _syncService.upsertEntity(
        head.copyWith(versionId: versionId, updatedAt: now),
      );
    });

    return GoalSpecRevisionMinted(
      version: minted,
      changeSummaries: applied.changeSummaries,
    );
  }
}
