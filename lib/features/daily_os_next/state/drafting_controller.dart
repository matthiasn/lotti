// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';

/// What stage of the drafting wait the user is in.
enum DraftingPhase {
  /// Waiting on the agent to produce the draft. Skeleton + learning
  /// cards are shown.
  drafting,

  /// Draft has arrived. The page auto-pushes the Day view.
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
    this.decidedCaptureItemIds = const [],
  });

  final CaptureId captureId;
  final List<String> decidedTaskIds;
  final List<String> decidedCaptureItemIds;
  final DateTime dayDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftingParams &&
          captureId == other.captureId &&
          dayDate == other.dayDate &&
          listEquals(decidedTaskIds, other.decidedTaskIds) &&
          listEquals(decidedCaptureItemIds, other.decidedCaptureItemIds);

  @override
  int get hashCode => Object.hash(
    captureId,
    dayDate,
    Object.hashAll(decidedTaskIds),
    Object.hashAll(decidedCaptureItemIds),
  );
}

/// Snapshot the Drafting screen renders against.
@immutable
class DraftingState {
  const DraftingState({
    required this.phase,
    required this.learningCards,
    required this.draft,
  });

  final DraftingPhase phase;

  /// Learning-card payload from `summarize_recent_patterns`. Null
  /// while still loading.
  final List<LearningCard>? learningCards;

  /// Completed draft plan. Null while still drafting.
  final DraftPlan? draft;

  DraftingState copyWith({
    DraftingPhase? phase,
    List<LearningCard>? learningCards,
    DraftPlan? draft,
  }) {
    return DraftingState(
      phase: phase ?? this.phase,
      learningCards: learningCards ?? this.learningCards,
      draft: draft ?? this.draft,
    );
  }
}

/// Drives the Drafting wait screen.
///
/// On first build the controller kicks off `summarizeRecentPatterns`
/// and `draftDayPlan` in parallel. Learning cards are awaited so the
/// right column has content from the first frame; the draft is
/// awaited lazily and flips [DraftingPhase.ready] when it arrives.
/// The previous "scripted reasoning lines streaming on a 900 ms
/// cadence" theatre is gone — the wait is now an honest skeleton.
class DraftingController extends AsyncNotifier<DraftingState> {
  DraftingController(this.params);

  final DraftingParams params;

  @override
  Future<DraftingState> build() async {
    final agent = ref.read(dayAgentProvider);

    // Track disposal locally so the polling loop in
    // `RealDayAgent.draftDayPlan` (up to 60s) exits the instant the
    // controller goes away instead of continuing to query the DB.
    var disposed = false;
    ref.onDispose(() => disposed = true);

    final learningsFuture = agent.summarizeRecentPatterns(asOf: params.dayDate);
    final draftFuture = agent.draftDayPlan(
      captureId: params.captureId,
      decidedTaskIds: params.decidedTaskIds,
      decidedCaptureItemIds: params.decidedCaptureItemIds,
      dayDate: params.dayDate,
      isCancelled: () => disposed,
    );

    // Learning-card failures shouldn't block the draft — render an
    // empty card list and keep going. The real adapter already returns
    // `[]` for the "no day agent" case; this guard covers transient
    // backend failures (network blip, model error).
    List<LearningCard> learnings;
    try {
      learnings = await learningsFuture;
    } catch (_) {
      learnings = const [];
    }

    // The draft resolves lazily — fire-and-forget the listener that
    // flips the phase to ready once it lands.
    unawaited(
      draftFuture
          .then((value) {
            if (!ref.mounted) return;
            final current = state.value;
            if (current == null) return;
            state = AsyncData(
              current.copyWith(draft: value, phase: DraftingPhase.ready),
            );
          })
          .catchError((Object error, StackTrace stack) {
            if (!ref.mounted) return;
            state = AsyncError<DraftingState>(error, stack);
          }),
    );

    return DraftingState(
      phase: DraftingPhase.drafting,
      learningCards: learnings,
      draft: null,
    );
  }
}

final draftingControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DraftingController, DraftingState, DraftingParams>(
      DraftingController.new,
    );
