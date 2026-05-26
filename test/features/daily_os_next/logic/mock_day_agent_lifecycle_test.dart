import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';

/// Tests for the lifecycle tools added when the Commit, Shutdown and
/// Tasks corpus screens shipped. Kept in a dedicated file so the
/// growing mock_day_agent_test.dart stays focused on the earlier
/// capture / reconcile / drafting paths.
void main() {
  group('MockDayAgent lifecycle', () {
    late MockDayAgent agent;

    setUp(() {
      agent = MockDayAgent(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );
    });

    test(
      'commitDay flips drafted blocks to committed and the plan state',
      () async {
        final plan = await agent.draftDayPlan(
          captureId: const CaptureId('cap'),
          decidedTaskIds: const ['t_deck_review'],
          dayDate: DateTime(2026, 5, 25),
        );
        // The freshly-drafted plan is, by construction, drafted.
        expect(plan.state, DayState.drafted);
        expect(
          plan.blocks.any((b) => b.state == TimeBlockState.drafted),
          isTrue,
        );

        final committed = await agent.commitDay(plan);
        expect(committed.state, DayState.committed);
        // No drafted blocks remain — they all transitioned.
        expect(
          committed.blocks.any((b) => b.state == TimeBlockState.drafted),
          isFalse,
        );
        // Real calendar events keep their original state — the
        // prototype's calendar block is already committed.
        expect(
          committed.blocks
              .where((b) => b.type == TimeBlockType.cal)
              .every((b) => b.state == TimeBlockState.committed),
          isTrue,
        );
      },
    );

    test(
      'surfaceShutdownData returns completed + carryover + metrics',
      () async {
        final result = await agent.surfaceShutdownData(
          forDate: DateTime(2026, 5, 25),
        );
        expect(result.completed, isNotEmpty);
        expect(result.carryover, isNotEmpty);
        expect(result.metrics.focusMinutes, greaterThan(0));
        expect(result.metrics.flowSessions, greaterThan(0));
        // Every carryover row carries a suggestedTarget label so the
        // primary teal chip always has something to render.
        for (final item in result.carryover) {
          expect(item.suggestedTarget, isNotEmpty);
        }
      },
    );

    test('generateTomorrowNote returns a non-empty body', () async {
      final note = await agent.generateTomorrowNote(
        forDate: DateTime(2026, 5, 25),
      );
      expect(note.body, isNotEmpty);
      expect(note.maturity, greaterThanOrEqualTo(1));
    });

    test(
      'recordReflection + recordCarryoverDecision are side-effect-only',
      () async {
        // These are no-ops in the mock; the test just verifies they
        // complete without throwing — the real agent layer will
        // persist + emit feedback events.
        await agent.recordReflection(
          forDate: DateTime(2026, 5, 25),
          text: 'morning was sharp',
          source: ReflectionSource.typed,
        );
        await agent.recordCarryoverDecision(
          taskId: 't_onboarding_doc',
          action: CarryoverAction.tomorrow,
        );
      },
    );

    group('surfaceTaskCorpus', () {
      test('default filter returns the full corpus', () async {
        final all = await agent.surfaceTaskCorpus();
        expect(all, isNotEmpty);
        // The corpus must include every TaskCorpusState the filter
        // chip row knows about, except `all` (which is a meta state).
        final present = all.map((i) => i.state).toSet();
        expect(present, contains(TaskCorpusState.inProgress));
        expect(present, contains(TaskCorpusState.overdue));
      });

      test('state filter narrows to matching items', () async {
        final overdue = await agent.surfaceTaskCorpus(
          stateFilter: TaskCorpusState.overdue,
        );
        expect(overdue, isNotEmpty);
        expect(
          overdue.every((i) => i.state == TaskCorpusState.overdue),
          isTrue,
        );
      });

      test('query filters by title substring (case-insensitive)', () async {
        final hits = await agent.surfaceTaskCorpus(query: 'deck');
        expect(hits, isNotEmpty);
        expect(
          hits.every((i) => i.title.toLowerCase().contains('deck')),
          isTrue,
        );

        final noMatch = await agent.surfaceTaskCorpus(query: 'zzzz');
        expect(noMatch, isEmpty);
      });
    });
  });
}
