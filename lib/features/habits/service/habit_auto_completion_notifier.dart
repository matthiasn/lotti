import 'dart:async';

import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/habits/service/habit_auto_completion_service.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/device_messages.dart';
import 'package:lotti/services/domain_logging.dart';

/// Turns the engine's completions into one notification per batch.
///
/// A health import can complete several habits within a second of each
/// other; the user should hear about that once. Completions are collected for
/// [groupingWindow] after the first one and then written as a single durable
/// inbox row through [NotificationRepository], which projects it to an OS
/// banner on write — so desktop gets the bell and mobile gets both.
///
/// Habits whose `autoCompleteNotify` is off are dropped before grouping.
/// Copy is baked in the device locale at write time, like every other inbox
/// row (see the notifications concept, "Copy is baked, not composed").
class HabitAutoCompletionNotifier {
  HabitAutoCompletionNotifier({
    required this._service,
    required this._notifications,
    required this._logger,
    AppLocalizations Function()? messages,
    this.groupingWindow = const Duration(seconds: 3),
  }) : _messages = messages ?? deviceMessages;

  final HabitAutoCompletionService _service;
  final NotificationRepository _notifications;
  final DomainLogger _logger;
  final AppLocalizations Function() _messages;

  /// How long after the first completion of a batch to wait for more.
  final Duration groupingWindow;

  /// How many times a failed batch is retried before it is dropped. The
  /// engine never emits a completion twice (the habit day is occupied), so a
  /// batch lost here is lost for good — hence the retries.
  static const maxWriteAttempts = 5;

  final _pending = <HabitAutoCompletion>[];
  final _attempts = <String, int>{};
  StreamSubscription<HabitAutoCompletion>? _subscription;
  Timer? _flushTimer;

  void start() {
    _subscription ??= _service.completions.listen(_onCompletion);
  }

  void _onCompletion(HabitAutoCompletion completion) {
    if (!completion.habit.autoCompleteNotify) return;
    _pending.add(completion);
    _flushTimer ??= Timer(groupingWindow, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  /// Writes the pending batch. Completions for different days (a late import
  /// for yesterday next to today's) become separate rows so each can say
  /// which day it counted for.
  Future<void> flush() async {
    if (_pending.isEmpty) return;
    final batch = [..._pending];
    _pending.clear();
    final byDay = <DateTime, List<HabitAutoCompletion>>{};
    for (final completion in batch) {
      byDay.putIfAbsent(completion.day, () => []).add(completion);
    }
    for (final entry in byDay.entries) {
      try {
        await _write(entry.key, entry.value);
        for (final completion in entry.value) {
          _attempts.remove(completion.entry.meta.id);
        }
      } catch (error, stackTrace) {
        _logger.error(
          LogDomain.habits,
          error,
          stackTrace: stackTrace,
          subDomain: 'autoCompletion.notify',
        );
        _requeue(entry.value);
      }
    }
  }

  /// Puts a batch whose write failed back in line for the next flush, giving
  /// up on a completion after [maxWriteAttempts] tries.
  void _requeue(List<HabitAutoCompletion> group) {
    if (_subscription == null) return; // disposed
    for (final completion in group) {
      final attempts = (_attempts[completion.entry.meta.id] ?? 0) + 1;
      if (attempts >= maxWriteAttempts) {
        _attempts.remove(completion.entry.meta.id);
        continue;
      }
      _attempts[completion.entry.meta.id] = attempts;
      _pending.add(completion);
    }
    if (_pending.isNotEmpty) {
      _flushTimer ??= Timer(groupingWindow, () {
        _flushTimer = null;
        unawaited(flush());
      });
    }
  }

  Future<void> _write(DateTime day, List<HabitAutoCompletion> group) async {
    final messages = _messages();
    final now = clock.now();
    final dayKey = DateFormat('yyyy-MM-dd').format(day);
    final String title;
    final String body;
    if (group.length == 1) {
      final only = group.single;
      final signal = only.entry.data.autoCompleteReason ?? '';
      title = messages.habitAutoCompletedTitle(only.habit.name);
      body = only.isLate(now)
          ? messages.habitAutoCompletedLateBody(
              signal,
              DateFormat.EEEE().format(day),
            )
          : messages.habitAutoCompletedBody(signal);
    } else {
      title = messages.habitAutoCompletedGroupTitle(group.length);
      body = group.map((completion) => completion.habit.name).join(', ');
    }
    await _notifications.createHabitAutoCompletion(
      linkedHabitIds: group.map((completion) => completion.habit.id).toList(),
      dayKey: dayKey,
      title: title,
      body: body,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    _attempts.clear();
  }
}
