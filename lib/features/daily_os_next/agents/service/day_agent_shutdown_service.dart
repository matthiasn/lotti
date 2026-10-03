import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/ai/helpers/prompt_placeholder_formatting.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/one_shot_text_generation.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_helpers.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/logic/actual_time_blocks.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/recorded_time.dart';
import 'package:lotti/features/daily_os_next/logic/shutdown_facts.dart';
import 'package:lotti/features/ratings/data/rating_catalogs.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/metadata_service.dart';

/// Why no tomorrow note could be written.
enum TomorrowNoteFailure {
  /// The day agent's template resolves to no inference profile.
  noInferenceProvider,

  /// The model answered with nothing.
  emptyResponse,
}

/// Thrown by [DayAgentShutdownService.tomorrowNote] when it cannot write a
/// note for a reason the user can act on.
class TomorrowNoteUnavailableException implements Exception {
  const TomorrowNoteUnavailableException(this.failure);

  final TomorrowNoteFailure failure;

  @override
  String toString() => 'TomorrowNoteUnavailableException(${failure.name})';
}

/// What the Shutdown screen shows for one day.
typedef ShutdownDay = ({
  List<CompletedItem> completed,
  List<CarryoverItem> carryover,
  ShutdownMetrics metrics,
});

/// The real backend of Daily OS Shutdown: the day's facts from recorded time,
/// the day plan and session ratings; the user's reflection as a journal
/// entry; carryover decisions applied to the tasks; and the "For tomorrow"
/// note, written once per set of facts and synced.
class DayAgentShutdownService {
  DayAgentShutdownService({
    required this._journalDb,
    required this._persistenceLogic,
    required this._dayAgentService,
    required this._planService,
    required this._captureService,
    required this._agentRepository,
    required this._syncService,
    required this._templateService,
    required this._profileResolver,
    required CloudInferenceRepository inferenceRepository,
    required this._categoryById,
    required this._eventsEnabled,
  }) : _inference = inferenceRepository;

  final JournalDb _journalDb;
  final PersistenceLogic _persistenceLogic;
  final DayAgentService _dayAgentService;
  final DayAgentPlanService _planService;
  final DayAgentCaptureService _captureService;
  final AgentRepository _agentRepository;
  final AgentSyncService _syncService;
  final AgentTemplateService _templateService;
  final ProfileResolver _profileResolver;
  final CloudInferenceRepository _inference;
  final CategoryDefinition? Function(String id) _categoryById;
  final Future<bool> Function() _eventsEnabled;

  /// Tasks the user decided in Shutdown this session, by day id, so the
  /// closing note still reports a due-only task after its due date moved.
  final Map<String, Set<String>> _decidedTaskIds = {};

  /// Completion cap for the note: one short paragraph.
  static const tomorrowNoteMaxTokens = 300;

  /// Hard limit on the stored note, matching the day summary's.
  static const tomorrowNoteMaxChars = 500;

  static const _noteSystemMessage =
      "You are the user's day planner. They are closing their day and will "
      'read your note first thing tomorrow. From the facts given, write one '
      'short paragraph of at most three sentences in the second person: '
      'what carries into tomorrow and where to start. Mention the '
      "reflection only if it changes tomorrow's start. Never invent tasks, "
      'times or feelings that are not in the facts. Write in the language of '
      'the task titles. Respond with the paragraph only.';

  // ─────────────────────────────── Facts ──

  /// Completed work, still-open carryover and the metrics for [forDate].
  Future<ShutdownDay> shutdownDay(DateTime forDate) async {
    final facts = await _loadFacts(forDate);
    return (
      completed: completedItems(
        blocks: facts.dayBlocks,
        doneToday: facts.doneToday,
      ),
      carryover: carryoverItems(
        openTasks: facts.open,
        blocks: facts.dayBlocks,
        forDate: facts.day,
      ),
      metrics: shutdownMetrics(
        blocks: facts.dayBlocks,
        energy: facts.energy,
        priorDays: facts.priorDays,
        priorEnergy: facts.priorEnergy,
      ),
    );
  }

  Future<_DayFacts> _loadFacts(DateTime forDate) async {
    final day = localDay(forDate);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    final lookbackStart = DateTime(
      day.year,
      day.month,
      day.day - shutdownLookbackDays,
    );
    final inputs = await loadRecordedTimeInputs(
      _journalDb,
      rangeStart: lookbackStart,
      rangeEnd: dayEnd,
    );
    final blocks = actualTimeBlocksForEntries(
      entries: inputs.entries,
      links: inputs.links,
      linkedFromById: inputs.linkedFromById,
      categoryById: _categoryById,
      eventsEnabled: await _eventsEnabled(),
    );
    // A block belongs to the day it lies entirely inside — the rule the Day
    // timeline's per-day query applies — so Shutdown never reports time the
    // timeline does not show. A recording across midnight shows on neither.
    final byDay = groupBy(
      blocks.where((block) {
        final start = localDay(block.start);
        return !block.end.isAfter(
          DateTime(start.year, start.month, start.day + 1),
        );
      }),
      (TimeBlock block) => localDay(block.start),
    );
    final dayBlocks = byDay[day] ?? const <TimeBlock>[];
    final priorDays = [
      for (var offset = 1; offset <= shutdownLookbackDays; offset++)
        byDay[DateTime(day.year, day.month, day.day - offset)] ??
            const <TimeBlock>[],
    ];

    final energyByEntry = await _sessionEnergy({
      for (final block in blocks) ?block.trackedEntryId,
    });
    List<double> energyOf(Iterable<TimeBlock> blocks) => [
      for (final block in blocks) ?energyByEntry[block.trackedEntryId],
    ];

    final plannedTaskIds = await _plannedTaskIds(day);
    final dueToday = await _journalDb.getTasksDueOn(day);
    // Closed on or after the day: finds what was done or dropped that day
    // even without recorded time, a plan block or a due date on it.
    final closedSince = await _journalDb.getTasksClosedSince(day);
    final decidedIds = _decidedTaskIds[dayAgentIdForDate(day)] ?? const {};
    final candidateIds = <String>{
      for (final block in dayBlocks) ?block.taskId,
      ...plannedTaskIds,
      ...decidedIds,
    };
    final tasks = {
      for (final task in [...dueToday, ...closedSince]) task.meta.id: task,
      for (final entity in await _journalDb.getJournalEntitiesForIdsUnordered(
        candidateIds,
      ))
        if (entity is Task && entity.meta.deletedAt == null)
          entity.meta.id: entity,
    };

    bool inDay(DateTime at) => !at.isBefore(day) && at.isBefore(dayEnd);
    // Done that day: completed within it and still done when it ended. The
    // history is chronological, so its last entry before the day's end is the
    // status the day closed on — a task finished and reopened the same day is
    // open work, not a completion.
    final doneToday = [
      for (final task in tasks.values)
        if (task.data.statusHistory.lastWhereOrNull(
              (status) => status.createdAt.isBefore(dayEnd),
            )
            case final TaskDone done when inDay(done.createdAt))
          _shutdownTask(task),
    ];
    // Meant for the day: planned, due on it, or decided in this Shutdown —
    // a task that was only due that day is no longer due on it once moved or
    // dropped, and the note must still say what happened to it. Open ones
    // that were not re-placed past the day carry forward.
    final meantIds = <String>{
      ...plannedTaskIds,
      for (final task in dueToday.sortedBy((task) => task.data.title))
        task.meta.id,
      ...decidedIds,
      // Closed that day without being planned or due: only a drop matters
      // here; a completion is already in doneToday.
      for (final task in closedSince)
        if (task.data.status is TaskRejected &&
            inDay(task.data.status.createdAt))
          task.meta.id,
    };
    final doneIds = {for (final task in doneToday) task.taskId};
    final open = <ShutdownTask>[];
    final replaced = <(ShutdownTask, DateTime)>[];
    final dropped = <ShutdownTask>[];
    for (final id in meantIds) {
      final task = tasks[id];
      if (task == null) continue;
      final due = task.data.due;
      if (task.data.status is TaskRejected &&
          inDay(task.data.status.createdAt)) {
        dropped.add(_shutdownTask(task));
      } else if (isClosedTask(task) || doneIds.contains(id)) {
        // Closed now, or done when the day ended and only reopened after it:
        // either way the day owes it nothing.
        continue;
      } else if (due != null && localDay(due).isAfter(day)) {
        replaced.add((_shutdownTask(task), localDay(due)));
      } else {
        open.add(_shutdownTask(task));
      }
    }

    return _DayFacts(
      day: day,
      dayBlocks: dayBlocks,
      priorDays: priorDays,
      energy: energyOf(dayBlocks),
      priorEnergy: energyOf(priorDays.flattened),
      doneToday: doneToday,
      open: open,
      replaced: replaced,
      dropped: dropped,
    );
  }

  ShutdownTask _shutdownTask(Task task) => (
    taskId: task.meta.id,
    title: task.data.title,
    category: projectDayAgentCategory(task.meta.categoryId, _categoryById),
  );

  /// Task ids of the day plan's blocks that were not dropped, in plan order.
  Future<List<String>> _plannedTaskIds(DateTime day) async {
    final identity = await _dayAgentService.getDayAgentForDate(day);
    if (identity == null) return const [];
    final plan = await _planService.draftPlanForDay(
      agentId: identity.agentId,
      dayId: dayAgentIdForDate(day),
    );
    final blocks = plan?.data.plannedBlocks ?? const <PlannedBlock>[];
    return <String>{
      for (final block in blocks.sortedBy((block) => block.startTime))
        if (block.state != PlannedBlockState.dropped) ?block.taskId,
    }.toList();
  }

  /// The `energy` dimension (0–1) of the session rating of each entry in
  /// [entryIds] that has one.
  Future<Map<String, double>> _sessionEnergy(Set<String> entryIds) async {
    final ratingLinks = (await _journalDb.linksForEntryIds(
      entryIds,
    )).whereType<RatingLink>().toList();
    if (ratingLinks.isEmpty) return const {};
    final ratings = await _journalDb.getJournalEntitiesForIdsUnordered(
      {for (final link in ratingLinks) link.fromId},
    );
    return {
      for (final rating in ratings.whereType<RatingEntry>())
        if (rating.meta.deletedAt == null &&
            rating.data.catalogId == sessionRatingCatalogId)
          if (rating.data.dimensions.firstWhereOrNull(
                (dimension) => dimension.key == sessionEnergyDimensionKey,
              )
              case final dimension?)
            rating.data.targetId: dimension.value,
    };
  }

  // ─────────────────────────── Decisions ──

  /// Applies the user's carryover choice to the task: re-placed on the day
  /// after [forDate], on [when], or dropped.
  Future<void> recordCarryoverDecision({
    required DateTime forDate,
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {
    final planner = await _dayAgentService.getOrCreatePlannerAgent();
    final day = localDay(forDate);
    _decidedTaskIds.putIfAbsent(dayAgentIdForDate(day), () => {}).add(taskId);
    switch (action) {
      case CarryoverAction.drop:
        await _captureService.applyTriage(
          agentId: planner.agentId,
          taskId: taskId,
          action: 'drop',
        );
      case CarryoverAction.tomorrow || CarryoverAction.pickDate:
        final target = action == CarryoverAction.tomorrow
            ? DateTime(day.year, day.month, day.day + 1)
            : when;
        if (target == null) {
          throw ArgumentError.notNull('when');
        }
        await _captureService.applyTriage(
          agentId: planner.agentId,
          taskId: taskId,
          action: 'defer',
          deferTo: target,
        );
    }
  }

  // ─────────────────────────── Reflection ──

  /// The id of [forDate]'s reflection entry — the same on every device.
  static String reflectionEntryId(DateTime forDate) =>
      MetadataService.deterministicId(
        'daily_os_reflection:${dayAgentIdForDate(forDate)}',
      );

  /// Appends [text] to [forDate]'s reflection entry in the journal, creating
  /// it on the first reflection of the day.
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final existing = await _journalDb.journalEntityById(
      reflectionEntryId(forDate),
    );
    if (existing is JournalEntry && existing.meta.deletedAt == null) {
      final previous = existing.entryText?.plainText.trim() ?? '';
      await _persistenceLogic.updateJournalEntityText(
        existing.meta.id,
        EntryText(
          plainText: previous.isEmpty ? trimmed : '$previous\n\n$trimmed',
        ),
        existing.meta.dateTo,
      );
      return;
    }
    await _createReflectionEntry(forDate, EntryText(plainText: trimmed));
  }

  /// The id of [forDate]'s reflection entry, created empty when the day has
  /// none yet — the parent a spoken reflection's recording is linked to.
  Future<String> ensureReflectionEntry(DateTime forDate) async {
    final id = reflectionEntryId(forDate);
    final existing = await _journalDb.journalEntityById(id);
    if (existing != null && existing.meta.deletedAt == null) return id;
    await _createReflectionEntry(forDate, const EntryText(plainText: ''));
    return id;
  }

  Future<void> _createReflectionEntry(
    DateTime forDate,
    EntryText entryText,
  ) async {
    final day = localDay(forDate);
    final lastMinute = DateTime(day.year, day.month, day.day, 23, 59);
    final now = clock.now();
    // A reflection on a past day is filed at its end, not today.
    final at = now.isBefore(lastMinute) ? now : lastMinute;
    await _persistenceLogic.createDbEntity(
      JournalEntity.journalEntry(
        entryText: entryText,
        meta: await _persistenceLogic.createMetadata(
          dateFrom: at,
          dateTo: at,
          uuidV5Input: 'daily_os_reflection:${dayAgentIdForDate(day)}',
        ),
      ),
    );
  }

  /// The day's reflection as the note reads it: the entry's own text, then
  /// the transcripts of recordings linked under it, oldest first — a spoken
  /// reflection lives on its audio entry, not in the reflection's text.
  Future<String?> _reflectionText(DateTime forDate) async {
    final id = reflectionEntryId(forDate);
    final entry = await _journalDb.journalEntityById(id);
    if (entry == null || entry.meta.deletedAt != null) return null;
    final recordings = [
      for (final linked in await _journalDb.getLinkedEntities(id))
        if (linked is JournalAudio && linked.meta.deletedAt == null) linked,
    ]..sort((a, b) => a.meta.dateFrom.compareTo(b.meta.dateFrom));
    final parts = [
      resolveEntryText(entry),
      for (final recording in recordings) resolveEntryText(recording),
    ].where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join('\n\n');
  }

  // ──────────────────────────── Tomorrow ──

  /// The "For tomorrow" note for [forDate]: the stored one when it was
  /// written from the same facts, otherwise a fresh one, stored and synced so
  /// tomorrow's drafting can read it.
  Future<TomorrowNote> tomorrowNote(DateTime forDate) async {
    final day = localDay(forDate);
    final dayId = dayAgentIdForDate(day);
    final prompt = _notePrompt(
      day: day,
      facts: await _loadFacts(day),
      reflection: await _reflectionText(day),
    );
    final fingerprint = sha256.convert(utf8.encode(prompt)).toString();
    final noteId = dayAgentTomorrowNoteEntityId(dayId);
    final stored = await _agentRepository.getEntity(noteId);
    if (stored is TomorrowNoteEntity &&
        stored.deletedAt == null &&
        stored.inputFingerprint == fingerprint) {
      return TomorrowNote(body: stored.text);
    }

    final agent =
        await _dayAgentService.getDayAgentForDate(day) ??
        await _dayAgentService.getOrCreatePlannerAgent();
    final profile = await _resolveProfile(agent);
    if (profile == null) {
      throw const TomorrowNoteUnavailableException(
        TomorrowNoteFailure.noInferenceProvider,
      );
    }
    final generated = await _inference.generateText(
      prompt: prompt,
      systemMessage: _noteSystemMessage,
      model: profile.thinkingModelId,
      provider: profile.thinkingProvider,
      temperature: 0.3,
      maxCompletionTokens: tomorrowNoteMaxTokens,
      attribution: OneShotGenerationAttribution(
        workType: AiWorkType.textGeneration,
        automationId: 'automation:daily-os-tomorrow-note',
        automationDisplayName: 'Daily OS tomorrow note',
        interactionContext: AiCapturedContext(agentId: agent.agentId),
      ),
    );
    if (generated.isEmpty) {
      throw const TomorrowNoteUnavailableException(
        TomorrowNoteFailure.emptyResponse,
      );
    }
    final text = generated.length > tomorrowNoteMaxChars
        ? '${generated.substring(0, tomorrowNoteMaxChars - 1).trimRight()}…'
        : generated;
    final now = clock.now();
    await _syncService.upsertEntity(
      AgentDomainEntity.tomorrowNote(
        id: noteId,
        agentId: agent.agentId,
        dayId: dayId,
        text: text,
        inputFingerprint: fingerprint,
        createdAt: stored is TomorrowNoteEntity ? stored.createdAt : now,
        updatedAt: now,
        vectorClock: null,
      ),
    );
    return TomorrowNote(body: text);
  }

  Future<ResolvedProfile?> _resolveProfile(AgentIdentityEntity agent) async {
    final template = await _templateService.getTemplateForAgent(agent.agentId);
    if (template == null) return null;
    final version = await _templateService.getActiveVersion(template.id);
    if (version == null) return null;
    return _profileResolver.resolve(
      agentConfig: agent.config,
      template: template,
      version: version,
    );
  }

  /// The facts the note is written from. Also the note's cache key: the same
  /// facts give the same prompt, so the stored note still holds.
  static String _notePrompt({
    required DateTime day,
    required _DayFacts facts,
    required String? reflection,
  }) {
    String minutes(int value) => '${value}m';
    final completed = completedItems(
      blocks: facts.dayBlocks,
      doneToday: facts.doneToday,
    );
    final carryover = carryoverItems(
      openTasks: facts.open,
      blocks: facts.dayBlocks,
      forDate: day,
    );
    final buffer = StringBuffer()
      ..writeln('Day: ${dayAgentIdForDate(day)}')
      ..writeln()
      ..writeln('Worked on:');
    if (completed.isEmpty) buffer.writeln('- nothing recorded');
    for (final item in completed) {
      buffer.writeln(
        '- ${item.title} (${item.category.name}): '
        '${minutes(item.durationMinutes)}'
        '${item.doneToday ? ', done' : ''}',
      );
    }
    buffer
      ..writeln()
      ..writeln('Still open, meant for today:');
    if (carryover.isEmpty) buffer.writeln('- none');
    for (final item in carryover) {
      buffer.writeln(
        '- ${item.title}: '
        '${item.loggedMinutes > 0 ? '${minutes(item.loggedMinutes)} in' : 'not started'}',
      );
    }
    if (facts.replaced.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Moved by the user:');
      for (final (task, date) in facts.replaced) {
        buffer.writeln('- ${task.title} → ${dayAgentIdForDate(date)}');
      }
    }
    if (facts.dropped.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Dropped by the user:');
      for (final task in facts.dropped) {
        buffer.writeln('- ${task.title}');
      }
    }
    if (reflection != null) {
      buffer
        ..writeln()
        ..writeln("The user's reflection on the day:")
        ..writeln(reflection);
    }
    return buffer.toString();
  }
}

class _DayFacts {
  const _DayFacts({
    required this.day,
    required this.dayBlocks,
    required this.priorDays,
    required this.energy,
    required this.priorEnergy,
    required this.doneToday,
    required this.open,
    required this.replaced,
    required this.dropped,
  });

  final DateTime day;
  final List<TimeBlock> dayBlocks;
  final List<List<TimeBlock>> priorDays;
  final List<double> energy;
  final List<double> priorEnergy;
  final List<ShutdownTask> doneToday;
  final List<ShutdownTask> open;
  final List<(ShutdownTask, DateTime)> replaced;
  final List<ShutdownTask> dropped;
}
