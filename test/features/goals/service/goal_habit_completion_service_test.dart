import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/goals/service/goal_habit_completion_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalDb journalDb;
  late MockAgentRepository agentRepository;
  late MockPersistenceLogic persistenceLogic;
  late MockWakeOrchestrator orchestrator;
  late GoalHabitCompletionService service;

  final habit = HabitDefinition(
    id: 'walk',
    name: 'Walk',
    description: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
    vectorClock: null,
    active: true,
    private: false,
    version: '1',
  );
  final activeGoal =
      AgentDomainEntity.agent(
            id: 'goal-1',
            agentId: 'goal-1',
            kind: 'goal',
            displayName: 'Walk goal',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '',
            config: const AgentConfig(),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  setUp(() {
    agentRepository = MockAgentRepository();
    journalDb = MockJournalDb();
    persistenceLogic = MockPersistenceLogic();
    orchestrator = MockWakeOrchestrator();
    service = GoalHabitCompletionService(
      agentRepository: agentRepository,
      journalDb: journalDb,
      persistenceLogic: persistenceLogic,
      orchestrator: orchestrator,
    );
    when(
      () => agentRepository.getEntity('goal-1'),
    ).thenAnswer((_) async => activeGoal);
    when(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
        workspaceKey: any(named: 'workspaceKey'),
      ),
    ).thenReturn('refresh-run');
    when(() => journalDb.getHabitById('walk')).thenAnswer((_) async => habit);
    when(
      () => persistenceLogic.createHabitCompletionEntry(
        data: any(named: 'data'),
        habitDefinition: any(named: 'habitDefinition'),
        comment: any(named: 'comment'),
      ),
    ).thenAnswer(
      (invocation) async {
        final data = invocation.namedArguments[#data]! as HabitCompletionData;
        return HabitCompletionEntry(
          meta: Metadata(
            id: 'saved',
            createdAt: data.dateFrom,
            updatedAt: data.dateFrom,
            dateFrom: data.dateFrom,
            dateTo: data.dateTo,
          ),
          data: data,
          entryText: const EntryText(plainText: ''),
        );
      },
    );
  });

  test('records today at the current time with the selected outcome', () async {
    final now = DateTime(2026, 8, 11, 14, 30);

    final saved = await withClock(
      Clock.fixed(now),
      () => service.record(
        agentId: 'goal-1',
        habitId: 'walk',
        day: DateTime.utc(2026, 8, 11),
        outcome: HabitCompletionType.success,
      ),
    );

    expect(saved, isTrue);
    final captured =
        verify(
              () => persistenceLogic.createHabitCompletionEntry(
                data: captureAny(named: 'data'),
                habitDefinition: habit,
                comment: '',
              ),
            ).captured.single
            as HabitCompletionData;
    expect(captured.dateFrom, now);
    expect(captured.dateTo, now);
    expect(captured.completionType, HabitCompletionType.success);
    verify(
      () => orchestrator.enqueueManualWake(
        agentId: 'goal-1',
        reason: WakeReason.reanalysis.name,
        triggerTokens: const {goalReportRefreshTriggerToken},
        workspaceKey: goalReportRefreshTriggerToken,
      ),
    ).called(1);
  });

  test(
    'records a historical miss on that date with the current wall-clock time',
    () async {
      final saved = await withClock(
        Clock.fixed(DateTime(2026, 8, 11, 14, 30)),
        () => service.record(
          agentId: 'goal-1',
          habitId: 'walk',
          day: DateTime.utc(2026, 8, 9),
          outcome: HabitCompletionType.fail,
        ),
      );

      expect(saved, isTrue);
      final captured =
          verify(
                () => persistenceLogic.createHabitCompletionEntry(
                  data: captureAny(named: 'data'),
                  habitDefinition: habit,
                  comment: '',
                ),
              ).captured.single
              as HabitCompletionData;
      expect(captured.dateFrom, DateTime(2026, 8, 9, 14, 30));
      expect(captured.completionType, HabitCompletionType.fail);
    },
  );

  test('historical corrections get distinct data timestamps so switching '
      'back to an earlier outcome can persist', () async {
    for (final now in [
      DateTime(2026, 8, 11, 14, 30),
      DateTime(2026, 8, 11, 14, 31),
    ]) {
      await withClock(
        Clock.fixed(now),
        () => service.record(
          agentId: 'goal-1',
          habitId: 'walk',
          day: DateTime.utc(2026, 8, 9),
          outcome: HabitCompletionType.success,
        ),
      );
    }

    final captured = verify(
      () => persistenceLogic.createHabitCompletionEntry(
        data: captureAny(named: 'data'),
        habitDefinition: habit,
        comment: '',
      ),
    ).captured.cast<HabitCompletionData>();
    expect(captured.map((data) => data.dateFrom), [
      DateTime(2026, 8, 9, 14, 30),
      DateTime(2026, 8, 9, 14, 31),
    ]);
    expect(captured.map((data) => data.dateFrom.toLocal().day).toSet(), {9});
  });

  test('does not write when the watched habit no longer exists', () async {
    when(() => journalDb.getHabitById('walk')).thenAnswer((_) async => null);

    final saved = await service.record(
      agentId: 'goal-1',
      habitId: 'walk',
      day: DateTime.utc(2026, 8, 11),
      outcome: HabitCompletionType.success,
    );

    expect(saved, isFalse);
    verifyNever(
      () => persistenceLogic.createHabitCompletionEntry(
        data: any(named: 'data'),
        habitDefinition: any(named: 'habitDefinition'),
        comment: any(named: 'comment'),
      ),
    );
    verifyNever(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
        workspaceKey: any(named: 'workspaceKey'),
      ),
    );
  });

  test('does not write when the goal agent is no longer active', () async {
    when(() => agentRepository.getEntity('goal-1')).thenAnswer(
      (_) async => activeGoal.copyWith(lifecycle: AgentLifecycle.dormant),
    );

    final saved = await service.record(
      agentId: 'goal-1',
      habitId: 'walk',
      day: DateTime.utc(2026, 8, 11),
      outcome: HabitCompletionType.success,
    );

    expect(saved, isFalse);
    verifyNever(() => journalDb.getHabitById(any()));
    verifyNever(
      () => persistenceLogic.createHabitCompletionEntry(
        data: any(named: 'data'),
        habitDefinition: any(named: 'habitDefinition'),
        comment: any(named: 'comment'),
      ),
    );
  });

  for (final (description, definition, selectedDay) in [
    (
      'habit is inactive',
      habit.copyWith(active: false),
      DateTime(2026, 8, 11),
    ),
    (
      'day is before the habit starts',
      habit.copyWith(activeFrom: DateTime(2026, 8, 10)),
      DateTime(2026, 8, 9),
    ),
    (
      'day is the exclusive habit end date',
      habit.copyWith(activeUntil: DateTime(2026, 8, 10)),
      DateTime(2026, 8, 10),
    ),
    (
      'day is after the habit end date',
      habit.copyWith(activeUntil: DateTime(2026, 8, 10)),
      DateTime(2026, 8, 11),
    ),
    ('day is in the future', habit, DateTime(2026, 8, 12)),
  ]) {
    test('does not write when $description', () async {
      when(
        () => journalDb.getHabitById('walk'),
      ).thenAnswer((_) async => definition);

      final saved = await withClock(
        Clock.fixed(DateTime(2026, 8, 11, 14, 30)),
        () => service.record(
          agentId: 'goal-1',
          habitId: 'walk',
          day: selectedDay,
          outcome: HabitCompletionType.success,
        ),
      );

      expect(saved, isFalse);
      verifyNever(
        () => persistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          habitDefinition: any(named: 'habitDefinition'),
          comment: any(named: 'comment'),
        ),
      );
      verifyNever(
        () => orchestrator.enqueueManualWake(
          agentId: any(named: 'agentId'),
          reason: any(named: 'reason'),
          triggerTokens: any(named: 'triggerTokens'),
          workspaceKey: any(named: 'workspaceKey'),
        ),
      );
    });
  }
}
