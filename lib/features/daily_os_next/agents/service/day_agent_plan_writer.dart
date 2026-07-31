import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_diff.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_parser.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_reads.dart';

DayAgentLearningCard _gentleNudgeCard({
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

/// Persistence-side day-plan operations: drafting plans, resolving plan
/// diffs, and summarizing recent drafting patterns.
class DayAgentPlanWriter {
  /// Creates the plan writer collaborator.
  DayAgentPlanWriter({
    required this.agentRepository,
    required this.syncService,
    required this.journalDb,
    required this.reads,
    this.onPersistedStateChanged,
  });

  /// Agent entity/link repository.
  final AgentRepository agentRepository;

  /// Sync-aware agent writer.
  final AgentSyncService syncService;

  /// Journal DB used for task/category reads while drafting.
  final JournalDb journalDb;

  /// Shared plan-entity reads.
  final DayAgentPlanReads reads;

  /// Callback fired when persisted state changes.
  final void Function(String id)? onPersistedStateChanged;

  /// Apply or reject some/all changes of [changeSetId] against the live plan.
  Future<ChangeSetEntity> resolvePlanDiff({
    required String agentId,
    required String changeSetId,
    required List<int>? itemIndices,
    required bool apply,
  }) async {
    final identity = await reads.requireIdentity(agentId);
    final loaded = await agentRepository.getEntity(changeSetId);
    if (loaded is! ChangeSetEntity ||
        loaded.deletedAt != null ||
        loaded.agentId != agentId) {
      throw DayAgentCaptureException('change set $changeSetId not found');
    }
    final changeSet = loaded;
    final plan = await reads.draftPlanForDay(
      agentId: agentId,
      dayId: dayIdFromPlanEntityId(changeSet.taskId),
    );
    if (plan == null) {
      throw DayAgentCaptureException(
        'plan ${changeSet.taskId} no longer exists',
      );
    }
    final selected = selectIndices(
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

    // Task id -> its category, resolved inside the apply branch below and read
    // again when the changes are applied, so a block always lands in the
    // category of the task it names.
    var taskCategoryIds = const <String, String?>{};

    if (apply) {
      // Pre-validate every pending selected change against the current
      // plan before mutating anything (atomic all-or-nothing). The sweep
      // is order-aware (drops/moves earlier in the batch affect later
      // items) and re-runs the propose-time invariants against the
      // *resolving* agent's allowed categories so a synced ChangeItem
      // cannot smuggle an unauthorized category or out-of-day timestamp
      // past the apply path.
      // Task references and the clock are re-resolved here, not carried over
      // from proposal time: a ChangeSet is durable and synced, so it can be
      // accepted long after it was written — by which point the task may have
      // been deleted or moved out of scope, and the part of the day it aimed
      // at may already have passed — or arrive from a peer on an older build
      // that never ran these checks at all.
      // Both the tasks a change proposes and the ones already on the blocks it
      // touches. A move that leaves the taskId alone still has its category
      // re-derived, so a change set written before this rule is filed
      // correctly when the user accepts it rather than persisting the old
      // mismatch.
      final blocksById = {
        for (final block in plan.data.plannedBlocks) block.id: block,
      };
      final referencedTaskIds = <String>{
        for (final entry in pendingByIndex.entries) ...{
          if (entry.value.args['taskId'] case final String taskId) taskId,
          if (entry.value.args['blockId'] case final String blockId)
            if (blocksById[blockId]?.taskId case final String onBlock) onBlock,
        },
      };
      taskCategoryIds = await resolveAllowedTaskIds(
        journalDb: journalDb,
        taskIds: referencedTaskIds,
        allowedCategoryIds: identity.allowedCategoryIds,
      );
      validateApplicablePlanDiffBatch(
        pendingByIndex.entries,
        plan,
        identity.allowedCategoryIds,
        earliestStart: earliestPlannableStart(
          planDate: plan.planDate,
          now: clock.now(),
        ),
        allowedTaskIds: taskCategoryIds.keys.toSet(),
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
    final addedBlockState = stateForAcceptedAddedBlock(plan.data.status);

    for (final entry in pendingByIndex.entries) {
      final index = entry.key;
      final item = entry.value;
      if (apply) {
        mutatedBlocks = applyPlanDiffItem(
          item,
          mutatedBlocks,
          addedBlockState: addedBlockState,
          taskCategoryIds: taskCategoryIds,
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
      final scheduledMinutes = scheduledMinutesFor(mutatedBlocks);
      final pinnedTasks = pinnedTasksFor(mutatedBlocks);
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
  ///
  /// Open-window drafts must contain at least one valid block. Once the
  /// planning window advertised to the model is closed, a fresh draft must be
  /// empty, while a non-empty baseline must be echoed exactly and is persisted
  /// as a metadata-preserving no-op with only wake provenance and the write
  /// timestamp advanced.
  Future<DayPlanEntity> persistDraftPlan({
    required String agentId,
    required String dayId,
    required DateTime planDate,
    required List<Object?> rawBlocks,
    String? captureId,
    List<Object?> rawEnergyBands = const [],
    List<String> decidedTaskIds = const [],
    int capacityMinutes = 480,
    String workingHoursStart = '09:00',
    String workingHoursEnd = '17:00',
    String? dayLabel,
    String? runKey,
    DateTime? planningSnapshotAt,
    DayPlanEntity? planningBaselinePlan,
  }) async {
    final identity = await reads.requireIdentity(agentId);
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
    if (capacityMinutes <= 0) {
      throw const DayAgentCaptureException(
        'capacityMinutes must be greater than zero',
      );
    }

    final now = clock.now();
    // The model planned against the window rendered before inference. Reusing
    // that snapshot here prevents the padded advertised start from moving
    // while the model thinks and turning a valid final slot into a closed
    // window at persistence time. Direct service callers still validate
    // against the live clock.
    final validationNow = planningSnapshotAt ?? now;
    final earliestDraftStart = earliestPlannableStart(
      planDate: planDate,
      now: validationNow,
    );
    final allowedCategoryIds = identity.allowedCategoryIds;
    final existing = await reads.draftPlanForDay(
      agentId: agentId,
      dayId: dayId,
    );
    if (existing != null && existing.data.status is DayPlanStatusCommitted) {
      // ADR 0006: a committed plan is user-approved state — including block
      // progress — and may only change through an approved ChangeSet. A
      // redraft here would wholesale replace it without any approval gate.
      throw const DayAgentCaptureException(
        'draft_day_plan cannot replace a committed plan. Propose changes '
        'with propose_plan_diff instead so the user can approve them.',
      );
    }
    final windowClosed = draftPlanningWindowClosed(
      planDate: planDate,
      now: validationNow,
      capacityMinutes: capacityMinutes,
      workingHoursStart: workingHoursStart,
      workingHoursEnd: workingHoursEnd,
    );
    if (planningBaselinePlan != null &&
        (planningBaselinePlan.dayId != dayId ||
            !canReadDailyOsDayArtifact(
              readerAgentId: agentId,
              ownerAgentId: planningBaselinePlan.agentId,
              dayId: dayId,
            ))) {
      throw const DayAgentCaptureException(
        'planning baseline must belong to the readable target day',
      );
    }
    // A closed wake validates the echo against the exact plan serialized into
    // its prompt, not a second read after inference. Without a workflow
    // snapshot (direct service callers), the current plan remains the
    // baseline.
    final validationBaseline = windowClosed && planningSnapshotAt != null
        ? planningBaselinePlan
        : existing;
    // A redraft may repeat a baseline block that has already started; it may
    // not invent one there.
    final baselineBlocks = {
      for (final block
          in validationBaseline?.data.plannedBlocks ?? const <PlannedBlock>[])
        block.id: block,
    };
    final validateClosedBaseline = windowClosed && baselineBlocks.isNotEmpty;
    // Persisted task/category pairs let a closed baseline remain its own
    // authority without re-resolving today's live journal rows.
    final baselineTaskCategories = <String, String?>{
      for (final block in baselineBlocks.values)
        ?block.taskId: block.categoryId,
    };
    // Otherwise resolve and category-filter like every other task reference.
    // This argument is written by the model itself, so an unchecked set let it
    // reference a deleted task, a non-existent one, or one belonging to a
    // category this agent may not touch, just by echoing the id into its own
    // `draft_day_plan` call. Legitimate decided tasks survive: they are
    // hydrated for the prompt through `hydrateDecidedTasks`, which already
    // applies exactly this filter, so the only ids dropped here are ones the
    // model was never given.
    final decidedTasks = validateClosedBaseline
        ? baselineTaskCategories
        : await _resolveTaskIds(decidedTaskIds, allowedCategoryIds);
    final allowedExistingTaskIds = validateClosedBaseline
        ? baselineTaskCategories
        : await _allowedExistingTaskIds(rawBlocks, allowedCategoryIds);
    final blocks = <PlannedBlock>[];
    for (final raw in rawBlocks) {
      blocks.add(
        parsePlannedBlock(
          raw: raw,
          day: planDate,
          earliestDraftStart: earliestDraftStart,
          // A closed baseline is already persisted user state. Validate the
          // model's echo against that snapshot rather than today's live task
          // or category rows, which may have been deleted or moved since the
          // plan was written; the accepted result below preserves the stored
          // payload verbatim.
          allowedCategoryIds: validateClosedBaseline
              ? const {}
              : allowedCategoryIds,
          decidedTaskIds: decidedTasks,
          allowedExistingTaskIds: allowedExistingTaskIds,
          baselineBlocks: baselineBlocks,
        ),
      );
    }
    if (windowClosed) {
      if (baselineBlocks.isEmpty && blocks.isNotEmpty) {
        throw const DayAgentCaptureException(
          'The planning window is closed. A fresh draft must persist an '
          'empty plan instead of adding blocks.',
        );
      }
      final emittedById = <String, PlannedBlock>{
        for (final block in blocks) block.id: block,
      };
      final baselineRepeatedExactly =
          emittedById.length == blocks.length &&
          emittedById.length == baselineBlocks.length &&
          baselineBlocks.entries.every(
            (entry) => emittedById[entry.key] == entry.value,
          );
      if (baselineBlocks.isNotEmpty && !baselineRepeatedExactly) {
        throw const DayAgentCaptureException(
          'The planning window is closed. Preserve every block from the '
          'non-empty baseline unchanged.',
        );
      }
      if (validationBaseline != null && existing == null) {
        throw const DayAgentCaptureException(
          'The planning baseline changed while the plan was being drafted. '
          'The deleted plan was not restored.',
        );
      }
    } else if (blocks.isEmpty) {
      throw const DayAgentCaptureException(
        'draft_day_plan requires at least one block while the planning '
        'window is open',
      );
    }
    late final DayPlanEntity plan;
    if (windowClosed && existing != null) {
      // A concurrent edit after prompt construction wins. The model still has
      // to echo the baseline it actually saw, but the accepted closed-window
      // no-op preserves the latest persisted payload rather than overwriting
      // it with stale prompt state.
      plan = existing.copyWith(
        runKey: runKey ?? existing.runKey,
        updatedAt: now,
        vectorClock: existing.vectorClock,
      );
    } else {
      blocks.sort((a, b) {
        final byStart = a.startTime.compareTo(b.startTime);
        if (byStart != 0) return byStart;
        return a.id.compareTo(b.id);
      });
      validateDraftWorkingHours(
        blocks: blocks,
        planDate: planDate,
        workingHoursStart: workingHoursStart,
        workingHoursEnd: workingHoursEnd,
      );
      final bands = [
        for (final raw in rawEnergyBands)
          parseEnergyBand(raw: raw, day: planDate),
      ];
      final scheduledMinutes = scheduledMinutesFor(blocks);
      final pinnedTasks = pinnedTasksFor(blocks);
      plan =
          AgentDomainEntity.dayPlan(
                id: dayAgentPlanEntityId(dayId),
                agentId: agentId,
                dayId: dayId,
                captureId: captureId,
                // Provenance for the durable draft job: which wake wrote this.
                // Without it the executor can only ask "was a plan touched
                // after I asked?", which a concurrent wake's write answers just
                // as well as this job's own.
                runKey: runKey,
                planDate: localDay(planDate),
                data: DayPlanData(
                  planDate: localDay(planDate),
                  status: const DayPlanStatus.draft(),
                  dayLabel: blankToNull(dayLabel),
                  plannedBlocks: blocks,
                  pinnedTasks: pinnedTasks,
                ),
                energyBands: bands,
                capacityMinutes: capacityMinutes,
                scheduledMinutes: scheduledMinutes,
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
                // Seed from the persisted register so the sync layer's
                // next-clock stamp causally DOMINATES the prior plan (same
                // discipline as _writeDaySummary and the rollup rewrite);
                // null would downgrade a redraft to wall-clock LWW against
                // any revision that synced in meanwhile.
                vectorClock: existing?.vectorClock,
              )
              as DayPlanEntity;
    }

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
    // Ask for exactly the window's days rather than every plan the agent
    // ever wrote: dayPlan stores its day as the indexed subtype, so the
    // lookback costs one indexed read of `lookbackDays` keys.
    final entities = await agentRepository.getEntitiesByAgentIdAndSubtypes(
      agentId,
      type: AgentEntityTypes.dayPlan,
      subtypes: [
        for (var offset = 0; offset < lookbackDays; offset++)
          dayAgentIdForDate(
            DateTime(asOfDay.year, asOfDay.month, asOfDay.day - offset),
          ),
      ],
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

  Future<Map<String, String?>> _allowedExistingTaskIds(
    List<Object?> rawBlocks,
    Set<String> allowedCategoryIds,
  ) async {
    final referenced = <String>{};
    for (final raw in rawBlocks) {
      if (raw is! Map) continue;
      final taskId = optionalStringArg(raw['taskId']);
      if (taskId != null) referenced.add(taskId);
    }
    if (referenced.isEmpty) return const <String, String?>{};

    return _resolveTaskIds(referenced, allowedCategoryIds);
  }

  Future<Map<String, String?>> _resolveTaskIds(
    Iterable<String> taskIds,
    Set<String> allowedCategoryIds,
  ) => resolveAllowedTaskIds(
    journalDb: journalDb,
    taskIds: taskIds,
    allowedCategoryIds: allowedCategoryIds,
  );
}
