import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_diff.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_parser.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_writer.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// In-place day-plan editing: plan-diff proposals, accept/revert/commit,
/// block renames, and decided-task hydration.
class DayAgentPlanEditor {
  /// Creates the plan editor collaborator.
  DayAgentPlanEditor({
    required this.agentRepository,
    required this.syncService,
    required this.journalDb,
    required this.reads,
    required this.writer,
    this.onPersistedStateChanged,
  });

  /// Agent entity/link repository.
  final AgentRepository agentRepository;

  /// Sync-aware agent writer.
  final AgentSyncService syncService;

  /// Journal DB used for task/category reads while editing.
  final JournalDb journalDb;

  /// Shared plan-entity reads.
  final DayAgentPlanReads reads;

  /// Persistence-side collaborator for plan-diff resolution.
  final DayAgentPlanWriter writer;

  /// Callback fired when persisted state changes.
  final void Function(String id)? onPersistedStateChanged;

  /// Pending plan-diff change sets for [agentId]'s plan on [dayId],
  /// newest-first. Used by the UI to surface the most recent refine
  /// proposal after a refine wake completes.
  ///
  /// Returns an empty list when the plan does not exist or has no
  /// pending diffs. Filters out resolved/deleted change sets so the
  /// UI never sees stale rows.
  Future<List<ChangeSetEntity>> pendingPlanDiffsForDay({
    required String agentId,
    required String dayId,
  }) async {
    final planId = dayAgentPlanEntityId(dayId);
    final entities = await agentRepository.getEntitiesByAgentId(
      agentId,
      type: 'changeSet',
    );
    // Per-item filtering: a change set can stay `pending` overall while
    // individual items have already been confirmed/rejected (e.g. the
    // user accepted one row out of three). The UI only wants to see the
    // rows it can still act on, so we project each set down to its
    // still-pending items and drop sets that have nothing left.
    final diffs =
        entities
            .whereType<ChangeSetEntity>()
            .where(
              (cs) =>
                  cs.taskId == planId &&
                  cs.deletedAt == null &&
                  cs.status == ChangeSetStatus.pending,
            )
            .map(
              (cs) => cs.copyWith(
                items: cs.items
                    .where(
                      (item) => item.status == ChangeItemStatus.pending,
                    )
                    .toList(growable: false),
              ),
            )
            .where((cs) => cs.items.isNotEmpty)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return diffs;
  }

  /// Soft-deletes the persisted [DayPlanEntity] for [dayId] (when one
  /// exists) and every `captureToPlan` link pointing at it. The agent
  /// identity and source captures stay intact — they predate the plan
  /// and belong to the journal-side record of the day.
  ///
  /// Returns `true` when a plan was found and soft-deleted, `false`
  /// otherwise (no plan, foreign owner, or already-deleted). Idempotent
  /// so a double-fire from the UI is safe.
  Future<bool> deletePlanForDay({
    required String agentId,
    required String dayId,
  }) async {
    final entity = await agentRepository.getEntity(dayAgentPlanEntityId(dayId));
    if (entity is! DayPlanEntity) return false;
    if (entity.agentId != agentId) return false;
    if (entity.deletedAt != null) return false;

    final now = clock.now();
    final softDeleted = entity.copyWith(deletedAt: now, updatedAt: now);
    final inboundLinks = await agentRepository.getLinksTo(
      entity.id,
      type: AgentLinkTypes.captureToPlan,
    );

    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(softDeleted);
      for (final link in inboundLinks) {
        if (link.deletedAt != null) continue;
        await syncService.upsertLink(link.softDeleted(now));
      }
    });

    onPersistedStateChanged
      ?..call(agentId)
      ..call(dayId)
      ..call(entity.id);
    return true;
  }

  /// Hydrate the set of tasks the model should know about when drafting.
  ///
  /// Merges two sources, in order:
  ///   1. [explicitTaskIds] — task ids the UI passed via `decided_task:<id>`
  ///      trigger tokens. These are "I want this placed today" decisions
  ///      the user made directly in the drafting flow.
  ///   2. [parsedItems] — accepted capture-derived matches. A parsed item
  ///      with a non-null `matchedTaskId` and `deletedAt == null` represents
  ///      a "yes" the user said during reconcile. `break_capture_link`
  ///      clears `matchedTaskId` on the entity, so a current-snapshot read
  ///      of the parsed item is the source of truth.
  ///
  /// The merged id set is bulk-resolved through [JournalDb] and filtered to:
  ///   * tasks that still exist (deleted/missing ids are skipped),
  ///   * tasks whose `categoryId` is in [allowedCategoryIds] (or unrestricted
  ///     when the set is empty).
  ///
  /// Returns results in insertion order — explicit ids first, then
  /// parsed-item matches — with duplicates collapsed to the first occurrence.
  /// Returns an empty list when both inputs are empty.
  Future<List<DecidedTaskRef>> hydrateDecidedTasks({
    required Set<String> allowedCategoryIds,
    List<String> explicitTaskIds = const [],
    List<ParsedItemEntity> parsedItems = const [],
  }) async {
    final seen = <String>{};
    final orderedIds = <String>[];

    void addCandidate(String? raw) {
      if (raw == null) return;
      final id = raw.trim();
      if (id.isEmpty) return;
      if (!seen.add(id)) return;
      orderedIds.add(id);
    }

    explicitTaskIds.forEach(addCandidate);
    for (final item in parsedItems) {
      if (item.deletedAt != null) continue;
      addCandidate(item.matchedTaskId);
    }

    if (orderedIds.isEmpty) return const [];

    final entities = await journalDb.journalEntityMapForIds(orderedIds);
    final out = <DecidedTaskRef>[];
    for (final id in orderedIds) {
      final entity = entities[id];
      if (entity is! Task) continue;
      if (entity.meta.deletedAt != null) continue;
      final categoryId = entity.meta.categoryId;
      if (!categoryAllowed(categoryId, allowedCategoryIds)) continue;
      out.add(
        DecidedTaskRef(
          id: entity.id,
          title: entity.data.title,
          categoryId: categoryId,
        ),
      );
    }
    return out;
  }

  /// Persist a structured plan diff against the current plan for [dayId].
  ///
  /// Each entry in [rawChanges] becomes a `ChangeItem` on a new
  /// [ChangeSetEntity] (tool name `move_block` / `add_block` / `drop_block`).
  /// Items are individually confirmable via [acceptPlanDiff] /
  /// [revertPlanDiff]. The optional [baselinePlanId] guards against stale
  /// diffs: when supplied and the live plan id has shifted, the proposal is
  /// rejected. The optional [captureId] is stashed in the first item's args
  /// so the change set is discoverable from a refine-transcript capture.
  ///
  /// Throws [DayAgentCaptureException] when:
  ///   * the agent does not exist,
  ///   * no plan exists for [dayId] (call `draft_day_plan` first),
  ///   * [baselinePlanId] is supplied and does not match the live plan id,
  ///   * [rawChanges] is empty, or
  ///   * any change is malformed (missing fields for the action,
  ///     out-of-day timestamps, unknown `blockId`, blank `reason`, etc.).
  Future<ChangeSetEntity> proposePlanDiff({
    required String agentId,
    required String threadId,
    required String runKey,
    required String dayId,
    required List<Object?> rawChanges,
    String? baselinePlanId,
    String? captureId,
  }) async {
    await reads.requireIdentity(agentId);
    final plan = await reads.draftPlanForDay(agentId: agentId, dayId: dayId);
    if (plan == null) {
      throw DayAgentCaptureException(
        'no plan for $dayId; call draft_day_plan first',
      );
    }
    if (baselinePlanId != null && baselinePlanId != plan.id) {
      throw DayAgentCaptureException(
        'baselinePlanId $baselinePlanId does not match live plan ${plan.id}; '
        'refresh the baseline and re-propose',
      );
    }
    if (captureId != null) {
      final capture = await reads.captureOrNull(captureId);
      if (capture == null || capture.agentId != agentId) {
        throw DayAgentCaptureException('capture $captureId not found');
      }
    }
    if (rawChanges.isEmpty) {
      throw const DayAgentCaptureException(
        'propose_plan_diff requires at least one change',
      );
    }

    final blockById = <String, PlannedBlock>{
      for (final block in plan.data.plannedBlocks) block.id: block,
    };
    final parsed = <PlanDiffChange>[];
    for (final raw in rawChanges) {
      parsed.add(
        parsePlanDiffChange(raw: raw, plan: plan, blockById: blockById),
      );
    }

    final now = clock.now();
    final items = <ChangeItem>[];
    for (var i = 0; i < parsed.length; i++) {
      final change = parsed[i];
      final args = <String, dynamic>{
        ...change.toArgs(),
        if (i == 0 && captureId != null) 'captureId': captureId,
      };
      items.add(
        ChangeItem(
          toolName: change.toolName,
          args: args,
          humanSummary: formatPlanChangeSummary(change, blockById),
        ),
      );
    }

    final changeSet =
        AgentDomainEntity.changeSet(
              id: 'plan_diff:${_uuid.v4()}',
              agentId: agentId,
              taskId: plan.id,
              threadId: threadId,
              runKey: runKey,
              status: ChangeSetStatus.pending,
              items: items,
              createdAt: now,
              vectorClock: null,
            )
            as ChangeSetEntity;
    await syncService.upsertEntity(changeSet);

    onPersistedStateChanged
      ?..call(agentId)
      ..call(changeSet.id);
    return changeSet;
  }

  /// Apply some or all changes of [changeSetId] to the live plan.
  ///
  /// When [itemIndices] is null, every pending item is accepted; otherwise
  /// only the listed indices are processed. Accept is atomic: if any
  /// selected change cannot be applied (e.g., the target `blockId` is no
  /// longer present), nothing is written. Items already resolved are
  /// skipped silently — re-issuing accept against a partially-resolved set
  /// is safe.
  Future<ChangeSetEntity> acceptPlanDiff({
    required String agentId,
    required String changeSetId,
    List<int>? itemIndices,
  }) async {
    return writer.resolvePlanDiff(
      agentId: agentId,
      changeSetId: changeSetId,
      itemIndices: itemIndices,
      apply: true,
    );
  }

  /// Retract some or all changes of [changeSetId] without mutating the plan.
  ///
  /// Mirrors [acceptPlanDiff] but flips selected items' status to
  /// `rejected` (with `actor = user`, `verdict = rejected`) and leaves the
  /// plan entity untouched.
  Future<ChangeSetEntity> revertPlanDiff({
    required String agentId,
    required String changeSetId,
    List<int>? itemIndices,
  }) async {
    return writer.resolvePlanDiff(
      agentId: agentId,
      changeSetId: changeSetId,
      itemIndices: itemIndices,
      apply: false,
    );
  }

  /// Commit the day's draft plan: flip `DayPlanStatus.draft` →
  /// `DayPlanStatus.committed` and walk every `drafted` block to
  /// `committed`. Blocks already in `inProgress` / `completed` / `dropped`
  /// keep their state.
  ///
  /// Idempotent: when the plan is already `committed`, the live entity is
  /// returned unchanged (no write, no notification). Throws
  /// [DayAgentCaptureException] when no plan exists, the agent does not
  /// own it, or the plan is in some other non-draft / non-committed state
  /// (e.g. legacy `agreed` / `needsReview`).
  Future<DayPlanEntity> commitDay({
    required String agentId,
    required String dayId,
  }) async {
    await reads.requireIdentity(agentId);
    final plan = await reads.draftPlanForDay(agentId: agentId, dayId: dayId);
    if (plan == null) {
      throw DayAgentCaptureException(
        'no draft plan for $dayId; call draft_day_plan first',
      );
    }
    if (plan.data.status is DayPlanStatusCommitted) {
      // Idempotent no-op: re-commit returns the live plan without a write.
      return plan;
    }
    if (plan.data.status is! DayPlanStatusDraft) {
      throw const DayAgentCaptureException(
        'plan is not in draft state; commit is gated to drafts',
      );
    }

    final now = clock.now();
    final flippedBlocks = [
      for (final block in plan.data.plannedBlocks)
        if (block.state == PlannedBlockState.drafted)
          block.copyWith(state: PlannedBlockState.committed)
        else
          block,
    ];
    final committedPlan = plan.copyWith(
      data: plan.data.copyWith(
        status: DayPlanStatus.committed(committedAt: now),
        plannedBlocks: flippedBlocks,
      ),
      updatedAt: now,
    );

    await syncService.upsertEntity(committedPlan);
    onPersistedStateChanged
      ?..call(agentId)
      ..call(dayId)
      ..call(committedPlan.id);
    return committedPlan;
  }

  /// Rename a **standalone** planned block in place — the inline
  /// title-edit affordance on Agenda cards and Day blocks (handoff v2
  /// item 3). Task-linked blocks take their titles from the task and
  /// are rejected here; rename the task instead.
  ///
  /// Throws [DayAgentCaptureException] when no plan exists, the agent
  /// does not own it, the block is unknown, or the block is
  /// task-linked.
  Future<DayPlanEntity> renameBlock({
    required String agentId,
    required String dayId,
    required String blockId,
    required String title,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const DayAgentCaptureException(
        'block title must not be blank',
      );
    }
    await reads.requireIdentity(agentId);
    final plan = await reads.draftPlanForDay(agentId: agentId, dayId: dayId);
    if (plan == null) {
      throw DayAgentCaptureException(
        'no plan for $dayId; call draft_day_plan first',
      );
    }
    final block = plan.data.plannedBlocks
        .where((candidate) => candidate.id == blockId)
        .firstOrNull;
    if (block == null) {
      throw DayAgentCaptureException(
        'no block $blockId on the plan for $dayId',
      );
    }
    if (block.taskId != null && block.taskId!.isNotEmpty) {
      throw DayAgentCaptureException(
        'block $blockId is task-linked — rename the task instead',
      );
    }

    final now = clock.now();
    final renamedBlocks = [
      for (final candidate in plan.data.plannedBlocks)
        if (candidate.id == blockId)
          candidate.copyWith(title: trimmedTitle)
        else
          candidate,
    ];
    final renamedPlan = plan.copyWith(
      data: plan.data.copyWith(plannedBlocks: renamedBlocks),
      updatedAt: now,
    );

    await syncService.upsertEntity(renamedPlan);
    onPersistedStateChanged
      ?..call(agentId)
      ..call(dayId)
      ..call(renamedPlan.id);
    return renamedPlan;
  }

  /// Revert a committed day plan back to draft so the user can edit it again.
  ///
  /// Mirrors [commitDay] in reverse: flips `DayPlanStatus.committed` →
  /// `DayPlanStatus.draft` and walks each `committed` block back to
  /// `drafted`. Blocks already in `inProgress` / `completed` / `dropped`
  /// keep their state — those reflect what actually happened during the
  /// day and are preserved as history.
  ///
  /// Idempotent: when the plan is already `draft`, the live entity is
  /// returned unchanged (no write, no notification). Throws
  /// [DayAgentCaptureException] when no plan exists, the agent does not
  /// own it, or the plan is in some other non-draft / non-committed state
  /// (e.g. legacy `agreed` / `needsReview`).
  Future<DayPlanEntity> uncommitDay({
    required String agentId,
    required String dayId,
  }) async {
    await reads.requireIdentity(agentId);
    final plan = await reads.draftPlanForDay(agentId: agentId, dayId: dayId);
    if (plan == null) {
      throw DayAgentCaptureException(
        'no plan for $dayId to uncommit',
      );
    }
    if (plan.data.status is DayPlanStatusDraft) {
      // Idempotent no-op: already a draft, no work to do.
      return plan;
    }
    if (plan.data.status is! DayPlanStatusCommitted) {
      throw const DayAgentCaptureException(
        'plan is not in committed state; uncommit is gated to committed '
        'plans',
      );
    }

    final now = clock.now();
    final flippedBlocks = [
      for (final block in plan.data.plannedBlocks)
        if (block.state == PlannedBlockState.committed)
          block.copyWith(state: PlannedBlockState.drafted)
        else
          block,
    ];
    final uncommittedPlan = plan.copyWith(
      data: plan.data.copyWith(
        status: const DayPlanStatus.draft(),
        plannedBlocks: flippedBlocks,
      ),
      updatedAt: now,
    );

    await syncService.upsertEntity(uncommittedPlan);
    onPersistedStateChanged
      ?..call(agentId)
      ..call(dayId)
      ..call(uncommittedPlan.id);
    return uncommittedPlan;
  }
}
