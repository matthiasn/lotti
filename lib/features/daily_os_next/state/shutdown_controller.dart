// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';

/// What the user chose for one carryover row: the action, and the day the
/// task was moved to (null when it was dropped).
typedef CarryoverDecision = ({CarryoverAction action, DateTime? movedTo});

/// Snapshot the Shutdown screen renders against.
@immutable
class ShutdownData {
  const ShutdownData({
    required this.completed,
    required this.carryover,
    required this.metrics,
    required this.decisions,
  });

  final List<CompletedItem> completed;
  final List<CarryoverItem> carryover;
  final ShutdownMetrics metrics;

  /// Decisions taken during this visit, keyed by task id, so decided rows
  /// dim and show what happened. A decided task leaves the carryover list on
  /// the next load — it is no longer open for the day.
  final Map<String, CarryoverDecision> decisions;

  ShutdownData copyWith({Map<String, CarryoverDecision>? decisions}) {
    return ShutdownData(
      completed: completed,
      carryover: carryover,
      metrics: metrics,
      decisions: decisions ?? this.decisions,
    );
  }
}

/// Loads a day's Shutdown facts and applies the user's actions through the
/// day agent.
class ShutdownController extends AsyncNotifier<ShutdownData> {
  ShutdownController(this.forDate);

  final DateTime forDate;
  late DayAgentInterface _agent;

  @override
  Future<ShutdownData> build() async {
    _agent = ref.watch(dayAgentProvider);
    final bundle = await _agent.surfaceShutdownData(forDate: forDate);
    return ShutdownData(
      completed: bundle.completed,
      carryover: bundle.carryover,
      metrics: bundle.metrics,
      decisions: const {},
    );
  }

  /// Re-places or drops the carryover task [taskId]; [when] is the picked
  /// day for [CarryoverAction.pickDate]. Throws when the write fails, so the
  /// row stays undecided.
  Future<void> applyCarryover({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {
    final current = state.value;
    if (current == null) return;
    await _agent.recordCarryoverDecision(
      forDate: forDate,
      taskId: taskId,
      action: action,
      when: when,
    );
    final suggested = current.carryover
        .firstWhere((item) => item.taskId == taskId)
        .suggestedDate;
    final movedTo = switch (action) {
      CarryoverAction.tomorrow => suggested,
      CarryoverAction.pickDate => when,
      CarryoverAction.drop => null,
    };
    state = AsyncData(
      current.copyWith(
        decisions: {
          ...current.decisions,
          taskId: (action: action, movedTo: movedTo),
        },
      ),
    );
  }

  /// Appends a typed reflection to the day's reflection entry.
  Future<void> submitReflection(String text) =>
      _agent.recordReflection(forDate: forDate, text: text);

  /// The day's reflection entry, created when missing — the parent a spoken
  /// reflection is recorded under.
  Future<String> ensureReflectionEntry() =>
      _agent.ensureReflectionEntry(forDate: forDate);
}

final shutdownControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ShutdownController, ShutdownData, DateTime>(
      ShutdownController.new,
    );

/// The "For tomorrow" note, loaded on its own so a failed or slow note never
/// takes the rest of Shutdown down with it. Refreshing it after the user's
/// decisions writes a new note only when the facts changed.
final shutdownTomorrowNoteProvider = FutureProvider.autoDispose
    .family<TomorrowNote, DateTime>(
      (ref, forDate) =>
          ref.watch(dayAgentProvider).generateTomorrowNote(forDate: forDate),
    );
