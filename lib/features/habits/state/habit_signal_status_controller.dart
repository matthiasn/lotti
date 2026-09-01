import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:lotti/logic/signals/signal_day_buckets.dart';
import 'package:lotti/logic/signals/signal_needs.dart';
import 'package:lotti/logic/signals/signal_reader.dart';
import 'package:lotti/logic/signals/signal_window.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// What a habit's signals look like today: the two-week window the sheet
/// draws its sparklines from and the verdict its status pills come from.
///
/// Built from the same reader and evaluator the auto-completion engine uses,
/// so the sheet and the engine cannot disagree about "done".
@immutable
class HabitSignalStatus {
  const HabitSignalStatus({
    required this.rule,
    required this.window,
    required this.verdict,
    required this.today,
  });

  final AutoCompleteRule rule;
  final SignalWindow window;
  final HabitRuleVerdict verdict;

  /// Day key of the evaluated day.
  final DateTime today;

  /// The window's days oldest-first, ending on [today].
  List<DateTime> get days => [
    for (var i = 0; i <= window.end.difference(window.start).inDays; i++)
      window.start.add(Duration(days: i)),
  ];
}

/// Per-habit signal status; `null` when the habit has no rule.
final AsyncNotifierProviderFamily<
  HabitSignalStatusController,
  HabitSignalStatus?,
  String
>
habitSignalStatusProvider = AsyncNotifierProvider.autoDispose
    .family<HabitSignalStatusController, HabitSignalStatus?, String>(
      HabitSignalStatusController.new,
    );

/// Loads a habit's [HabitSignalStatus] and refreshes it in place — never
/// back through a loading state — when a journal write touches one of the
/// series its rule reads.
class HabitSignalStatusController extends AsyncNotifier<HabitSignalStatus?> {
  HabitSignalStatusController(this.habitId);

  final String habitId;
  StreamSubscription<Set<String>>? _subscription;

  @override
  Future<HabitSignalStatus?> build() async {
    ref.onDispose(() => _subscription?.cancel());
    final habit = getIt<EntitiesCacheService>().getHabitById(habitId);
    final rule = habit?.autoCompleteRule;
    if (rule == null) return null;

    final tokens = SignalNeeds.of(rule).notificationTokens;
    _subscription = getIt<UpdateNotifications>().updateStream.listen((
      affectedIds,
    ) {
      if (tokens.intersection(affectedIds).isNotEmpty) unawaited(refresh());
    });
    return _load(rule);
  }

  /// Re-reads the window and re-evaluates, keeping the last value on screen
  /// until the new one is in.
  Future<void> refresh() async {
    final habit = getIt<EntitiesCacheService>().getHabitById(habitId);
    final rule = habit?.autoCompleteRule;
    if (rule == null) {
      state = const AsyncData(null);
      return;
    }
    state = AsyncData(await _load(rule));
  }

  Future<HabitSignalStatus> _load(AutoCompleteRule rule) async {
    final now = clock.now();
    final cache = getIt<EntitiesCacheService>();
    final normalizedRule = normalizeChoiceMeasurableBounds(
      rule,
      isChoice: (dataTypeId) =>
          cache.getDataTypeById(dataTypeId)?.isChoice ?? false,
    );
    final reader = SignalReader(journalDb: getIt<JournalDb>());
    final window = await reader.read(rule: normalizedRule, reference: now);
    final verdict = const HabitRuleEvaluator().evaluate(
      rule: normalizedRule,
      window: window,
      day: now,
    );
    return HabitSignalStatus(
      rule: normalizedRule,
      window: window,
      verdict: verdict,
      today: signalDayKey(now),
    );
  }
}
