import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/shutdown_controller.dart';

void main() {
  group('ShutdownController', () {
    final forDate = DateTime(2026, 5, 25);

    MockDayAgent freshAgent() => MockDayAgent(
      parseLatency: Duration.zero,
      pendingLatency: Duration.zero,
      triageLatency: Duration.zero,
      summarizeLatency: Duration.zero,
      clock: () => DateTime(2026, 5, 25, 18),
    );

    ProviderContainer makeContainer(DayAgentInterface agent) {
      final container = ProviderContainer(
        overrides: [dayAgentProvider.overrideWithValue(agent)],
      )..listen(shutdownControllerProvider(forDate), (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    test(
      'build merges surfaceShutdownData and generateTomorrowNote into one '
      'snapshot',
      () async {
        final container = makeContainer(freshAgent());

        final data = await container.read(
          shutdownControllerProvider(forDate).future,
        );

        expect(data.completed, hasLength(2));
        expect(data.completed.first.taskId, 't_deck_review');
        expect(data.carryover, hasLength(2));
        expect(data.carryover.first.taskId, 't_onboarding_doc');
        expect(data.metrics.focusMinutes, 215);
        expect(data.metrics.flowSessions, 3);
        expect(data.tomorrowNote.maturity, 1);
        expect(data.tomorrowNote.body, contains('Onboarding doc'));
        expect(data.decisions, isEmpty);
      },
    );

    test(
      'applyCarryover records the decision and merges it into state without '
      'touching unrelated decisions',
      () async {
        final agent = _RecordingAgent();
        final container = makeContainer(agent);
        await container.read(shutdownControllerProvider(forDate).future);

        await container
            .read(shutdownControllerProvider(forDate).notifier)
            .applyCarryover(
              taskId: 't_onboarding_doc',
              action: CarryoverAction.tomorrow,
            );

        expect(agent.carryoverCalls, hasLength(1));
        expect(agent.carryoverCalls.single.$1, 't_onboarding_doc');
        expect(agent.carryoverCalls.single.$2, CarryoverAction.tomorrow);

        var data = container.read(shutdownControllerProvider(forDate)).value!;
        expect(
          data.decisions,
          {'t_onboarding_doc': CarryoverAction.tomorrow},
        );

        await container
            .read(shutdownControllerProvider(forDate).notifier)
            .applyCarryover(
              taskId: 't_invoices',
              action: CarryoverAction.drop,
            );

        data = container.read(shutdownControllerProvider(forDate)).value!;
        expect(data.decisions, {
          't_onboarding_doc': CarryoverAction.tomorrow,
          't_invoices': CarryoverAction.drop,
        });
      },
    );

    test(
      'submitReflection forwards forDate, text, and source to the agent',
      () async {
        final agent = _RecordingAgent();
        final container = makeContainer(agent);
        await container.read(shutdownControllerProvider(forDate).future);

        await container
            .read(shutdownControllerProvider(forDate).notifier)
            .submitReflection(
              text: 'Felt steady today.',
              source: ReflectionSource.voice,
            );

        expect(agent.reflectionCalls, hasLength(1));
        final call = agent.reflectionCalls.single;
        expect(call.$1, forDate);
        expect(call.$2, 'Felt steady today.');
        expect(call.$3, ReflectionSource.voice);
      },
    );

    test(
      'applyCarryover is a no-op when build has not produced a snapshot yet',
      () async {
        // Construct the notifier directly so `state.value` is the initial
        // AsyncLoading rather than an AsyncData.
        final agent = _RecordingAgent();
        final container = ProviderContainer(
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        );
        addTearDown(container.dispose);

        // No listen() + no awaiting future = stays loading.
        await container
            .read(shutdownControllerProvider(forDate).notifier)
            .applyCarryover(
              taskId: 't_onboarding_doc',
              action: CarryoverAction.tomorrow,
            );

        expect(agent.carryoverCalls, isEmpty);
      },
    );
  });
}

class _RecordingAgent extends MockDayAgent {
  _RecordingAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 18),
      );

  final List<(String, CarryoverAction)> carryoverCalls = [];
  final List<(DateTime, String, ReflectionSource)> reflectionCalls = [];

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {
    carryoverCalls.add((taskId, action));
    await super.recordCarryoverDecision(
      taskId: taskId,
      action: action,
      when: when,
    );
  }

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) async {
    reflectionCalls.add((forDate, text, source));
    await super.recordReflection(
      forDate: forDate,
      text: text,
      source: source,
    );
  }
}
