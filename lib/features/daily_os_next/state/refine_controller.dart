// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';

/// Discrete phases the Refine screen passes through.
enum RefinePhase {
  /// Initial state — the screen shows the current plan unchanged
  /// with the voice button armed.
  idle,

  /// User tapped the voice button; transcript streams in.
  listening,

  /// Transcript captured; the agent is producing a `PlanDiff`.
  thinking,

  /// Diff returned; the timeline shows the proposed plan with pings,
  /// the right column shows the diff rows + Revert / Keep talking /
  /// Accept buttons.
  diffReady,

  /// User accepted the diff; the controller hands the new plan back
  /// to the caller and pops the screen.
  accepted,
}

@immutable
class RefineState {
  const RefineState({
    required this.phase,
    required this.transcript,
    required this.currentPlan,
    this.diff,
  });

  final RefinePhase phase;
  final String transcript;
  final DraftPlan currentPlan;
  final PlanDiff? diff;

  RefineState copyWith({
    RefinePhase? phase,
    String? transcript,
    DraftPlan? currentPlan,
    PlanDiff? diff,
    bool clearDiff = false,
  }) {
    return RefineState(
      phase: phase ?? this.phase,
      transcript: transcript ?? this.transcript,
      currentPlan: currentPlan ?? this.currentPlan,
      diff: clearDiff ? null : (diff ?? this.diff),
    );
  }
}

/// Drives the Refine screen.
///
/// Scripted voice (same shape as `CaptureController`): tapping the
/// voice button arms `listening`, streams a hard-coded transcript on
/// a 90 ms cadence, then flips to `thinking` while the day agent
/// produces a [PlanDiff], then to `diffReady`.
///
/// `accept` commits the diff via `acceptDiff`; `revert` rolls back to
/// the original plan and returns to `idle` (so the user can try
/// again); `keepTalking` re-enters `listening` with the existing
/// transcript still attached.
class RefineController extends Notifier<RefineState> {
  RefineController(
    this.originalPlan, {
    this.chunkInterval = const Duration(milliseconds: 90),
    List<String>? transcriptChunks,
  }) : _chunks = transcriptChunks ?? _defaultChunks;

  final DraftPlan originalPlan;
  final Duration chunkInterval;
  final List<String> _chunks;

  Timer? _streamTimer;
  int _cursor = 0;

  @override
  RefineState build() {
    ref.onDispose(_cancelTimer);
    return RefineState(
      phase: RefinePhase.idle,
      transcript: '',
      currentPlan: originalPlan,
    );
  }

  void toggleListening() {
    switch (state.phase) {
      case RefinePhase.idle:
      case RefinePhase.diffReady:
        _beginListening(resetTranscript: state.phase == RefinePhase.idle);
      case RefinePhase.listening:
        _finishListening();
      case RefinePhase.thinking:
      case RefinePhase.accepted:
        // No-op — we're mid-flight.
        break;
    }
  }

  /// User tapped "Keep talking" — re-arms listening without
  /// discarding the existing transcript so the agent has context.
  void keepTalking() {
    if (state.phase == RefinePhase.diffReady) {
      _beginListening(resetTranscript: false);
    }
  }

  Future<void> accept() async {
    final diff = state.diff;
    if (diff == null) return;
    final agent = ref.read(dayAgentProvider);
    final next = await agent.acceptDiff(diff);
    if (!ref.mounted) return;
    state = state.copyWith(phase: RefinePhase.accepted, currentPlan: next);
  }

  Future<void> revert() async {
    final diff = state.diff;
    if (diff == null) return;
    final agent = ref.read(dayAgentProvider);
    final restored = await agent.revertDiff(
      diff: diff,
      originalPlan: originalPlan,
    );
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: RefinePhase.idle,
      currentPlan: restored,
      clearDiff: true,
    );
  }

  void _beginListening({required bool resetTranscript}) {
    _cancelTimer();
    _cursor = 0;
    state = state.copyWith(
      phase: RefinePhase.listening,
      transcript: resetTranscript ? '' : state.transcript,
      clearDiff: true,
    );
    _streamTimer = Timer.periodic(chunkInterval, (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      if (_cursor >= _chunks.length) {
        timer.cancel();
        _finishListening();
        return;
      }
      final next = _chunks[_cursor++];
      final current = state.transcript;
      final joined = current.isEmpty
          ? next
          : '$current${_needsLeadingSpace(next) ? ' ' : ''}$next';
      state = state.copyWith(transcript: joined);
    });
  }

  Future<void> _finishListening() async {
    _cancelTimer();
    state = state.copyWith(phase: RefinePhase.thinking);
    final agent = ref.read(dayAgentProvider);
    final diff = await agent.proposePlanDiff(
      currentPlan: originalPlan,
      voiceTranscript: state.transcript,
    );
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: RefinePhase.diffReady,
      diff: diff,
      currentPlan: diff.updatedPlan,
    );
  }

  void _cancelTimer() {
    _streamTimer?.cancel();
    _streamTimer = null;
  }

  bool _needsLeadingSpace(String next) {
    if (next.isEmpty) return false;
    final first = next.codeUnitAt(0);
    const comma = 0x2C;
    const period = 0x2E;
    const question = 0x3F;
    const exclamation = 0x21;
    return first != comma &&
        first != period &&
        first != question &&
        first != exclamation;
  }
}

final refineControllerProvider = NotifierProvider.autoDispose
    .family<RefineController, RefineState, DraftPlan>(RefineController.new);

const List<String> _defaultChunks = [
  'Move',
  'the',
  'deck',
  'earlier',
  ',',
  'skip',
  'onboarding',
  'this',
  'afternoon',
  ',',
  'and',
  'add',
  'a',
  'buffer',
  'after',
  'lunch',
  '.',
];
