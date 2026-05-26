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

    test('failed diff proposal returns to idle with the transcript', () async {
      final container = makeContainer(overrideAgent: _ThrowingRefineAgent());
      final notifier = container.read(refineControllerProvider(draft).notifier)
        ..beginListening(resetTranscript: true)
        ..updateActiveTranscript('make the writing block longer');

      await notifier.finishWithTranscript('make the writing block longer');

      final state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.idle);
      expect(state.transcript, 'make the writing block longer');
      expect(state.diff, isNull);
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
  });
}

class _RecordingRefineAgent extends MockDayAgent {
  _RecordingRefineAgent({
    required this.updatedPlan,
    required this.livePlanAfterReject,
  }) : super(
         parseLatency: Duration.zero,
         pendingLatency: Duration.zero,
         triageLatency: Duration.zero,
         draftLatency: Duration.zero,
         summarizeLatency: Duration.zero,
         clock: () => DateTime(2026, 5, 25, 9),
       );

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

class _ThrowingRefineAgent extends MockDayAgent {
  _ThrowingRefineAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) async {
    throw StateError('refine rejected');
  }
}
