import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentCaptureException;
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// Pure parsing/option helpers shared by the plan service. Library-private
// top-level functions so the class and the other parts call them
// unqualified.

/// Validates and parses one model-emitted block into a [PlannedBlock],
/// throwing [DayAgentCaptureException] on any contract violation: an
/// out-of-allowlist category, `end` not after `start`, a block outside the
/// plan day, a drafted today AI/manual block starting before
/// [earliestDraftStart], an AI block missing its `reason`, or a `taskId` not
/// in [decidedTaskIds]/[allowedExistingTaskIds]. Defaults `type` to `ai` and
/// `state` to `drafted`, and mints a block id when none is supplied.
PlannedBlock parsePlannedBlock({
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
  final type = optionalEnumArg(
    PlannedBlockType.values,
    optionalStringArg(data['type']),
  );
  final state = optionalEnumArg(
    PlannedBlockState.values,
    optionalStringArg(data['state']),
  );
  final blockType = type ?? PlannedBlockType.ai;
  final categoryId = requiredStringArg(data, 'categoryId');
  if (!categoryAllowed(categoryId, allowedCategoryIds)) {
    throw DayAgentCaptureException('categoryId $categoryId is not allowed');
  }
  final start = requiredDateTimeArg(data, 'start');
  final end = requiredDateTimeArg(data, 'end');
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
  final reason = optionalStringArg(data['reason']);
  if (blockType == PlannedBlockType.ai && reason == null) {
    throw const DayAgentCaptureException(
      'AI planned blocks require a non-empty reason',
    );
  }
  final taskId = optionalStringArg(data['taskId']);
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
    id: optionalStringArg(data['id']) ?? 'block_${_uuid.v4()}',
    categoryId: categoryId,
    startTime: start,
    endTime: end,
    note: optionalStringArg(data['note']),
    taskId: taskId,
    title: requiredStringArg(data, 'title'),
    type: blockType,
    state: blockState,
    reason: reason,
  );
}

/// Validates and parses one model-emitted energy band into a
/// [DayAgentEnergyBand], throwing [DayAgentCaptureException] when `end` is not
/// after `start`, the band falls outside the plan day, or `level` is not one
/// of `high`/`low`/`secondWind`.
DayAgentEnergyBand parseEnergyBand({
  required Object? raw,
  required DateTime day,
}) {
  if (raw is! Map) {
    throw const DayAgentCaptureException('energyBand must be an object');
  }
  final data = raw.cast<String, dynamic>();
  final start = requiredDateTimeArg(data, 'start');
  final end = requiredDateTimeArg(data, 'end');
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
  final level = optionalEnumArg(
    DayAgentEnergyLevel.values,
    requiredStringArg(data, 'level'),
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
    label: requiredStringArg(data, 'label'),
  );
}

/// The distinct tasks referenced by [blocks], in first-seen order, as
/// [PinnedTaskRef]s — the persisted record of which tasks the plan pins to the
/// day.
List<PinnedTaskRef> pinnedTasksFor(List<PlannedBlock> blocks) {
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

/// Total scheduled minutes across [blocks], excluding dropped blocks — the
/// figure compared against the day's capacity.
int scheduledMinutesFor(List<PlannedBlock> blocks) {
  return blocks
      .where((block) => block.state != PlannedBlockState.dropped)
      .fold<int>(0, (sum, block) => sum + block.duration.inMinutes);
}

/// Serializes a persisted [DayPlanEntity] into the JSON tool-result shape
/// returned to the model (plan/day ids, capacity vs. scheduled minutes, and
/// each block + energy band).
Map<String, Object?> planJson(DayPlanEntity plan) => {
  'planId': plan.id,
  'dayId': plan.dayId,
  'captureId': plan.captureId,
  'planDate': plan.planDate.toIso8601String(),
  'state': 'drafted',
  'capacityMinutes': plan.capacityMinutes,
  'scheduledMinutes': plan.scheduledMinutes,
  'blocks': [for (final block in plan.data.plannedBlocks) blockJson(block)],
  'energyBands': [for (final band in plan.energyBands) band.toJson()],
};

Map<String, Object?> blockJson(PlannedBlock block) => {
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

List<Object?> objectListArg(Object? raw, String name) {
  if (raw == null) return const <Object?>[];
  if (raw is List) return raw;
  throw DayAgentCaptureException('$name must be an array');
}

List<String> stringListArg(Object? raw) {
  if (raw == null) return const <String>[];
  if (raw is! List) {
    throw const DayAgentCaptureException('decidedTaskIds must be an array');
  }
  final out = <String>[];
  for (final value in raw) {
    final parsed = optionalStringArg(value);
    if (parsed == null) {
      throw const DayAgentCaptureException(
        'decidedTaskIds must contain non-empty strings',
      );
    }
    out.add(parsed);
  }
  return out;
}

DateTime requiredDateTimeArg(Map<String, dynamic> args, String key) {
  final date = optionalDateTimeArg(args[key]);
  if (date == null) {
    throw DayAgentCaptureException(
      '$key must be a valid ISO-8601 date-time',
    );
  }
  return date;
}

String requiredStringArg(Map<String, dynamic> args, String key) {
  final value = optionalStringArg(args[key]);
  if (value == null) {
    throw DayAgentCaptureException('$key must not be empty');
  }
  return value;
}

String? optionalStringArg(Object? value) {
  if (value is! String) return null;
  return blankToNull(value);
}

int? optionalIntArg(Object? value) {
  if (value is int) return value;
  if (value is num) {
    if (value % 1 != 0) {
      throw const DayAgentCaptureException('value must be an integer');
    }
    return value.toInt();
  }
  return null;
}

DateTime? optionalDateTimeArg(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim());
}

T? optionalEnumArg<T extends Enum>(List<T> values, String? raw) {
  if (raw == null) return null;
  return parseEnumByName(values, raw);
}

String? blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

bool categoryAllowed(String? categoryId, Set<String>? allowed) {
  if (allowed == null || allowed.isEmpty) return true;
  return categoryId != null && allowed.contains(categoryId);
}

DateTime? dateFromDayId(String dayId) {
  const prefix = 'dayplan-';
  if (!dayId.startsWith(prefix)) return null;
  return DateTime.tryParse(dayId.substring(prefix.length));
}

/// Strips the `day_agent_plan:` prefix from a plan entity id to recover its
/// bare `dayId`, returning the input unchanged when the prefix is absent.
String dayIdFromPlanEntityId(String planEntityId) {
  const prefix = 'day_agent_plan:';
  if (planEntityId.startsWith(prefix)) {
    return planEntityId.substring(prefix.length);
  }
  return planEntityId;
}

/// Resolves a model-supplied `itemIndices` selection into a sorted, unique
/// index list. A null selection means "all items"; any out-of-range index
/// throws [DayAgentCaptureException].
List<int> selectIndices({
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
