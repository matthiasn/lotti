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
/// `DayAgentPlanService`):
/// `submitCapture`, `parseCaptureToItems`, `surfacePendingDecisions`,
/// `applyTriage`, `linkCapturePhraseToTask`, `breakCaptureLink`,
/// `summarizeRecentPatterns`.
///
/// **Still mocked** (no agent-side tool ships yet, OR backend tool
/// exists but no UI-callable wake trigger):
/// `matchToCorpus`, `draftDayPlan` (needs drafting wake trigger),
/// `proposePlanDiff`, `acceptDiff`, `revertDiff`, `commitDay`,
/// `surfaceShutdownData`, `recordReflection`,
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
  }) async {
    final identity = await dayAgentService.createDayAgent(date: capturedAt);
    final capture = await captureService.submitCapture(
      agentId: identity.agentId,
      transcript: transcript,
      capturedAt: capturedAt,
    );
    return CaptureId(capture.id);
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

  // ───────────────────────────── Mocked methods ──

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<TimeBlock> calendarBlocks = const [],
  }) => mockFallback.draftDayPlan(
    captureId: captureId,
    decidedTaskIds: decidedTaskIds,
    dayDate: dayDate,
    calendarBlocks: calendarBlocks,
  );

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
