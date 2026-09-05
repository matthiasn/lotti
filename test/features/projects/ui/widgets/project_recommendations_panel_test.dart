import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_widgets_part.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/projects/ui/widgets/project_recommendations_panel.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';

void main() {
  const projectId = 'project-1';
  late MockProjectRecommendationService service;
  late MockChangeSetConfirmationService confirmation;
  setUpAll(registerAllFallbackValues);
  setUp(() {
    service = MockProjectRecommendationService();
    confirmation = MockChangeSetConfirmationService();
  });

  final recommendations = [
    makeTestProjectRecommendation(
      id: 'recommendation-1',
      agentId: 'agent-1',
      projectId: projectId,
      title: 'Unblock launch QA',
      rationale: 'The staging dataset is incomplete.',
    ),
    makeTestProjectRecommendation(
      id: 'recommendation-2',
      agentId: 'agent-1',
      projectId: projectId,
      title: 'Confirm the launch manifest',
    ),
  ];
  final changeSet = makeTestChangeSet(
    id: 'set-1',
    agentId: 'agent-1',
    taskId: projectId,
    items: [
      const ChangeItem(
        toolName: 'create_task',
        args: {'title': 'Pack fish'},
        humanSummary: 'Create task',
      ),
    ],
  );

  Widget subject({
    List<ProjectRecommendationEntity>? items,
    List<AgentDomainEntity> sets = const [],
    Future<List<ProjectRecommendationEntity>> Function()? load,
  }) => makeTestableWidgetWithScaffold(
    const ProjectRecommendationsPanel(projectId: projectId),
    overrides: [
      projectNextStepsProvider(projectId).overrideWith(
        (ref) async => ProjectNextStepsSnapshot(
          steps: await (load?.call() ?? Future.value(items ?? recommendations)),
          runCreatedAt: null,
        ),
      ),
      projectPendingChangeSetsProvider(
        projectId,
      ).overrideWith((ref) async => sets),
      projectRecommendationServiceProvider.overrideWithValue(service),
      projectChangeSetConfirmationServiceProvider.overrideWithValue(
        confirmation,
      ),
      agentUpdateStreamProvider(
        'agent-1',
      ).overrideWith((ref) => const Stream.empty()),
    ],
  );

  testWidgets('shows actual text, shared row controls and one confirm-all', (
    tester,
  ) async {
    await tester.pumpWidget(subject(sets: [changeSet]));
    await tester.pumpAndSettle();
    expect(find.text('Recommended next steps'), findsOneWidget);
    expect(find.text('Unblock launch QA'), findsOneWidget);
    expect(find.text('The staging dataset is incomplete.'), findsOneWidget);
    expect(find.text('Create task: Pack fish'), findsOneWidget);
    expect(find.text('Confirm all'), findsOneWidget);
    expect(find.byType(RowActions), findsNWidgets(3));
  });

  testWidgets('individual confirmation removes only that suggestion', (
    tester,
  ) async {
    when(() => service.markResolved(any())).thenAnswer((_) async => true);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Confirm').first);
    await tester.pumpAndSettle();
    verify(() => service.markResolved('recommendation-1')).called(1);
    verifyNever(() => service.markResolved('recommendation-2'));
    expect(find.text('Unblock launch QA'), findsNothing);
    expect(find.text('Confirm the launch manifest'), findsOneWidget);
  });

  testWidgets('individual dismissal preserves the other suggestion', (
    tester,
  ) async {
    when(
      () => service.dismissRecommendation(any()),
    ).thenAnswer((_) async => true);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reject').first);
    await tester.pumpAndSettle();
    verify(() => service.dismissRecommendation('recommendation-1')).called(1);
    expect(find.text('Unblock launch QA'), findsNothing);
    expect(find.text('Confirm the launch manifest'), findsOneWidget);
  });

  testWidgets(
    'create task consumes the suggestion without resolving siblings',
    (tester) async {
      when(() => service.createTask(any())).thenAnswer(
        (_) async => const ToolExecutionResult(
          success: true,
          output: '',
          mutatedEntityId: 'task-1',
        ),
      );
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add task').first);
      await tester.pumpAndSettle();
      verify(() => service.createTask('recommendation-1')).called(1);
      verifyNever(() => service.markResolved(any()));
      expect(find.text('Unblock launch QA'), findsNothing);
      expect(find.text('Confirm the launch manifest'), findsOneWidget);
    },
  );

  testWidgets('created task warnings consume the suggestion and stay visible', (
    tester,
  ) async {
    when(() => service.createTask(any())).thenAnswer(
      (_) async => const ToolExecutionResult(
        success: true,
        output: '',
        mutatedEntityId: 'task-1',
        errorMessage: 'Agent assignment unavailable',
      ),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add task').first);
    await tester.pumpAndSettle();
    expect(find.text('Unblock launch QA'), findsNothing);
    expect(find.textContaining('Agent assignment unavailable'), findsOneWidget);
  });

  testWidgets(
    'disposing during a pending action completes without stale UI writes',
    (tester) async {
      final pending = Completer<bool>();
      when(() => service.markResolved(any())).thenAnswer((_) => pending.future);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Confirm').first);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(true);
      await tester.pump();
      expect(tester.takeException(), isNull);
      verify(() => service.markResolved('recommendation-1')).called(1);
    },
  );

  testWidgets('confirm-all handles suggestions and proposals independently', (
    tester,
  ) async {
    when(
      () => service.markResolved('recommendation-1'),
    ).thenAnswer((_) async => true);
    when(
      () => service.markResolved('recommendation-2'),
    ).thenAnswer((_) async => false);
    when(() => confirmation.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(success: true, output: ''),
    );
    await tester.pumpWidget(subject(sets: [changeSet]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm all'));
    await tester.pumpAndSettle();
    verify(() => service.markResolved('recommendation-1')).called(1);
    verify(() => service.markResolved('recommendation-2')).called(1);
    verify(() => confirmation.confirmItem(changeSet, 0)).called(1);
    expect(find.text('Unblock launch QA'), findsNothing);
    expect(find.text('Create task: Pack fish'), findsNothing);
    expect(find.text('Confirm the launch manifest'), findsOneWidget);
    expect(
      find.text("Couldn't update the recommendation. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('all actions stay inert while creating a task', (tester) async {
    final pending = Completer<ToolExecutionResult>();
    when(() => service.createTask(any())).thenAnswer((_) => pending.future);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add task').first);
    await tester.pump();
    expect(
      tester
          .widgetList<RowActions>(find.byType(RowActions))
          .every((row) => row.busy),
      isTrue,
    );
    expect(
      tester
          .widgetList<DesignSystemIconAction>(
            find.byType(DesignSystemIconAction),
          )
          .every((row) => row.onPressed == null),
      isTrue,
    );
    pending.complete(
      const ToolExecutionResult(success: false, output: 'failed'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unblock launch QA'), findsOneWidget);
    expect(
      find.text("Couldn't update the recommendation. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('throwing actions retain suggestions and surface an error', (
    tester,
  ) async {
    when(() => service.markResolved(any())).thenThrow(StateError('failed'));
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Confirm').first);
    await tester.pumpAndSettle();
    expect(find.text('Unblock launch QA'), findsOneWidget);
    expect(
      find.text("Couldn't update the recommendation. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('mutation-only list has individual reject and confirm controls', (
    tester,
  ) async {
    when(
      () => confirmation.rejectItem(any(), any()),
    ).thenAnswer((_) async => true);
    await tester.pumpWidget(subject(items: [], sets: [changeSet]));
    await tester.pumpAndSettle();
    expect(find.text('Proposed changes'), findsOneWidget);
    await tester.tap(find.byTooltip('Reject'));
    await tester.pumpAndSettle();
    verify(() => confirmation.rejectItem(changeSet, 0)).called(1);
    expect(find.text('Create task: Pack fish'), findsNothing);
    expect(find.text('Proposed changes'), findsNothing);
  });

  testWidgets('retains a legacy proposal summary when its tool is unknown', (
    tester,
  ) async {
    final legacy = changeSet.copyWith(
      items: const [
        ChangeItem(
          toolName: 'legacy_project_action',
          args: {},
          humanSummary: 'Review the launch plan',
        ),
      ],
    );
    await tester.pumpWidget(subject(items: [], sets: [legacy]));
    await tester.pumpAndSettle();
    expect(find.text('Review the launch plan'), findsOneWidget);
    expect(find.byTooltip('Confirm'), findsOneWidget);
  });

  testWidgets('repeated confirmation while pending dispatches only once', (
    tester,
  ) async {
    final pending = Completer<bool>();
    when(() => service.markResolved(any())).thenAnswer((_) => pending.future);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    final actions = tester.widget<RowActions>(find.byType(RowActions).first);
    final first = actions.onConfirm();
    await actions.onConfirm();
    verify(() => service.markResolved('recommendation-1')).called(1);
    pending.complete(true);
    await first;
    await tester.pumpAndSettle();
    expect(find.text('Unblock launch QA'), findsNothing);
    expect(find.text('Confirm the launch manifest'), findsOneWidget);
  });

  testWidgets('empty and initial error states have no action header', (
    tester,
  ) async {
    await tester.pumpWidget(subject(items: []));
    await tester.pumpAndSettle();
    expect(find.text('Recommended next steps'), findsNothing);
    await tester.pumpWidget(
      subject(load: () async => throw StateError('failed')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Proposed changes'), findsNothing);
    expect(find.text('Recommended next steps'), findsNothing);
  });
}
