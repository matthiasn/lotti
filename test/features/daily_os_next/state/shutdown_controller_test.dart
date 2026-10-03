import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/shutdown_controller.dart';

import '../test_doubles/mock_day_agent.dart';

final _forDate = DateTime(2026, 5, 25);
final _nextDay = DateTime(2026, 5, 26);

/// Scripted agent that records every Shutdown write it receives.
class _RecordingAgent extends MockDayAgent {
  _RecordingAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

  final carryoverCalls =
      <
        ({
          DateTime forDate,
          String taskId,
          CarryoverAction action,
          DateTime? when,
        })
      >[];
  final reflections = <(DateTime, String)>[];
  Error? failCarryoverWith;
  TomorrowNote note = const TomorrowNote(body: 'Invoices first.');
  Error? failNoteWith;

  @override
  Future<void> recordCarryoverDecision({
    required DateTime forDate,
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {
    final failure = failCarryoverWith;
    if (failure != null) throw failure;
    carryoverCalls.add(
      (forDate: forDate, taskId: taskId, action: action, when: when),
    );
  }

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
  }) async => reflections.add((forDate, text));

  @override
  Future<TomorrowNote> generateTomorrowNote({required DateTime forDate}) async {
    final failure = failNoteWith;
    if (failure != null) throw failure;
    return note;
  }
}

void main() {
  late _RecordingAgent agent;
  late ProviderContainer container;

  setUp(() {
    agent = _RecordingAgent();
    container = ProviderContainer(
      overrides: [dayAgentProvider.overrideWithValue(agent)],
    )..listen(shutdownControllerProvider(_forDate), (_, _) {});
  });

  tearDown(() => container.dispose());

  ShutdownController notifier() =>
      container.read(shutdownControllerProvider(_forDate).notifier);

  Future<ShutdownData> load() =>
      container.read(shutdownControllerProvider(_forDate).future);

  test('build loads the day facts with no decisions yet', () async {
    final data = await load();

    expect(data.completed.map((item) => item.title).first, contains('Deck'));
    expect(data.carryover.map((item) => item.taskId), [
      't_onboarding_doc',
      't_invoices',
    ]);
    expect(data.carryover.first.suggestedDate, _nextDay);
    expect(data.metrics.focusMinutes, 215);
    expect(data.decisions, isEmpty);
  });

  group('applyCarryover', () {
    test('tomorrow re-places on the suggested day and records it', () async {
      await load();
      await notifier().applyCarryover(
        taskId: 't_onboarding_doc',
        action: CarryoverAction.tomorrow,
      );

      expect(agent.carryoverCalls.single, (
        forDate: _forDate,
        taskId: 't_onboarding_doc',
        action: CarryoverAction.tomorrow,
        when: null,
      ));
      expect(
        container.read(shutdownControllerProvider(_forDate)).value!.decisions,
        {
          't_onboarding_doc': (
            action: CarryoverAction.tomorrow,
            movedTo: _nextDay,
          ),
        },
      );
    });

    test('a picked date is forwarded and becomes the moved-to day', () async {
      final picked = DateTime(2026, 6, 2);
      await load();
      await notifier().applyCarryover(
        taskId: 't_invoices',
        action: CarryoverAction.pickDate,
        when: picked,
      );

      expect(agent.carryoverCalls.single.when, picked);
      expect(
        container.read(shutdownControllerProvider(_forDate)).value!.decisions,
        {'t_invoices': (action: CarryoverAction.pickDate, movedTo: picked)},
      );
    });

    test('a drop has no moved-to day and keeps earlier decisions', () async {
      await load();
      await notifier().applyCarryover(
        taskId: 't_onboarding_doc',
        action: CarryoverAction.tomorrow,
      );
      await notifier().applyCarryover(
        taskId: 't_invoices',
        action: CarryoverAction.drop,
      );

      expect(
        container.read(shutdownControllerProvider(_forDate)).value!.decisions,
        {
          't_onboarding_doc': (
            action: CarryoverAction.tomorrow,
            movedTo: _nextDay,
          ),
          't_invoices': (action: CarryoverAction.drop, movedTo: null),
        },
      );
    });

    test('a failed write throws and leaves the row undecided', () async {
      await load();
      agent.failCarryoverWith = StateError('offline');

      await expectLater(
        notifier().applyCarryover(
          taskId: 't_invoices',
          action: CarryoverAction.drop,
        ),
        throwsStateError,
      );
      expect(
        container.read(shutdownControllerProvider(_forDate)).value!.decisions,
        isEmpty,
      );
    });
  });

  test('submitReflection forwards the text for the day', () async {
    await load();
    await notifier().submitReflection('Afternoon dragged.');
    expect(agent.reflections, [(_forDate, 'Afternoon dragged.')]);
  });

  test('ensureReflectionEntry returns the day entry id', () async {
    await load();
    expect(await notifier().ensureReflectionEntry(), 'reflection-2026-5-25');
  });

  group('shutdownTomorrowNoteProvider', () {
    test('loads the note for the day', () async {
      expect(
        (await container.read(
          shutdownTomorrowNoteProvider(_forDate).future,
        )).body,
        'Invoices first.',
      );
    });

    test('surfaces a failure without touching the Shutdown data', () async {
      agent.failNoteWith = StateError('no provider');
      container.listen(shutdownTomorrowNoteProvider(_forDate), (_, _) {});

      await expectLater(
        container.read(shutdownTomorrowNoteProvider(_forDate).future),
        throwsStateError,
      );
      expect((await load()).carryover, hasLength(2));
    });
  });
}
