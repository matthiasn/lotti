import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

part 'day_agent_corpus_service.dart';
part 'day_agent_triage_service.dart';

/// Task creation seam for capture-derived NEW items.
typedef DayAgentTaskFactory =
    Future<Task?> Function({
      required String title,
      required String categoryId,
      required DateTime now,
      int? estimateMinutes,
      DateTime? due,
      String? profileId,
    });

/// Backend implementation for Daily OS capture and reconcile tools.
class DayAgentCaptureService {
  /// Creates a capture/reconcile service.
  DayAgentCaptureService({
    required this.agentRepository,
    required this.syncService,
    required this.journalDb,
    required this.journalRepository,
    required this.fts5Db,
    required this.orchestrator,
    required this.domainLogger,
    DayAgentTaskFactory? taskFactory,
    this.onPersistedStateChanged,
  }) : _taskFactory = taskFactory ?? _defaultTaskFactory;

  /// Agent entity/link repository.
  final AgentRepository agentRepository;

  /// Sync-aware agent writer.
  final AgentSyncService syncService;

  /// Journal DB used for task reads.
  final JournalDb journalDb;

  /// Journal repository used for task mutations.
  final JournalRepository journalRepository;

  /// FTS index used by `match_to_corpus`.
  final Fts5Db fts5Db;

  /// Wake orchestrator used to enqueue capture parsing.
  final WakeOrchestrator orchestrator;

  /// Structured logger.
  final DomainLogger domainLogger;

  final DayAgentTaskFactory _taskFactory;

  /// Callback fired when persisted state changes.
  final void Function(String id)? onPersistedStateChanged;

  static const _uuid = Uuid();
  static const _maxCorpusTasks = 200;
  static const _maxMatchCandidates = 8;
  static const _overdueLookbackDays = 7;

  /// Executes a non-foundation day-agent tool.
  Future<DayAgentDirectToolResult> executeTool({
    required String agentId,
    required String threadId,
    required String runKey,
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    try {
      final data = switch (toolName) {
        DayAgentToolNames.submitCapture => await _submitCaptureTool(
          agentId,
          args,
        ),
        DayAgentToolNames.parseCaptureToItems => await _parseCaptureTool(
          agentId,
          args,
        ),
        DayAgentToolNames.matchToCorpus => await _matchToCorpusTool(
          agentId,
          args,
        ),
        DayAgentToolNames.linkCapturePhraseToTask => await _linkTool(args),
        DayAgentToolNames.breakCaptureLink => await _breakLinkTool(args),
        DayAgentToolNames.surfacePendingDecisions =>
          await _surfacePendingDecisionsTool(agentId, args),
        DayAgentToolNames.applyTriage => await _applyTriageTool(args),
        DayAgentToolNames.createTaskFromPhrase =>
          await _createTaskFromPhraseTool(
            agentId: agentId,
            args: args,
          ),
        _ => throw DayAgentCaptureException('unknown tool "$toolName"'),
      };
      return DayAgentDirectToolResult.success(data);
    } on DayAgentCaptureException catch (e) {
      return DayAgentDirectToolResult.failure(e.message);
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        message: 'day-agent capture tool failed',
        stackTrace: s,
      );
      return DayAgentDirectToolResult.failure(e.toString());
    }
  }

  /// Writes a submitted capture and enqueues a parse wake.
  Future<CaptureEntity> submitCapture({
    required String agentId,
    required String transcript,
    DateTime? capturedAt,
    String? audioRef,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw const DayAgentCaptureException('transcript must not be empty');
    }

    final now = clock.now();
    final capture =
        AgentDomainEntity.capture(
              id: 'capture_${_uuid.v4()}',
              agentId: agentId,
              transcript: trimmed,
              capturedAt: capturedAt ?? now,
              createdAt: now,
              vectorClock: null,
              audioRef: _blankToNull(audioRef),
            )
            as CaptureEntity;

    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(capture);
    });

    onPersistedStateChanged
      ?..call(agentId)
      ..call(capture.id);

    orchestrator.enqueueManualWake(
      agentId: agentId,
      reason: dayAgentCaptureSubmittedReason,
      triggerTokens: {dayAgentCaptureSubmittedToken(capture.id)},
      // Partition the parse wake by the capture's day workspace so it never
      // supersedes or merges with another day's queued work under one planner
      // (ADR 0022). PR3 makes the capture carry an explicit dayId; until then
      // the day derives from when it was captured.
      workspaceKey: dayAgentWorkspaceKey(
        dayAgentIdForDate(capturedAt ?? now),
      ),
    );

    return capture;
  }

  /// Fetch a capture by ID.
  Future<CaptureEntity?> getCapture(String captureId) async {
    final entity = await agentRepository.getEntity(captureId);
    return entity?.mapOrNull(capture: (capture) => capture);
  }

  /// Fetch parsed items linked to [captureId], oldest first.
  Future<List<ParsedItemEntity>> parsedItemsForCapture(String captureId) async {
    final links = await agentRepository.getLinksFrom(
      captureId,
      type: AgentLinkTypes.captureToParsedItem,
    );
    if (links.isEmpty) return const <ParsedItemEntity>[];

    final entities = await agentRepository.getEntitiesByIds(
      links.map((link) => link.toId),
    );
    final items =
        [
          for (final entity in entities.values)
            if (entity is ParsedItemEntity) entity,
        ]..sort((a, b) {
          final byCreatedAt = a.createdAt.compareTo(b.createdAt);
          if (byCreatedAt != 0) return byCreatedAt;
          return a.id.compareTo(b.id);
        });
    return items;
  }

  /// Build the bounded task corpus embedded in capture-triggered wakes;
  /// see [DayAgentCorpusService].
  Future<List<Map<String, Object?>>> buildTaskCorpusSnapshot({
    required Set<String> allowedCategoryIds,
    required DateTime day,
    int limit = _maxCorpusTasks,
  }) => buildTaskCorpusSnapshotImpl(
    allowedCategoryIds: allowedCategoryIds,
    day: day,
    limit: limit,
  );

  /// Finds existing tasks that may match a capture phrase;
  /// see [DayAgentCorpusService].
  Future<List<DayAgentCorpusMatch>> matchToCorpus({
    required String agentId,
    required String phrase,
    String? categoryHint,
  }) => matchToCorpusImpl(
    agentId: agentId,
    phrase: phrase,
    categoryHint: categoryHint,
  );

  /// Persist parsed items emitted by the inference tool.
  Future<List<ParsedItemEntity>> persistParsedItems({
    required String agentId,
    required String captureId,
    required List<Object?> rawItems,
  }) async {
    final identity = await _requireIdentity(agentId);
    final capture = await getCapture(captureId);
    if (capture == null || capture.agentId != agentId) {
      throw DayAgentCaptureException('capture $captureId not found');
    }

    final now = clock.now();
    final parsedItems = <ParsedItemEntity>[];
    final taskLinks = <AgentLink>[];

    for (final raw in rawItems) {
      final item = await _parseModelItem(
        agentId: agentId,
        captureId: captureId,
        raw: raw,
        allowedCategoryIds: identity.allowedCategoryIds,
        now: now,
      );
      if (item == null) continue;
      parsedItems.add(item.entity);
      if (item.taskLink != null) taskLinks.add(item.taskLink!);
    }

    await syncService.runInTransaction(() async {
      await _softDeleteExistingParsedItems(captureId, now);
      for (final parsedItem in parsedItems) {
        await syncService.upsertEntity(parsedItem);
        await syncService.upsertLink(
          AgentLink.captureToParsedItem(
            id:
                'capture_to_parsed_item:${parsedItem.captureId}:'
                '${parsedItem.id}',
            fromId: parsedItem.captureId,
            toId: parsedItem.id,
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          ),
        );
      }
      for (final link in taskLinks) {
        await syncService.upsertLink(link);
      }
    });

    onPersistedStateChanged
      ?..call(agentId)
      ..call(captureId);
    return parsedItems;
  }

  /// Returns pending decisions for one day.
  Future<List<DayAgentPendingItem>> surfacePendingDecisions({
    required String agentId,
    required String dayId,
  }) async {
    final identity = await _requireIdentity(agentId);
    final day = _dateFromDayId(dayId);
    if (day == null) {
      throw DayAgentCaptureException('invalid dayId "$dayId"');
    }

    final dayStart = localDay(day);
    final dueToday = await journalDb.getTasksDueOn(dayStart);
    final dueOnOrBefore = await journalDb.getTasksDueOnOrBefore(dayStart);
    final overdueCutoff = dayStart.subtract(
      const Duration(days: _overdueLookbackDays),
    );
    final overdue = dueOnOrBefore.where((task) {
      final due = task.data.due;
      return due != null &&
          due.isBefore(dayStart) &&
          !due.isBefore(overdueCutoff);
    });
    final inProgress = await journalDb.getInProgressTasks(
      categoryIds: identity.allowedCategoryIds,
    );
    final missedRecurring = await journalDb.getMissedRecurringTasks(
      asOf: dayStart,
      categoryIds: identity.allowedCategoryIds,
    );

    final items = <DayAgentPendingItem>[
      for (final task in overdue)
        if (_categoryAllowed(task.meta.categoryId, identity.allowedCategoryIds))
          pendingItemFromTask(task, DayAgentPendingKind.overdue),
      for (final task in inProgress)
        if (_categoryAllowed(task.meta.categoryId, identity.allowedCategoryIds))
          pendingItemFromTask(task, DayAgentPendingKind.inProgress),
      for (final task in missedRecurring)
        if (_categoryAllowed(task.meta.categoryId, identity.allowedCategoryIds))
          pendingItemFromTask(task, DayAgentPendingKind.missedRecurring),
      for (final task in dueToday)
        if (_categoryAllowed(task.meta.categoryId, identity.allowedCategoryIds))
          pendingItemFromTask(task, DayAgentPendingKind.dueToday),
    ];
    return dedupeAndSortPendingItems(items);
  }

  /// Applies one reconcile triage action to a task;
  /// see [DayAgentTriageService].
  Future<Task> applyTriage({
    required String taskId,
    required String action,
    DateTime? deferTo,
  }) => applyTriageImpl(taskId: taskId, action: action, deferTo: deferTo);

  /// Links a parsed capture item to an existing task.
  Future<ParsedItemEntity> linkCapturePhraseToTask({
    required String captureItemId,
    required String taskId,
  }) async {
    final parsedItem = await _requireParsedItem(captureItemId);
    final task = await _requireTask(taskId);
    final now = clock.now();
    final updated = parsedItem.copyWith(
      matchedTaskId: task.id,
      categoryId: task.meta.categoryId ?? parsedItem.categoryId,
      kind: parsedItem.kind == ParsedItemKind.newTask
          ? ParsedItemKind.matched
          : parsedItem.kind,
      confidence: ParsedItemConfidence.high,
      lowConfidence: false,
    );

    await syncService.runInTransaction(() async {
      await _softDeleteTaskLinksForParsedItem(captureItemId, now);
      await syncService.upsertEntity(updated);
      await syncService.upsertLink(
        AgentLink.parsedItemToTask(
          id: 'parsed_item_to_task:$captureItemId:$taskId',
          fromId: captureItemId,
          toId: taskId,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );
    });

    onPersistedStateChanged
      ?..call(parsedItem.agentId)
      ..call(parsedItem.captureId)
      ..call(captureItemId);
    return updated;
  }

  /// Removes the active task link from a parsed capture item.
  Future<ParsedItemEntity> breakCaptureLink(String captureItemId) async {
    final parsedItem = await _requireParsedItem(captureItemId);
    final now = clock.now();
    final updated = parsedItem.copyWith(
      matchedTaskId: null,
      kind: ParsedItemKind.newTask,
      confidence: ParsedItemConfidence.low,
      lowConfidence: false,
    );

    await syncService.runInTransaction(() async {
      await _softDeleteTaskLinksForParsedItem(captureItemId, now);
      await syncService.upsertEntity(updated);
    });

    onPersistedStateChanged
      ?..call(parsedItem.agentId)
      ..call(parsedItem.captureId)
      ..call(captureItemId);
    return updated;
  }

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
    Map<String, dynamic> args,
  ) async {
    final task = await applyTriage(
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

  static Task _withStatus(Task task, TaskStatus status) {
    return task.copyWith(
      data: task.data.copyWith(
        status: status,
        statusHistory: [...task.data.statusHistory, status],
      ),
    );
  }

  static Task _withDueToday(Task task, DateTime now) {
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

  static Map<String, Object?> _parsedItemJson(ParsedItemEntity item) => {
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

  static double _requiredScore(Map<String, dynamic> args) {
    final raw = args['confidenceScore'] ?? args['confidence'];
    final score = raw is num ? raw.toDouble() : null;
    if (score == null || score.isNaN || score < 0 || score > 1) {
      throw const DayAgentCaptureException(
        'confidenceScore must be a number between 0 and 1',
      );
    }
    return score;
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
    if (value is num && value.isFinite && value % 1 == 0) return value.toInt();
    return null;
  }

  static DateTime? _optionalDateTime(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  static DateTime? _dueFromAnchor(String? raw, DateTime now) {
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

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static Set<String>? _categoryFilterForHint({
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

  static bool _categoryAllowed(String? categoryId, Set<String>? allowed) {
    if (allowed == null || allowed.isEmpty) return true;
    return categoryId != null && allowed.contains(categoryId);
  }

  static bool _isClosedTask(Task task) {
    const closedTaskStatuses = {'DONE', 'REJECTED'};
    return closedTaskStatuses.contains(task.data.status.toDbString);
  }

  static DateTime _endOfDay(DateTime date) {
    // Preserve the input's UTC/local zone so callers comparing the resulting
    // `due` against other UTC timestamps (created_at, etc.) don't get a
    // local→UTC offset surprise.
    return date.isUtc
        ? DateTime.utc(date.year, date.month, date.day, 23, 59, 59, 999)
        : DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  static Future<Task?> _defaultTaskFactory({
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

  static DateTime? _dateFromDayId(String dayId) {
    const prefix = 'dayplan-';
    if (!dayId.startsWith(prefix)) return null;
    return DateTime.tryParse(dayId.substring(prefix.length));
  }
}

/// JSON-string result for direct day-agent tools.
class DayAgentDirectToolResult {
  const DayAgentDirectToolResult._({
    required this.success,
    required this.output,
  });

  /// Successful result.
  factory DayAgentDirectToolResult.success(Map<String, Object?> data) {
    return DayAgentDirectToolResult._(
      success: true,
      output: const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  /// Failed result.
  factory DayAgentDirectToolResult.failure(String error) {
    return DayAgentDirectToolResult._(
      success: false,
      output: 'Error: $error',
    );
  }

  /// Whether the tool completed successfully.
  final bool success;

  /// Tool response text.
  final String output;
}

/// Validation failure for capture/reconcile tools.
class DayAgentCaptureException implements Exception {
  /// Creates a capture/reconcile validation failure.
  const DayAgentCaptureException(this.message);

  /// User/model-visible message.
  final String message;
}

class _ParsedItemWithLink {
  const _ParsedItemWithLink({
    required this.entity,
    required this.taskLink,
  });

  final ParsedItemEntity entity;
  final AgentLink? taskLink;
}
