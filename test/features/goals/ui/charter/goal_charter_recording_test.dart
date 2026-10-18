import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/charter/goal_charter_recording.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockGoalRepository repository;
  late MockDomainLogger logger;
  late List<TriggerSkillParams> transcribed;
  late List<String?> recordedInCategory;
  Error? transcriptionError;

  final goal = GoalEntry(
    meta: Metadata(
      id: 'goal-row',
      createdAt: DateTime(2026, 8),
      updatedAt: DateTime(2026, 8),
      dateFrom: DateTime(2026, 8),
      dateTo: DateTime(2026, 8),
      categoryId: 'cat-journal',
    ),
    data: const GoalData(
      title: 'Daily journal',
      statement: 'Reflect every day.',
      criteria: GoalCriterion.checkInTime(
        criterionId: 'reflect',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetMinutes: 3,
      ),
      specVersion: 1,
      specVersionId: 'agent-1:spec-v1',
    ),
  );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    repository = MockGoalRepository();
    logger = MockDomainLogger();
    transcribed = [];
    recordedInCategory = [];
    transcriptionError = null;
    when(
      () => repository.getGoalForAgent('agent-1'),
    ).thenAnswer((_) async => goal);
  });

  /// Pumps a button that runs the flow with [recorded] standing in for the
  /// recording sheet, and taps it.
  Future<void> record(
    WidgetTester tester, {
    String? recorded = 'audio-1',
    bool journalStack = true,
  }) async {
    var opened = false;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => DesignSystemButton(
            label: 'record',
            onPressed: () => recordGoalCharterEntry(
              context,
              agentId: 'agent-1',
              recordAudio: (_, {categoryId}) async {
                opened = true;
                recordedInCategory.add(categoryId);
                return recorded;
              },
            ),
          ),
        ),
        overrides: [
          goalRepositoryProvider.overrideWithValue(
            journalStack ? repository : null,
          ),
          domainLoggerProvider.overrideWithValue(logger),
          triggerSkillProvider.overrideWith((ref, params) async {
            transcribed.add(params);
            if (transcriptionError case final error?) throw error;
          }),
        ],
      ),
    );
    await tester.tap(find.text('record'));
    await tester.pump();
    await tester.pump();
    expect(opened, journalStack, reason: 'the recorder opens with a stack');
  }

  testWidgets("records in the goal's category, links the recording into the "
      'charter, then transcribes that recording', (tester) async {
    when(
      () => repository.attachCharterRecording(
        agentId: any(named: 'agentId'),
        audioId: any(named: 'audioId'),
      ),
    ).thenAnswer((_) async => true);

    await record(tester);

    expect(recordedInCategory, ['cat-journal']);
    verify(
      () => repository.attachCharterRecording(
        agentId: 'agent-1',
        audioId: 'audio-1',
      ),
    ).called(1);
    expect(transcribed.single.entityId, 'audio-1');
    expect(transcribed.single.skillId, skillTranscribeContextId);
  });

  testWidgets('a cancelled recording changes nothing', (tester) async {
    await record(tester, recorded: null);

    verifyNever(
      () => repository.attachCharterRecording(
        agentId: any(named: 'agentId'),
        audioId: any(named: 'audioId'),
      ),
    );
    expect(transcribed, isEmpty);
  });

  testWidgets('a recording that cannot join the charter says so and is not '
      'transcribed', (tester) async {
    when(
      () => repository.attachCharterRecording(
        agentId: any(named: 'agentId'),
        audioId: any(named: 'audioId'),
      ),
    ).thenAnswer((_) async => false);

    await record(tester);

    expect(find.text("That didn't save. Try again."), findsOneWidget);
    expect(transcribed, isEmpty);
  });

  testWidgets('a link that throws is logged and reported', (tester) async {
    when(
      () => repository.attachCharterRecording(
        agentId: any(named: 'agentId'),
        audioId: any(named: 'audioId'),
      ),
    ).thenThrow(StateError('db gone'));

    await record(tester);

    expect(find.text("That didn't save. Try again."), findsOneWidget);
    expect(transcribed, isEmpty);
    verify(
      () => logger.error(
        LogDomain.general,
        any(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace', that: isNotNull),
        subDomain: 'GoalCharterRecording',
        message: 'Failed to link a recording into a goal charter',
      ),
    ).called(1);
  });

  testWidgets('a transcription that cannot start is logged; the recording '
      'stays in the charter', (tester) async {
    when(
      () => repository.attachCharterRecording(
        agentId: any(named: 'agentId'),
        audioId: any(named: 'audioId'),
      ),
    ).thenAnswer((_) async => true);
    transcriptionError = StateError('no model');

    await record(tester);

    expect(transcribed.single.entityId, 'audio-1');
    expect(find.text("That didn't save. Try again."), findsNothing);
    verify(
      () => logger.error(
        LogDomain.general,
        any(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace', that: isNotNull),
        subDomain: 'GoalCharterRecording',
        message: 'Failed to start transcribing a goal charter recording',
      ),
    ).called(1);
  });

  testWidgets('without a journal stack the recorder never opens', (
    tester,
  ) async {
    await record(tester, journalStack: false);

    expect(recordedInCategory, isEmpty);
  });
}
