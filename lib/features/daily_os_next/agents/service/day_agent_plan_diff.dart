part of 'day_agent_plan_service.dart';

// Plan-diff machinery: change parsing, validation, application, and the
// snapshot/change model types.

_DiffChange _parseDiffChange({
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

_BlockSnapshot? _optionalBlockSnapshot(
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

void _assertWithinDay(
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

String _formatChangeSummary(
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
void _validateApplicableBatch(
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

List<PlannedBlock> _applyItem(
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

PlannedBlockState _stateForAcceptedAddedBlock(
  DayPlanStatus planStatus,
) {
  return planStatus.maybeMap(
    agreed: (_) => PlannedBlockState.committed,
    committed: (_) => PlannedBlockState.committed,
    orElse: () => PlannedBlockState.drafted,
  );
}

DateTime? _argDate(Map<String, dynamic> args, String key) {
  final raw = args[key];
  if (raw is! String) return null;
  return DateTime.tryParse(raw);
}

PlannedBlockType? _argType(Map<String, dynamic> args) {
  final raw = args['type'];
  if (raw is! String) return null;
  return parseEnumByName(PlannedBlockType.values, raw);
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
