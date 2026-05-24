// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';

/// Atomic snapshot used by the Reconcile screen.
///
/// `parsed` and `pending` are the two columns. `triageDecisions` is a
/// per-task lookup the UI consults to dim cards and render the
/// "Today" / "Done now" / "Deferred" / "Dropped" confirmation pill
/// that replaces the action row once a decision is made.
@immutable
class ReconcileData {
  const ReconcileData({
    required this.parsed,
    required this.pending,
    required this.triageDecisions,
  });

  final List<ParsedItem> parsed;
  final List<PendingItem> pending;
  final Map<String, TriageResult> triageDecisions;

  ReconcileData copyWith({
    List<ParsedItem>? parsed,
    List<PendingItem>? pending,
    Map<String, TriageResult>? triageDecisions,
  }) {
    return ReconcileData(
      parsed: parsed ?? this.parsed,
      pending: pending ?? this.pending,
      triageDecisions: triageDecisions ?? this.triageDecisions,
    );
  }
}

final reconcileControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ReconcileController, ReconcileData, CaptureId>(
      ReconcileController.new,
    );

/// Backs the Reconcile screen.
///
/// On first build, fans out `parseCaptureToItems` and
/// `surfacePendingDecisions` in parallel and exposes the merged
/// snapshot. Triage actions and link-breaks flow through the same
/// [DayAgentInterface] so the path matches what the real agent layer
/// will use later.
class ReconcileController extends AsyncNotifier<ReconcileData> {
  ReconcileController(this.captureId);

  final CaptureId captureId;
  late DayAgentInterface _agent;

  @override
  Future<ReconcileData> build() async {
    _agent = ref.watch(dayAgentProvider);
    final parsedFuture = _agent.parseCaptureToItems(captureId);
    final pendingFuture = _agent.surfacePendingDecisions();
    final parsed = await parsedFuture;
    final pending = await pendingFuture;
    return ReconcileData(
      parsed: parsed,
      pending: pending,
      triageDecisions: const {},
    );
  }

  /// Apply a triage action against either a pending item or a parsed
  /// NEW card (both flow through the same `apply_triage` tool).
  Future<void> triage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async {
    final current = state.value;
    if (current == null) return;
    final result = await _agent.applyTriage(
      taskId: taskId,
      action: action,
      deferTo: deferTo,
    );
    state = AsyncData(
      current.copyWith(
        triageDecisions: {
          ...current.triageDecisions,
          taskId: result,
        },
      ),
    );
  }

  /// Break the link between a matched parsed card and its task.
  /// The card downgrades to a NEW-task card in place.
  Future<void> breakLink(String parsedItemId) async {
    final current = state.value;
    if (current == null) return;
    final updated = await _agent.breakCaptureLink(parsedItemId);
    state = AsyncData(
      current.copyWith(
        parsed: [
          for (final item in current.parsed)
            if (item.id == parsedItemId) updated else item,
        ],
      ),
    );
  }
}
