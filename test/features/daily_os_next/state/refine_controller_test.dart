import 'package:fake_async/fake_async.dart';
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

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [dayAgentProvider.overrideWithValue(agent)],
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

    test('listening → thinking → diffReady, plan reshaped in place', () {
      fakeAsync((async) {
        final container = ProviderContainer(
          overrides: [
            dayAgentProvider.overrideWithValue(agent),
            refineControllerProvider(draft).overrideWith(
              () => RefineController(
                draft,
                chunkInterval: const Duration(milliseconds: 10),
                transcriptChunks: const ['move', 'deck', 'earlier'],
              ),
            ),
          ],
        )..listen(refineControllerProvider(draft), (_, _) {});
        addTearDown(container.dispose);

        container
            .read(refineControllerProvider(draft).notifier)
            .toggleListening();
        expect(
          container.read(refineControllerProvider(draft)).phase,
          RefinePhase.listening,
        );

        // 3 chunks × 10 ms = 30 ms; the timer also needs one more
        // tick to fall through to _finishListening. After draining,
        // the controller awaits proposePlanDiff (zero latency) so a
        // microtask flush bumps us to diffReady.
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();
        final state = container.read(refineControllerProvider(draft));
        expect(state.phase, RefinePhase.diffReady);
        expect(state.diff, isNotNull);
        expect(state.diff!.changes, isNotEmpty);
        // The current plan reflects the diff so the timeline shows
        // the reshape "in place".
        expect(state.currentPlan, isNot(equals(draft)));
      });
    });

    test('accept transitions to accepted with the updated plan', () async {
      final container = makeContainer();
      final notifier = container.read(refineControllerProvider(draft).notifier)
        // Drive listening → thinking → diffReady on real microtasks.
        ..toggleListening();
      // Wait for scripted transcript to drain. 17 chunks at 90 ms by
      // default; pump enough cycles.
      for (var i = 0; i < 25; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 90));
      }

      var state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.diffReady);

      await notifier.accept();
      state = container.read(refineControllerProvider(draft));
      expect(state.phase, RefinePhase.accepted);
      expect(state.currentPlan, state.diff!.updatedPlan);
    });

    test('revert returns to idle with the original plan', () async {
      final container = makeContainer();
      final notifier = container.read(refineControllerProvider(draft).notifier)
        ..toggleListening();
      for (var i = 0; i < 25; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 90));
      }
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
