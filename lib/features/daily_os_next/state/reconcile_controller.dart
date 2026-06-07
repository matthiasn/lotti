// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
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
    .family<ReconcileController, ReconcileData, ReconcileParams>(
      ReconcileController.new,
    );

@immutable
class ReconcileParams {
  ReconcileParams({
    required this.captureId,
    required DateTime dayDate,
  }) : dayDate = DateTime(dayDate.year, dayDate.month, dayDate.day);

  final CaptureId captureId;
  final DateTime dayDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReconcileParams &&
          captureId == other.captureId &&
          dayDate == other.dayDate;

  @override
  int get hashCode => Object.hash(captureId, dayDate);
}

final reconcileCaptureUpdateProvider = StreamProvider.autoDispose
    .family<Set<String>, String>((ref, captureId) {
      final notifications = ref.watch(maybeUpdateNotificationsProvider);
      if (notifications == null) return const Stream<Set<String>>.empty();
      return notifications.updateStream.where((ids) => ids.contains(captureId));
    });

/// Backs the Reconcile screen.
///
/// On first build, fans out `parseCaptureToItems` and
/// `surfacePendingDecisions` in parallel and exposes the merged
/// snapshot. Triage actions and link-breaks flow through the same
/// [DayAgentInterface] so the path matches what the real agent layer
/// will use later.
class ReconcileController extends AsyncNotifier<ReconcileData> {
  ReconcileController(this.params);

  final ReconcileParams params;
  late DayAgentInterface _agent;

  @override
  Future<ReconcileData> build() async {
    _agent = ref.watch(dayAgentProvider);
    final preferences = ref.watch(dailyOsPreferencesControllerProvider);
    // When the capture-submitted parse wake finishes (running true → false),
    // re-read so the Heard column fills in even if the per-capture update
    // notification doesn't carry the capture id. Uses `listen` (not `watch`)
    // so the signal's intermediate emissions don't re-run — and abort — the
    // initial parse build.
    ref
      ..watch(reconcileCaptureUpdateProvider(params.captureId.value))
      ..listen(agentIsRunningProvider(dayAgentIdForDate(params.dayDate)), (
        previous,
        next,
      ) {
        final wasRunning = previous?.value ?? false;
        final isRunning = next.value ?? false;
        if (wasRunning && !isRunning) ref.invalidateSelf();
      });
    final triageDecisions =
        state.value?.triageDecisions ?? const <String, TriageResult>{};
    final parsedFuture = _agent.parseCaptureToItems(params.captureId);
    final pendingFuture = _agent.surfacePendingDecisions(
      forDate: params.dayDate,
    );
    final parsed = await parsedFuture;
    final pending = await pendingFuture;
    return ReconcileData(
      parsed: [
        for (final item in parsed)
          if (preferences.allowsCategory(item.category)) item,
      ],
      pending: [
        for (final item in pending)
          if (preferences.allowsCategory(item.category)) item,
      ],
      triageDecisions: triageDecisions,
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
