import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../helpers/fake_linked_entries_controller.dart';
import '../../../helpers/service_overrides.dart';
import '../../../helpers/test_get_it.dart';
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
      overrides: withServiceOverrides([
        goalRepositoryProvider.overrideWithValue(withJournal ? goals : null),
        goalMirrorServiceProvider.overrideWithValue(
          withJournal ? mirror : null,
        ),
      ]),
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

  group('goalCategoryIdProvider', () {
    test("is the goal row's category, which its check-ins take", () async {
      final goal = goalEntry('goal-1');
      when(() => goals.getGoalForAgent('agent-1')).thenAnswer(
        (_) async => goal.copyWith(
          meta: goal.meta.copyWith(categoryId: 'fitness'),
        ),
      );

      expect(
        await container().read(goalCategoryIdProvider('agent-1').future),
        'fitness',
      );
    });

    test('is null for an uncategorized goal, a goal with no row yet, and '
        'without the journal stack', () async {
      when(
        () => goals.getGoalForAgent('agent-1'),
      ).thenAnswer((_) async => goalEntry('goal-1'));
      expect(
        await container().read(goalCategoryIdProvider('agent-1').future),
        isNull,
      );

      when(
        () => goals.getGoalForAgent('agent-1'),
      ).thenAnswer((_) async => null);
      expect(
        await container().read(goalCategoryIdProvider('agent-1').future),
        isNull,
      );

      expect(
        await container(
          withJournal: false,
        ).read(goalCategoryIdProvider('agent-1').future),
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

  group('goalCheckInsLoadProvider', () {
    // An entry controller reads its services from GetIt as it is built.
    setUp(
      () => setUpTestGetIt(
        additionalSetup: () => getIt.registerSingleton<EditorStateService>(
          MockEditorStateService(),
        ),
      ),
    );
    tearDown(tearDownTestGetIt);

    final link = EntryLink.basic(
      id: 'link-1',
      fromId: 'goal-1',
      toId: 'note-1',
      createdAt: at,
      updatedAt: at,
      vectorClock: null,
    );
    final note = JournalEntry(
      meta: meta('note-1'),
      entryText: const EntryText(plainText: 'Gym bag packed.'),
    );

    Future<GoalCheckInsLoad> loadWith(
      List<Override> overrides, {
      bool withJournal = true,
    }) async {
      final c = ProviderContainer(
        overrides: withServiceOverrides([
          goalRepositoryProvider.overrideWithValue(withJournal ? goals : null),
          goalMirrorServiceProvider.overrideWithValue(
            withJournal ? mirror : null,
          ),
          ...overrides,
        ]),
      );
      addTearDown(c.dispose);
      final sub = c.listen(goalCheckInsLoadProvider('agent-1'), (_, _) {});
      addTearDown(sub.close);
      // Let the futures behind it settle (or fail) first.
      await pumpEventQueue();
      return c.read(goalCheckInsLoadProvider('agent-1'));
    }

    test('settled once the links, their entries and the assessments have '
        'all been read', () async {
      expect(
        await loadWith([
          goalAssessmentHistoryProvider(
            'agent-1',
          ).overrideWith((ref) async => []),
          linkedEntriesControllerProvider(
            'goal-1',
          ).overrideWith(() => FakeLinkedEntriesController(links: [link])),
          createEntryControllerOverride(note),
        ]),
        GoalCheckInsLoad.settled,
      );
    });

    test('loading while the assessments are still on their way', () async {
      final never = Completer<List<GoalAssessmentRecord>>();
      expect(
        await loadWith([
          goalAssessmentHistoryProvider(
            'agent-1',
          ).overrideWith((ref) => never.future),
          linkedEntriesControllerProvider(
            'goal-1',
          ).overrideWith(FakeLinkedEntriesController.new),
        ]),
        GoalCheckInsLoad.loading,
      );
    });

    test('loading while a linked entry is still on its way', () async {
      expect(
        await loadWith([
          goalAssessmentHistoryProvider(
            'agent-1',
          ).overrideWith((ref) async => []),
          linkedEntriesControllerProvider(
            'goal-1',
          ).overrideWith(() => FakeLinkedEntriesController(links: [link])),
          entryControllerProvider('note-1').overrideWith(_PendingEntry.new),
        ]),
        GoalCheckInsLoad.loading,
      );
    });

    test(
      'failed when a linked entry could not be read, never settled',
      () async {
        expect(
          await loadWith([
            goalAssessmentHistoryProvider(
              'agent-1',
            ).overrideWith((ref) async => []),
            linkedEntriesControllerProvider(
              'goal-1',
            ).overrideWith(() => FakeLinkedEntriesController(links: [link])),
            entryControllerProvider('note-1').overrideWith(_FailingEntry.new),
          ]),
          GoalCheckInsLoad.failed,
        );
      },
    );

    test(
      'failed when a read failed, so the rail never calls it empty',
      () async {
        expect(
          await loadWith([
            goalAssessmentHistoryProvider(
              'agent-1',
            ).overrideWith((ref) async => throw StateError('db gone')),
            linkedEntriesControllerProvider(
              'goal-1',
            ).overrideWith(FakeLinkedEntriesController.new),
          ]),
          GoalCheckInsLoad.failed,
        );
      },
    );

    test('settled with no goal row: nothing is linked to read', () async {
      expect(
        await loadWith([
          goalAssessmentHistoryProvider(
            'agent-1',
          ).overrideWith((ref) async => []),
        ], withJournal: false),
        GoalCheckInsLoad.settled,
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
        overrides: withServiceOverrides([
          goalRepositoryProvider.overrideWithValue(goals),
          goalMirrorServiceProvider.overrideWithValue(mirror),
          resolvedOutgoingLinkedEntriesProvider(
            'goal-1',
          ).overrideWithValue([entry]),
        ]),
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

  group('goalAudioTranscriptionFailedProvider', () {
    test('restores a durable failure after transient state is gone', () async {
      final consumption = MockConsumptionRepository();
      final failed = AiWorkAttribution(
        id: 'attempt-1',
        workType: AiWorkType.audioTranscription,
        status: AiWorkStatus.failed,
        initiator: const AiActorSnapshot(
          type: AiActorType.human,
          id: 'user-1',
          displayName: 'User',
        ),
        trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
        startedAt: at,
        completedAt: at.add(const Duration(seconds: 1)),
        vectorClock: null,
        primaryOutput: const AiArtifactReference(
          type: AiArtifactType.journalAudio,
          id: 'audio-1',
          subId: 'transcript-1',
        ),
      );
      when(
        () => consumption.getLatestAttributionForArtifact(
          type: AiArtifactType.journalAudio,
          id: 'audio-1',
        ),
      ).thenAnswer((_) async => failed);
      final c = ProviderContainer(
        overrides: withServiceOverrides([
          consumptionRepositoryProvider.overrideWithValue(consumption),
        ]),
      );
      addTearDown(c.dispose);

      expect(
        await c.read(
          goalAudioTranscriptionFailedProvider('audio-1').future,
        ),
        isTrue,
      );
    });

    test('a later successful retry clears durable failure', () async {
      final consumption = MockConsumptionRepository();
      when(
        () => consumption.getLatestAttributionForArtifact(
          type: AiArtifactType.journalAudio,
          id: 'audio-1',
        ),
      ).thenAnswer(
        (_) async => AiWorkAttribution(
          id: 'attempt-2',
          workType: AiWorkType.audioTranscription,
          status: AiWorkStatus.succeeded,
          initiator: const AiActorSnapshot(
            type: AiActorType.human,
            id: 'user-1',
            displayName: 'User',
          ),
          trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
          startedAt: at,
          completedAt: at.add(const Duration(seconds: 1)),
          vectorClock: null,
          primaryOutput: const AiArtifactReference(
            type: AiArtifactType.journalAudio,
            id: 'audio-1',
            subId: 'transcript-2',
          ),
        ),
      );
      final c = ProviderContainer(
        overrides: withServiceOverrides([
          consumptionRepositoryProvider.overrideWithValue(consumption),
        ]),
      );
      addTearDown(c.dispose);

      expect(
        await c.read(
          goalAudioTranscriptionFailedProvider('audio-1').future,
        ),
        isFalse,
      );
    });
  });
}

/// An entry whose read never finishes: the rail must wait for it.
class _PendingEntry extends EntryController {
  @override
  Future<EntryState?> build() => Completer<EntryState?>().future;
}

/// An entry whose read fails: the rail cannot call the history empty.
class _FailingEntry extends EntryController {
  @override
  Future<EntryState?> build() async => throw StateError('entry unreadable');
}
