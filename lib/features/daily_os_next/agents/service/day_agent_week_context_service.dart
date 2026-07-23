import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/week_context.dart';
import 'package:lotti/features/daily_os_next/agents/domain/week_rollup.dart';
import 'package:lotti/features/daily_os_next/agents/prompt/day_agent_prompt_sections.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentDirectToolResult;
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/logic/recorded_time.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Raised by the week-context service for an invalid tool/argument.
class DayAgentWeekContextException implements Exception {
  /// Creates the exception with a model-facing [message].
  const DayAgentWeekContextException(this.message);

  /// Model-facing error text.
  final String message;

  @override
  String toString() => message;
}

/// Backend for the planner's week context: assembles the inputs for the pure
/// [buildWeekContext] renderer and executes the `write_day_summary` tool.
///
/// Reading is fail-soft: any load error logs and returns null so a wake never
/// dies on lookback context (accepted: a transient error and genuine no-data
/// are indistinguishable in the prompt). Writing day summaries is windowed to
/// the WALL CLOCK, independent of the wake's plan date: only today's and
/// yesterday's summaries are writable — a drafting-tomorrow wake must not
/// write testimony for unhappened days, and a stale-device wake must not
/// overwrite genuine testimony from further back.
class DayAgentWeekContextService {
  /// Creates the service.
  DayAgentWeekContextService({
    required this.agentRepository,
    required this.journalDb,
    required this.syncService,
    required this.domainLogger,
    this.onPersistedStateChanged,
    this.categoryNameResolver,
  });

  /// Agent entity repository.
  final AgentRepository agentRepository;

  /// Journal database (recorded time entries + links).
  final JournalDb journalDb;

  /// Sync-aware writer.
  final AgentSyncService syncService;

  /// Structured logger.
  final DomainLogger domainLogger;

  /// Callback fired when persisted state changes.
  final void Function(String id)? onPersistedStateChanged;

  /// Test/DI override for category-name resolution; defaults to the
  /// getIt-guarded [EntitiesCacheService] lookup.
  final String? Function(String categoryId)? categoryNameResolver;

  /// Builds the rendered week context for [planDate], or null when loading
  /// fails (fail-soft). An information-free window yields a [WeekContext]
  /// whose sections are null ([WeekContext.isEmpty]) — the prompt builder
  /// omits absent sections, so callers need not special-case it.
  ///
  /// Reads are not keyed to the waking agent: lookback/lookahead plans and
  /// summaries are accepted from any Daily OS day owner (coordinator or
  /// per-day agent, ADR 0032), since neighboring days are owned by different
  /// identities across the cutover.
  ///
  /// [now] lets the caller pass its own wall-clock read so the rendered day
  /// classification agrees with the rest of the prompt (e.g. the payload's
  /// `current_local_time`) across a midnight straddle; defaults to
  /// `clock.now()`.
  Future<WeekContext?> buildForDay({
    required DateTime planDate,
    DateTime? now,
  }) async {
    try {
      now ??= clock.now();
      // `localDay` returns a LOCAL midnight (it converts to local first), so
      // all `DateTime(y, m, d ± n)` window arithmetic on these bases is
      // local-by-construction — the wall-clock day contract of ADR 0028.
      final anchor = localDay(planDate);
      final today = localDay(now);

      // The 21 deterministic ids — 13 plans (8 lookback + 5 lookahead) and
      // 8 lookback summaries — fetched in ONE chunked getEntitiesByIds call.
      // A per-id Future.wait fan-out is exactly the writer-lock pile-up the
      // repository's own doc comment documents as a production incident.
      final lookbackDays = <DateTime>[
        for (var offset = -weekContextLookbackDays; offset <= 0; offset++)
          DateTime(anchor.year, anchor.month, anchor.day + offset),
      ];
      final lookaheadDays = <DateTime>[
        for (var offset = 1; offset <= weekContextLookaheadDays; offset++)
          DateTime(anchor.year, anchor.month, anchor.day + offset),
      ];
      final ids = <String>{
        for (final day in lookbackDays) ...[
          dayAgentPlanEntityId(dayPlanId(day)),
          dayAgentSummaryEntityId(dayPlanId(day)),
        ],
        for (final day in lookaheadDays) dayAgentPlanEntityId(dayPlanId(day)),
      };
      final entitiesById = await agentRepository.getEntitiesByIds(ids);
      // Ownership spans the ADR 0032 cutover: lookback/lookahead days may be
      // written by the coordinator (pre-cutover) or by sibling per-day agents
      // (post-cutover), so accept any Daily OS day owner rather than only the
      // waking agent. Foreign/unknown agent ids stay excluded.
      final dayPlans = <DayPlanEntity>[
        for (final entity in entitiesById.values)
          if (entity is DayPlanEntity &&
              isDailyOsDayOwner(entity.agentId) &&
              entity.deletedAt == null)
            entity,
      ];
      final daySummaries = <DaySummaryEntity>[
        for (final entity in entitiesById.values)
          if (entity is DaySummaryEntity &&
              isDailyOsDayOwner(entity.agentId) &&
              entity.deletedAt == null)
            entity,
      ];

      // Claim deadlines are anchored to the wall clock (today .. today+5).
      final claims = await agentRepository.getAttentionClaimsForWindow(
        start: today,
        end: DateTime(
          today.year,
          today.month,
          today.day + weekContextLookaheadDays,
        ),
      );

      return buildWeekContext(
        planDate: planDate,
        now: now,
        claims: claims,
        dayPlans: dayPlans,
        daySummaries: daySummaries,
        recordedSpans: await _recordedSpans(anchor: anchor, today: today),
        categoryName: _resolveCategoryName,
      );
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        message: 'failed to build week context',
        stackTrace: s,
      );
      return null;
    }
  }

  /// Loads the lookback window's recorded time as lightweight spans via the
  /// shared recorded-time resolution.
  ///
  /// The range ends at END OF DAY of `min(planDate, today)` — never at
  /// `clock.now()`: `sortedCalendarEntries` is a containment query
  /// (`date_from >= start AND date_to <= end`), so a now-capped range would
  /// drop entries finishing later today. Accepted: the currently RUNNING
  /// timer is excluded either way (its growing `dateTo` exists only in
  /// memory until the timer stops).
  Future<List<RecordedSpan>> _recordedSpans({
    required DateTime anchor,
    required DateTime today,
  }) {
    final recordedEnd = anchor.isBefore(today) ? anchor : today;
    return _recordedSpansInRange(
      rangeStart: DateTime(
        anchor.year,
        anchor.month,
        anchor.day - weekContextLookbackDays,
      ),
      rangeEnd: DateTime(
        recordedEnd.year,
        recordedEnd.month,
        recordedEnd.day + 1,
      ),
    );
  }

  /// Shared recorded-time resolution for an arbitrary local-midnight range
  /// (containment query semantics — see [_recordedSpans] for the caveats).
  Future<List<RecordedSpan>> _recordedSpansInRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final entries = await journalDb.sortedCalendarEntries(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    final links = await journalDb.basicLinksForEntryIds(
      entries.map((entry) => entry.meta.id).toSet(),
    );
    final linkedFromIds = links.map((link) => link.fromId).toSet();
    final linkedFrom = linkedFromIds.isEmpty
        ? const <JournalEntity>[]
        : await journalDb.getJournalEntitiesForIdsUnordered(linkedFromIds);
    final resolved = resolveTimeEntries(
      entries: entries,
      links: links,
      linkedFromById: {
        for (final entity in linkedFrom) entity.meta.id: entity,
      },
    );
    return [
      for (final pair in resolved)
        RecordedSpan(
          categoryId: pair.categoryId,
          start: pair.start,
          duration: pair.duration,
          taskId: pair.taskId,
        ),
    ];
  }

  String? _resolveCategoryName(String categoryId) {
    final resolver = categoryNameResolver;
    if (resolver != null) return resolver(categoryId);
    if (!getIt.isRegistered<EntitiesCacheService>()) return null;
    return getIt<EntitiesCacheService>().getCategoryById(categoryId)?.name;
  }

  /// Recomputes and persists the weekly rollup registers the digest renders
  /// (ADR 0032 digest pooling): the last [recentWeekRollupCount] complete
  /// calendar weeks, coordinator-owned, keyed `week_rollup:<Monday>`.
  ///
  /// EVERY week is recomputed from source on every call — this is what makes
  /// the "plain LWW converges because every device recomputes" claim true:
  /// late-synced plans/time entries and an incomplete aggregate that won a
  /// concurrent-LWW race on another device both self-heal at the next
  /// digest, no dirty-tracking needed. The cost stays bounded by batching:
  /// one plan read and one recorded-time read span all
  /// [recentWeekRollupCount] weeks (see [_computeAggregatesForWeeks]), and
  /// a recompute whose aggregates match the stored register skips the write
  /// entirely (steady state writes nothing). A tombstoned register is a
  /// deliberate delete and is never resurrected. Fail-soft: any error logs
  /// and returns — rollups are advisory context, never worth killing a
  /// digest wake.
  Future<void> ensureWeekRollups({DateTime? now}) async {
    try {
      now ??= clock.now();
      final weekStarts = _recentCompleteWeekStarts(now);
      final existingById = await agentRepository.getEntitiesByIds({
        for (final weekStart in weekStarts) weekRollupEntityId(weekStart),
      });
      final aggregatesByWeek = await _computeAggregatesForWeeks(weekStarts);
      for (final weekStart in weekStarts) {
        final id = weekRollupEntityId(weekStart);
        final existing = existingById[id];
        if (existing is WeekRollupEntity && existing.deletedAt != null) {
          continue;
        }
        final prior = existing is WeekRollupEntity ? existing : null;
        final aggregates = aggregatesByWeek[weekStart]!;
        const equality = DeepCollectionEquality();
        if (prior != null &&
            prior.daysWithPlans == aggregates.daysWithPlans &&
            equality.equals(
              prior.plannedMinutesByCategory,
              aggregates.plannedMinutesByCategory,
            ) &&
            equality.equals(
              prior.recordedMinutesByCategory,
              aggregates.recordedMinutesByCategory,
            )) {
          continue;
        }
        final entity = prior != null
            ? prior.copyWith(
                plannedMinutesByCategory: aggregates.plannedMinutesByCategory,
                recordedMinutesByCategory: aggregates.recordedMinutesByCategory,
                daysWithPlans: aggregates.daysWithPlans,
                updatedAt: now,
              )
            : AgentDomainEntity.weekRollup(
                id: id,
                agentId: dailyOsPlannerAgentId,
                weekStart: weekStart,
                createdAt: now,
                updatedAt: now,
                vectorClock: null,
                plannedMinutesByCategory: aggregates.plannedMinutesByCategory,
                recordedMinutesByCategory: aggregates.recordedMinutesByCategory,
                daysWithPlans: aggregates.daysWithPlans,
              );
        await syncService.upsertEntity(entity);
      }
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        message: 'failed to ensure week rollups',
        stackTrace: s,
      );
    }
  }

  /// Loads the persisted rollups for the last [recentWeekRollupCount]
  /// complete weeks, newest first. Fail-soft: errors log and return an empty
  /// list so the digest simply omits `<recent_weeks>`.
  Future<List<WeekRollupEntity>> recentWeekRollups({DateTime? now}) async {
    try {
      now ??= clock.now();
      final byId = await agentRepository.getEntitiesByIds({
        for (final weekStart in _recentCompleteWeekStarts(now))
          weekRollupEntityId(weekStart),
      });
      return <WeekRollupEntity>[
        for (final entity in byId.values)
          if (entity is WeekRollupEntity && entity.deletedAt == null) entity,
      ]..sort((a, b) => b.weekStart.compareTo(a.weekStart));
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        message: 'failed to load week rollups',
        stackTrace: s,
      );
      return const [];
    }
  }

  /// The rendered `<recent_weeks>` JSON body — [recentWeekRollups] passed
  /// through [renderRecentWeeksJson] with this service's category-name
  /// resolution (test-overridable via [categoryNameResolver]). Null when no
  /// rollups exist so the prompt section is omitted.
  Future<List<Map<String, Object?>>?> recentWeeksJson({DateTime? now}) async =>
      renderRecentWeeksJson(
        rollups: await recentWeekRollups(now: now),
        categoryName: _resolveCategoryName,
      );

  /// Mondays of the last [recentWeekRollupCount] COMPLETE weeks (strictly
  /// before the week containing [now]), newest first.
  List<DateTime> _recentCompleteWeekStarts(DateTime now) {
    final currentWeekStart = weekStartFor(now);
    return [
      for (var back = 1; back <= recentWeekRollupCount; back++)
        DateTime(
          currentWeekStart.year,
          currentWeekStart.month,
          currentWeekStart.day - 7 * back,
        ),
    ];
  }

  /// Computes every week's pooled aggregates in TWO batch reads spanning
  /// all [weekStarts] (assumed consecutive, newest first): one
  /// deterministic-id plan fetch (same ownership filter as [buildForDay])
  /// and one recorded-time range resolution, bucketed per week afterwards.
  /// A per-week read loop would multiply both queries by
  /// [recentWeekRollupCount] every digest for identical results.
  Future<
    Map<
      DateTime,
      ({
        int daysWithPlans,
        Map<String, int> plannedMinutesByCategory,
        Map<String, int> recordedMinutesByCategory,
      })
    >
  >
  _computeAggregatesForWeeks(List<DateTime> weekStarts) async {
    final weekByPlanId = <String, DateTime>{};
    for (final weekStart in weekStarts) {
      for (var offset = 0; offset < DateTime.daysPerWeek; offset++) {
        final day = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + offset,
        );
        weekByPlanId[dayAgentPlanEntityId(dayPlanId(day))] = weekStart;
      }
    }
    final entitiesById = await agentRepository.getEntitiesByIds(
      weekByPlanId.keys,
    );
    final plansByWeek = <DateTime, List<DayPlanEntity>>{};
    for (final entry in entitiesById.entries) {
      final entity = entry.value;
      if (entity is DayPlanEntity &&
          isDailyOsDayOwner(entity.agentId) &&
          entity.deletedAt == null) {
        plansByWeek.putIfAbsent(weekByPlanId[entry.key]!, () => []).add(entity);
      }
    }

    final oldest = weekStarts.last;
    final newest = weekStarts.first;
    final spans = await _recordedSpansInRange(
      rangeStart: oldest,
      rangeEnd: DateTime(
        newest.year,
        newest.month,
        newest.day + DateTime.daysPerWeek,
      ),
    );
    final spansByWeek = <DateTime, List<RecordedSpan>>{};
    for (final span in spans) {
      spansByWeek.putIfAbsent(weekStartFor(span.start), () => []).add(span);
    }

    return {
      for (final weekStart in weekStarts)
        weekStart: computeWeekRollupAggregates(
          dayPlans: plansByWeek[weekStart] ?? const [],
          recordedSpans: spansByWeek[weekStart] ?? const [],
        ),
    };
  }

  /// Executes a week-context tool emitted by the agent.
  Future<DayAgentDirectToolResult> executeTool({
    required String agentId,
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    try {
      final data = switch (toolName) {
        DayAgentToolNames.writeDaySummary => await _writeDaySummary(
          agentId,
          args,
        ),
        _ => throw DayAgentWeekContextException('unknown tool "$toolName"'),
      };
      return DayAgentDirectToolResult.success(data);
    } on DayAgentWeekContextException catch (e) {
      return DayAgentDirectToolResult.failure(e.message);
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        message: 'week-context tool failed',
        stackTrace: s,
      );
      return DayAgentDirectToolResult.failure(e.toString());
    }
  }

  /// Persists the contemporaneous day summary for `args.dayId`.
  ///
  /// The writable window is anchored to the WALL CLOCK, independent of the
  /// wake's plan date (the ADR-governed exception to the workspace-day tool
  /// guard): `dayId ∈ {today, yesterday}`. Future days are rejected (no
  /// testimony for unhappened days); anything older than yesterday is
  /// rejected (stale-device wakes must not overwrite genuine testimony).
  /// Within the window the write UPSERTS the day's single register —
  /// preserving the original `createdAt`, which the earliest-createdAt-wins
  /// conflict rule treats as the testimony's canonical creation moment.
  /// Days with no wake inside their window keep a permanent hole; accepted.
  Future<Map<String, Object?>> _writeDaySummary(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final dayId = _requireString(args, 'dayId');
    final rawText = _requireString(args, 'text');
    final text = collapseToSingleLine(rawText);
    if (text.isEmpty) {
      throw const DayAgentWeekContextException(
        '"text" must not be empty after whitespace normalization.',
      );
    }
    if (text.length > daySummaryMaxChars) {
      throw DayAgentWeekContextException(
        '"text" exceeds $daySummaryMaxChars characters '
        '(${text.length}). Write one tight paragraph.',
      );
    }

    final now = clock.now();
    final today = localDay(now);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    if (dayId != dayPlanId(today) && dayId != dayPlanId(yesterday)) {
      // No 'Error: ' prefix — DayAgentDirectToolResult.failure adds it.
      throw DayAgentWeekContextException(
        'day summaries can only be written for today '
        '(${dayPlanId(today)}) or yesterday (${dayPlanId(yesterday)}); '
        'got "$dayId".',
      );
    }

    final id = dayAgentSummaryEntityId(dayId);
    final existing = await agentRepository.getEntity(id);
    final priorSummary = existing is DaySummaryEntity ? existing : null;
    final prior = priorSummary != null && priorSummary.deletedAt == null
        ? priorSummary
        : null;
    final entity = prior != null
        ? prior.copyWith(
            agentId: agentId,
            text: text,
            updatedAt: now,
          )
        : AgentDomainEntity.daySummary(
            id: id,
            agentId: agentId,
            dayId: dayId,
            text: text,
            createdAt: now,
            updatedAt: now,
            // Seed from a tombstoned prior register (if any) so the sync
            // layer's next-clock stamp causally DOMINATES the tombstone:
            // judged concurrent instead, the earliest-createdAt rule would
            // let the tombstone win on peers while this device keeps the
            // rewrite — permanent divergence.
            vectorClock: priorSummary?.vectorClock,
          );
    await syncService.upsertEntity(entity);
    onPersistedStateChanged?.call(agentId);
    return {
      'dayId': dayId,
      'updated': prior != null,
    };
  }

  static String _requireString(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty) {
      throw DayAgentWeekContextException('"$key" must be a non-empty string.');
    }
    return value.trim();
  }
}
