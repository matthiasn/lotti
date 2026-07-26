import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_diff.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_parser.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_writer.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
import 'package:lotti/utils/date_utils_extension.dart';
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
    // Span the ADR 0032 ownership cutover: the day's diffs may be owned by
    // the coordinator (pre-cutover, or a cross-device ownership race) or by
    // the day's own agent. A foreign caller keeps the exact-owner read.
    final ownerIds = <String>{
      agentId,
      if (isDailyOsDayOwner(agentId)) ...{
        dailyOsPlannerAgentId,
        perDayAgentId(dayId),
      },
    };
    // Only pending sets can produce a visible row, and `changeSet` stores its
    // status as the indexed subtype — so the confirmed/rejected history, which
    // grows with every diff the user has ever acted on, never has to be read.
    final entities = <AgentDomainEntity>[
      for (final ownerId in ownerIds)
        ...await agentRepository.getEntitiesByAgentIdAndSubtype(
          ownerId,
          type: 'changeSet',
          subtype: ChangeSetStatus.pending.name,
        ),
    ];
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
  ///
  /// When [dependencyResolver] is supplied, each returned ref also carries the
  /// task's `status` and its one-hop `blockedBy` (ADR 0043), resolved in a
  /// single batched `resolveBlockedStatus` call over the surviving ids. When
  /// it is null both are omitted — not merely empty — because the resolver is
  /// also what gates the blocked-work rule into the prompt, and a wake without
  /// one must serialize byte-identically to pre-ADR-0043 to keep the prefix
  /// cache intact. Emitting a `status` no rule refers to would spend prompt
  /// bytes to say nothing.
  Future<List<DecidedTaskRef>> hydrateDecidedTasks({
    required Set<String> allowedCategoryIds,
    List<String> explicitTaskIds = const [],
    List<ParsedItemEntity> parsedItems = const [],
    TaskDependencyResolver? dependencyResolver,
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
    final tasks = <Task>[];
    for (final id in orderedIds) {
      final entity = entities[id];
      if (entity is! Task) continue;
      if (entity.meta.deletedAt != null) continue;
      if (!categoryAllowed(entity.meta.categoryId, allowedCategoryIds)) {
        continue;
      }
      tasks.add(entity);
    }
    if (tasks.isEmpty) return const [];
    // ADR 0043's blocked-work rule is stated in terms of a task's status and
    // blockers, and it reaches the model on every drafting wake — but the task
    // corpus that used to carry them renders inside `<capture>` alone. A wake
    // without a capture was therefore told to respect blockers while being
    // shown nothing that could be blocked, which is not a rule a model can
    // follow. One batched resolver call, keyed by the ids already in hand.
    //
    // Gated on the resolver rather than always emitted: the same field gates
    // the rule itself, so a wake without one gets no rule *and* no annotation,
    // and its prompt stays byte-identical to pre-ADR-0043.
    final resolver = dependencyResolver;
    if (resolver == null) {
      return [
        for (final task in tasks)
          DecidedTaskRef(
            id: task.id,
            title: task.data.title,
            categoryId: task.meta.categoryId,
          ),
      ];
    }
    final blockedBy = await resolver.resolveBlockedStatus({
      for (final task in tasks) task.id,
    }, allowedCategoryIds: allowedCategoryIds);
    return [
      for (final task in tasks)
        DecidedTaskRef(
          id: task.id,
          title: task.data.title,
          categoryId: task.meta.categoryId,
          status: task.data.status.toDbString,
          blockedBy: blockedBy[task.id] ?? const [],
        ),
    ];
  }

  /// Blocked-work state for tasks an earlier draft already scheduled.
  ///
  /// A re-draft replaces the whole block list, so the model re-affirms every
  /// baseline block — including one whose task became blocked *after* that
  /// draft was written. Such a task is in neither `decidedTasks` (the user did
  /// not approve it this wake) nor, on a capture-less wake, the corpus, so
  /// without this the blocked-work rule reaches the model with nothing behind
  /// it for exactly that set.
  ///
  /// Returns entries **only for tasks that are actually blocked**, by ADR
  /// 0043's union predicate — so an ordinary re-draft of unblocked work adds
  /// no prompt bytes. Reads statuses as well as blockers because the resolver
  /// reports only link-derived blockers: a task marked blocked by hand has
  /// none, and projecting blockers alone would miss it entirely.
  ///
  /// Returns empty when [dependencyResolver] is null, matching the rest of
  /// ADR 0043's gating — no resolver means no rule, so no data for it either.
  Future<Map<String, PlannedTaskState>> resolvePlannedTaskStates({
    required Iterable<String> taskIds,
    required Set<String> allowedCategoryIds,
    TaskDependencyResolver? dependencyResolver,
  }) async {
    final resolver = dependencyResolver;
    if (resolver == null) return const {};
    final ids = {
      for (final raw in taskIds)
        if (raw.trim().isNotEmpty) raw.trim(),
    };
    if (ids.isEmpty) return const {};

    final entities = await journalDb.journalEntityMapForIds(ids);
    final tasks = <Task>[
      for (final id in ids)
        if (entities[id] case final Task task)
          if (task.meta.deletedAt == null &&
              categoryAllowed(task.meta.categoryId, allowedCategoryIds))
            task,
    ];
    if (tasks.isEmpty) return const {};

    final blockedBy = await resolver.resolveBlockedStatus({
      for (final task in tasks) task.id,
    }, allowedCategoryIds: allowedCategoryIds);

    return {
      for (final task in tasks)
        if (PlannedTaskState.isBlocked(
          status: task.data.status.toDbString,
          blockedBy: blockedBy[task.id] ?? const [],
        ))
          task.id: PlannedTaskState(
            status: task.data.status.toDbString,
            blockedBy: blockedBy[task.id] ?? const [],
          ),
    };
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
      // Ownership spans the ADR 0032 cutover (see persistParsedItems).
      if (capture == null ||
          !canReadDailyOsDayArtifact(
            readerAgentId: agentId,
            ownerAgentId: capture.agentId,
            dayId: captureDayId(capture),
          )) {
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

    // Every task a diff would attach, held to the same standard as a fresh
    // draft. `acceptPlanDiff` copies `to.taskId` onto the live plan, and the
    // approval summary the user sees carries the title and times but not the
    // task reference — so without this an approved diff could quietly attach a
    // deleted task, a non-existent one, or one from a category this agent may
    // not touch, which is the draft-path hole reopened one door over.
    final identity = await reads.requireIdentity(agentId);
    // Refining today's plan cannot *move* work into a part of the day that has
    // already gone. Repeating a block's own unchanged start is not a move:
    // a full `to` snapshot carries it, so extending the end of a block that
    // began at 09:00 would otherwise be refused at noon for saying 09:00.
    if (localDay(plan.planDate) == localDay(clock.now())) {
      final now = clock.now();
      for (final change in parsed) {
        final start = change.to?.start;
        if (start == null || !start.isBefore(now)) continue;
        final live = change.blockId == null ? null : blockById[change.blockId];
        if (live != null && live.startTime == start) continue;
        throw const DayAgentCaptureException(
          'proposed blocks for today must not start before current time',
        );
      }
    }
    final proposedTaskIds = {for (final change in parsed) ?change.to?.taskId};
    if (proposedTaskIds.isNotEmpty) {
      final allowed = await resolveAllowedTaskIds(
        journalDb: journalDb,
        taskIds: proposedTaskIds,
        allowedCategoryIds: identity.allowedCategoryIds,
      );
      final refused = proposedTaskIds.difference(allowed.keys.toSet()).toList()
        ..sort();
      if (refused.isNotEmpty) {
        throw DayAgentCaptureException(
          'taskId(s) ${refused.join(', ')} are not allowed tasks for this plan',
        );
      }
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

  /// Applies one atomic manual edit to a planned block.
  ///
  /// The block may move, resize, and—when it is standalone—change title or
  /// category in the same sync write. Task-linked title/category fields remain
  /// owned by the task, while imported calendar blocks remain owned by their
  /// calendar source. Category changes must stay inside the agent identity's
  /// allowed scope and use an active planning category. All ranges must stay
  /// inside the plan's local day.
  Future<DayPlanEntity> editBlock({
    required String agentId,
    required String dayId,
    required String blockId,
    required DateTime start,
    required DateTime end,
    String? title,
    String? categoryId,
  }) async {
    final identity = await reads.requireIdentity(agentId);
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
    if (block.type == PlannedBlockType.cal) {
      throw DayAgentCaptureException(
        'block $blockId is calendar-owned — edit it in the source calendar',
      );
    }

    final planDate = plan.data.planDate;
    final dayStart = planDate.dateOnly;
    final dayEnd = dayStart.addCalendarDays(1);
    if (!start.isBefore(end)) {
      throw const DayAgentCaptureException(
        'block start must be before block end',
      );
    }
    if (start.isBefore(dayStart) || end.isAfter(dayEnd)) {
      throw DayAgentCaptureException(
        'block range must stay inside ${planDate.toIso8601String()}',
      );
    }

    final trimmedTitle = title?.trim();
    if (title != null && (trimmedTitle == null || trimmedTitle.isEmpty)) {
      throw const DayAgentCaptureException(
        'block title must not be blank',
      );
    }
    final trimmedCategoryId = categoryId?.trim();
    if (categoryId != null &&
        (trimmedCategoryId == null || trimmedCategoryId.isEmpty)) {
      throw const DayAgentCaptureException(
        'block category must not be blank',
      );
    }
    final titleChanged = trimmedTitle != null && trimmedTitle != block.title;
    final categoryChanged =
        trimmedCategoryId != null && trimmedCategoryId != block.categoryId;
    final isTaskLinked = block.taskId?.trim().isNotEmpty ?? false;
    if (isTaskLinked && (titleChanged || categoryChanged)) {
      throw DayAgentCaptureException(
        'block $blockId is task-linked — edit title/category on the task',
      );
    }
    if (block.type == PlannedBlockType.buffer &&
        (titleChanged || categoryChanged)) {
      throw DayAgentCaptureException(
        'block $blockId is a buffer — only its time range is editable',
      );
    }
    if (categoryChanged) {
      final category = await journalDb.getCategoryById(trimmedCategoryId);
      if (!categoryAllowed(
            trimmedCategoryId,
            identity.allowedCategoryIds,
          ) ||
          category == null ||
          category.deletedAt != null ||
          !category.active ||
          !(category.isAvailableForDayPlan ?? false)) {
        throw DayAgentCaptureException(
          'category $trimmedCategoryId is not available',
        );
      }
    }

    final timeChanged = start != block.startTime || end != block.endTime;
    if (!timeChanged && !titleChanged && !categoryChanged) return plan;

    final editedBlocks =
        [
          for (final candidate in plan.data.plannedBlocks)
            if (candidate.id == blockId)
              candidate.copyWith(
                startTime: start,
                endTime: end,
                title: trimmedTitle ?? candidate.title,
                categoryId: trimmedCategoryId ?? candidate.categoryId,
              )
            else
              candidate,
        ]..sort((a, b) {
          final byStart = a.startTime.compareTo(b.startTime);
          return byStart != 0 ? byStart : a.id.compareTo(b.id);
        });
    final now = clock.now();
    final editedPlan = plan.copyWith(
      data: plan.data.copyWith(plannedBlocks: editedBlocks),
      scheduledMinutes: scheduledMinutesFor(editedBlocks),
      updatedAt: now,
    );

    await syncService.upsertEntity(editedPlan);
    onPersistedStateChanged
      ?..call(agentId)
      ..call(dayId)
      ..call(editedPlan.id);
    return editedPlan;
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
