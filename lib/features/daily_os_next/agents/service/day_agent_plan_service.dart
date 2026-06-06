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

part 'day_agent_plan_diff.dart';
part 'day_agent_plan_parser.dart';
part 'day_agent_plan_tool_dispatcher.dart';

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
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const DayAgentCaptureException(
        'block title must not be blank',
      );
    }
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
}
