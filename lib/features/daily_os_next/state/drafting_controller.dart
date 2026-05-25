// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';

/// What stage of the drafting wait the user is in.
enum DraftingPhase {
  /// Reasoning lines are still streaming in. The draft may or may
  /// not be ready behind the scenes.
  streaming,

  /// Both the reasoning stream and the draft plan have completed.
  /// The UI animates a brief beat then auto-advances to the Day view.
  ready,
}

/// Parameters carried into [DraftingController] — the captureId of the
/// just-finished check-in, the task ids the user decided to keep, and
/// the day date being drafted.
@immutable
class DraftingParams {
  const DraftingParams({
    required this.captureId,
    required this.decidedTaskIds,
    required this.dayDate,
  });

  final CaptureId captureId;
  final List<String> decidedTaskIds;
  final DateTime dayDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftingParams &&
          captureId == other.captureId &&
          dayDate == other.dayDate &&
          listEquals(decidedTaskIds, other.decidedTaskIds);

  @override
  int get hashCode =>
      Object.hash(captureId, dayDate, Object.hashAll(decidedTaskIds));
}

/// Snapshot the Drafting screen renders against.
@immutable
class DraftingState {
  const DraftingState({
    required this.phase,
    required this.visibleLines,
    required this.totalLines,
    required this.learningCards,
    required this.draft,
  });

  final DraftingPhase phase;

  /// Reasoning lines emitted so far. The most recent line is the one
  /// the UI highlights with a pulsing dot; earlier ones fade.
  final List<ReasoningLine> visibleLines;

  /// Total scripted lines the controller will emit. The UI uses this
  /// for the 2 px teal progress bar.
  final int totalLines;

  /// Learning-card payload from `summarize_recent_patterns`. Null
  /// while still loading.
  final List<LearningCard>? learningCards;

  /// Completed draft plan. Null while still drafting.
  final DraftPlan? draft;

  DraftingState copyWith({
    DraftingPhase? phase,
    List<ReasoningLine>? visibleLines,
    int? totalLines,
    List<LearningCard>? learningCards,
    DraftPlan? draft,
  }) {
    return DraftingState(
      phase: phase ?? this.phase,
      visibleLines: visibleLines ?? this.visibleLines,
      totalLines: totalLines ?? this.totalLines,
      learningCards: learningCards ?? this.learningCards,
      draft: draft ?? this.draft,
    );
  }
}

/// Drives the Drafting wait screen.
///
/// On first build the controller:
/// 1. Kicks off `summarizeRecentPatterns` + `draftDayPlan` in parallel.
/// 2. Starts streaming the scripted reasoning lines on a 900 ms
///    cadence. The final "Ready" line is gated on `draftDayPlan`
///    having actually returned, so the reflection beat never
///    completes before the plan is real.
/// 3. Flips [DraftingPhase.ready] when both streams are exhausted.
///
/// Test seam: pass `lineInterval`, `readyBeat`, and `lines` to control
/// timing deterministically with `fakeAsync`.
class DraftingController extends AsyncNotifier<DraftingState> {
  DraftingController(
    this.params, {
    this.lineInterval = const Duration(milliseconds: 900),
    this.readyBeat = const Duration(milliseconds: 600),
    List<ReasoningLine>? lines,
  }) : _lines = lines ?? _defaultLines;

  final DraftingParams params;
  final Duration lineInterval;
  final Duration readyBeat;
  final List<ReasoningLine> _lines;

  Timer? _streamTimer;
  Timer? _readyTimer;

  @override
  Future<DraftingState> build() async {
    ref.onDispose(() {
      _streamTimer?.cancel();
      _readyTimer?.cancel();
    });

    final agent = ref.read(dayAgentProvider);

    final learningsFuture = agent.summarizeRecentPatterns(asOf: params.dayDate);
    final draftFuture = agent.draftDayPlan(
      captureId: params.captureId,
      decidedTaskIds: params.decidedTaskIds,
      dayDate: params.dayDate,
    );

    // The build awaits the *learning cards* so the right column has
    // content from the first frame. The draft is awaited lazily —
    // its readiness gates the final "Ready" reasoning line.
    final learnings = await learningsFuture;

    // Start streaming after the controller exposes its initial state.
    unawaited(
      Future<void>.microtask(() => _startStreaming(draftFuture)),
    );

    return DraftingState(
      phase: DraftingPhase.streaming,
      visibleLines: const [],
      totalLines: _lines.length,
      learningCards: learnings,
      draft: null,
    );
  }

  void _startStreaming(Future<DraftPlan> draftFuture) {
    var cursor = 0;
    var draft = state.value?.draft;

    draftFuture.then((value) {
      if (!ref.mounted) return;
      draft = value;
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(draft: value));
      }
    });

    _streamTimer = Timer.periodic(lineInterval, (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      // Hold the final line until the draft actually resolves — the
      // reflection beat must not "complete" before the plan exists.
      if (cursor == _lines.length - 1 && draft == null) {
        return;
      }
      if (cursor >= _lines.length) {
        timer.cancel();
        _scheduleReady();
        return;
      }
      final current = state.value;
      if (current == null) return;
      state = AsyncData(
        current.copyWith(
          visibleLines: [...current.visibleLines, _lines[cursor]],
        ),
      );
      cursor++;
    });
  }

  void _scheduleReady() {
    _readyTimer = Timer(readyBeat, () {
      if (!ref.mounted) return;
      final current = state.value;
      if (current == null || current.draft == null) return;
      state = AsyncData(current.copyWith(phase: DraftingPhase.ready));
    });
  }
}

final draftingControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DraftingController, DraftingState, DraftingParams>(
      DraftingController.new,
    );

const List<ReasoningLine> _defaultLines = [
  ReasoningLine(
    text: "Reviewing yesterday's carryover…",
    icon: ReasoningIcon.review,
  ),
  ReasoningLine(
    text: 'Pulling in calendar events…',
    icon: ReasoningIcon.calendar,
  ),
  ReasoningLine(
    text: 'Protecting your morning focus block',
    icon: ReasoningIcon.shield,
  ),
  ReasoningLine(
    text: 'Placing deep work in your high-energy window',
    icon: ReasoningIcon.energy,
  ),
  ReasoningLine(
    text: 'Balancing capacity',
    icon: ReasoningIcon.balance,
  ),
  ReasoningLine(
    text: 'Ready',
    icon: ReasoningIcon.ready,
  ),
];
