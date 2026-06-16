part of 'day_agent_capture_service.dart';

/// Direct-tool dispatch handlers for [DayAgentCaptureService] (driven by
/// its `executeTool`): they parse the JSON tool args, call the service's
/// typed capture/parse/match/triage methods, and shape the result map.
/// Kept in a private extension (not a helper class) because they reach the
/// service's private internals (`_taskFactory`, `_requireIdentity`, etc.).
extension _DayAgentCaptureToolHandlers on DayAgentCaptureService {
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
    if (!categoryAllowed(categoryId, identity.allowedCategoryIds)) {
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

  // ---------------------------------------------------------------------------
  // Capture/parse persistence helpers.
  // ---------------------------------------------------------------------------

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
    if (!categoryAllowed(categoryId, allowedCategoryIds)) return null;

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
          isClosedTask(matchedTask) ||
          !categoryAllowed(matchedTask.meta.categoryId, allowedCategoryIds)) {
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
}
