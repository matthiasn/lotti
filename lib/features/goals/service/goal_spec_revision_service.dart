import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_spec_validator.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/goals/service/goal_revision_apply.dart';
import 'package:uuid/uuid.dart';

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
  static const _uuid = Uuid();

  Future<GoalSpecRevisionOutcome> reviseFromProposal({
    required String agentId,
    required Map<String, dynamic> changes,
    required String rationale,
    String? sourceThreadId,
  }) async {
    final now = clock.now();
    // Everything — reads included — runs inside the serialized
    // transaction: two near-simultaneous acceptances reading the head
    // BEFORE their transactions would both allocate spec-v(n+1) and the
    // later commit would silently swallow the earlier user-approved
    // revision.
    try {
      return await _syncService.runInTransaction(
        () => _reviseInTransaction(
          agentId: agentId,
          changes: changes,
          rationale: rationale,
          sourceThreadId: sourceThreadId,
          now: now,
        ),
      );
    } catch (error) {
      // The transaction's database writes can be durable even when a
      // deferred post-commit step (the sync outbox flush) rethrows. If
      // the head already moved to the version this call was minting, the
      // revision IS committed — reporting failure would let a retry mint
      // a second version on top of it.
      final head = await _repository.getEntity(goalSpecHeadId(agentId));
      if (head is GoalSpecHeadEntity) {
        final version = await _repository.getEntity(head.versionId);
        if (version is GoalSpecVersionEntity &&
            version.authoredBy == AgentKinds.goalAgent &&
            version.createdAt == now) {
          return GoalSpecRevisionMinted(
            version: version,
            changeSummaries: const ['(committed before a sync error)'],
          );
        }
      }
      rethrow;
    }
  }

  Future<GoalSpecRevisionOutcome> _reviseInTransaction({
    required String agentId,
    required Map<String, dynamic> changes,
    required String rationale,
    required String? sourceThreadId,
    required DateTime now,
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

    final nextVersion = current.version + 1;
    // The id carries a random suffix: two DISCONNECTED replicas approving
    // different proposals both mint a v$nextVersion, and deterministic
    // ids would collide — generic LWW would then silently swallow one
    // explicit user approval, provenance and all. Unique ids keep both
    // rows; the head's own LWW picks the standing one and the other
    // stays in history.
    final versionId =
        '$agentId:spec-v$nextVersion-${_uuid.v4().substring(0, 8)}';
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

    await _syncService.upsertEntity(
      current.copyWith(status: GoalSpecVersionStatus.superseded),
    );
    await _syncService.upsertEntity(minted);
    await _syncService.upsertEntity(
      head.copyWith(versionId: versionId, updatedAt: now),
    );

    // Ads pitched for the superseded goal must not keep running beside
    // the revised statement until their own staleAt: every nudge that
    // has not reached a terminal state moves to `superseded` with the
    // spec (ADR 0055 — the agent retires, the clock expires, the USER
    // dismisses; a revision is the spec itself moving on). `retired`
    // rows move too: they are the reuse library (`reusableTopRated`),
    // and a top-rated ad written for the old target must not be
    // re-activated beside the revised statement on a later wake.
    final nudges = (await _repository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.goalNudge,
    )).whereType<GoalNudgeEntity>();
    for (final nudge in nudges) {
      if (nudge.deletedAt != null) continue;
      const affected = {
        GoalNudgeStatus.draft,
        GoalNudgeStatus.ready,
        GoalNudgeStatus.active,
        GoalNudgeStatus.retired,
      };
      if (!affected.contains(nudge.status)) continue;
      await _syncService.upsertEntity(
        nudge.copyWith(
          status: GoalNudgeStatus.superseded,
          supersededAt: now,
          updatedAt: now,
        ),
      );
    }

    return GoalSpecRevisionMinted(
      version: minted,
      changeSummaries: applied.changeSummaries,
    );
  }
}
