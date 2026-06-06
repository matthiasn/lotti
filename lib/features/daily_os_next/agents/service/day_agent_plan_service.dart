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
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Backend implementation for Daily OS day-plan drafting tools.
class DayAgentPlanService {
  /// Creates a day-plan service.
  DayAgentPlanService({
    required this.agentRepository,
    required this.syncService,
    required this.journalDb,
    required this.domainLogger,
    this.onPersistedStateChanged,
  });

  /// Agent entity/link repository.
  final AgentRepository agentRepository;

  /// Sync-aware agent writer.
  final AgentSyncService syncService;

  /// Journal DB used for task/category reads while drafting.
  final JournalDb journalDb;

  /// Structured logger.
  final DomainLogger domainLogger;

  /// Callback fired when persisted state changes.
  final void Function(String id)? onPersistedStateChanged;

  static const _uuid = Uuid();

  /// Executes a day-plan drafting tool.
  Future<DayAgentDirectToolResult> executeTool({
    required String agentId,
    required String threadId,
    required String runKey,
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    try {
      final data = switch (toolName) {
        DayAgentToolNames.draftDayPlan => await _draftDayPlanTool(
          agentId,
          args,
        ),
        DayAgentToolNames.summarizeRecentPatterns =>
          await _summarizeRecentPatternsTool(agentId, args),
        DayAgentToolNames.proposePlanDiff => await _proposePlanDiffTool(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          args: args,
        ),
        DayAgentToolNames.acceptDiff => await _acceptPlanDiffTool(
          agentId: agentId,
          args: args,
        ),
        DayAgentToolNames.revertDiff => await _revertPlanDiffTool(
          agentId: agentId,
          args: args,
        ),
        DayAgentToolNames.commitDay => await _commitDayTool(
          agentId: agentId,
          args: args,
        ),
        DayAgentToolNames.uncommitDay => await _uncommitDayTool(
          agentId: agentId,
          args: args,
        ),
        _ => throw DayAgentCaptureException('unknown tool "$toolName"'),
      };
      return DayAgentDirectToolResult.success(data);
    } on DayAgentCaptureException catch (e) {
      return DayAgentDirectToolResult.failure(e.message);
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        message: 'day-agent plan tool failed',
        stackTrace: s,
      );
      return DayAgentDirectToolResult.failure(e.toString());
    }
  }

  /// Fetch the persisted plan for one day. Soft-deleted entities are
  /// hidden so callers that come in after `deletePlanForDay` (commit,
  /// uncommit, refine, the UI's `currentPlanForDate` projection) all
  /// see the same "no plan" state instead of operating on the deleted
  /// row.
  Future<DayPlanEntity?> draftPlanForDay({
    required String agentId,
    required String dayId,
  }) async {
    final entity = await agentRepository.getEntity(dayAgentPlanEntityId(dayId));
    if (entity is DayPlanEntity &&
        entity.agentId == agentId &&
        entity.deletedAt == null) {
      return entity;
    }
    return null;
  }

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
      if (!_categoryAllowed(categoryId, allowedCategoryIds)) continue;
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
    await _requireIdentity(agentId);
    final plan = await draftPlanForDay(agentId: agentId, dayId: dayId);
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
      final capture = await _captureOrNull(captureId);
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
    final parsed = <_DiffChange>[];
    for (final raw in rawChanges) {
      parsed.add(_parseDiffChange(raw: raw, plan: plan, blockById: blockById));
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
          humanSummary: _formatChangeSummary(change, blockById),
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
    return _resolvePlanDiff(
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
    return _resolvePlanDiff(
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
    await _requireIdentity(agentId);
    final plan = await draftPlanForDay(agentId: agentId, dayId: dayId);
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
    await _requireIdentity(agentId);
    final plan = await draftPlanForDay(agentId: agentId, dayId: dayId);
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
          candidate.copyWith(title: title)
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
    await _requireIdentity(agentId);
    final plan = await draftPlanForDay(agentId: agentId, dayId: dayId);
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

  Future<ChangeSetEntity> _resolvePlanDiff({
    required String agentId,
    required String changeSetId,
    required List<int>? itemIndices,
    required bool apply,
  }) async {
    final identity = await _requireIdentity(agentId);
    final loaded = await agentRepository.getEntity(changeSetId);
    if (loaded is! ChangeSetEntity ||
        loaded.deletedAt != null ||
        loaded.agentId != agentId) {
      throw DayAgentCaptureException('change set $changeSetId not found');
    }
    final changeSet = loaded;
    final plan = await draftPlanForDay(
      agentId: agentId,
      dayId: _dayIdFromPlanEntityId(changeSet.taskId),
    );
    if (plan == null) {
      throw DayAgentCaptureException(
        'plan ${changeSet.taskId} no longer exists',
      );
    }
    final selected = _selectIndices(
      itemIndices: itemIndices,
      itemCount: changeSet.items.length,
    );
    final pendingByIndex = <int, ChangeItem>{};
    for (final index in selected) {
      final item = changeSet.items[index];
      if (item.status == ChangeItemStatus.pending) {
        pendingByIndex[index] = item;
      }
    }

    if (apply) {
      // Pre-validate every pending selected change against the current
      // plan before mutating anything (atomic all-or-nothing). The sweep
      // is order-aware (drops/moves earlier in the batch affect later
      // items) and re-runs the propose-time invariants against the
      // *resolving* agent's allowed categories so a synced ChangeItem
      // cannot smuggle an unauthorized category or out-of-day timestamp
      // past the apply path.
      _validateApplicableBatch(
        pendingByIndex.entries,
        plan,
        identity.allowedCategoryIds,
      );
    }

    final now = clock.now();
    final updatedItems = List<ChangeItem>.of(changeSet.items);
    final decisions = <ChangeDecisionEntity>[];
    var mutatedBlocks = List<PlannedBlock>.of(plan.data.plannedBlocks);
    final newVerdict = apply
        ? ChangeDecisionVerdict.confirmed
        : ChangeDecisionVerdict.rejected;
    final newItemStatus = apply
        ? ChangeItemStatus.confirmed
        : ChangeItemStatus.rejected;
    final addedBlockState = _stateForAcceptedAddedBlock(plan.data.status);

    for (final entry in pendingByIndex.entries) {
      final index = entry.key;
      final item = entry.value;
      if (apply) {
        mutatedBlocks = _applyItem(
          item,
          mutatedBlocks,
          addedBlockState: addedBlockState,
        );
      }
      updatedItems[index] = item.copyWith(status: newItemStatus);
      decisions.add(
        AgentDomainEntity.changeDecision(
              id: '${changeSet.id}:decision:$index',
              agentId: agentId,
              changeSetId: changeSet.id,
              itemIndex: index,
              toolName: item.toolName,
              verdict: newVerdict,
              createdAt: now,
              vectorClock: null,
              taskId: plan.id,
              humanSummary: item.humanSummary,
              args: item.args,
            )
            as ChangeDecisionEntity,
      );
    }

    final newSetStatus = ChangeItem.deriveSetStatus(updatedItems);
    final updatedChangeSet = changeSet.copyWith(
      items: updatedItems,
      status: newSetStatus,
      resolvedAt: ChangeItem.deriveResolvedAt(
        newStatus: newSetStatus,
        existingResolvedAt: changeSet.resolvedAt,
        now: now,
      ),
    );

    DayPlanEntity? updatedPlan;
    if (apply && pendingByIndex.isNotEmpty) {
      mutatedBlocks.sort((a, b) {
        final byStart = a.startTime.compareTo(b.startTime);
        if (byStart != 0) return byStart;
        return a.id.compareTo(b.id);
      });
      final scheduledMinutes = _scheduledMinutesFor(mutatedBlocks);
      final pinnedTasks = _pinnedTasksFor(mutatedBlocks);
      updatedPlan = plan.copyWith(
        data: plan.data.copyWith(
          plannedBlocks: mutatedBlocks,
          pinnedTasks: pinnedTasks,
        ),
        scheduledMinutes: scheduledMinutes,
        updatedAt: now,
      );
    }

    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(updatedChangeSet);
      for (final decision in decisions) {
        await syncService.upsertEntity(decision);
      }
      if (updatedPlan != null) {
        await syncService.upsertEntity(updatedPlan);
      }
    });

    onPersistedStateChanged
      ?..call(agentId)
      ..call(changeSet.id);
    if (updatedPlan != null) {
      onPersistedStateChanged
        ?..call(updatedPlan.dayId)
        ..call(updatedPlan.id);
    }
    return updatedChangeSet;
  }

  /// Persist a model-emitted draft plan.
  Future<DayPlanEntity> persistDraftPlan({
    required String agentId,
    required String dayId,
    required DateTime planDate,
    required List<Object?> rawBlocks,
    String? captureId,
    List<Object?> rawEnergyBands = const [],
    List<String> decidedTaskIds = const [],
    int capacityMinutes = 480,
    String? dayLabel,
  }) async {
    final identity = await _requireIdentity(agentId);
    if (identity.allowedCategoryIds.isNotEmpty) {
      for (final categoryId in identity.allowedCategoryIds) {
        if (categoryId.trim().isEmpty) {
          throw const DayAgentCaptureException(
            'allowed category ids must not be empty',
          );
        }
      }
    }
    if (dayId != dayAgentIdForDate(planDate)) {
      throw DayAgentCaptureException(
        'dayId must match planDate (${dayAgentIdForDate(planDate)})',
      );
    }
    if (captureId != null) {
      final capture = await _captureOrNull(captureId);
      if (capture == null || capture.agentId != agentId) {
        throw DayAgentCaptureException('capture $captureId not found');
      }
    }
    if (capacityMinutes <= 0) {
      throw const DayAgentCaptureException(
        'capacityMinutes must be greater than zero',
      );
    }

    final now = clock.now();
    final earliestDraftStart = localDay(planDate) == localDay(now) ? now : null;
    final allowedCategoryIds = identity.allowedCategoryIds;
    final decidedTasks = decidedTaskIds.toSet();
    final allowedExistingTaskIds = await _allowedExistingTaskIds(
      rawBlocks,
      allowedCategoryIds,
    );
    final blocks = <PlannedBlock>[];
    for (final raw in rawBlocks) {
      blocks.add(
        _parsePlannedBlock(
          raw: raw,
          day: planDate,
          earliestDraftStart: earliestDraftStart,
          allowedCategoryIds: allowedCategoryIds,
          decidedTaskIds: decidedTasks,
          allowedExistingTaskIds: allowedExistingTaskIds,
        ),
      );
    }
    if (blocks.isEmpty) {
      throw const DayAgentCaptureException(
        'draft_day_plan requires at least one block',
      );
    }
    blocks.sort((a, b) {
      final byStart = a.startTime.compareTo(b.startTime);
      if (byStart != 0) return byStart;
      return a.id.compareTo(b.id);
    });

    final bands = [
      for (final raw in rawEnergyBands)
        _parseEnergyBand(raw: raw, day: planDate),
    ];
    final scheduledMinutes = _scheduledMinutesFor(blocks);
    final pinnedTasks = _pinnedTasksFor(blocks);
    final existing = await draftPlanForDay(agentId: agentId, dayId: dayId);
    final plan =
        AgentDomainEntity.dayPlan(
              id: dayAgentPlanEntityId(dayId),
              agentId: agentId,
              dayId: dayId,
              captureId: captureId,
              planDate: localDay(planDate),
              data: DayPlanData(
                planDate: localDay(planDate),
                status: const DayPlanStatus.draft(),
                dayLabel: _blankToNull(dayLabel),
                plannedBlocks: blocks,
                pinnedTasks: pinnedTasks,
              ),
              energyBands: bands,
              capacityMinutes: capacityMinutes,
              scheduledMinutes: scheduledMinutes,
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
              vectorClock: null,
            )
            as DayPlanEntity;

    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(plan);
      if (captureId != null) {
        await syncService.upsertLink(
          AgentLink.captureToPlan(
            id: 'capture_to_plan:$captureId:${plan.id}',
            fromId: captureId,
            toId: plan.id,
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          ),
        );
      }
    });

    onPersistedStateChanged
      ?..call(agentId)
      ..call(dayId)
      ..call(plan.id);
    return plan;
  }

  /// Build transient learning cards from recently drafted day plans.
  Future<List<DayAgentLearningCard>> summarizeRecentPatterns({
    required String agentId,
    required DateTime asOf,
    int lookbackDays = 7,
  }) async {
    if (lookbackDays <= 0) {
      throw const DayAgentCaptureException(
        'lookbackDays must be greater than zero',
      );
    }
    final asOfDay = localDay(asOf);
    final start = asOfDay.subtract(Duration(days: lookbackDays - 1));
    final entities = await agentRepository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.dayPlan,
    );
    final plans = entities.whereType<DayPlanEntity>().where((plan) {
      final day = localDay(plan.planDate);
      return !day.isBefore(start) && !day.isAfter(asOfDay);
    }).toList()..sort((a, b) => a.planDate.compareTo(b.planDate));
    final yesterday = asOfDay.subtract(const Duration(days: 1));
    final yesterdayPlan = plans
        .where((plan) => localDay(plan.planDate) == yesterday)
        .firstOrNull;
    final totalScheduled = plans.fold<int>(
      0,
      (sum, plan) => sum + plan.scheduledMinutes,
    );
    final averageScheduled = plans.isEmpty
        ? 0
        : (totalScheduled / plans.length).round();
    final averageCapacity = plans.isEmpty
        ? 480
        : (plans.fold<int>(0, (sum, plan) => sum + plan.capacityMinutes) /
                  plans.length)
              .round();

    return [
      DayAgentLearningCard(
        id: 'yesterday',
        overline: 'Yesterday',
        summary: yesterdayPlan == null
            ? 'No drafted day plan was recorded yesterday.'
            : 'Yesterday had ${yesterdayPlan.data.plannedBlocks.length} '
                  'planned block(s) and ${yesterdayPlan.scheduledMinutes} '
                  'scheduled minute(s).',
        bullets: [
          DayAgentLearningBullet(
            text: yesterdayPlan == null
                ? 'Use today as the first clean drafting baseline.'
                : 'Carry forward only the blocks that still matter.',
            tone: yesterdayPlan == null
                ? DayAgentLearningBulletTone.info
                : DayAgentLearningBulletTone.positive,
          ),
        ],
      ),
      DayAgentLearningCard(
        id: 'week_so_far',
        overline: 'This week',
        summary: plans.isEmpty
            ? 'No recent Daily OS drafts are available yet.'
            : '${plans.length} draft(s) in the last $lookbackDays day(s), '
                  'averaging $averageScheduled scheduled minute(s).',
        bullets: [
          DayAgentLearningBullet(
            text: 'Average capacity is $averageCapacity minute(s).',
            tone: DayAgentLearningBulletTone.info,
          ),
        ],
      ),
      _gentleNudgeCard(
        plansIsEmpty: plans.isEmpty,
        averageScheduled: averageScheduled,
        averageCapacity: averageCapacity,
      ),
    ];
  }

  static DayAgentLearningCard _gentleNudgeCard({
    required bool plansIsEmpty,
    required int averageScheduled,
    required int averageCapacity,
  }) {
    if (plansIsEmpty) {
      return DayAgentLearningCard(
        id: 'gentle_nudge',
        overline: 'Gentle nudge',
        summary:
            'No recent drafts to compare against; start small and adjust as '
            'patterns emerge.',
        kind: 'nudge',
        bullets: const [
          DayAgentLearningBullet(
            text: 'Treat today as the first data point.',
            tone: DayAgentLearningBulletTone.info,
          ),
        ],
      );
    }
    final overCapacity = averageScheduled > averageCapacity;
    return DayAgentLearningCard(
      id: 'gentle_nudge',
      overline: 'Gentle nudge',
      summary: overCapacity
          ? 'Your recent drafts run over capacity; protect a buffer before '
                'adding more work.'
          : 'Your recent drafts fit capacity; place demanding work in the '
                'highest-energy window.',
      kind: 'nudge',
      bullets: [
        DayAgentLearningBullet(
          text: overCapacity
              ? 'Leave at least one transition block unassigned.'
              : 'Keep the plan specific enough to act on.',
          tone: overCapacity
              ? DayAgentLearningBulletTone.warning
              : DayAgentLearningBulletTone.positive,
        ),
      ],
    );
  }

  Future<Map<String, Object?>> _draftDayPlanTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final dayId = _requiredString(args, 'dayId');
    final planDate =
        _optionalDateTime(args['dayDate']) ?? _dateFromDayId(dayId);
    if (planDate == null) {
      throw const DayAgentCaptureException(
        'dayDate must be a valid ISO-8601 date-time',
      );
    }
    final plan = await persistDraftPlan(
      agentId: agentId,
      dayId: dayId,
      planDate: planDate,
      captureId: _optionalString(args['captureId']),
      decidedTaskIds: _stringList(args['decidedTaskIds']),
      rawBlocks: _objectList(args['blocks'], 'blocks'),
      rawEnergyBands: _objectList(args['energyBands'], 'energyBands'),
      capacityMinutes: _optionalInt(args['capacityMinutes']) ?? 480,
      dayLabel: _optionalString(args['dayLabel']),
    );
    return _planJson(plan);
  }

  Future<Map<String, Object?>> _summarizeRecentPatternsTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final asOf = _optionalDateTime(args['asOf']) ?? clock.now();
    final cards = await summarizeRecentPatterns(
      agentId: agentId,
      asOf: asOf,
      lookbackDays: _optionalInt(args['lookbackDays']) ?? 7,
    );
    return {
      'cards': [for (final card in cards) card.toJson()],
    };
  }

  Future<Map<String, Object?>> _proposePlanDiffTool({
    required String agentId,
    required String threadId,
    required String runKey,
    required Map<String, dynamic> args,
  }) async {
    final dayId = _requiredString(args, 'dayId');
    final changeSet = await proposePlanDiff(
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      dayId: dayId,
      rawChanges: _objectList(args['changes'], 'changes'),
      baselinePlanId: _optionalString(args['baselinePlanId']),
      captureId: _optionalString(args['captureId']),
    );
    return {
      'changeSetId': changeSet.id,
      'items': [
        for (var i = 0; i < changeSet.items.length; i++)
          <String, Object?>{
            'index': i,
            'toolName': changeSet.items[i].toolName,
            'summary': changeSet.items[i].humanSummary,
            'reason': changeSet.items[i].args['reason'],
          },
      ],
    };
  }

  Future<Map<String, Object?>> _acceptPlanDiffTool({
    required String agentId,
    required Map<String, dynamic> args,
  }) async {
    final changeSet = await acceptPlanDiff(
      agentId: agentId,
      changeSetId: _requiredString(args, 'changeSetId'),
      itemIndices: _optionalIntList(args['itemIndices']),
    );
    return _resolutionSummary(changeSet);
  }

  Future<Map<String, Object?>> _revertPlanDiffTool({
    required String agentId,
    required Map<String, dynamic> args,
  }) async {
    final changeSet = await revertPlanDiff(
      agentId: agentId,
      changeSetId: _requiredString(args, 'changeSetId'),
      itemIndices: _optionalIntList(args['itemIndices']),
    );
    return _resolutionSummary(changeSet);
  }

  Future<Map<String, Object?>> _commitDayTool({
    required String agentId,
    required Map<String, dynamic> args,
  }) async {
    final committedPlan = await commitDay(
      agentId: agentId,
      dayId: _requiredString(args, 'dayId'),
    );
    final status = committedPlan.data.status;
    final committedAt = status is DayPlanStatusCommitted
        ? status.committedAt
        : null;
    return <String, Object?>{
      'planId': committedPlan.id,
      'dayId': committedPlan.dayId,
      'status': 'committed',
      'committedAt': committedAt?.toIso8601String(),
      'blockCount': committedPlan.data.plannedBlocks.length,
    };
  }

  Future<Map<String, Object?>> _uncommitDayTool({
    required String agentId,
    required Map<String, dynamic> args,
  }) async {
    final plan = await uncommitDay(
      agentId: agentId,
      dayId: _requiredString(args, 'dayId'),
    );
    return <String, Object?>{
      'planId': plan.id,
      'dayId': plan.dayId,
      'status': 'draft',
      'blockCount': plan.data.plannedBlocks.length,
    };
  }

  static Map<String, Object?> _resolutionSummary(ChangeSetEntity changeSet) {
    var confirmed = 0;
    var rejected = 0;
    var pending = 0;
    for (final item in changeSet.items) {
      switch (item.status) {
        case ChangeItemStatus.confirmed:
          confirmed++;
        case ChangeItemStatus.rejected:
          rejected++;
        case ChangeItemStatus.pending:
          pending++;
        case ChangeItemStatus.deferred:
        case ChangeItemStatus.retracted:
          break;
      }
    }
    return {
      'changeSetId': changeSet.id,
      'status': changeSet.status.name,
      'confirmedCount': confirmed,
      'rejectedCount': rejected,
      'pendingCount': pending,
    };
  }

  Future<AgentIdentityEntity> _requireIdentity(String agentId) async {
    final entity = await agentRepository.getEntity(agentId);
    if (entity is AgentIdentityEntity && entity.deletedAt == null) {
      return entity;
    }
    throw DayAgentCaptureException('agent $agentId not found');
  }

  Future<CaptureEntity?> _captureOrNull(String captureId) async {
    final entity = await agentRepository.getEntity(captureId);
    return entity is CaptureEntity ? entity : null;
  }

  static PlannedBlock _parsePlannedBlock({
    required Object? raw,
    required DateTime day,
    required Set<String> allowedCategoryIds,
    required Set<String> decidedTaskIds,
    required Set<String> allowedExistingTaskIds,
    DateTime? earliestDraftStart,
  }) {
    if (raw is! Map) {
      throw const DayAgentCaptureException('block must be an object');
    }
    final data = raw.cast<String, dynamic>();
    final type = _optionalEnum(
      PlannedBlockType.values,
      _optionalString(data['type']),
    );
    final state = _optionalEnum(
      PlannedBlockState.values,
      _optionalString(data['state']),
    );
    final blockType = type ?? PlannedBlockType.ai;
    final categoryId = _requiredString(data, 'categoryId');
    if (!_categoryAllowed(categoryId, allowedCategoryIds)) {
      throw DayAgentCaptureException('categoryId $categoryId is not allowed');
    }
    final start = _requiredDateTime(data, 'start');
    final end = _requiredDateTime(data, 'end');
    if (!end.isAfter(start)) {
      throw const DayAgentCaptureException('block end must be after start');
    }
    final blockState = state ?? PlannedBlockState.drafted;
    final dayStart = localDay(day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    if (start.isBefore(dayStart) || end.isAfter(dayEnd)) {
      throw const DayAgentCaptureException(
        'blocks must stay within the planDate day',
      );
    }
    if (earliestDraftStart != null &&
        blockState == PlannedBlockState.drafted &&
        (blockType == PlannedBlockType.ai ||
            blockType == PlannedBlockType.manual) &&
        start.isBefore(earliestDraftStart)) {
      throw const DayAgentCaptureException(
        'drafted AI/manual blocks for today must not start before '
        'current time',
      );
    }
    final reason = _optionalString(data['reason']);
    if (blockType == PlannedBlockType.ai && reason == null) {
      throw const DayAgentCaptureException(
        'AI planned blocks require a non-empty reason',
      );
    }
    final taskId = _optionalString(data['taskId']);
    // Always validate — an empty `decidedTaskIds` is not a license for the
    // model to reference arbitrary task IDs; with no decided tasks the only
    // permitted references are tasks the user has already authorised via
    // `allowedExistingTaskIds`.
    if (taskId != null &&
        !decidedTaskIds.contains(taskId) &&
        !allowedExistingTaskIds.contains(taskId)) {
      throw DayAgentCaptureException(
        'taskId $taskId was not included in decidedTaskIds',
      );
    }
    return PlannedBlock(
      id: _optionalString(data['id']) ?? 'block_${_uuid.v4()}',
      categoryId: categoryId,
      startTime: start,
      endTime: end,
      note: _optionalString(data['note']),
      taskId: taskId,
      title: _requiredString(data, 'title'),
      type: blockType,
      state: blockState,
      reason: reason,
    );
  }

  Future<Set<String>> _allowedExistingTaskIds(
    List<Object?> rawBlocks,
    Set<String> allowedCategoryIds,
  ) async {
    final referenced = <String>{};
    for (final raw in rawBlocks) {
      if (raw is! Map) continue;
      final taskId = _optionalString(raw['taskId']);
      if (taskId != null) referenced.add(taskId);
    }
    if (referenced.isEmpty) return const <String>{};

    final entities = await journalDb.journalEntityMapForIds(
      referenced.toList(),
    );
    return {
      for (final entry in entities.entries)
        if (entry.value is Task &&
            (entry.value as Task).meta.deletedAt == null &&
            _categoryAllowed(
              (entry.value as Task).meta.categoryId,
              allowedCategoryIds,
            ))
          entry.key,
    };
  }

  static DayAgentEnergyBand _parseEnergyBand({
    required Object? raw,
    required DateTime day,
  }) {
    if (raw is! Map) {
      throw const DayAgentCaptureException('energyBand must be an object');
    }
    final data = raw.cast<String, dynamic>();
    final start = _requiredDateTime(data, 'start');
    final end = _requiredDateTime(data, 'end');
    if (!end.isAfter(start)) {
      throw const DayAgentCaptureException(
        'energyBand end must be after start',
      );
    }
    final dayStart = localDay(day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    if (start.isBefore(dayStart) || end.isAfter(dayEnd)) {
      throw const DayAgentCaptureException(
        'energyBands must stay within the planDate day',
      );
    }
    final level = _optionalEnum(
      DayAgentEnergyLevel.values,
      _requiredString(data, 'level'),
    );
    if (level == null) {
      throw const DayAgentCaptureException(
        'energyBand level must be high, low, or secondWind',
      );
    }
    return DayAgentEnergyBand(
      start: start,
      end: end,
      level: level,
      label: _requiredString(data, 'label'),
    );
  }

  static List<PinnedTaskRef> _pinnedTasksFor(List<PlannedBlock> blocks) {
    final seen = <String>{};
    final out = <PinnedTaskRef>[];
    for (final block in blocks) {
      final taskId = block.taskId;
      if (taskId == null || !seen.add(taskId)) continue;
      out.add(
        PinnedTaskRef(
          taskId: taskId,
          categoryId: block.categoryId,
          sortOrder: out.length,
        ),
      );
    }
    return out;
  }

  static int _scheduledMinutesFor(List<PlannedBlock> blocks) {
    return blocks
        .where((block) => block.state != PlannedBlockState.dropped)
        .fold<int>(0, (sum, block) => sum + block.duration.inMinutes);
  }

  static Map<String, Object?> _planJson(DayPlanEntity plan) => {
    'planId': plan.id,
    'dayId': plan.dayId,
    'captureId': plan.captureId,
    'planDate': plan.planDate.toIso8601String(),
    'state': 'drafted',
    'capacityMinutes': plan.capacityMinutes,
    'scheduledMinutes': plan.scheduledMinutes,
    'blocks': [for (final block in plan.data.plannedBlocks) _blockJson(block)],
    'energyBands': [for (final band in plan.energyBands) band.toJson()],
  };

  static Map<String, Object?> _blockJson(PlannedBlock block) => {
    'id': block.id,
    'title': block.title,
    'taskId': block.taskId,
    'categoryId': block.categoryId,
    'start': block.startTime.toIso8601String(),
    'end': block.endTime.toIso8601String(),
    'type': block.type.name,
    'state': block.state.name,
    'reason': block.reason,
    'note': block.note,
  };

  static List<Object?> _objectList(Object? raw, String name) {
    if (raw == null) return const <Object?>[];
    if (raw is List) return raw;
    throw DayAgentCaptureException('$name must be an array');
  }

  static List<String> _stringList(Object? raw) {
    if (raw == null) return const <String>[];
    if (raw is! List) {
      throw const DayAgentCaptureException('decidedTaskIds must be an array');
    }
    final out = <String>[];
    for (final value in raw) {
      final parsed = _optionalString(value);
      if (parsed == null) {
        throw const DayAgentCaptureException(
          'decidedTaskIds must contain non-empty strings',
        );
      }
      out.add(parsed);
    }
    return out;
  }

  static DateTime _requiredDateTime(Map<String, dynamic> args, String key) {
    final date = _optionalDateTime(args[key]);
    if (date == null) {
      throw DayAgentCaptureException(
        '$key must be a valid ISO-8601 date-time',
      );
    }
    return date;
  }

  static String _requiredString(Map<String, dynamic> args, String key) {
    final value = _optionalString(args[key]);
    if (value == null) {
      throw DayAgentCaptureException('$key must not be empty');
    }
    return value;
  }

  static String? _optionalString(Object? value) {
    if (value is! String) return null;
    return _blankToNull(value);
  }

  static int? _optionalInt(Object? value) {
    if (value is int) return value;
    if (value is num) {
      if (value % 1 != 0) {
        throw const DayAgentCaptureException('value must be an integer');
      }
      return value.toInt();
    }
    return null;
  }

  static DateTime? _optionalDateTime(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  static T? _optionalEnum<T extends Enum>(List<T> values, String? raw) {
    if (raw == null) return null;
    return parseEnumByName(values, raw);
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static bool _categoryAllowed(String? categoryId, Set<String>? allowed) {
    if (allowed == null || allowed.isEmpty) return true;
    return categoryId != null && allowed.contains(categoryId);
  }

  static DateTime? _dateFromDayId(String dayId) {
    const prefix = 'dayplan-';
    if (!dayId.startsWith(prefix)) return null;
    return DateTime.tryParse(dayId.substring(prefix.length));
  }

  static String _dayIdFromPlanEntityId(String planEntityId) {
    const prefix = 'day_agent_plan:';
    if (planEntityId.startsWith(prefix)) {
      return planEntityId.substring(prefix.length);
    }
    return planEntityId;
  }

  static List<int>? _optionalIntList(Object? raw) {
    if (raw == null) return null;
    if (raw is! List) {
      throw const DayAgentCaptureException('itemIndices must be an array');
    }
    final out = <int>[];
    for (final value in raw) {
      if (value is int) {
        out.add(value);
        continue;
      }
      if (value is num && value % 1 == 0) {
        out.add(value.toInt());
        continue;
      }
      throw const DayAgentCaptureException(
        'itemIndices entries must be integers',
      );
    }
    return out;
  }

  static List<int> _selectIndices({
    required List<int>? itemIndices,
    required int itemCount,
  }) {
    if (itemIndices == null) {
      return [for (var i = 0; i < itemCount; i++) i];
    }
    final out = <int>{};
    for (final index in itemIndices) {
      if (index < 0 || index >= itemCount) {
        throw DayAgentCaptureException(
          'itemIndex $index is out of range for a set with $itemCount items',
        );
      }
      out.add(index);
    }
    return out.toList()..sort();
  }

  static _DiffChange _parseDiffChange({
    required Object? raw,
    required DayPlanEntity plan,
    required Map<String, PlannedBlock> blockById,
  }) {
    if (raw is! Map) {
      throw const DayAgentCaptureException('change must be an object');
    }
    final data = raw.cast<String, dynamic>();
    final actionName = _requiredString(data, 'action');
    final action = parseEnumByName(_DiffAction.values, actionName);
    if (action == null) {
      throw DayAgentCaptureException(
        'change action must be moved, added, or dropped (got "$actionName")',
      );
    }
    final reason = _requiredString(data, 'reason');
    final blockId = _optionalString(data['blockId']);
    final from = _optionalBlockSnapshot(data['from'], 'from', plan);
    final to = _optionalBlockSnapshot(data['to'], 'to', plan);
    switch (action) {
      case _DiffAction.moved:
        if (blockId == null) {
          throw const DayAgentCaptureException(
            'moved change requires blockId',
          );
        }
        if (!blockById.containsKey(blockId)) {
          throw DayAgentCaptureException(
            'moved change references unknown blockId $blockId',
          );
        }
        if (to == null) {
          throw const DayAgentCaptureException('moved change requires `to`');
        }
        if (from == null) {
          throw const DayAgentCaptureException(
            'moved change requires `from`',
          );
        }
      case _DiffAction.added:
        if (to == null) {
          throw const DayAgentCaptureException('added change requires `to`');
        }
        if (to.start == null || to.end == null) {
          throw const DayAgentCaptureException(
            'added change requires `to.start` and `to.end`',
          );
        }
        if (to.title == null || to.title!.isEmpty) {
          throw const DayAgentCaptureException(
            'added change requires `to.title`',
          );
        }
        if (to.categoryId == null) {
          throw const DayAgentCaptureException(
            'added change requires `to.categoryId`',
          );
        }
      case _DiffAction.dropped:
        if (blockId == null) {
          throw const DayAgentCaptureException(
            'dropped change requires blockId',
          );
        }
        if (!blockById.containsKey(blockId)) {
          throw DayAgentCaptureException(
            'dropped change references unknown blockId $blockId',
          );
        }
        if (from == null) {
          throw const DayAgentCaptureException(
            'dropped change requires `from`',
          );
        }
    }
    return _DiffChange(
      action: action,
      reason: reason,
      blockId: blockId,
      from: from,
      to: to,
    );
  }

  static _BlockSnapshot? _optionalBlockSnapshot(
    Object? raw,
    String label,
    DayPlanEntity plan,
  ) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw DayAgentCaptureException('`$label` must be an object');
    }
    final data = raw.cast<String, dynamic>();
    final start = _optionalDateTime(data['start']);
    final end = _optionalDateTime(data['end']);
    if (start != null && end != null && !end.isAfter(start)) {
      throw DayAgentCaptureException(
        '`$label.end` must be after `$label.start`',
      );
    }
    if (start != null) {
      _assertWithinDay(start, plan.planDate, '$label.start');
    }
    if (end != null) {
      _assertWithinDay(end, plan.planDate, '$label.end');
    }
    final typeRaw = _optionalString(data['type']);
    final type = typeRaw == null
        ? null
        : parseEnumByName(PlannedBlockType.values, typeRaw);
    if (typeRaw != null && type == null) {
      throw DayAgentCaptureException(
        '`$label.type` must be ai, cal, buffer, or manual (got "$typeRaw")',
      );
    }
    return _BlockSnapshot(
      start: start,
      end: end,
      title: _optionalString(data['title']),
      categoryId: _optionalString(data['categoryId']),
      taskId: _optionalString(data['taskId']),
      type: type,
      reason: _optionalString(data['reason']),
    );
  }

  static void _assertWithinDay(
    DateTime time,
    DateTime planDate,
    String label,
  ) {
    final dayStart = localDay(planDate);
    final dayEnd = dayStart.add(const Duration(days: 1));
    if (time.isBefore(dayStart) || time.isAfter(dayEnd)) {
      throw DayAgentCaptureException(
        '`$label` must fall inside the plan day',
      );
    }
  }

  static String _formatChangeSummary(
    _DiffChange change,
    Map<String, PlannedBlock> blockById,
  ) {
    String fmt(DateTime? time) =>
        time == null ? '?' : time.toIso8601String().substring(11, 16);
    final liveBlock = change.blockId == null ? null : blockById[change.blockId];
    final title =
        change.to?.title ?? change.from?.title ?? liveBlock?.title ?? 'block';
    switch (change.action) {
      case _DiffAction.moved:
        final fromStart = fmt(change.from?.start ?? liveBlock?.startTime);
        final fromEnd = fmt(change.from?.end ?? liveBlock?.endTime);
        final toStart = fmt(change.to?.start);
        final toEnd = fmt(change.to?.end);
        return 'Move "$title" from $fromStart–$fromEnd to $toStart–$toEnd';
      case _DiffAction.added:
        final start = fmt(change.to?.start);
        final end = fmt(change.to?.end);
        return 'Add "$title" at $start–$end';
      case _DiffAction.dropped:
        final start = fmt(change.from?.start ?? liveBlock?.startTime);
        final end = fmt(change.from?.end ?? liveBlock?.endTime);
        return 'Drop "$title" at $start–$end';
    }
  }

  /// Order-aware validation across a batch of pending items.
  ///
  /// Walks the items in resolution order against a simulated block set so
  /// that one item's effect (e.g. dropping a block) is visible to later
  /// items in the same batch. Also re-runs the propose-time invariants
  /// against the resolving agent's [allowedCategoryIds]:
  ///   * `add_block` carries a full new block — validate shape, parseable
  ///     timestamps, `end > start`, in-day bounds, allowed category.
  ///   * `move_block` may carry partial overrides — validate any provided
  ///     timestamps (parseable + in-day), the effective end > effective
  ///     start (using the live block as fallback), and any category
  ///     override against [allowedCategoryIds].
  ///   * `drop_block` only needs the blockId still to exist in the
  ///     simulated set.
  static void _validateApplicableBatch(
    Iterable<MapEntry<int, ChangeItem>> entries,
    DayPlanEntity plan,
    Set<String> allowedCategoryIds,
  ) {
    final simulatedIds = <String>{
      for (final block in plan.data.plannedBlocks) block.id,
    };
    final blocksById = <String, PlannedBlock>{
      for (final block in plan.data.plannedBlocks) block.id: block,
    };
    final dayStart = localDay(plan.planDate);
    final dayEnd = dayStart.add(const Duration(days: 1));

    void assertInDay(DateTime t, int idx, String label) {
      if (t.isBefore(dayStart) || t.isAfter(dayEnd)) {
        throw DayAgentCaptureException(
          'cannot apply change at index $idx: $label is outside the plan day',
        );
      }
    }

    void assertAllowedCategory(String categoryId, int idx) {
      if (allowedCategoryIds.isEmpty) return;
      if (!allowedCategoryIds.contains(categoryId)) {
        throw DayAgentCaptureException(
          'cannot apply change at index $idx: categoryId $categoryId is '
          'not allowed for this agent',
        );
      }
    }

    DateTime? parseDate(Object? raw, int idx, String label) {
      if (raw == null) return null;
      if (raw is! String) {
        throw DayAgentCaptureException(
          'cannot apply change at index $idx: $label must be a string',
        );
      }
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) {
        throw DayAgentCaptureException(
          'cannot apply change at index $idx: $label is not a valid '
          'ISO-8601 date-time',
        );
      }
      return parsed;
    }

    for (final entry in entries) {
      final idx = entry.key;
      final item = entry.value;
      switch (item.toolName) {
        case 'move_block':
          final blockId = item.args['blockId'] as String?;
          if (blockId == null || !simulatedIds.contains(blockId)) {
            throw DayAgentCaptureException(
              'cannot apply move_block at index $idx: blockId $blockId not '
              'in plan (possibly dropped earlier in this batch)',
            );
          }
          final live = blocksById[blockId]!;
          final newStart = parseDate(item.args['toStart'], idx, 'toStart');
          final newEnd = parseDate(item.args['toEnd'], idx, 'toEnd');
          final effStart = newStart ?? live.startTime;
          final effEnd = newEnd ?? live.endTime;
          if (!effEnd.isAfter(effStart)) {
            throw DayAgentCaptureException(
              'cannot apply move_block at index $idx: effective end must '
              'be after effective start',
            );
          }
          assertInDay(effStart, idx, 'effective start');
          assertInDay(effEnd, idx, 'effective end');
          final newCategoryId = item.args['categoryId'];
          if (newCategoryId is String && newCategoryId.isNotEmpty) {
            assertAllowedCategory(newCategoryId, idx);
          }
        case 'drop_block':
          final blockId = item.args['blockId'] as String?;
          if (blockId == null || !simulatedIds.contains(blockId)) {
            throw DayAgentCaptureException(
              'cannot apply drop_block at index $idx: blockId $blockId not '
              'in plan (possibly dropped earlier in this batch)',
            );
          }
          simulatedIds.remove(blockId);
        case 'add_block':
          final categoryId = item.args['categoryId'];
          if (categoryId is! String || categoryId.isEmpty) {
            throw DayAgentCaptureException(
              'cannot apply add_block at index $idx: categoryId must be a '
              'non-empty string',
            );
          }
          assertAllowedCategory(categoryId, idx);
          final start = parseDate(item.args['toStart'], idx, 'toStart');
          final end = parseDate(item.args['toEnd'], idx, 'toEnd');
          if (start == null) {
            throw DayAgentCaptureException(
              'cannot apply add_block at index $idx: toStart is required',
            );
          }
          if (end == null) {
            throw DayAgentCaptureException(
              'cannot apply add_block at index $idx: toEnd is required',
            );
          }
          if (!end.isAfter(start)) {
            throw DayAgentCaptureException(
              'cannot apply add_block at index $idx: toEnd must be after '
              'toStart',
            );
          }
          assertInDay(start, idx, 'toStart');
          assertInDay(end, idx, 'toEnd');
        default:
          throw DayAgentCaptureException(
            'cannot apply unknown change tool "${item.toolName}"',
          );
      }
    }
  }

  static List<PlannedBlock> _applyItem(
    ChangeItem item,
    List<PlannedBlock> blocks, {
    required PlannedBlockState addedBlockState,
  }) {
    // Defensive: `_validateApplicableBatch` runs immediately before this
    // and rejects every malformed item, so the assertions below should be
    // unreachable in normal flow. They exist so an accidental future
    // bypass surfaces a clean `DayAgentCaptureException` instead of a
    // bare `RangeError` / `TypeError`.
    final out = List<PlannedBlock>.of(blocks);
    final args = item.args;
    switch (item.toolName) {
      case 'move_block':
        final blockId = args['blockId'] as String;
        final index = out.indexWhere((b) => b.id == blockId);
        if (index == -1) {
          throw DayAgentCaptureException(
            'cannot apply move_block: blockId $blockId not found in plan',
          );
        }
        final block = out[index];
        // NB: `args['reason']` is the change-level rationale (why the user
        // wants this edit); the per-block reason override travels under
        // `args['blockReason']` per `_DiffChange.toArgs()`. Mixing them
        // would overwrite the block's placement reason with the diff
        // motivation.
        out[index] = block.copyWith(
          startTime: _argDate(args, 'toStart') ?? block.startTime,
          endTime: _argDate(args, 'toEnd') ?? block.endTime,
          title: (args['title'] as String?) ?? block.title,
          categoryId: (args['categoryId'] as String?) ?? block.categoryId,
          taskId: args.containsKey('taskId')
              ? args['taskId'] as String?
              : block.taskId,
          type: _argType(args) ?? block.type,
          reason: args.containsKey('blockReason')
              ? args['blockReason'] as String?
              : block.reason,
        );
      case 'add_block':
        out.add(
          PlannedBlock(
            id: 'block_${_uuid.v4()}',
            categoryId: args['categoryId'] as String,
            startTime: _argDate(args, 'toStart')!,
            endTime: _argDate(args, 'toEnd')!,
            title: args['title'] as String?,
            taskId: args['taskId'] as String?,
            type: _argType(args) ?? PlannedBlockType.ai,
            state: addedBlockState,
            reason: args['blockReason'] as String?,
          ),
        );
      case 'drop_block':
        final blockId = args['blockId'] as String;
        final before = out.length;
        out.removeWhere((b) => b.id == blockId);
        if (out.length == before) {
          throw DayAgentCaptureException(
            'cannot apply drop_block: blockId $blockId not found in plan',
          );
        }
    }
    return out;
  }

  static PlannedBlockState _stateForAcceptedAddedBlock(
    DayPlanStatus planStatus,
  ) {
    return planStatus.maybeMap(
      agreed: (_) => PlannedBlockState.committed,
      committed: (_) => PlannedBlockState.committed,
      orElse: () => PlannedBlockState.drafted,
    );
  }

  static DateTime? _argDate(Map<String, dynamic> args, String key) {
    final raw = args[key];
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }

  static PlannedBlockType? _argType(Map<String, dynamic> args) {
    final raw = args['type'];
    if (raw is! String) return null;
    return parseEnumByName(PlannedBlockType.values, raw);
  }
}

enum _DiffAction { moved, added, dropped }

class _DiffChange {
  const _DiffChange({
    required this.action,
    required this.reason,
    this.blockId,
    this.from,
    this.to,
  });

  final _DiffAction action;
  final String reason;
  final String? blockId;
  final _BlockSnapshot? from;
  final _BlockSnapshot? to;

  String get toolName => switch (action) {
    _DiffAction.moved => 'move_block',
    _DiffAction.added => 'add_block',
    _DiffAction.dropped => 'drop_block',
  };

  Map<String, dynamic> toArgs() {
    final args = <String, dynamic>{
      'action': action.name,
      'reason': reason,
    };
    if (blockId != null) args['blockId'] = blockId;
    final fromSnap = from;
    if (fromSnap != null) {
      if (fromSnap.start != null) {
        args['fromStart'] = fromSnap.start!.toIso8601String();
      }
      if (fromSnap.end != null) {
        args['fromEnd'] = fromSnap.end!.toIso8601String();
      }
      if (fromSnap.title != null) args['fromTitle'] = fromSnap.title;
      if (fromSnap.categoryId != null) {
        args['fromCategoryId'] = fromSnap.categoryId;
      }
    }
    final toSnap = to;
    if (toSnap != null) {
      if (toSnap.start != null) {
        args['toStart'] = toSnap.start!.toIso8601String();
      }
      if (toSnap.end != null) args['toEnd'] = toSnap.end!.toIso8601String();
      if (toSnap.title != null) args['title'] = toSnap.title;
      if (toSnap.categoryId != null) args['categoryId'] = toSnap.categoryId;
      if (toSnap.taskId != null) args['taskId'] = toSnap.taskId;
      if (toSnap.type != null) args['type'] = toSnap.type!.name;
      if (toSnap.reason != null) args['blockReason'] = toSnap.reason;
    }
    return args;
  }
}

class _BlockSnapshot {
  const _BlockSnapshot({
    this.start,
    this.end,
    this.title,
    this.categoryId,
    this.taskId,
    this.type,
    this.reason,
  });

  final DateTime? start;
  final DateTime? end;
  final String? title;
  final String? categoryId;
  final String? taskId;
  final PlannedBlockType? type;
  final String? reason;
}
