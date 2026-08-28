import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:lotti/logic/signals/signal_day_buckets.dart';
import 'package:lotti/logic/signals/signal_needs.dart';
import 'package:lotti/logic/signals/signal_reader.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// One completion the engine wrote, for the notification layer and the UI.
@immutable
class HabitAutoCompletion {
  const HabitAutoCompletion({
    required this.habit,
    required this.entry,
    required this.day,
    required this.verdict,
  });

  final HabitDefinition habit;
  final HabitCompletionEntry entry;

  /// The calendar day the completion counts for (midnight-UTC day key).
  final DateTime day;
  final HabitRuleVerdict verdict;

  /// Whether the completion landed on a day before the current one — a late
  /// import counted for yesterday, which the notification words differently.
  bool isLate(DateTime now) => day.isBefore(signalDayKey(now));
}

/// Checks habits off from recorded data.
///
/// Every active habit with an `autoCompleteRule` is a candidate. The service
/// listens to the journal's update stream, and when a write touches a series
/// one of those rules reads (a measurable id, a health data type, a workout
/// type or another habit's id — the same tokens `JournalEntity.affectedIds`
/// emits, locally or from sync), it debounces briefly and re-evaluates the
/// affected habits for today and yesterday, so an import that lands after
/// midnight still counts for the day it belongs to.
///
/// Invariants:
/// - **A day with any completion is never touched.** The latest-per-day
///   entry — manual success, an explicit skip, or an earlier auto
///   completion — wins; the engine only ever fills an empty day. That is what
///   makes "manual beats auto" and "skip beats data" hold, and what breaks
///   the feedback loop of its own writes (which emit the habit's id).
/// - Completions are written through [PersistenceLogic] like manual ones,
///   with [HabitCompletionSource.auto] and a reason naming the leaf that
///   fired, so they sync and resolve exactly as user entries do.
///
/// Consumers observe [completions]; [autoCompletedToday] lists what this
/// instance wrote today (the persisted, sync-aware view is
/// `HabitsState.autoCompletedToday`).
class HabitAutoCompletionService {
  HabitAutoCompletionService({
    required JournalDb journalDb,
    required this._persistenceLogic,
    required this._updateNotifications,
    required this._entitiesCache,
    required this._logger,
    SignalReader? signalReader,
    this.evaluator = const HabitRuleEvaluator(),
    this.debounce = const Duration(seconds: 2),
  }) : _journalDb = journalDb,
       _signalReader = signalReader ?? SignalReader(journalDb: journalDb);

  final JournalDb _journalDb;
  final PersistenceLogic _persistenceLogic;
  final UpdateNotifications _updateNotifications;
  final EntitiesCacheService _entitiesCache;
  final DomainLogger _logger;
  final SignalReader _signalReader;
  final HabitRuleEvaluator evaluator;

  /// How long to wait after the last relevant write before evaluating, so a
  /// health import of many samples runs the rules once.
  final Duration debounce;

  final _completions = StreamController<HabitAutoCompletion>.broadcast();
  final _pendingHabitIds = <String>{};
  final _autoCompletedToday = <String>{};
  DateTime? _autoCompletedDay;

  StreamSubscription<Set<String>>? _subscription;
  Timer? _debounceTimer;
  Timer? _midnightTimer;
  Future<void>? _inFlight;
  bool _disposed = false;

  /// Every completion the engine writes, in write order.
  Stream<HabitAutoCompletion> get completions => _completions.stream;

  /// Ids of habits the engine completed for the current day. Resets when the
  /// day changes.
  Set<String> get autoCompletedToday {
    final today = signalDayKey(clock.now());
    if (_autoCompletedDay != today) {
      _autoCompletedToday.clear();
      _autoCompletedDay = today;
    }
    return Set.unmodifiable(_autoCompletedToday);
  }

  /// Subscribes to journal updates, schedules the midnight pass and runs an
  /// initial pass so a day that already has the data is checked off on
  /// launch.
  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = _updateNotifications.updateStream.listen(_onUpdate);
    _scheduleMidnightPass();
    unawaited(evaluateAll());
  }

  /// Evaluates every candidate habit for today and yesterday. Runs are
  /// serialised: a call while one is in flight waits for it.
  Future<void> evaluateAll() => _run(null);

  Future<void> _onUpdateAsync(Set<String> affectedIds) async {
    final candidates = await _candidates();
    if (candidates.isEmpty) return;
    var touched = false;
    for (final habit in candidates) {
      final needs = SignalNeeds.of(habit.autoCompleteRule!);
      final tokens = {
        ...needs.measurableIds,
        ...needs.quantitativeTypes,
        ...needs.workoutTypes,
        ...needs.habitIds,
      };
      if (tokens.intersection(affectedIds).isNotEmpty) {
        _pendingHabitIds.add(habit.id);
        touched = true;
      }
    }
    if (!touched) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      _debounceTimer = null;
      final ids = {..._pendingHabitIds};
      _pendingHabitIds.clear();
      unawaited(_run(ids));
    });
  }

  void _onUpdate(Set<String> affectedIds) {
    if (_disposed) return;
    unawaited(
      _onUpdateAsync(affectedIds).catchError((Object error, StackTrace stack) {
        _logger.error(
          LogDomain.habits,
          error,
          stackTrace: stack,
          subDomain: 'autoCompletion.onUpdate',
        );
      }),
    );
  }

  Future<void> _run(Set<String>? onlyHabitIds) async {
    if (_disposed) return;
    final previous = _inFlight;
    final completer = Completer<void>();
    _inFlight = completer.future;
    try {
      if (previous != null) await previous;
      final habits = await _candidates();
      final now = clock.now();
      final today = signalDayKey(now);
      final yesterday = today.subtract(const Duration(days: 1));
      for (final habit in habits) {
        if (onlyHabitIds != null && !onlyHabitIds.contains(habit.id)) continue;
        if (_disposed) return;
        for (final day in [yesterday, today]) {
          await _evaluateDay(habit, day, now);
        }
      }
    } catch (error, stack) {
      _logger.error(
        LogDomain.habits,
        error,
        stackTrace: stack,
        subDomain: 'autoCompletion.run',
      );
    } finally {
      completer.complete();
    }
  }

  Future<List<HabitDefinition>> _candidates() async {
    final all = await _journalDb.getAllHabitDefinitions();
    return all
        .where(
          (habit) =>
              habit.active &&
              habit.deletedAt == null &&
              habit.autoCompleteRule != null,
        )
        .toList(growable: false);
  }

  Future<void> _evaluateDay(
    HabitDefinition habit,
    DateTime day,
    DateTime now,
  ) async {
    final rule = habit.autoCompleteRule!;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    // Anything already recorded for the day — manual, skip, or an earlier
    // auto completion — wins; the engine only fills empty days.
    final existing = await _journalDb.getHabitCompletionsByHabitId(
      habitId: habit.id,
      rangeStart: dayStart,
      rangeEnd: dayEnd,
    );
    if (existing.isNotEmpty || _disposed) return;

    // A past day is evaluated at its last instant so nothing of it is
    // clipped; today is evaluated as of now.
    final reference = day == signalDayKey(now)
        ? now
        : dayEnd.subtract(const Duration(milliseconds: 1));
    final window = await _signalReader.read(
      rule: rule,
      reference: reference,
      days: 1,
    );
    final verdict = evaluator.evaluate(rule: rule, window: window, day: day);
    // Re-checked after every await: a profile switch or shutdown that
    // disposed the service mid-read must not write through a PersistenceLogic
    // that may already belong to the next generation, nor add to a closed
    // stream.
    if (!verdict.satisfied || _disposed) return;

    final data = HabitCompletionData(
      dateFrom: reference,
      dateTo: reference,
      habitId: habit.id,
      completionType: HabitCompletionType.success,
      source: HabitCompletionSource.auto,
      autoCompleteReason: describeReason(verdict),
    );
    final entry = await _persistenceLogic.createHabitCompletionEntry(
      data: data,
      habitDefinition: habit,
    );
    if (entry == null || _disposed) return;
    if (day == signalDayKey(now)) {
      autoCompletedToday; // roll the day if needed
      _autoCompletedToday.add(habit.id);
    }
    _completions.add(
      HabitAutoCompletion(
        habit: habit,
        entry: entry,
        day: day,
        verdict: verdict,
      ),
    );
  }

  /// Names the satisfied leaves, e.g. `Steps · 7412` or `Running`, joined
  /// with ` · ` when several fired. Stored on the entry so the habit row can
  /// say what checked it off without re-reading the journal.
  @visibleForTesting
  String describeReason(HabitRuleVerdict verdict) {
    final parts = <String>[];
    for (final leaf in verdict.satisfiedLeaves) {
      final measurable = switch (leaf.rule) {
        AutoCompleteRuleMeasurable(:final dataTypeId) =>
          _entitiesCache.getDataTypeById(dataTypeId),
        _ => null,
      };
      // A choice measurable's day value is an occurrence count, not something
      // the user would recognise as "what checked it off"; its name alone is
      // the reason.
      final showValue = !(measurable?.isChoice ?? false);
      final name = switch (leaf.rule) {
        AutoCompleteRuleMeasurable(:final dataTypeId, :final title) =>
          title ?? measurable?.displayName ?? dataTypeId,
        AutoCompleteRuleHealth(:final dataType, :final title) =>
          title ?? healthTypes[dataType]?.displayName ?? dataType,
        AutoCompleteRuleWorkout(:final dataType, :final title) =>
          title ?? dataType,
        AutoCompleteRuleHabit(:final habitId, :final title) =>
          title ?? _entitiesCache.getHabitById(habitId)?.name ?? habitId,
        AutoCompleteRuleAnd() ||
        AutoCompleteRuleOr() ||
        AutoCompleteRuleMultiple() => null,
      };
      if (name == null) continue;
      final value = leaf.value;
      parts.add(
        value == null || !showValue ? name : '$name · ${_formatValue(value)}',
      );
    }
    return parts.join(' · ');
  }

  static String _formatValue(num value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  void _scheduleMidnightPass() {
    _midnightTimer?.cancel();
    final now = clock.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    // A hair past midnight so `clock.now()` is already on the new day.
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (_disposed) return;
        unawaited(evaluateAll());
        _scheduleMidnightPass();
      },
    );
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    _debounceTimer?.cancel();
    _midnightTimer?.cancel();
    _completions.close();
  }
}
