import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

/// Bridges the UI's [DayAgentInterface] to the real agent layer that
/// landed in PR #3209.
///
/// **Graduated to real** (calls `DayAgentCaptureService` /
/// `DayAgentPlanService` / `DayAgentService`):
/// `submitCapture`, `parseCaptureToItems`, `surfacePendingDecisions`,
/// `applyTriage`, `linkCapturePhraseToTask`, `breakCaptureLink`,
/// `summarizeRecentPatterns`, `draftDayPlan`.
///
/// **Still mocked** (no agent-side tool ships yet):
/// `matchToCorpus`, `proposePlanDiff`, `acceptDiff`, `revertDiff`,
/// `commitDay`, `surfaceShutdownData`, `recordReflection`,
/// `recordCarryoverDecision`, `generateTomorrowNote`,
/// `surfaceTaskCorpus`.
///
/// As those phases ship in the agent layer, methods graduate from
/// `mockFallback` to direct service calls.
class RealDayAgent implements DayAgentInterface {
  RealDayAgent({
    required this.captureService,
    required this.planService,
    required this.dayAgentService,
    required this.journalDb,
    required this.mockFallback,
  });

  final DayAgentCaptureService captureService;
  final DayAgentPlanService planService;
  final DayAgentService dayAgentService;
  final JournalDb journalDb;
  final DayAgentInterface mockFallback;

  /// In-memory cache so the adapter does not hit the categories
  /// table once per parsed item / pending item. Cleared on adapter
  /// recreation (Riverpod provider invalidation).
  final Map<String, DayAgentCategory> _categoryCache = {};

  /// Default fallback when a `categoryId` is null or resolves to a
  /// deleted/missing row. Teal matches the brand interactive token
  /// so the UI still surfaces *something* sensible.
  static const _fallbackCategory = DayAgentCategory(
    id: 'unknown',
    name: 'Uncategorised',
    colorHex: '5ED4B7',
  );

  // ───────────────────────────── Graduated methods ──

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  }) async {
    final existing = await dayAgentService.getDayAgentForDate(capturedAt);
    final identity =
        existing ?? await dayAgentService.createDayAgent(date: capturedAt);
    final capture = await captureService.submitCapture(
      agentId: identity.agentId,
      transcript: transcript,
      capturedAt: capturedAt,
      audioRef: audioId,
    );
    return CaptureId(capture.id);
  }

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) async {
    final identity = await dayAgentService.getDayAgentForDate(date);
    if (identity is! AgentIdentityEntity) return null;
    final dayId = dayAgentIdForDate(date);
    final plan = await planService.draftPlanForDay(
      agentId: identity.agentId,
      dayId: dayId,
    );
    if (plan == null) return null;
    return _projectDayPlan(plan, date);
  }

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async {
    final entities = await captureService.parsedItemsForCapture(id.value);
    final out = <ParsedItem>[];
    for (final entity in entities) {
      out.add(await _projectParsedItem(entity));
    }
    return out;
  }

  @override
  Future<List<PendingItem>> surfacePendingDecisions({DateTime? forDate}) async {
    final date = forDate ?? DateTime.now();
    final identity = await dayAgentService.getDayAgentForDate(date);
    if (identity is! AgentIdentityEntity) return const [];
    final items = await captureService.surfacePendingDecisions(
      agentId: identity.agentId,
      dayId: dayAgentIdForDate(date),
    );
    final out = <PendingItem>[];
    for (final item in items) {
      out.add(await _projectPendingItem(item));
    }
    return out;
  }

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async {
    final updated = await captureService.breakCaptureLink(parsedItemId);
    return _projectParsedItem(updated);
  }

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async {
    await captureService.applyTriage(
      taskId: taskId,
      action: action.name,
      deferTo: deferTo,
    );
    return TriageResult(
      taskId: taskId,
      action: action,
      deferredTo: action == TriageAction.defer ? deferTo : null,
    );
  }

  /// Not part of [DayAgentInterface] but exposed for the Reconcile
  /// UI to call when the user re-points a parsed item to a different
  /// task from the "did you mean…" overflow menu.
  Future<ParsedItem> linkCapturePhraseToTask({
    required String parsedItemId,
    required String taskId,
  }) async {
    final updated = await captureService.linkCapturePhraseToTask(
      captureItemId: parsedItemId,
      taskId: taskId,
    );
    return _projectParsedItem(updated);
  }

  /// How often to re-check `draftPlanForDay` while waiting for the
  /// drafting wake to produce a new `DayPlanEntity`.
  static const _draftPollInterval = Duration(milliseconds: 500);

  /// Upper bound on how long [draftDayPlan] waits for the wake to
  /// produce a plan before falling back to the mock. Long enough for
  /// a typical model round-trip, short enough that the UI does not
  /// look stuck.
  static const _draftTimeout = Duration(seconds: 60);

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<TimeBlock> calendarBlocks = const [],
  }) async {
    final identity = await dayAgentService.getDayAgentForDate(dayDate);
    if (identity is! AgentIdentityEntity) {
      return mockFallback.draftDayPlan(
        captureId: captureId,
        decidedTaskIds: decidedTaskIds,
        dayDate: dayDate,
        calendarBlocks: calendarBlocks,
      );
    }
    final dayId = dayAgentIdForDate(dayDate);
    final baseline = await planService.draftPlanForDay(
      agentId: identity.agentId,
      dayId: dayId,
    );
    final baselineUpdatedAt = baseline?.updatedAt;

    final enqueued = await dayAgentService.enqueueDraftingWake(
      dayDate: dayDate,
      captureId: captureId.value,
    );
    if (!enqueued) {
      return mockFallback.draftDayPlan(
        captureId: captureId,
        decidedTaskIds: decidedTaskIds,
        dayDate: dayDate,
        calendarBlocks: calendarBlocks,
      );
    }

    final deadline = clock.now().add(_draftTimeout);
    while (clock.now().isBefore(deadline)) {
      await Future<void>.delayed(_draftPollInterval);
      final current = await planService.draftPlanForDay(
        agentId: identity.agentId,
        dayId: dayId,
      );
      if (current == null) continue;
      if (baselineUpdatedAt == null ||
          current.updatedAt.isAfter(baselineUpdatedAt)) {
        return _projectDayPlan(current, dayDate);
      }
    }

    // Timed out — fall back to the mock so the UI still shows a plan.
    return mockFallback.draftDayPlan(
      captureId: captureId,
      decidedTaskIds: decidedTaskIds,
      dayDate: dayDate,
      calendarBlocks: calendarBlocks,
    );
  }

  // ───────────────────────────── Mocked methods ──

  @override
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) async {
    final identity = await dayAgentService.getDayAgentForDate(asOf);
    if (identity is! AgentIdentityEntity) return const [];
    final cards = await planService.summarizeRecentPatterns(
      agentId: identity.agentId,
      asOf: asOf,
      lookbackDays: lookbackDays,
    );
    return [for (final card in cards) _projectLearningCard(card)];
  }

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
  }) => mockFallback.proposePlanDiff(
    currentPlan: currentPlan,
    voiceTranscript: voiceTranscript,
  );

  @override
  Future<DraftPlan> acceptDiff(PlanDiff diff) => mockFallback.acceptDiff(diff);

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
  }) => mockFallback.revertDiff(diff: diff, originalPlan: originalPlan);

  @override
  Future<DraftPlan> commitDay(DraftPlan plan) => mockFallback.commitDay(plan);

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) =>
      mockFallback.surfaceShutdownData(forDate: forDate);

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) => mockFallback.recordReflection(
    forDate: forDate,
    text: text,
    source: source,
  );

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) => mockFallback.recordCarryoverDecision(
    taskId: taskId,
    action: action,
    when: when,
  );

  @override
  Future<TomorrowNote> generateTomorrowNote({required DateTime forDate}) =>
      mockFallback.generateTomorrowNote(forDate: forDate);

  @override
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  }) => mockFallback.surfaceTaskCorpus(
    stateFilter: stateFilter,
    categoryId: categoryId,
    query: query,
  );

  // ───────────────────────────── Helpers ──

  Future<ParsedItem> _projectParsedItem(ParsedItemEntity entity) async {
    final category = await _resolveCategory(entity.categoryId);
    return ParsedItem(
      id: entity.id,
      kind: entity.kind,
      title: entity.title,
      category: category,
      confidence: entity.confidence,
      spokenPhrase: entity.spokenPhrase,
      matchedTaskId: entity.matchedTaskId,
      matchedTaskTitle: await _lookupTaskTitle(entity.matchedTaskId),
      estimateMinutes: entity.estimateMinutes,
      timeAnchor: entity.timeAnchor,
      proposedUpdate: entity.proposedUpdate,
    );
  }

  Future<PendingItem> _projectPendingItem(DayAgentPendingItem item) async {
    final category = await _resolveCategory(item.categoryId);
    final reason = _projectPendingReason(item.kind);
    return PendingItem(
      taskId: item.taskId,
      title: item.title,
      category: category,
      reason: reason,
      overdueByDays: reason == PendingItemReason.overdue && item.due != null
          ? _daysBetween(item.due!, DateTime.now())
          : null,
    );
  }

  PendingItemReason _projectPendingReason(DayAgentPendingKind kind) {
    switch (kind) {
      case DayAgentPendingKind.overdue:
        return PendingItemReason.overdue;
      case DayAgentPendingKind.inProgress:
        return PendingItemReason.inProgress;
      case DayAgentPendingKind.missedRecurring:
        return PendingItemReason.missedRecurring;
      case DayAgentPendingKind.dueToday:
        return PendingItemReason.dueToday;
    }
  }

  Future<DayAgentCategory> _resolveCategory(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) return _fallbackCategory;
    final cached = _categoryCache[categoryId];
    if (cached != null) return cached;
    final def = await journalDb.getCategoryById(categoryId);
    final projected = def == null
        ? _fallbackCategory.copyWith(id: categoryId)
        : _projectCategory(def);
    _categoryCache[categoryId] = projected;
    return projected;
  }

  DayAgentCategory _projectCategory(CategoryDefinition def) {
    final raw = (def.color ?? '').replaceFirst('#', '');
    // Normalise to the 6-char `RRGGBB` shape DayAgentCategory expects.
    final colorHex = raw.length >= 6
        ? raw.substring(0, 6)
        : (raw.isEmpty ? _fallbackCategory.colorHex : raw);
    return DayAgentCategory(id: def.id, name: def.name, colorHex: colorHex);
  }

  Future<String?> _lookupTaskTitle(String? taskId) async {
    if (taskId == null || taskId.isEmpty) return null;
    final entity = await journalDb.journalEntityById(taskId);
    return entity is Task ? entity.data.title : null;
  }

  LearningCard _projectLearningCard(DayAgentLearningCard card) {
    return LearningCard(
      id: card.id,
      overline: card.overline,
      summary: card.summary,
      bullets: [for (final bullet in card.bullets) _projectBullet(bullet)],
      kind: card.kind == 'nudge'
          ? LearningCardKind.nudge
          : LearningCardKind.standard,
    );
  }

  LearningBullet _projectBullet(DayAgentLearningBullet bullet) {
    return LearningBullet(
      text: bullet.text,
      tone: switch (bullet.tone) {
        DayAgentLearningBulletTone.info => LearningBulletTone.info,
        DayAgentLearningBulletTone.positive => LearningBulletTone.positive,
        DayAgentLearningBulletTone.warning => LearningBulletTone.warning,
      },
    );
  }

  int _daysBetween(DateTime from, DateTime to) {
    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day);
    return toDay.difference(fromDay).inDays;
  }

  Future<DraftPlan> _projectDayPlan(
    DayPlanEntity entity,
    DateTime dayDate,
  ) async {
    final blocks = <TimeBlock>[];
    for (final raw in entity.data.plannedBlocks) {
      blocks.add(await _projectPlannedBlock(raw));
    }
    final bands = [
      for (final band in entity.energyBands) _projectEnergyBand(band),
    ];
    return DraftPlan(
      dayDate: dayDate,
      blocks: blocks,
      bands: bands,
      capacityMinutes: entity.capacityMinutes,
      scheduledMinutes: entity.scheduledMinutes,
      agendaItems: _agendaFor(blocks),
      state: _projectDayState(entity.data.status),
    );
  }

  /// Build agenda items from drafted blocks. Buffers are dropped
  /// (they are plumbing, not intent). Task-linked blocks are grouped
  /// per `taskId`; standalone blocks become one agenda item each so
  /// the Agenda surface mirrors the Day timeline instead of going
  /// silent when the model has not linked tasks yet.
  List<AgendaItem> _agendaFor(List<TimeBlock> blocks) {
    final taskGroups = <String, List<TimeBlock>>{};
    final standalone = <TimeBlock>[];
    for (final block in blocks) {
      if (block.type == TimeBlockType.buffer) continue;
      final taskId = block.taskId;
      if (taskId != null && taskId.isNotEmpty) {
        taskGroups.putIfAbsent(taskId, () => <TimeBlock>[]).add(block);
      } else {
        standalone.add(block);
      }
    }

    AgendaItem build({
      required String id,
      required String title,
      required DayAgentCategory category,
      required List<TimeBlock> linked,
      String? taskId,
    }) {
      final estimate = linked.fold<int>(
        0,
        (acc, b) => acc + b.duration.inMinutes,
      );
      final state = linked.any((b) => b.state == TimeBlockState.inProgress)
          ? AgendaItemState.inProgress
          : (linked.every((b) => b.state == TimeBlockState.completed)
                ? AgendaItemState.done
                : AgendaItemState.open);
      return AgendaItem(
        id: id,
        title: title,
        category: category,
        linkedBlockIds: linked.map((b) => b.id).toList(),
        taskId: taskId,
        totalEstimateMinutes: estimate,
        state: state,
      );
    }

    return [
      for (final entry in taskGroups.entries)
        build(
          id: 'agenda_${entry.key}',
          title: entry.value.first.title,
          category: entry.value.first.category,
          linked: entry.value,
          taskId: entry.key,
        ),
      for (final block in standalone)
        build(
          id: 'agenda_${block.id}',
          title: block.title,
          category: block.category,
          linked: [block],
        ),
    ];
  }

  Future<TimeBlock> _projectPlannedBlock(PlannedBlock block) async {
    final category = await _resolveCategory(block.categoryId);
    return TimeBlock(
      id: block.id,
      title: (block.title?.isNotEmpty ?? false) ? block.title! : 'Untitled',
      start: block.startTime,
      end: block.endTime,
      type: _projectBlockType(block.type),
      state: _projectBlockState(block.state),
      category: category,
      taskId: block.taskId,
      reason: block.reason,
    );
  }

  EnergyBand _projectEnergyBand(DayAgentEnergyBand band) {
    return EnergyBand(
      start: band.start,
      end: band.end,
      level: switch (band.level) {
        DayAgentEnergyLevel.high => EnergyLevel.high,
        DayAgentEnergyLevel.low => EnergyLevel.low,
        DayAgentEnergyLevel.secondWind => EnergyLevel.secondWind,
      },
      label: band.label,
    );
  }

  TimeBlockType _projectBlockType(PlannedBlockType type) {
    switch (type) {
      case PlannedBlockType.ai:
        return TimeBlockType.ai;
      case PlannedBlockType.cal:
        return TimeBlockType.cal;
      case PlannedBlockType.buffer:
        return TimeBlockType.buffer;
      case PlannedBlockType.manual:
        return TimeBlockType.manual;
    }
  }

  TimeBlockState _projectBlockState(PlannedBlockState state) {
    switch (state) {
      case PlannedBlockState.drafted:
        return TimeBlockState.drafted;
      case PlannedBlockState.committed:
        return TimeBlockState.committed;
      case PlannedBlockState.inProgress:
        return TimeBlockState.inProgress;
      case PlannedBlockState.completed:
        return TimeBlockState.completed;
      case PlannedBlockState.dropped:
        return TimeBlockState.dropped;
    }
  }

  DayState _projectDayState(DayPlanStatus status) {
    return status.maybeMap(
      agreed: (_) => DayState.committed,
      orElse: () => DayState.drafted,
    );
  }
}

/// Tiny helper so the adapter can override one field on the fallback
/// category constant without exposing a public copyWith on the model.
extension on DayAgentCategory {
  DayAgentCategory copyWith({String? id, String? name, String? colorHex}) =>
      DayAgentCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        colorHex: colorHex ?? this.colorHex,
      );
}
