import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_spec_validator.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/goals/service/goal_mirror_service.dart';
import 'package:lotti/features/goals/service/goal_revision_apply.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
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
  const GoalSpecRevisionRefused(this.reason, {this.retryable = false});

  final String reason;

  /// Whether the refusal can become applicable after more synced state arrives.
  final bool retryable;
}

/// Mints a new goal spec version from an APPROVED `propose_goal_revision_v2`
/// ChangeSet item or an explicit owner edit, then moves the head. These are the
/// only paths that change a goal after creation (ADR 0053: the coach never
/// quietly moves its own goalposts; approval or direct editing is required).
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
    this._goalMirrorService,
  });

  final AgentRepository _repository;
  final AgentSyncService _syncService;

  /// Mirrors each accepted revision into the journal. Optional: the agent tier
  /// is authoritative for evaluation and must not depend on the mirror.
  final GoalMirrorService? _goalMirrorService;
  static const _uuid = Uuid();
  static const String ownerNoChangesReason =
      'the owner edit does not change the goal';
  static const String ownerStaleVersionReason =
      'the goal changed after this editor was opened';
  static const String proposalStaleVersionReason =
      'the goal changed after this proposal was created';

  /// Applies an approved agent proposal against the exact goal version from
  /// which it was authored.
  ///
  /// Callers must pass that originating version as [baseVersionId]. The save
  /// is refused when the current head no longer matches, preventing a stale
  /// synced proposal from overwriting a newer owner or agent revision.
  Future<GoalSpecRevisionOutcome> reviseFromProposal({
    required String agentId,
    required String baseVersionId,
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
          baseVersionId: baseVersionId,
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

  /// Applies an explicit owner edit as a new immutable goal version.
  ///
  /// Unlike an agent proposal, this path receives the complete authored
  /// shape from the create/edit flow. It may rename the goal, change the
  /// verbatim intention, replace the observable criteria, and rename the
  /// goal's conversational persona. History is retained through
  /// [GoalSpecVersionEntity.diffFromVersionId]; the active version is never
  /// rewritten in place. [baseVersionId] is the head loaded by the editor;
  /// the save is refused if another writer moved the head in the meantime.
  /// A successful owner edit also retracts pending agent-authored revision
  /// proposals so an older suggestion cannot later overwrite the new spec.
  Future<GoalSpecRevisionOutcome> reviseFromOwner({
    required String agentId,
    required String baseVersionId,
    required String displayName,
    required String title,
    required String statement,
    required GoalCriterion criteria,
  }) async {
    final normalizedDisplayName = displayName.trim();
    final normalizedTitle = title.trim();
    final normalizedStatement = statement.trim();
    if (normalizedDisplayName.isEmpty ||
        normalizedTitle.isEmpty ||
        normalizedStatement.isEmpty) {
      return const GoalSpecRevisionRefused(
        'the persona, goal name, and intention must not be blank',
      );
    }
    final issues = GoalSpecValidator.criterionIssues(criteria);
    if (issues.isNotEmpty) {
      return GoalSpecRevisionRefused(
        'the revised criteria fail validation: ${issues.join('; ')}',
      );
    }

    final now = clock.now();
    try {
      return await _syncService.runInTransaction(() async {
        final identity = await _repository.getEntity(agentId);
        if (identity is! AgentIdentityEntity ||
            identity.kind != AgentKinds.goalAgent ||
            identity.lifecycle != AgentLifecycle.active) {
          return const GoalSpecRevisionRefused('goal agent is not active');
        }
        final head = await _repository.getEntity(goalSpecHeadId(agentId));
        if (head is! GoalSpecHeadEntity) {
          return const GoalSpecRevisionRefused(
            'the goal no longer exists (no spec head)',
            retryable: true,
          );
        }
        final current = await _repository.getEntity(head.versionId);
        if (current is! GoalSpecVersionEntity) {
          return GoalSpecRevisionRefused(
            'spec head ${head.versionId} points at nothing',
            retryable: true,
          );
        }
        if (current.id != baseVersionId) {
          return const GoalSpecRevisionRefused(ownerStaleVersionReason);
        }
        if (identity.displayName == normalizedDisplayName &&
            current.title == normalizedTitle &&
            current.statement == normalizedStatement &&
            current.criteria == criteria) {
          return const GoalSpecRevisionRefused(ownerNoChangesReason);
        }

        final summaries = <String>[
          if (identity.displayName != normalizedDisplayName)
            'persona name updated',
          if (current.title != normalizedTitle) 'goal name updated',
          if (current.statement != normalizedStatement) 'intention updated',
          if (current.criteria != criteria) 'goal criteria updated',
        ];
        return _mintRevision(
          identity: identity,
          head: head,
          current: current,
          displayName: normalizedDisplayName,
          title: normalizedTitle,
          statement: normalizedStatement,
          criteria: criteria,
          authoredBy: AgentAuthors.user,
          rationale: 'Owner edited the goal.',
          sourceThreadId: null,
          changeSummaries: summaries,
          now: now,
        );
      });
    } catch (error) {
      final head = await _repository.getEntity(goalSpecHeadId(agentId));
      if (head is GoalSpecHeadEntity) {
        final version = await _repository.getEntity(head.versionId);
        if (version is GoalSpecVersionEntity &&
            version.authoredBy == AgentAuthors.user &&
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
    required String baseVersionId,
    required Map<String, dynamic> changes,
    required String rationale,
    required String? sourceThreadId,
    required DateTime now,
  }) async {
    final identity = await _repository.getEntity(agentId);
    if (identity is! AgentIdentityEntity ||
        identity.kind != AgentKinds.goalAgent ||
        identity.lifecycle != AgentLifecycle.active) {
      return const GoalSpecRevisionRefused('goal agent is not active');
    }
    final head = await _repository.getEntity(goalSpecHeadId(agentId));
    if (head is! GoalSpecHeadEntity) {
      return const GoalSpecRevisionRefused(
        'the goal no longer exists (no spec head)',
        retryable: true,
      );
    }
    final current = await _repository.getEntity(head.versionId);
    if (current is! GoalSpecVersionEntity) {
      return GoalSpecRevisionRefused(
        'spec head ${head.versionId} points at nothing',
        retryable: true,
      );
    }
    if (current.id != baseVersionId) {
      return const GoalSpecRevisionRefused(proposalStaleVersionReason);
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

    return _mintRevision(
      identity: identity,
      head: head,
      current: current,
      displayName: identity.displayName,
      title: current.title,
      statement: current.statement,
      criteria: revised,
      authoredBy: AgentKinds.goalAgent,
      rationale: rationale,
      sourceThreadId: sourceThreadId,
      changeSummaries: applied.changeSummaries,
      now: now,
    );
  }

  Future<GoalSpecRevisionOutcome> _mintRevision({
    required AgentIdentityEntity identity,
    required GoalSpecHeadEntity head,
    required GoalSpecVersionEntity current,
    required String displayName,
    required String title,
    required String statement,
    required GoalCriterion criteria,
    required String authoredBy,
    required String rationale,
    required String? sourceThreadId,
    required List<String> changeSummaries,
    required DateTime now,
  }) async {
    final agentId = identity.agentId;
    final nextVersion = current.version + 1;
    // The id carries a random suffix: two DISCONNECTED replicas can both mint
    // a v$nextVersion, and deterministic ids would collide and lose history.
    // Owner-authored ids additionally carry a marker used by the pure head
    // conflict resolver: at the same ordinal, direct owner intent wins over an
    // independently approved agent proposal on every replica.
    final versionId = goalSpecRevisionVersionId(
      agentId: agentId,
      version: nextVersion,
      ownerAuthored: authoredBy == AgentAuthors.user,
      uniqueSuffix: _uuid.v4().substring(0, 8),
    );
    final minted =
        AgentDomainEntity.goalSpecVersion(
              id: versionId,
              agentId: agentId,
              version: nextVersion,
              status: GoalSpecVersionStatus.active,
              authoredBy: authoredBy,
              title: title,
              statement: statement,
              criteria: criteria,
              createdAt: now,
              vectorClock: null,
              sourceSessionId: sourceThreadId,
              diffFromVersionId: current.id,
              startDate: current.startDate,
              targetDate: current.targetDate,
              rationale: rationale,
            )
            as GoalSpecVersionEntity;

    if (identity.displayName != displayName) {
      await _syncService.upsertEntity(
        identity.copyWith(displayName: displayName, updatedAt: now),
      );
    }
    await _syncService.upsertEntity(
      current.copyWith(status: GoalSpecVersionStatus.superseded),
    );
    await _syncService.upsertEntity(minted);
    await _syncService.upsertEntity(
      head.copyWith(versionId: versionId, updatedAt: now),
    );
    // The journal keeps every version: this writes the new immutable snapshot
    // and moves the goal onto it, so the durable record follows the head
    // rather than drifting a revision behind it.
    await _goalMirrorService?.mirrorSpec(version: minted);

    if (authoredBy == AgentAuthors.user) {
      await _retractPendingRevisionProposals(agentId: agentId, now: now);
    }

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
        NudgeStatus.draft,
        NudgeStatus.ready,
        NudgeStatus.active,
        NudgeStatus.retired,
      };
      if (!affected.contains(nudge.status)) continue;
      await _syncService.upsertEntity(
        nudge.copyWith(
          status: NudgeStatus.superseded,
          supersededAt: now.toUtc(),
          updatedAt: now,
        ),
      );
    }

    // Pending escalations were armed under the OLD spec: left alone they
    // would later resolve against the revised register and spend
    // inference on a transition the new goal never made. The immediate
    // post-approval evaluation re-arms anything genuinely due.
    final wakes = (await _repository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.scheduledWake,
    )).whereType<ScheduledWakeEntity>();
    for (final wake in wakes) {
      if (wake.deletedAt != null ||
          wake.status != ScheduledWakeStatus.pending ||
          !(wake.workspaceKey?.startsWith('goal-escalation') ?? false)) {
        continue;
      }
      await _syncService.upsertEntity(
        wake.copyWith(status: ScheduledWakeStatus.consumed, consumedAt: now),
      );
    }

    return GoalSpecRevisionMinted(
      version: minted,
      changeSummaries: changeSummaries,
    );
  }

  Future<void> _retractPendingRevisionProposals({
    required String agentId,
    required DateTime now,
  }) async {
    final pendingSets =
        (await _repository.getEntitiesByAgentIdAndSubtypes(
          agentId,
          type: AgentEntityTypes.changeSet,
          subtypes: const {
            ChangeSetStatus.pending,
            ChangeSetStatus.partiallyResolved,
          }.map((status) => status.name),
        )).whereType<ChangeSetEntity>().where(
          (changeSet) => changeSet.taskId == agentId,
        );
    for (final changeSet in pendingSets) {
      var changed = false;
      final items = changeSet.items
          .map((item) {
            if (item.status != ChangeItemStatus.pending ||
                !GoalAgentToolNames.isGoalRevisionProposal(item.toolName)) {
              return item;
            }
            changed = true;
            return item.copyWith(status: ChangeItemStatus.retracted);
          })
          .toList(growable: false);
      if (!changed) continue;

      final status = ChangeItem.deriveSetStatus(items);
      await _syncService.upsertEntity(
        changeSet.copyWith(
          items: items,
          status: status,
          resolvedAt: ChangeItem.deriveResolvedAt(
            newStatus: status,
            existingResolvedAt: changeSet.resolvedAt,
            now: now,
          ),
        ),
      );
    }
  }
}
