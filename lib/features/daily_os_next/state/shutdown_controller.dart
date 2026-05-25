// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';

/// Snapshot the Shutdown screen renders against.
@immutable
class ShutdownData {
  const ShutdownData({
    required this.completed,
    required this.carryover,
    required this.metrics,
    required this.tomorrowNote,
    required this.decisions,
  });

  final List<CompletedItem> completed;
  final List<CarryoverItem> carryover;
  final ShutdownMetrics metrics;
  final TomorrowNote tomorrowNote;

  /// Map of taskId → action the user already took on a carryover row.
  /// Used to dim decided rows + render a confirmation chip.
  final Map<String, CarryoverAction> decisions;

  ShutdownData copyWith({
    List<CompletedItem>? completed,
    List<CarryoverItem>? carryover,
    ShutdownMetrics? metrics,
    TomorrowNote? tomorrowNote,
    Map<String, CarryoverAction>? decisions,
  }) {
    return ShutdownData(
      completed: completed ?? this.completed,
      carryover: carryover ?? this.carryover,
      metrics: metrics ?? this.metrics,
      tomorrowNote: tomorrowNote ?? this.tomorrowNote,
      decisions: decisions ?? this.decisions,
    );
  }
}

/// Loads Shutdown data + applies user actions through the day agent.
class ShutdownController extends AsyncNotifier<ShutdownData> {
  ShutdownController(this.forDate);

  final DateTime forDate;
  late DayAgentInterface _agent;

  @override
  Future<ShutdownData> build() async {
    _agent = ref.watch(dayAgentProvider);
    final results = await Future.wait<Object>([
      _agent.surfaceShutdownData(forDate: forDate),
      _agent.generateTomorrowNote(forDate: forDate),
    ]);
    final bundle =
        results[0]
            as ({
              List<CompletedItem> completed,
              List<CarryoverItem> carryover,
              ShutdownMetrics metrics,
            });
    final note = results[1] as TomorrowNote;
    return ShutdownData(
      completed: bundle.completed,
      carryover: bundle.carryover,
      metrics: bundle.metrics,
      tomorrowNote: note,
      decisions: const {},
    );
  }

  Future<void> applyCarryover({
    required String taskId,
    required CarryoverAction action,
  }) async {
    final current = state.value;
    if (current == null) return;
    await _agent.recordCarryoverDecision(taskId: taskId, action: action);
    state = AsyncData(
      current.copyWith(
        decisions: {...current.decisions, taskId: action},
      ),
    );
  }

  Future<void> submitReflection({
    required String text,
    required ReflectionSource source,
  }) async {
    await _agent.recordReflection(
      forDate: forDate,
      text: text,
      source: source,
    );
  }
}

final shutdownControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ShutdownController, ShutdownData, DateTime>(
      ShutdownController.new,
    );
