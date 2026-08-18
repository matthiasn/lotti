import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  final at = DateTime(2026, 8, 18, 9);

  const criteria = GoalCriterion.habit(
    criterionId: 'walk',
    habitId: 'habit-walk',
    targetCount: 5,
    window: GoalWindow.rollingDays(count: 7),
  );

  Metadata meta(String id) => Metadata(
    id: id,
    createdAt: at,
    updatedAt: at,
    dateFrom: at,
    dateTo: at,
  );

  GoalEntry goalEntry(String id) => GoalEntry(
    meta: meta(id),
    data: const GoalData(
      title: 'Walk more',
      statement: 'Walk on five days a week.',
      criteria: criteria,
      specVersion: 1,
      specVersionId: 'snap-1',
    ),
  );

  late MockGoalRepository goals;
  late MockGoalMirrorService mirror;

  setUp(() {
    goals = MockGoalRepository();
    mirror = MockGoalMirrorService();
    when(() => goals.goalIdForAgent('agent-1')).thenReturn('goal-1');
  });

  ProviderContainer container({bool withJournal = true}) {
    final c = ProviderContainer(
      overrides: [
        goalRepositoryProvider.overrideWithValue(withJournal ? goals : null),
        goalMirrorServiceProvider.overrideWithValue(
          withJournal ? mirror : null,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('goalEntryIdProvider', () {
    test('derives the id without touching the database', () {
      expect(container().read(goalEntryIdProvider('agent-1')), 'goal-1');
      verifyNever(() => goals.getGoalForAgent(any()));
    });

    test('is null where the journal stack is unavailable', () {
      expect(
        container(withJournal: false).read(goalEntryIdProvider('agent-1')),
        isNull,
      );
    });
  });

  group('goalCaptureTargetProvider', () {
    test('returns the existing goal row', () async {
      when(
        () => goals.getGoalForAgent('agent-1'),
      ).thenAnswer((_) async => goalEntry('goal-1'));

      expect(
        await container().read(goalCaptureTargetProvider('agent-1').future),
        'goal-1',
      );
      verifyNever(() => mirror.mirrorHead(any()));
    });

    test(
      'repairs a missing mirror rather than refusing the recording',
      () async {
        // A freshly synced goal has no journal row until the backfill runs;
        // refusing capture until then would lose the moment the user wanted to
        // record.
        when(
          () => goals.getGoalForAgent('agent-1'),
        ).thenAnswer((_) async => null);
        when(
          () => mirror.mirrorHead('agent-1'),
        ).thenAnswer((_) async => goalEntry('goal-1'));

        expect(
          await container().read(goalCaptureTargetProvider('agent-1').future),
          'goal-1',
        );
        verify(() => mirror.mirrorHead('agent-1')).called(1);
      },
    );

    test('is null when no row can be produced', () async {
      // Capture must be withheld rather than silently creating an unlinked
      // entry that never reaches the timeline.
      when(
        () => goals.getGoalForAgent('agent-1'),
      ).thenAnswer((_) async => null);
      when(() => mirror.mirrorHead('agent-1')).thenAnswer((_) async => null);

      expect(
        await container().read(goalCaptureTargetProvider('agent-1').future),
        isNull,
      );
    });

    test('is null where the journal stack is unavailable', () async {
      expect(
        await container(
          withJournal: false,
        ).read(goalCaptureTargetProvider('agent-1').future),
        isNull,
      );
    });
  });

  group('goalCheckInEntriesProvider', () {
    test('resolves the entries linked to the goal row', () {
      final entry = JournalEntry(
        meta: meta('note-1'),
        entryText: const EntryText(plainText: 'Gym bag packed.'),
      );
      final c = ProviderContainer(
        overrides: [
          goalRepositoryProvider.overrideWithValue(goals),
          goalMirrorServiceProvider.overrideWithValue(mirror),
          resolvedOutgoingLinkedEntriesProvider(
            'goal-1',
          ).overrideWithValue([entry]),
        ],
      );
      addTearDown(c.dispose);

      expect(c.read(goalCheckInEntriesProvider('agent-1')), [entry]);
    });

    test('is empty where the journal stack is unavailable', () {
      expect(
        container(withJournal: false).read(
          goalCheckInEntriesProvider('agent-1'),
        ),
        isEmpty,
      );
    });
  });
}
