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

    if (apply) {
      // Pre-validate every pending selected change against the current
      // plan before mutating anything (atomic all-or-nothing). The sweep
      // is order-aware (drops/moves earlier in the batch affect later
      // items) and re-runs the propose-time invariants against the
      // *resolving* agent's allowed categories so a synced ChangeItem
      // cannot smuggle an unauthorized category or out-of-day timestamp
      // past the apply path.
      validateApplicablePlanDiffBatch(
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
    final addedBlockState = stateForAcceptedAddedBlock(plan.data.status);

    for (final entry in pendingByIndex.entries) {
      final index = entry.key;
      final item = entry.value;
      if (apply) {
        mutatedBlocks = applyPlanDiffItem(
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
        parsePlannedBlock(
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
        parseEnergyBand(raw: raw, day: planDate),
    ];
    final scheduledMinutes = scheduledMinutesFor(blocks);
    final pinnedTasks = pinnedTasksFor(blocks);
    final existing = await reads.draftPlanForDay(
      agentId: agentId,
      dayId: dayId,
    );
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
                dayLabel: blankToNull(dayLabel),
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

  Future<Set<String>> _allowedExistingTaskIds(
    List<Object?> rawBlocks,
    Set<String> allowedCategoryIds,
  ) async {
    final referenced = <String>{};
    for (final raw in rawBlocks) {
      if (raw is! Map) continue;
      final taskId = optionalStringArg(raw['taskId']);
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
            categoryAllowed(
              (entry.value as Task).meta.categoryId,
              allowedCategoryIds,
            ))
          entry.key,
    };
  }
}
