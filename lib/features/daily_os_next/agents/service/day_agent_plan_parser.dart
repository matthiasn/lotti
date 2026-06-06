part of 'day_agent_plan_service.dart';

// Pure parsing/option helpers shared by the plan service. Library-private
// top-level functions so the class and the other parts call them
// unqualified.

PlannedBlock _parsePlannedBlock({
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
    id:
        _optionalString(data['id']) ??
        'block_${DayAgentPlanService._uuid.v4()}',
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

DayAgentEnergyBand _parseEnergyBand({
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

List<PinnedTaskRef> _pinnedTasksFor(List<PlannedBlock> blocks) {
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

int _scheduledMinutesFor(List<PlannedBlock> blocks) {
  return blocks
      .where((block) => block.state != PlannedBlockState.dropped)
      .fold<int>(0, (sum, block) => sum + block.duration.inMinutes);
}

Map<String, Object?> _planJson(DayPlanEntity plan) => {
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

Map<String, Object?> _blockJson(PlannedBlock block) => {
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

List<Object?> _objectList(Object? raw, String name) {
  if (raw == null) return const <Object?>[];
  if (raw is List) return raw;
  throw DayAgentCaptureException('$name must be an array');
}

List<String> _stringList(Object? raw) {
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

DateTime _requiredDateTime(Map<String, dynamic> args, String key) {
  final date = _optionalDateTime(args[key]);
  if (date == null) {
    throw DayAgentCaptureException(
      '$key must be a valid ISO-8601 date-time',
    );
  }
  return date;
}

String _requiredString(Map<String, dynamic> args, String key) {
  final value = _optionalString(args[key]);
  if (value == null) {
    throw DayAgentCaptureException('$key must not be empty');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  return _blankToNull(value);
}

int? _optionalInt(Object? value) {
  if (value is int) return value;
  if (value is num) {
    if (value % 1 != 0) {
      throw const DayAgentCaptureException('value must be an integer');
    }
    return value.toInt();
  }
  return null;
}

DateTime? _optionalDateTime(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim());
}

T? _optionalEnum<T extends Enum>(List<T> values, String? raw) {
  if (raw == null) return null;
  return parseEnumByName(values, raw);
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

bool _categoryAllowed(String? categoryId, Set<String>? allowed) {
  if (allowed == null || allowed.isEmpty) return true;
  return categoryId != null && allowed.contains(categoryId);
}

DateTime? _dateFromDayId(String dayId) {
  const prefix = 'dayplan-';
  if (!dayId.startsWith(prefix)) return null;
  return DateTime.tryParse(dayId.substring(prefix.length));
}

String _dayIdFromPlanEntityId(String planEntityId) {
  const prefix = 'day_agent_plan:';
  if (planEntityId.startsWith(prefix)) {
    return planEntityId.substring(prefix.length);
  }
  return planEntityId;
}

List<int>? _optionalIntList(Object? raw) {
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

List<int> _selectIndices({
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
