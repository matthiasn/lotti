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
part 'day_agent_capture_tools.dart';

const _uuid = Uuid();
const _maxCorpusTasks = 200;
const _maxMatchCandidates = 8;
const _overdueLookbackDays = 7;

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
        DayAgentToolNames.applyTriage => await _applyTriageTool(agentId, args),
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
    final effectiveCapturedAt = capturedAt ?? now;
    final capture =
        AgentDomainEntity.capture(
              id: 'capture_${_uuid.v4()}',
              agentId: agentId,
              transcript: trimmed,
              capturedAt: effectiveCapturedAt,
              createdAt: now,
              vectorClock: null,
              // Stamp the day workspace explicitly (ADR 0022) so the capture
              // is queryable by day and a parse wake can resolve its day from
              // the capture even when one planner owns many days.
              dayId: dayAgentIdForDate(effectiveCapturedAt),
              audioRef: _blankToNull(audioRef),
            )
            as CaptureEntity;

    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(capture);
    });

    // Emit the day workspace too (ADR 0022): post-cutover the agentId is the
    // shared planner, so day-keyed providers (capturesForDateProvider) refresh
    // on `dayId`, not the agent id.
    onPersistedStateChanged
      ?..call(agentId)
      ..call(captureDayId(capture))
      ..call(capture.id);

    orchestrator.enqueueManualWake(
      agentId: agentId,
      reason: dayAgentCaptureSubmittedReason,
      triggerTokens: {dayAgentCaptureSubmittedToken(capture.id)},
      // Partition the parse wake by the capture's day workspace (ADR 0022) so
      // it never supersedes or merges with another day's queued work under one
      // planner.
      workspaceKey: dayAgentWorkspaceKey(captureDayId(capture)),
      // Each capture carries its own transcript to parse; a second capture for
      // the same day must not drop the first's still-queued parse. Accumulate
      // instead of superseding so every submission is parsed.
      supersede: false,
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
    required String agentId,
    required String taskId,
    required String action,
    DateTime? deferTo,
  }) => applyTriageImpl(
    agentId: agentId,
    taskId: taskId,
    action: action,
    deferTo: deferTo,
  );

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
