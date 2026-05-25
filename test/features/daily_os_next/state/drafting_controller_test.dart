import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/drafting_controller.dart';

void main() {
  group('DraftingController', () {
    late MockDayAgent agent;

    setUp(() {
      agent = MockDayAgent(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 7),
      );
    });

    DraftingParams params() => DraftingParams(
      captureId: const CaptureId('cap_draft'),
      decidedTaskIds: const ['t_deck_review', 't_onboarding_doc'],
      dayDate: DateTime(2026, 5, 25),
    );

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [dayAgentProvider.overrideWithValue(agent)],
      )..listen(draftingControllerProvider(params()), (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    test('learning cards are present from the first frame', () async {
      final container = makeContainer();
      final initial = await container.read(
        draftingControllerProvider(params()).future,
      );
      expect(initial.phase, DraftingPhase.streaming);
      expect(initial.visibleLines, isEmpty);
      expect(initial.learningCards, isNotNull);
      expect(initial.learningCards!.length, 3);
    });

    test(
      'reasoning lines stream in on cadence and ready holds until draft '
      'arrives',
      () {
        fakeAsync((async) {
          final container = ProviderContainer(
            overrides: [
              dayAgentProvider.overrideWithValue(
                MockDayAgent(
                  // The draft latency must be > the time it would take
                  // to drain the reasoning script — that way the final
                  // "Ready" line stalls until the draft resolves, which
                  // is the contract the screen relies on.
                  draftLatency: const Duration(milliseconds: 700),
                  parseLatency: Duration.zero,
                  pendingLatency: Duration.zero,
                  triageLatency: Duration.zero,
                  summarizeLatency: Duration.zero,
                ),
              ),
              draftingControllerProvider(params()).overrideWith(
                () => DraftingController(
                  params(),
                  lineInterval: const Duration(milliseconds: 100),
                  readyBeat: const Duration(milliseconds: 50),
                ),
              ),
            ],
          )..listen(draftingControllerProvider(params()), (_, _) {});
          addTearDown(container.dispose);

          // Drain microtasks so the controller's build completes,
          // then elapse 540ms — 5 lines × 100ms = 500ms; the 6th line
          // ("Ready") will be held because the draft has not yet
          // resolved (700ms).
          async
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 540));
          var state = container
              .read(draftingControllerProvider(params()))
              .value;
          expect(state, isNotNull);
          expect(state!.visibleLines.length, 5);
          expect(state.phase, DraftingPhase.streaming);

          // Cross the 700ms threshold so the draft resolves; the next
          // periodic tick emits the "Ready" line, then the readyBeat
          // fires. Allow generous slack so timer/future ordering
          // inside fakeAsync stays robust.
          async.elapse(const Duration(milliseconds: 600));
          state = container.read(draftingControllerProvider(params())).value;
          expect(state!.draft, isNotNull);
          expect(state.visibleLines.length, 6);
          expect(state.phase, DraftingPhase.ready);
        });
      },
    );
  });
}
