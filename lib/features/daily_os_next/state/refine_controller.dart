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

  /// Final transcript is ready and editable before the agent sees it.
  reviewing,

  /// Transcript captured; the agent is producing a `PlanDiff`.
  thinking,

  /// Diff returned; the timeline shows the proposed plan with pings, and the
  /// right column shows per-change diff cards plus Revert / Keep talking.
  diffReady,

  /// User resolved every diff item; the controller hands the resulting plan
  /// back to the caller and pops the screen.
  accepted,
}

/// Non-fatal feedback that should stay visible in the Refine UI.
enum RefineProblem {
  /// The agent returned a diff payload but none of its items could be shown
  /// as supported plan changes.
  noChanges,

  /// The proposal request failed or timed out.
  proposalFailed,
}

@immutable
class RefineState {
  const RefineState({
    required this.phase,
    required this.transcript,
    required this.currentPlan,
    this.decisions = const {},
    this.resolvingChangeId,
    this.diff,
    this.problem,
    this.problemDetail,
    this.accepting = false,
  });

  final RefinePhase phase;
  final String transcript;
  final DraftPlan currentPlan;
  final PlanDiff? diff;
  final Map<String, PlanDiffChangeDecision> decisions;
  final String? resolvingChangeId;
  final RefineProblem? problem;
  final String? problemDetail;

  /// True while the whole-diff [RefineController.accept] round-trip is in
  /// flight. The action bar treats this as busy so a second tap can't
  /// start a second accept (whose completion would re-emit `accepted`
  /// and double-pop the host route).
  final bool accepting;

  RefineState copyWith({
    RefinePhase? phase,
    String? transcript,
    DraftPlan? currentPlan,
    PlanDiff? diff,
    Map<String, PlanDiffChangeDecision>? decisions,
    String? resolvingChangeId,
    RefineProblem? problem,
    String? problemDetail,
    bool? accepting,
    bool clearDiff = false,
    bool clearResolvingChangeId = false,
    bool clearProblem = false,
  }) {
    return RefineState(
      phase: phase ?? this.phase,
      transcript: transcript ?? this.transcript,
      currentPlan: currentPlan ?? this.currentPlan,
      diff: clearDiff ? null : (diff ?? this.diff),
      decisions: decisions ?? this.decisions,
      resolvingChangeId: clearResolvingChangeId
          ? null
          : (resolvingChangeId ?? this.resolvingChangeId),
      problem: clearProblem ? null : (problem ?? this.problem),
      problemDetail: clearProblem
          ? null
          : (problemDetail ?? this.problemDetail),
      accepting: accepting ?? this.accepting,
    );
  }

  PlanDiffChangeDecision decisionFor(PlanDiffChange change) =>
      decisions[change.id] ?? PlanDiffChangeDecision.pending;
}

/// Drives the Refine screen.
///
/// Voice capture is owned by `CaptureController`; this controller only tracks
/// the refine state and submits the captured transcript to the day agent.
///
/// `acceptChange` / `rejectChange` resolve individual diff rows via
/// `acceptDiff` / `revertDiff`; `revert` rejects the whole pending diff and
/// returns to `idle` (so the user can try again); `keepTalking` re-enters
/// `listening` with the existing transcript still attached.
class RefineController extends Notifier<RefineState> {
  RefineController(this.originalPlan);

  final DraftPlan originalPlan;
  String _transcriptPrefix = '';

  // Tracks Notifier disposal so the polling loop inside
  // `RealDayAgent.proposePlanDiff` (up to 60s) cancels the moment the
  // controller is torn down instead of continuing to query the DB.
  bool _disposed = false;

  @override
  RefineState build() {
    ref.onDispose(() => _disposed = true);
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
        beginListening(resetTranscript: state.phase == RefinePhase.idle);
      case RefinePhase.listening:
        // CaptureController stops the microphone and calls finishWithTranscript.
        break;
      case RefinePhase.reviewing:
        beginListening(resetTranscript: true);
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
      beginListening(resetTranscript: false);
    }
  }

  void reviewTranscript(String transcript) {
    final nextTranscript = _joinTranscript(_transcriptPrefix, transcript);
    _transcriptPrefix = '';
    state = state.copyWith(
      phase: nextTranscript.isEmpty ? RefinePhase.idle : RefinePhase.reviewing,
      transcript: nextTranscript,
      clearDiff: true,
      decisions: const {},
      clearResolvingChangeId: true,
      clearProblem: true,
    );
  }

  void updateTranscript(String transcript) {
    if (state.phase != RefinePhase.reviewing) return;
    state = state.copyWith(transcript: transcript, clearProblem: true);
  }

  Future<void> submitReviewedTranscript() async {
    if (state.phase != RefinePhase.reviewing) return;
    await finishWithTranscript(state.transcript);
  }

  Future<void> accept() async {
    final diff = state.diff;
    // Re-entry guard: a second tap while the first round-trip is in
    // flight would start a second future whose completion re-emits
    // `accepted` and double-pops the host route.
    if (diff == null || state.accepting) return;
    final agent = ref.read(dayAgentProvider);
    final itemIndices = _indicesForDecision(PlanDiffChangeDecision.pending);
    if (itemIndices.isEmpty) return;
    state = state.copyWith(accepting: true);
    try {
      final next = await agent.acceptDiff(diff, itemIndices: itemIndices);
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: RefinePhase.accepted,
        accepting: false,
        currentPlan: next,
        decisions: _resolveMany(
          itemIndices,
          PlanDiffChangeDecision.accepted,
        ),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'daily_os_next',
          context: ErrorDescription('while accepting a plan refinement'),
        ),
      );
      if (!ref.mounted) return;
      // Re-arm the bar and surface the failure in the problem notice
      // (the caller fires accept() unawaited — a silent re-enable would
      // look like the tap did nothing).
      state = state.copyWith(
        accepting: false,
        problem: RefineProblem.proposalFailed,
        problemDetail: error.toString(),
      );
    }
  }

  Future<void> acceptChange(String changeId) async {
    await _resolveChange(
      changeId: changeId,
      decision: PlanDiffChangeDecision.accepted,
    );
  }

  Future<void> rejectChange(String changeId) async {
    await _resolveChange(
      changeId: changeId,
      decision: PlanDiffChangeDecision.rejected,
    );
  }

  Future<void> revert() async {
    final diff = state.diff;
    // `accepting` guard: a revert racing a whole-diff accept would make
    // `currentPlan` last-write-wins between two agent round-trips.
    if (diff == null || state.accepting) return;
    final agent = ref.read(dayAgentProvider);
    final itemIndices = _indicesForDecision(PlanDiffChangeDecision.pending);
    final restored = await agent.revertDiff(
      diff: diff,
      originalPlan: originalPlan,
      itemIndices: itemIndices.isEmpty ? null : itemIndices,
    );
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: RefinePhase.idle,
      currentPlan: restored,
      clearDiff: true,
      decisions: const {},
      clearResolvingChangeId: true,
      // A notice from a failed accept refers to the diff being discarded
      // here — don't let it outlive the plan it described.
      clearProblem: true,
    );
  }

  void beginListening({required bool resetTranscript}) {
    // `accepting` guard: starting a listening flow while a whole-diff
    // accept round-trip is in flight would race `acceptDiff`'s completion
    // (last-write-wins on `phase`/`transcript`). This is the choke point
    // for every listening entry (toggleListening, keepTalking), mirroring
    // the guards in accept()/revert()/_resolveChange().
    if (state.accepting) return;
    _transcriptPrefix = resetTranscript ? '' : state.transcript.trim();
    state = state.copyWith(
      phase: RefinePhase.listening,
      transcript: _transcriptPrefix,
      clearDiff: true,
      decisions: const {},
      clearResolvingChangeId: true,
      clearProblem: true,
    );
  }

  void updateActiveTranscript(String transcript) {
    if (state.phase != RefinePhase.listening) return;
    state = state.copyWith(
      transcript: _joinTranscript(_transcriptPrefix, transcript),
    );
  }

  void cancelListening() {
    if (state.phase != RefinePhase.listening) return;
    _transcriptPrefix = '';
    state = state.copyWith(
      phase: state.diff == null ? RefinePhase.idle : RefinePhase.diffReady,
    );
  }

  Future<void> finishWithTranscript(String transcript) async {
    final nextTranscript = _joinTranscript(_transcriptPrefix, transcript);
    _transcriptPrefix = '';
    if (nextTranscript.isEmpty) {
      state = state.copyWith(
        phase: state.diff == null ? RefinePhase.idle : RefinePhase.diffReady,
        clearProblem: true,
      );
      return;
    }
    final baselinePlan = state.currentPlan;
    state = state.copyWith(phase: RefinePhase.thinking, clearProblem: true);
    final agent = ref.read(dayAgentProvider);
    final PlanDiff diff;
    try {
      diff = await agent.proposePlanDiff(
        currentPlan: baselinePlan,
        voiceTranscript: nextTranscript,
        isCancelled: () => _disposed,
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'daily_os_next',
          context: ErrorDescription('while proposing a plan refinement'),
        ),
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: RefinePhase.reviewing,
        transcript: nextTranscript,
        clearDiff: true,
        problem: RefineProblem.proposalFailed,
        problemDetail: error.toString(),
        decisions: const {},
        clearResolvingChangeId: true,
      );
      return;
    }
    if (!ref.mounted) return;
    if (diff.changes.isEmpty) {
      state = state.copyWith(
        phase: RefinePhase.reviewing,
        transcript: nextTranscript,
        currentPlan: baselinePlan,
        clearDiff: true,
        problem: RefineProblem.noChanges,
        decisions: const {},
        clearResolvingChangeId: true,
      );
      return;
    }
    state = state.copyWith(
      phase: RefinePhase.diffReady,
      transcript: nextTranscript,
      diff: diff,
      currentPlan: diff.updatedPlan,
      decisions: {
        for (final change in diff.changes)
          change.id: PlanDiffChangeDecision.pending,
      },
      clearResolvingChangeId: true,
      clearProblem: true,
    );
  }

  Future<void> _resolveChange({
    required String changeId,
    required PlanDiffChangeDecision decision,
  }) async {
    final diff = state.diff;
    // `accepting` guard: a per-row resolve racing a whole-diff accept
    // would make `currentPlan` last-write-wins between two round-trips.
    if (diff == null || state.resolvingChangeId != null || state.accepting) {
      return;
    }
    final itemIndex = diff.changes.indexWhere(
      (change) => change.id == changeId,
    );
    if (itemIndex < 0) return;
    if (state.decisionFor(diff.changes[itemIndex]) !=
        PlanDiffChangeDecision.pending) {
      return;
    }

    final baselinePlan = state.currentPlan;
    state = state.copyWith(resolvingChangeId: changeId);
    final agent = ref.read(dayAgentProvider);
    final DraftPlan next;
    try {
      switch (decision) {
        case PlanDiffChangeDecision.accepted:
          next = await agent.acceptDiff(diff, itemIndices: [itemIndex]);
        case PlanDiffChangeDecision.rejected:
          next = await agent.revertDiff(
            diff: diff,
            originalPlan: baselinePlan,
            itemIndices: [itemIndex],
          );
        case PlanDiffChangeDecision.pending:
          return;
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'daily_os_next',
          context: ErrorDescription('while resolving a plan refinement item'),
        ),
      );
      if (!ref.mounted) return;
      state = state.copyWith(clearResolvingChangeId: true);
      return;
    }
    if (!ref.mounted) return;
    final decisions = _resolveMany([itemIndex], decision);
    state = state.copyWith(
      phase: _allResolved(decisions)
          ? RefinePhase.accepted
          : RefinePhase.diffReady,
      currentPlan: next,
      decisions: decisions,
      clearResolvingChangeId: true,
      // A successful resolve supersedes any earlier failure notice.
      clearProblem: true,
    );
  }

  List<int> _indicesForDecision(PlanDiffChangeDecision decision) {
    final diff = state.diff;
    if (diff == null) return const [];
    final indices = <int>[];
    for (var i = 0; i < diff.changes.length; i++) {
      if (state.decisionFor(diff.changes[i]) == decision) indices.add(i);
    }
    return indices;
  }

  Map<String, PlanDiffChangeDecision> _resolveMany(
    List<int> itemIndices,
    PlanDiffChangeDecision decision,
  ) {
    final diff = state.diff;
    if (diff == null) return state.decisions;
    final next = Map<String, PlanDiffChangeDecision>.of(state.decisions);
    for (final index in itemIndices) {
      if (index >= 0 && index < diff.changes.length) {
        next[diff.changes[index].id] = decision;
      }
    }
    return Map.unmodifiable(next);
  }

  bool _allResolved(Map<String, PlanDiffChangeDecision> decisions) {
    final diff = state.diff;
    if (diff == null) return false;
    // An empty diff has nothing left to act on — treat it as resolved so
    // callers don't get stuck waiting for a final accept that never comes.
    if (diff.changes.isEmpty) return true;
    return diff.changes.every(
      (change) => decisions[change.id] != PlanDiffChangeDecision.pending,
    );
  }

  String _joinTranscript(String prefix, String transcript) {
    final cleanPrefix = prefix.trim();
    final cleanTranscript = transcript.trim();
    if (cleanPrefix.isEmpty) return cleanTranscript;
    if (cleanTranscript.isEmpty) return cleanPrefix;
    if (cleanPrefix.endsWith(cleanTranscript)) return cleanPrefix;
    return '$cleanPrefix $cleanTranscript';
  }
}

// ignore: specify_nonobvious_property_types
final refineControllerProvider = NotifierProvider.autoDispose
    .family<RefineController, RefineState, DraftPlan>(RefineController.new);
