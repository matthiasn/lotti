part of 'day_agent_capture_service.dart';

/// Direct-tool dispatch handlers and capture/parse helpers for
/// [DayAgentCaptureService], plus the pure arg-parsing/task-shaping helpers
/// (de-statified to library-private top-levels). Split from the main file.
extension DayAgentCaptureToolHandlers on DayAgentCaptureService {
  Future<Map<String, Object?>> _submitCaptureTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final transcript = _requiredString(args, 'transcript');
    final rawCapturedAt = args['capturedAt'];
    final parsedCapturedAt = _optionalDateTime(rawCapturedAt);
    if (rawCapturedAt != null && parsedCapturedAt == null) {
      throw const DayAgentCaptureException(
        'capturedAt must be a valid ISO-8601 date-time',
      );
    }
    final capture = await submitCapture(
      agentId: agentId,
      transcript: transcript,
      capturedAt: parsedCapturedAt ?? clock.now(),
      audioRef: _optionalString(args['audioRef']),
    );
    return {'captureId': capture.id};
  }

  Future<Map<String, Object?>> _parseCaptureTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final captureId = _requiredString(args, 'captureId');
    final rawItems = args['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw const DayAgentCaptureException('items must be a non-empty array');
    }
    final items = await persistParsedItems(
      agentId: agentId,
      captureId: captureId,
      rawItems: rawItems,
    );
    return {
      'captureId': captureId,
      'items': [for (final item in items) _parsedItemJson(item)],
    };
  }

  Future<Map<String, Object?>> _matchToCorpusTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final matches = await matchToCorpus(
      agentId: agentId,
      phrase: _requiredString(args, 'phrase'),
      categoryHint: _optionalString(args['categoryHint']),
    );
    return {
      'candidates': [for (final match in matches) match.toJson()],
      'best': matches.isEmpty ? null : matches.first.toJson(),
    };
  }

  Future<Map<String, Object?>> _linkTool(Map<String, dynamic> args) async {
    final item = await linkCapturePhraseToTask(
      captureItemId: _requiredString(args, 'captureItemId'),
      taskId: _requiredString(args, 'taskId'),
    );
    return {'item': _parsedItemJson(item)};
  }

  Future<Map<String, Object?>> _breakLinkTool(Map<String, dynamic> args) async {
    final item = await breakCaptureLink(_requiredString(args, 'captureItemId'));
    return {'item': _parsedItemJson(item)};
  }

  Future<Map<String, Object?>> _surfacePendingDecisionsTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final items = await surfacePendingDecisions(
      agentId: agentId,
      dayId: _requiredString(args, 'dayId'),
    );
    return {
      'items': [for (final item in items) item.toJson()],
    };
  }

  Future<Map<String, Object?>> _applyTriageTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final task = await applyTriage(
      agentId: agentId,
      taskId: _requiredString(args, 'taskId'),
      action: _requiredString(args, 'action'),
      deferTo: _optionalDateTime(args['deferTo']),
    );
    return {
      'taskId': task.id,
      'status': task.data.status.toDbString,
      'due': task.data.due?.toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _createTaskFromPhraseTool({
    required String agentId,
    required Map<String, dynamic> args,
  }) async {
    final identity = await _requireIdentity(agentId);
    final phrase = _requiredString(args, 'phrase');
    final categoryId = _requiredString(args, 'category');
    if (!_categoryAllowed(categoryId, identity.allowedCategoryIds)) {
      throw DayAgentCaptureException('category $categoryId is not allowed');
    }
    final now = clock.now();
    final category = await journalDb.getCategoryById(categoryId);
    final task = await _taskFactory(
      title: phrase,
      categoryId: categoryId,
      now: now,
      estimateMinutes: _optionalInt(args['estimate']),
      due: _dueFromAnchor(_optionalString(args['dueAnchor']), now),
      profileId: category?.defaultProfileId,
    );
    if (task == null) {
      throw const DayAgentCaptureException('failed to create task');
    }

    final captureItemId = _optionalString(args['captureItemId']);
    ParsedItemEntity? updatedParsedItem;
    AgentLink? taskLink;
    if (captureItemId != null) {
      final entity = await agentRepository.getEntity(captureItemId);
      if (entity is ParsedItemEntity && entity.agentId == agentId) {
        updatedParsedItem = entity.copyWith(
          matchedTaskId: task.id,
          categoryId: task.meta.categoryId ?? categoryId,
          kind: ParsedItemKind.matched,
          confidence: ParsedItemConfidence.high,
          lowConfidence: false,
        );
        taskLink = AgentLink.parsedItemToTask(
          id: 'parsed_item_to_task:$captureItemId:${task.id}',
          fromId: captureItemId,
          toId: task.id,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        );
      }
    }

    if (updatedParsedItem != null || taskLink != null) {
      await syncService.runInTransaction(() async {
        if (updatedParsedItem != null) {
          await syncService.upsertEntity(updatedParsedItem);
        }
        if (taskLink != null) {
          await _softDeleteTaskLinksForParsedItem(captureItemId!, now);
          await syncService.upsertLink(taskLink);
        }
      });
    }

    onPersistedStateChanged
      ?..call(agentId)
      ..call(task.id);
    if (captureItemId != null) {
      onPersistedStateChanged?.call(captureItemId);
    }
    return {
      'taskId': task.id,
      'title': task.data.title,
      'categoryId': task.meta.categoryId,
      'estimateMinutes': task.data.estimate?.inMinutes,
      'due': task.data.due?.toIso8601String(),
    };
  }

  Future<_ParsedItemWithLink?> _parseModelItem({
    required String agentId,
    required String captureId,
    required Object? raw,
    required Set<String> allowedCategoryIds,
    required DateTime now,
  }) async {
    if (raw is! Map) return null;
    final data = raw.cast<String, dynamic>();
    final title = _requiredString(data, 'title');
    final categoryId = _requiredString(data, 'categoryId');
    if (!_categoryAllowed(categoryId, allowedCategoryIds)) return null;

    final score = _requiredScore(data);
    final classification = classifyParsedItemMatch(score);
    var matchedTaskId = _optionalString(data['matchedTaskId']);
    final rawKind = _optionalString(data['kind']);
    final parsedKind = rawKind == null
        ? null
        : parseEnumByName(ParsedItemKind.values, rawKind);
    if (rawKind != null && parsedKind == null) {
      throw DayAgentCaptureException(
        'kind must be one of '
        '${ParsedItemKind.values.map((value) => value.name).join(', ')}',
      );
    }
    var kind = parsedKind ?? ParsedItemKind.newTask;
    var confidence = classification.confidence;
    var lowConfidence = classification.lowConfidence;

    if (!classification.shouldAutoLink) {
      matchedTaskId = null;
      kind = ParsedItemKind.newTask;
    }

    Task? matchedTask;
    if (matchedTaskId != null) {
      matchedTask = await _taskOrNull(matchedTaskId);
      if (matchedTask == null ||
          _isClosedTask(matchedTask) ||
          !_categoryAllowed(matchedTask.meta.categoryId, allowedCategoryIds)) {
        matchedTaskId = null;
        matchedTask = null;
        kind = ParsedItemKind.newTask;
        confidence = ParsedItemConfidence.low;
        lowConfidence = true;
      } else if (kind == ParsedItemKind.newTask) {
        kind = ParsedItemKind.matched;
      }
    }

    final item =
        AgentDomainEntity.parsedItem(
              id: 'parsed_${_uuid.v4()}',
              agentId: agentId,
              captureId: captureId,
              kind: kind,
              title: title,
              categoryId: matchedTask?.meta.categoryId ?? categoryId,
              confidence: confidence,
              confidenceScore: score,
              createdAt: now,
              vectorClock: null,
              lowConfidence: lowConfidence,
              spokenPhrase: _optionalString(data['spokenPhrase']),
              matchedTaskId: matchedTaskId,
              estimateMinutes: _optionalInt(data['estimateMinutes']),
              timeAnchor: _optionalString(data['timeAnchor']),
              proposedUpdate: _optionalString(data['proposedUpdate']),
            )
            as ParsedItemEntity;

    final link = matchedTaskId == null
        ? null
        : AgentLink.parsedItemToTask(
            id: 'parsed_item_to_task:${item.id}:$matchedTaskId',
            fromId: item.id,
            toId: matchedTaskId,
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          );
    return _ParsedItemWithLink(entity: item, taskLink: link);
  }

  Future<void> _softDeleteExistingParsedItems(
    String captureId,
    DateTime now,
  ) async {
    final links = await agentRepository.getLinksFrom(
      captureId,
      type: AgentLinkTypes.captureToParsedItem,
    );
    if (links.isEmpty) return;

    final entitiesById = await agentRepository.getEntitiesByIds(
      links.map((link) => link.toId),
    );
    for (final link in links) {
      await syncService.upsertLink(link.softDeleted(now));
    }
    for (final entity in entitiesById.values) {
      if (entity is ParsedItemEntity) {
        await _softDeleteTaskLinksForParsedItem(entity.id, now);
        await syncService.upsertEntity(entity.copyWith(deletedAt: now));
      }
    }
  }

  Future<void> _softDeleteTaskLinksForParsedItem(
    String parsedItemId,
    DateTime now,
  ) async {
    final links = await agentRepository.getLinksFrom(
      parsedItemId,
      type: AgentLinkTypes.parsedItemToTask,
    );
    for (final link in links) {
      await syncService.upsertLink(link.softDeleted(now));
    }
  }

  Future<AgentIdentityEntity> _requireIdentity(String agentId) async {
    final entity = await agentRepository.getEntity(agentId);
    if (entity is AgentIdentityEntity) return entity;
    throw DayAgentCaptureException('agent $agentId not found');
  }

  Future<ParsedItemEntity> _requireParsedItem(String parsedItemId) async {
    final entity = await agentRepository.getEntity(parsedItemId);
    if (entity is ParsedItemEntity) return entity;
    throw DayAgentCaptureException('parsed item $parsedItemId not found');
  }

  Future<Task> _requireTask(String taskId) async {
    final task = await _taskOrNull(taskId);
    if (task != null) return task;
    throw DayAgentCaptureException('task $taskId not found');
  }

  Future<Task?> _taskOrNull(String taskId) async {
    final entity = await journalDb.journalEntityById(taskId);
    return entity is Task ? entity : null;
  }
}

Task _withStatus(Task task, TaskStatus status) {
  return task.copyWith(
    data: task.data.copyWith(
      status: status,
      statusHistory: [...task.data.statusHistory, status],
    ),
  );
}

Task _withDueToday(Task task, DateTime now) {
  final updated = task.copyWith(
    data: task.data.copyWith(due: _endOfDay(now)),
  );
  final status = task.data.status.toDbString;
  if (status == 'BLOCKED' || status == 'ON HOLD') {
    return _withStatus(
      updated,
      TaskStatus.open(
        id: _uuid.v4(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
    );
  }
  return updated;
}

Map<String, Object?> _parsedItemJson(ParsedItemEntity item) => {
  'id': item.id,
  'captureId': item.captureId,
  'kind': item.kind.name,
  'title': item.title,
  'categoryId': item.categoryId,
  'confidence': item.confidence.name,
  'confidenceScore': item.confidenceScore,
  'lowConfidence': item.lowConfidence,
  'spokenPhrase': item.spokenPhrase,
  'matchedTaskId': item.matchedTaskId,
  'estimateMinutes': item.estimateMinutes,
  'timeAnchor': item.timeAnchor,
  'proposedUpdate': item.proposedUpdate,
};

double _requiredScore(Map<String, dynamic> args) {
  final raw = args['confidenceScore'] ?? args['confidence'];
  final score = raw is num ? raw.toDouble() : null;
  if (score == null || score.isNaN || score < 0 || score > 1) {
    throw const DayAgentCaptureException(
      'confidenceScore must be a number between 0 and 1',
    );
  }
  return score;
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
  if (value is num && value.isFinite && value % 1 == 0) return value.toInt();
  return null;
}

DateTime? _optionalDateTime(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim());
}

DateTime? _dueFromAnchor(String? raw, DateTime now) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  final due = switch (trimmed.toLowerCase()) {
    'today' => _endOfDay(now),
    'tomorrow' => _endOfDay(now.add(const Duration(days: 1))),
    _ => DateTime.tryParse(trimmed),
  };
  if (due == null) {
    // Surfacing this as a structured failure (rather than silently dropping
    // the anchor) prevents `create_task_from_phrase` from persisting an
    // undated task when the model produces a malformed `dueAnchor`.
    throw DayAgentCaptureException(
      'dueAnchor must be "today", "tomorrow", or a valid ISO-8601 '
      'date-time; got "$raw"',
    );
  }
  return due;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

Set<String>? _categoryFilterForHint({
  required Set<String> allowedCategoryIds,
  required String? categoryHint,
}) {
  if (categoryHint == null) {
    return allowedCategoryIds.isEmpty ? null : allowedCategoryIds;
  }
  if (allowedCategoryIds.isNotEmpty &&
      !allowedCategoryIds.contains(categoryHint)) {
    return const <String>{};
  }
  return {categoryHint};
}

bool _categoryAllowed(String? categoryId, Set<String>? allowed) {
  if (allowed == null || allowed.isEmpty) return true;
  return categoryId != null && allowed.contains(categoryId);
}

bool _isClosedTask(Task task) {
  const closedTaskStatuses = {'DONE', 'REJECTED'};
  return closedTaskStatuses.contains(task.data.status.toDbString);
}

DateTime _endOfDay(DateTime date) {
  // Preserve the input's UTC/local zone so callers comparing the resulting
  // `due` against other UTC timestamps (created_at, etc.) don't get a
  // local→UTC offset surprise.
  return date.isUtc
      ? DateTime.utc(date.year, date.month, date.day, 23, 59, 59, 999)
      : DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

Future<Task?> _defaultTaskFactory({
  required String title,
  required String categoryId,
  required DateTime now,
  int? estimateMinutes,
  DateTime? due,
  String? profileId,
}) {
  return getIt<PersistenceLogic>().createTaskEntry(
    data: TaskData(
      status: TaskStatus.open(
        id: _uuid.v4(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      title: title,
      statusHistory: const [],
      dateTo: now,
      dateFrom: now,
      estimate: Duration(minutes: estimateMinutes ?? 0),
      due: due,
      profileId: profileId,
    ),
    entryText: EntryText(plainText: title, markdown: title),
    categoryId: categoryId,
  );
}

DateTime? _dateFromDayId(String dayId) {
  const prefix = 'dayplan-';
  if (!dayId.startsWith(prefix)) return null;
  return DateTime.tryParse(dayId.substring(prefix.length));
}
