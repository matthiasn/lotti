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
      expect(initial.phase, DraftingPhase.drafting);
      expect(initial.learningCards, isNotNull);
      expect(initial.learningCards!.length, 3);
    });

    test(
      'phase flips to ready and draft is populated once draftDayPlan '
      'resolves',
      () async {
        final container = makeContainer();
        await container.read(draftingControllerProvider(params()).future);

        // Drain microtasks so the fire-and-forget draftFuture listener
        // completes and the controller pushes the ready state.
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        final state = container
            .read(draftingControllerProvider(params()))
            .value;
        expect(state, isNotNull);
        expect(state!.phase, DraftingPhase.ready);
        expect(state.draft, isNotNull);
      },
    );
  });
}
