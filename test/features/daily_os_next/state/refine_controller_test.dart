import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';

void main() {
  group('RefineController', () {
    late MockDayAgent agent;
    late DraftPlan draft;

    setUp(() async {
      agent = MockDayAgent(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );
      // Use a real draft so propose_plan_diff has blocks to reshape.
      draft = await agent.draftDayPlan(
        captureId: const CaptureId('cap'),
        decidedTaskIds: const ['t_deck_review', 't_onboarding_doc'],
        dayDate: DateTime(2026, 5, 25),
      );
    });

    ProviderContainer makeContainer({MockDayAgent? overrideAgent}) {
      final container = ProviderContainer(
        overrides: [dayAgentProvider.overrideWithValue(overrideAgent ?? agent)],
      )..listen(refineControllerProvider(draft), (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    test('starts in the idle phase with the original plan', () {
      final container = makeContainer();
      final state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.idle);
      expect(state.currentPlan, draft);
      expect(state.diff, isNull);
    });

    test('listening does not synthesize a canned transcript', () {
      final container = makeContainer();
      container
          .read(refineControllerProvider(draft).notifier)
          .toggleListening();

      final state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.listening);
      expect(state.transcript, isEmpty);
      expect(state.diff, isNull);
    });

    test(
      'failed diff proposal keeps review open with the transcript',
      () async {
        final previousOnError = FlutterError.onError;
        FlutterErrorDetails? reportedError;
        FlutterError.onError = (details) => reportedError = details;
        addTearDown(() => FlutterError.onError = previousOnError);

        final container = makeContainer(overrideAgent: _ThrowingRefineAgent());
        final notifier =
            container.read(refineControllerProvider(draft).notifier)
              ..beginListening(resetTranscript: true)
              ..updateActiveTranscript('make the writing block longer');

        await notifier.finishWithTranscript('make the writing block longer');

        final state = container.read(refineControllerProvider(draft));
        expect(state.phase, RefinePhase.reviewing);
        expect(state.transcript, 'make the writing block longer');
        expect(state.diff, isNull);
        expect(state.problem, RefineProblem.proposalFailed);
        expect(state.problemDetail, contains('refine rejected'));
        expect(state.currentPlan, draft);
        expect(reportedError?.exception, isA<StateError>());
        expect(
          reportedError?.context?.toDescription(),
          'while proposing a plan refinement',
        );
      },
    );

    test('empty diff keeps review open with no-changes feedback', () async {
      final container = makeContainer(overrideAgent: _EmptyDiffRefineAgent());
      final notifier = container.read(refineControllerProvider(draft).notifier)
        ..beginListening(resetTranscript: true)
        ..updateActiveTranscript('make the day easier');

      await notifier.finishWithTranscript('make the day easier');

      final state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.reviewing);
      expect(state.transcript, 'make the day easier');
      expect(state.diff, isNull);
      expect(state.problem, RefineProblem.noChanges);
      expect(state.currentPlan, draft);
    });

    test('captured transcript drives the diff proposal', () async {
      final container = makeContainer();
      final notifier = container.read(refineControllerProvider(draft).notifier)
        ..beginListening(resetTranscript: true)
        ..updateActiveTranscript('move client review later');
      expect(
        container.read(refineControllerProvider(draft)).transcript,
        'move client review later',
      );

      await notifier.finishWithTranscript('move client review later');

      final state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.diffReady);
      expect(state.diff, isNotNull);
      expect(state.diff!.transcript, 'move client review later');
      expect(state.diff!.changes, isNotEmpty);
      // The current plan reflects the diff so the timeline shows
      // the reshape "in place".
      expect(state.currentPlan, isNot(equals(draft)));
    });

    test('captured transcript enters an editable review phase first', () async {
      final container = makeContainer();
      final notifier = container.read(refineControllerProvider(draft).notifier)
        ..beginListening(resetTranscript: true)
        ..updateActiveTranscript('move client review later')
        ..reviewTranscript('move client review later');

      var state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.reviewing);
      expect(state.transcript, 'move client review later');
      expect(state.diff, isNull);

      notifier.updateTranscript('move client review to tomorrow');
      state = container.read(refineControllerProvider(draft));
      expect(state.transcript, 'move client review to tomorrow');

      await notifier.finishWithTranscript(state.transcript);

      state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.diffReady);
      expect(state.diff!.transcript, 'move client review to tomorrow');
    });

    test('blank transcript returns to idle without producing a diff', () async {
      final container = makeContainer();
      final notifier = container.read(refineControllerProvider(draft).notifier)
        ..beginListening(resetTranscript: true);

      await notifier.finishWithTranscript('   ');

      final state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.idle);
      expect(state.transcript, isEmpty);
      expect(state.diff, isNull);
    });

    test('accept transitions to accepted with the updated plan', () async {
      final container = makeContainer();
      final notifier = container.read(refineControllerProvider(draft).notifier)
        ..beginListening(resetTranscript: true);
      await notifier.finishWithTranscript('move client review later');

      var state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.diffReady);

      await notifier.accept();
      state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.accepted);
      expect(state.currentPlan, state.diff!.updatedPlan);
    });

    test('resolves individual diff changes with item indices', () async {
      final acceptedPlan = draft.copyWith(scheduledMinutes: 360);
      final agent = _RecordingRefineAgent(
        updatedPlan: acceptedPlan,
        livePlanAfterReject: acceptedPlan,
      );
      final container = makeContainer(overrideAgent: agent);
      final notifier = container.read(refineControllerProvider(draft).notifier)
        ..beginListening(resetTranscript: true);

      await notifier.finishWithTranscript('add gym and move review later');

      var state = container.read(refineControllerProvider(draft));
      final diff = state.diff!;
      expect(diff.changes, hasLength(2));
      expect(
        state.decisionFor(diff.changes.first),
        PlanDiffChangeDecision.pending,
      );

      await notifier.acceptChange(diff.changes.first.id);

      state = container.read(refineControllerProvider(draft));
      expect(agent.acceptedItemIndices, [
        [0],
      ]);
      expect(state.phase, RefinePhase.diffReady);
      expect(
        state.decisionFor(diff.changes.first),
        PlanDiffChangeDecision.accepted,
      );
      expect(
        state.decisionFor(diff.changes.last),
        PlanDiffChangeDecision.pending,
      );
      expect(state.currentPlan, acceptedPlan);

      await notifier.rejectChange(diff.changes.last.id);

      state = container.read(refineControllerProvider(draft));
      expect(agent.rejectedItemIndices, [
        [1],
      ]);
      expect(state.phase, RefinePhase.accepted);
      expect(
        state.decisionFor(diff.changes.last),
        PlanDiffChangeDecision.rejected,
      );
      expect(state.currentPlan, acceptedPlan);
    });

    test('revert returns to idle with the original plan', () async {
      final container = makeContainer();
      final notifier = container.read(refineControllerProvider(draft).notifier)
        ..beginListening(resetTranscript: true);
      await notifier.finishWithTranscript('move client review later');
      expect(
        container.read(refineControllerProvider(draft)).phase,
        RefinePhase.diffReady,
      );
      await notifier.revert();
      final state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.idle);
      expect(state.diff, isNull);
      expect(state.currentPlan, draft);
    });

    // -----------------------------------------------------------------------
    // toggleListening branch coverage
    // -----------------------------------------------------------------------

    test(
      'toggleListening from diffReady re-enters listening without reset',
      () async {
        final container = makeContainer();
        final notifier = container.read(
          refineControllerProvider(draft).notifier,
        )..beginListening(resetTranscript: true);
        await notifier.finishWithTranscript('move client review later');
        expect(
          container.read(refineControllerProvider(draft)).phase,
          RefinePhase.diffReady,
        );

        // toggleListening from diffReady should call beginListening with
        // resetTranscript: false, so the transcript is preserved.
        final transcriptBefore = container
            .read(refineControllerProvider(draft))
            .transcript;
        notifier.toggleListening();

        final state = container.read(refineControllerProvider(draft));
        expect(state.phase, RefinePhase.listening);
        // resetTranscript: false means the prefix equals the prior transcript
        expect(state.transcript, transcriptBefore);
      },
    );

    test(
      'toggleListening while listening is a no-op (phase stays listening)',
      () {
        final container = makeContainer();
        final notifier = container.read(
          refineControllerProvider(draft).notifier,
        )..beginListening(resetTranscript: true);
        expect(
          container.read(refineControllerProvider(draft)).phase,
          RefinePhase.listening,
        );

        // A second toggle while already listening should be a no-op.
        notifier.toggleListening();
        expect(
          container.read(refineControllerProvider(draft)).phase,
          RefinePhase.listening,
        );
      },
    );

    test(
      'toggleListening from reviewing resets transcript and enters listening',
      () {
        final container = makeContainer();
        // Put the controller into reviewing state.
        final notifier =
            container.read(refineControllerProvider(draft).notifier)
              ..beginListening(resetTranscript: true)
              ..reviewTranscript('some transcript');
        expect(
          container.read(refineControllerProvider(draft)).phase,
          RefinePhase.reviewing,
        );

        notifier.toggleListening();

        final state = container.read(refineControllerProvider(draft));
        expect(state.phase, RefinePhase.listening);
        // resetTranscript: true clears the transcript.
        expect(state.transcript, isEmpty);
      },
    );

    test(
      'toggleListening during thinking and accepted phases is a no-op',
      () async {
        // ---- thinking phase: controller is awaiting proposePlanDiff ----
        // We use a completer-based agent to freeze the controller in thinking.
        final thinkingAgent = _HoldingRefineAgent();
        final thinkingContainer = makeContainer(overrideAgent: thinkingAgent)
          ..read(
            refineControllerProvider(draft).notifier,
          ).beginListening(resetTranscript: true);
        // Fire finishWithTranscript but do not await — the agent holds.
        unawaited(
          thinkingContainer
              .read(refineControllerProvider(draft).notifier)
              .finishWithTranscript('do something'),
        );
        // Yield one microtask so the async body starts and sets phase=thinking.
        // Drain the event queue (not a single microtask) so the thinking
        // phase is observed without relying on microtask-ordering details.
        await pumpEventQueue();
        expect(
          thinkingContainer.read(refineControllerProvider(draft)).phase,
          RefinePhase.thinking,
        );

        thinkingContainer
            .read(refineControllerProvider(draft).notifier)
            .toggleListening();
        expect(
          thinkingContainer.read(refineControllerProvider(draft)).phase,
          RefinePhase.thinking,
        );
        // Release the agent so the container can be disposed cleanly.
        thinkingAgent.complete();

        // ---- accepted phase ----
        final container = makeContainer();
        final notifier = container.read(
          refineControllerProvider(draft).notifier,
        )..beginListening(resetTranscript: true);
        await notifier.finishWithTranscript('move client review later');
        await notifier.accept();
        expect(
          container.read(refineControllerProvider(draft)).phase,
          RefinePhase.accepted,
        );

        notifier.toggleListening();
        expect(
          container.read(refineControllerProvider(draft)).phase,
          RefinePhase.accepted,
        );
      },
    );

    // -----------------------------------------------------------------------
    // _resolveChange: pending decision is a no-op (line 349)
    // -----------------------------------------------------------------------

    test(
      'resolveChange skips a change that is already resolved',
      () async {
        final acceptedPlan = draft.copyWith(scheduledMinutes: 360);
        final recordingAgent = _RecordingRefineAgent(
          updatedPlan: acceptedPlan,
          livePlanAfterReject: acceptedPlan,
        );
        final container = makeContainer(overrideAgent: recordingAgent);
        final notifier = container.read(
          refineControllerProvider(draft).notifier,
        )..beginListening(resetTranscript: true);
        await notifier.finishWithTranscript('add gym and move review later');

        final diff = container.read(refineControllerProvider(draft)).diff!;
        // Accept the first change.
        await notifier.acceptChange(diff.changes.first.id);
        final acceptCallCount = recordingAgent.acceptedItemIndices.length;

        // Calling acceptChange on an already-accepted change is a no-op.
        await notifier.acceptChange(diff.changes.first.id);
        expect(
          recordingAgent.acceptedItemIndices.length,
          acceptCallCount,
          reason: 'Already-resolved change must not trigger another agent call',
        );
      },
    );

    // -----------------------------------------------------------------------
    // _resolveChange error path: acceptDiff / revertDiff throws
    // -----------------------------------------------------------------------

    test(
      'acceptChange clears resolvingChangeId and reports error when agent throws',
      () async {
        final previousOnError = FlutterError.onError;
        FlutterErrorDetails? reportedError;
        FlutterError.onError = (details) => reportedError = details;
        addTearDown(() => FlutterError.onError = previousOnError);

        // Switch the override to a throwing agent AFTER we have the diff.
        final throwingContainer = ProviderContainer(
          overrides: [
            dayAgentProvider.overrideWithValue(_ThrowingAcceptAgent()),
          ],
        )..listen(refineControllerProvider(draft), (_, _) {});
        addTearDown(throwingContainer.dispose);

        // Manually put the throwingContainer into diffReady with the same diff.
        // Drive to listening → finish to get a diff (ThrowingAcceptAgent.proposePlanDiff succeeds).
        final throwingNotifier = throwingContainer.read(
          refineControllerProvider(draft).notifier,
        )..beginListening(resetTranscript: true);
        await throwingNotifier.finishWithTranscript('move client review later');

        final throwingDiff = throwingContainer
            .read(refineControllerProvider(draft))
            .diff!;
        expect(throwingDiff.changes, isNotEmpty);

        await throwingNotifier.acceptChange(throwingDiff.changes.first.id);

        final state = throwingContainer.read(refineControllerProvider(draft));
        // resolvingChangeId must be cleared after the error.
        expect(state.resolvingChangeId, isNull);
        // Phase should stay diffReady (not transition to accepted).
        expect(state.phase, RefinePhase.diffReady);
        // FlutterError was reported.
        expect(reportedError?.exception, isA<StateError>());
        expect(
          reportedError?.context?.toDescription(),
          'while resolving a plan refinement item',
        );
      },
    );

    test(
      'rejectChange clears resolvingChangeId and reports error when agent throws',
      () async {
        final previousOnError = FlutterError.onError;
        FlutterErrorDetails? reportedError;
        FlutterError.onError = (details) => reportedError = details;
        addTearDown(() => FlutterError.onError = previousOnError);

        final container = ProviderContainer(
          overrides: [
            dayAgentProvider.overrideWithValue(_ThrowingRevertAgent()),
          ],
        )..listen(refineControllerProvider(draft), (_, _) {});
        addTearDown(container.dispose);

        final notifier = container.read(
          refineControllerProvider(draft).notifier,
        )..beginListening(resetTranscript: true);
        await notifier.finishWithTranscript('move client review later');

        final diffState = container.read(refineControllerProvider(draft));
        expect(diffState.phase, RefinePhase.diffReady);
        expect(diffState.diff!.changes, isNotEmpty);

        await notifier.rejectChange(diffState.diff!.changes.first.id);

        final state = container.read(refineControllerProvider(draft));
        expect(state.resolvingChangeId, isNull);
        expect(state.phase, RefinePhase.diffReady);
        expect(reportedError?.exception, isA<StateError>());
        expect(
          reportedError?.context?.toDescription(),
          'while resolving a plan refinement item',
        );
      },
    );

    // -----------------------------------------------------------------------
    // keepTalking — re-arms listening while preserving the transcript
    // -----------------------------------------------------------------------

    test(
      'keepTalking from diffReady re-enters listening with existing transcript',
      () async {
        final container = makeContainer();
        final notifier = container.read(
          refineControllerProvider(draft).notifier,
        )..beginListening(resetTranscript: true);
        await notifier.finishWithTranscript('move client review later');

        final transcriptBefore = container
            .read(refineControllerProvider(draft))
            .transcript;
        expect(
          container.read(refineControllerProvider(draft)).phase,
          RefinePhase.diffReady,
        );

        notifier.keepTalking();

        final state = container.read(refineControllerProvider(draft));
        expect(state.phase, RefinePhase.listening);
        expect(state.transcript, transcriptBefore);
        expect(state.diff, isNull);
      },
    );

    test('keepTalking is a no-op when not in diffReady', () {
      final container = makeContainer();
      // idle phase — keepTalking should not change the phase.
      container.read(refineControllerProvider(draft).notifier).keepTalking();
      expect(
        container.read(refineControllerProvider(draft)).phase,
        RefinePhase.idle,
      );
    });

    // -----------------------------------------------------------------------
    // _joinTranscript edge cases (lines 417-419)
    // -----------------------------------------------------------------------

    test(
      'keepTalking then updateActiveTranscript deduplicates overlapping text',
      () async {
        // Exercises _joinTranscript where prefix ends with the new transcript.
        final container = makeContainer();
        final notifier = container.read(
          refineControllerProvider(draft).notifier,
        )..beginListening(resetTranscript: true);
        await notifier.finishWithTranscript('move client review later');

        // keepTalking preserves 'move client review later' as prefix.
        // The STT system re-sends the whole utterance. _joinTranscript must
        // not duplicate it: prefix ends with transcript → return prefix.
        notifier
          ..keepTalking()
          ..updateActiveTranscript('move client review later');

        final state = container.read(refineControllerProvider(draft));
        expect(state.transcript, 'move client review later');
      },
    );

    test(
      'updateActiveTranscript appends new text to an existing prefix',
      () async {
        // Exercises the _joinTranscript '$prefix $transcript' branch.
        final container = makeContainer();
        final notifier = container.read(
          refineControllerProvider(draft).notifier,
        )..beginListening(resetTranscript: true);
        await notifier.finishWithTranscript('first part');

        // The incoming transcript is fresh new words.
        notifier
          ..keepTalking()
          ..updateActiveTranscript('second part');

        final state = container.read(refineControllerProvider(draft));
        expect(state.transcript, 'first part second part');
      },
    );

    test(
      'reviewTranscript with empty new transcript returns to idle',
      () {
        // Exercises _joinTranscript where prefix is empty → returns cleanTranscript.
        // When transcript itself is also empty the controller returns to idle.
        final container = makeContainer();
        container.read(refineControllerProvider(draft).notifier)
          ..beginListening(resetTranscript: true)
          ..reviewTranscript('');

        final state = container.read(refineControllerProvider(draft));
        expect(state.phase, RefinePhase.idle);
        expect(state.transcript, isEmpty);
      },
    );
  });
}

/// Base for the scripted agents below: zero latencies and a fixed clock so
/// each subclass only overrides the method under test.
class _ZeroLatencyAgent extends MockDayAgent {
  _ZeroLatencyAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );
}

class _RecordingRefineAgent extends _ZeroLatencyAgent {
  _RecordingRefineAgent({
    required this.updatedPlan,
    required this.livePlanAfterReject,
  });

  final DraftPlan updatedPlan;
  final DraftPlan livePlanAfterReject;
  final acceptedItemIndices = <List<int>?>[];
  final rejectedItemIndices = <List<int>?>[];

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) async {
    final block = currentPlan.blocks.first;
    return PlanDiff(
      id: 'diff-recording',
      transcript: voiceTranscript,
      updatedPlan: updatedPlan,
      changes: [
        PlanDiffChange(
          id: 'diff-recording_0',
          kind: PlanDiffChangeKind.moved,
          title: block.title,
          category: block.category,
          reason: 'Move it later.',
          affectedBlockId: block.id,
          fromStart: block.start,
          fromEnd: block.end,
          toStart: block.start.add(const Duration(hours: 1)),
          toEnd: block.end.add(const Duration(hours: 1)),
        ),
        PlanDiffChange(
          id: 'diff-recording_1',
          kind: PlanDiffChangeKind.added,
          title: 'Gym session',
          category: block.category,
          reason: 'Add the requested evening workout.',
          affectedBlockId: block.id,
          toStart: DateTime(2026, 5, 25, 20),
          toEnd: DateTime(2026, 5, 25, 21, 45),
        ),
      ],
    );
  }

  @override
  Future<DraftPlan> acceptDiff(
    PlanDiff diff, {
    List<int>? itemIndices,
  }) async {
    acceptedItemIndices.add(itemIndices);
    return updatedPlan;
  }

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
    List<int>? itemIndices,
  }) async {
    rejectedItemIndices.add(itemIndices);
    return livePlanAfterReject;
  }
}

class _ThrowingRefineAgent extends _ZeroLatencyAgent {
  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) async {
    throw StateError('refine rejected');
  }
}

class _EmptyDiffRefineAgent extends _ZeroLatencyAgent {
  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) async {
    return PlanDiff(
      id: 'diff-empty',
      transcript: voiceTranscript,
      changes: const [],
      updatedPlan: currentPlan,
    );
  }
}

/// Holds `proposePlanDiff` until [complete] is called, so tests can assert
/// behaviour in the `thinking` phase before the future resolves.
class _HoldingRefineAgent extends _ZeroLatencyAgent {
  final _completer = Completer<PlanDiff>();

  // Captured on the first proposePlanDiff call so complete() can echo
  // back a structurally valid (but empty) diff.
  DraftPlan? _capturedPlan;

  void complete() {
    final plan = _capturedPlan;
    if (!_completer.isCompleted && plan != null) {
      _completer.complete(
        PlanDiff(
          id: 'diff-hold',
          transcript: '',
          changes: const [],
          updatedPlan: plan,
        ),
      );
    }
  }

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) {
    _capturedPlan = currentPlan;
    return _completer.future;
  }
}

/// Delegates `proposePlanDiff` to the scripted [MockDayAgent] but throws
/// from `acceptDiff`, simulating an agent failure during individual-change
/// acceptance.
class _ThrowingAcceptAgent extends _ZeroLatencyAgent {
  @override
  Future<DraftPlan> acceptDiff(
    PlanDiff diff, {
    List<int>? itemIndices,
  }) async {
    throw StateError('accept failed');
  }
}

/// Delegates `proposePlanDiff` to the scripted [MockDayAgent] but throws
/// from `revertDiff`, simulating an agent failure during change rejection.
class _ThrowingRevertAgent extends _ZeroLatencyAgent {
  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
    List<int>? itemIndices,
  }) async {
    throw StateError('revert failed');
  }
}
