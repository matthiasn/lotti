import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/drafting_controller.dart';

/// [MockDayAgent] that actually consults the `isCancelled` callback the
/// controller wires up and records what it returned. The scripted mock
/// ignores `isCancelled` (it has no poll loop), so it never exercises
/// the `() => disposed` closure in the controller. This subclass closes
/// that gap by capturing and invoking the callback.
class _CancelProbeAgent extends MockDayAgent {
  _CancelProbeAgent({required this.gate})
    : super(
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 7),
      );

  /// When this completes, [draftDayPlan] is allowed to finish. Lets the
  /// test capture the callback, dispose the controller, and only then
  /// resolve the draft.
  final Completer<void> gate;

  /// The `isCancelled` callback the controller passed in.
  bool Function()? capturedIsCancelled;

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) async {
    capturedIsCancelled = isCancelled;
    await gate.future;
    return super.draftDayPlan(
      captureId: captureId,
      decidedTaskIds: decidedTaskIds,
      dayDate: dayDate,
      decidedCaptureItemIds: decidedCaptureItemIds,
      calendarBlocks: calendarBlocks,
      isCancelled: isCancelled,
    );
  }
}

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

    ProviderContainer makeContainer(MockDayAgent dayAgent) {
      final container = ProviderContainer(
        overrides: [dayAgentProvider.overrideWithValue(dayAgent)],
      )..listen(draftingControllerProvider(params()), (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    test('learning cards are present from the first frame', () async {
      final container = makeContainer(agent);
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
        final container = makeContainer(agent);
        await container.read(draftingControllerProvider(params()).future);

        // Drain the event queue deterministically so the fire-and-forget
        // draftFuture listener completes and the controller pushes the
        // ready state — no magic-count delay loop (fake-time policy).
        await pumpEventQueue();

        final state = container
            .read(draftingControllerProvider(params()))
            .value;
        expect(state, isNotNull);
        expect(state!.phase, DraftingPhase.ready);
        expect(state.draft, isNotNull);
      },
    );

    test(
      'wires isCancelled to controller disposal: false while mounted, '
      'true after dispose',
      () async {
        final probe = _CancelProbeAgent(gate: Completer<void>());
        final container = makeContainer(probe);

        // Completing build() means summarizeRecentPatterns resolved and
        // draftDayPlan has been kicked off (and parked on the gate), so
        // the controller has handed us its isCancelled callback.
        await container.read(draftingControllerProvider(params()).future);

        final isCancelled = probe.capturedIsCancelled;
        expect(isCancelled, isNotNull);

        // While the controller is alive the closure reports not-cancelled.
        expect(isCancelled!(), isFalse);

        // Disposing the family element fires ref.onDispose, flipping the
        // `disposed` flag the closure closes over.
        container.dispose();
        expect(isCancelled(), isTrue);

        // Release the parked draft so nothing leaks; the controller is
        // already disposed so the resolution is a no-op.
        probe.gate.complete();
        await pumpEventQueue();
      },
    );
  });

  group('DraftingState.copyWith', () {
    const card = LearningCard(
      id: 'l1',
      overline: 'YESTERDAY',
      summary: 'A solid morning.',
      bullets: [],
    );
    final draft = DraftPlan(
      dayDate: DateTime(2026, 5, 25),
      blocks: const [],
      bands: const [],
      capacityMinutes: 480,
      scheduledMinutes: 0,
    );

    const base = DraftingState(
      phase: DraftingPhase.drafting,
      learningCards: [card],
      draft: null,
    );

    test('returns provided values when arguments are supplied', () {
      final updated = base.copyWith(
        phase: DraftingPhase.ready,
        learningCards: const [],
        draft: draft,
      );

      expect(updated.phase, DraftingPhase.ready);
      expect(updated.learningCards, isEmpty);
      expect(updated.draft, same(draft));
    });

    test('falls back to existing values when no arguments are supplied', () {
      final unchanged = base.copyWith();

      expect(unchanged.phase, DraftingPhase.drafting);
      expect(unchanged.learningCards, same(base.learningCards));
      expect(unchanged.draft, isNull);
    });

    test('updates a single field while preserving the rest', () {
      final readyOnly = base.copyWith(phase: DraftingPhase.ready);

      expect(readyOnly.phase, DraftingPhase.ready);
      // The other two fields fall through the `?? this.x` branches.
      expect(readyOnly.learningCards, same(base.learningCards));
      expect(readyOnly.draft, isNull);
    });
  });
}
