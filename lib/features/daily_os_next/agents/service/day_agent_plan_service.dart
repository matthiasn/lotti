import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
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
        _ => throw DayAgentCaptureException('unknown tool "$toolName"'),
      };
      return DayAgentDirectToolResult.success(data);
    } on DayAgentCaptureException catch (e) {
      return DayAgentDirectToolResult.failure(e.message);
    } catch (e, s) {
      domainLogger.error(
        LogDomains.agentWorkflow,
        'day-agent plan tool failed',
        error: e,
        stackTrace: s,
      );
      return DayAgentDirectToolResult.failure(e.toString());
    }
  }

  /// Fetch the persisted draft for one day.
  Future<DayPlanEntity?> draftPlanForDay({
    required String agentId,
    required String dayId,
  }) async {
    final entity = await agentRepository.getEntity(_planEntityId(dayId));
    if (entity is DayPlanEntity && entity.agentId == agentId) {
      return entity;
    }
    return null;
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

    final allowedCategoryIds = identity.allowedCategoryIds;
    final decidedTasks = decidedTaskIds.toSet();
    final blocks = <PlannedBlock>[];
    for (final raw in rawBlocks) {
      blocks.add(
        _parsePlannedBlock(
          raw: raw,
          day: planDate,
          allowedCategoryIds: allowedCategoryIds,
          decidedTaskIds: decidedTasks,
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
    final scheduledMinutes = blocks.fold<int>(
      0,
      (sum, block) => sum + block.duration.inMinutes,
    );
    final pinnedTasks = _pinnedTasksFor(blocks);
    final now = clock.now();
    final existing = await draftPlanForDay(agentId: agentId, dayId: dayId);
    final plan =
        AgentDomainEntity.dayPlan(
              id: _planEntityId(dayId),
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
      DayAgentLearningCard(
        id: 'gentle_nudge',
        overline: 'Gentle nudge',
        summary: averageScheduled > averageCapacity
            ? 'Your recent drafts run over capacity; protect a buffer before '
                  'adding more work.'
            : 'Your recent drafts fit capacity; place demanding work in the '
                  'highest-energy window.',
        kind: 'nudge',
        bullets: [
          DayAgentLearningBullet(
            text: averageScheduled > averageCapacity
                ? 'Leave at least one transition block unassigned.'
                : 'Keep the plan specific enough to act on.',
            tone: averageScheduled > averageCapacity
                ? DayAgentLearningBulletTone.warning
                : DayAgentLearningBulletTone.positive,
          ),
        ],
      ),
    ];
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
    final dayStart = localDay(day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    if (start.isBefore(dayStart) || end.isAfter(dayEnd)) {
      throw const DayAgentCaptureException(
        'blocks must stay within the planDate day',
      );
    }
    final reason = _optionalString(data['reason']);
    if (blockType == PlannedBlockType.ai && reason == null) {
      throw const DayAgentCaptureException(
        'AI planned blocks require a non-empty reason',
      );
    }
    final taskId = _optionalString(data['taskId']);
    if (taskId != null &&
        decidedTaskIds.isNotEmpty &&
        !decidedTaskIds.contains(taskId)) {
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
      state: state ?? PlannedBlockState.drafted,
      reason: reason,
    );
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
    return [
      for (final value in raw) ?_optionalString(value),
    ];
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
    if (value is num) return value.toInt();
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

  static String _planEntityId(String dayId) => 'day_agent_plan:$dayId';
}
