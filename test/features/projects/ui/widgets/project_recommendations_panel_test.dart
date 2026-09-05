import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_widgets_part.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/projects/state/project_detail_record_provider.dart';
import 'package:lotti/features/projects/ui/widgets/project_recommendations_panel.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/change_set_factories.dart';

void main() {
  const projectId = 'project-1';
  final now = DateTime(2026, 9, 5, 12);
  final runCreatedAt = now.subtract(const Duration(hours: 2));
  late MockProjectRecommendationService service;
  late MockChangeSetConfirmationService confirmation;
  late int pendingReads;

  setUpAll(registerAllFallbackValues);
  setUp(() {
    service = MockProjectRecommendationService();
    confirmation = MockChangeSetConfirmationService();
    pendingReads = 0;
  });

  ProjectRecommendationEntity step(
    String id,
    String title, {
    int position = 0,
    ProjectRecommendationStatus status = ProjectRecommendationStatus.active,
    String? createdTaskId,
  }) => makeTestProjectRecommendation(
    id: id,
    agentId: 'agent-1',
    projectId: projectId,
    title: title,
    position: position,
    status: status,
    createdTaskId: createdTaskId,
    rationale: null,
    priority: null,
    createdAt: runCreatedAt,
  );

  final steps = [
    step('s1', 'Confirm the escort'),
    step('s2', 'Split the first wave', position: 1),
    step('s3', 'Brief the elders', position: 2),
    step('s4', 'Stage the krill', position: 3),
    step('s5', 'Tag the pathfinders', position: 4),
  ];
  final proposals = makeTestChangeSet(
    id: 'set-1',
    agentId: 'agent-1',
    taskId: projectId,
    items: const [
      ChangeItem(
        toolName: 'create_task',
        args: {'title': 'Pack fish'},
        humanSummary: 'Create task',
      ),
    ],
  );

  Widget subject({
    List<ProjectRecommendationEntity>? items,
    DateTime? run,
    List<AgentDomainEntity> sets = const [],
    bool enabled = true,
    ValueChanged<String>? onOpenTask,
    double width = 390,
    bool withoutSnapshot = false,
    bool legacyRun = false,
  }) => makeTestableWidgetWithScaffold(
    SingleChildScrollView(
      child: ProjectRecommendationsPanel(
        projectId: projectId,
        enabled: enabled,
        onOpenTask: onOpenTask,
      ),
    ),
    mediaQueryData: MediaQueryData(size: Size(width, 900)),
    overrides: [
      projectNextStepsProvider(projectId).overrideWith(
        (ref) => withoutSnapshot
            ? Completer<ProjectNextStepsSnapshot>().future
            : Future.value(
                ProjectNextStepsSnapshot(
                  steps: items ?? steps,
                  runCreatedAt: legacyRun ? null : (run ?? runCreatedAt),
                ),
              ),
      ),
      projectPendingChangeSetsProvider(projectId).overrideWith((ref) async {
        pendingReads++;
        return sets;
      }),
      projectRecommendationServiceProvider.overrideWithValue(service),
      projectChangeSetConfirmationServiceProvider.overrideWithValue(
        confirmation,
      ),
      projectDetailNowProvider.overrideWithValue(() => now),
    ],
  );

  /// Drops the previous tree first: re-pumping a subject in place would keep
  /// the old ProviderScope container and the panel's own state, and a test
  /// could pass on data it never reloaded.
  Future<void> pumpSubject(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  const updateError = "Couldn't update the recommendation. Please try again.";

  testWidgets('renders the run in order with tags and counts only open steps', (
    tester,
  ) async {
    await pumpSubject(
      tester,
      subject(
        width: 1000,
        items: [
          steps[0],
          step(
            's2',
            'Split the first wave',
            position: 1,
            status: ProjectRecommendationStatus.dismissed,
          ),
          step(
            's3',
            'Brief the elders',
            position: 2,
            status: ProjectRecommendationStatus.resolved,
            createdTaskId: 'task-3',
          ),
        ],
        sets: [proposals],
      ),
    );

    expect(find.text('Recommended next steps'), findsOneWidget);
    expect(find.text('1 pending'), findsNWidgets(2));
    expect(find.text('Dismissed'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Open task'), findsOneWidget);
    expect(
      find.text('Undo'),
      findsOneWidget,
      reason: 'A dismissal stays undoable; a stored addition does not.',
    );
    expect(find.text('Proposed changes'), findsOneWidget);
    expect(find.text('Create task: Pack fish'), findsOneWidget);
    expect(
      find.text('Add all as tasks'),
      findsNothing,
      reason: 'Bulk actions need more than one open step.',
    );
    final tops = [
      'Confirm the escort',
      'Split the first wave',
      'Brief the elders',
    ].map((title) => tester.getTopLeft(find.text(title)).dy).toList();
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets(
    'Add task marks the row added, offers Undo for eight seconds and opens '
    'the task',
    (tester) async {
      final creation = Completer<ToolExecutionResult>();
      when(() => service.createTask('s1')).thenAnswer((_) => creation.future);
      final opened = <String>[];
      await pumpSubject(
        tester,
        subject(items: steps.sublist(0, 2), onOpenTask: opened.add),
      );

      await tester.tap(find.text('Add task').first);
      await tester.pump();
      expect(find.text('Creating task…'), findsOneWidget);
      expect(find.text('2 pending'), findsNothing);
      expect(find.text('1 pending'), findsOneWidget);
      creation.complete(
        const ToolExecutionResult(
          success: true,
          output: '',
          mutatedEntityId: 'task-1',
        ),
      );
      await settle(tester);

      verify(() => service.createTask('s1')).called(1);
      expect(find.text('Added'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(
        find.text('Add task'),
        findsOneWidget,
        reason: 'The other step stays open.',
      );
      await tester.tap(find.text('Open task'));
      expect(opened, ['task-1']);

      await tester.pump(ProjectRecommendationsPanel.undoWindow);
      await settle(tester);
      expect(
        find.text('Undo'),
        findsNothing,
        reason: 'The undo window closed.',
      );
      expect(find.text('Added'), findsOneWidget);
    },
  );

  testWidgets('a failed Add task keeps the row with Retry and tries again', (
    tester,
  ) async {
    var calls = 0;
    when(() => service.createTask('s1')).thenAnswer((_) async {
      calls++;
      return ToolExecutionResult(
        success: calls > 1,
        output: calls > 1 ? '' : 'Recommendation is no longer active',
        mutatedEntityId: calls > 1 ? 'task-1' : null,
      );
    });
    await pumpSubject(tester, subject(items: steps.sublist(0, 1)));

    await tester.tap(find.text('Add task'));
    await settle(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining("Couldn't create the task."), findsOneWidget);
    expect(find.text('Confirm the escort'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(calls, 2);
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
    'a creation warning surfaces as a toast while the row reads Added',
    (tester) async {
      when(() => service.createTask('s1')).thenAnswer(
        (_) async => const ToolExecutionResult(
          success: true,
          output: '',
          mutatedEntityId: 'task-1',
          errorMessage: 'Agent assignment unavailable',
        ),
      );
      await pumpSubject(tester, subject(items: steps.sublist(0, 1)));

      await tester.tap(find.text('Add task'));
      await settle(tester);

      expect(
        find.textContaining('Agent assignment unavailable'),
        findsOneWidget,
      );
      expect(find.text('Added'), findsOneWidget);
    },
  );

  testWidgets('a task created without an id reads Done rather than Added', (
    tester,
  ) async {
    when(() => service.createTask('s1')).thenAnswer(
      (_) async => const ToolExecutionResult(success: true, output: ''),
    );
    await pumpSubject(tester, subject(items: steps.sublist(0, 1)));

    await tester.tap(find.text('Add task'));
    await settle(tester);

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Open task'), findsNothing);
  });

  testWidgets('Dismiss and Undo flip the row in place', (tester) async {
    when(
      () => service.dismissRecommendation('s1'),
    ).thenAnswer((_) async => true);
    when(
      () => service.restoreRecommendation('s1'),
    ).thenAnswer((_) async => true);
    await pumpSubject(tester, subject(items: steps.sublist(0, 1)));

    await tester.tap(find.text('Dismiss'));
    await settle(tester);
    verify(() => service.dismissRecommendation('s1')).called(1);
    expect(find.text('Dismissed'), findsOneWidget);
    expect(find.text('Confirm the escort'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    verify(() => service.restoreRecommendation('s1')).called(1);
    expect(find.text('Dismissed'), findsNothing);
    expect(find.text('Add task'), findsOneWidget);
  });

  testWidgets('a refused Undo keeps the tag and says so', (tester) async {
    when(
      () => service.restoreRecommendation('s2'),
    ).thenAnswer((_) async => false);
    await pumpSubject(
      tester,
      subject(
        items: [
          steps[0],
          step(
            's2',
            'Split the first wave',
            position: 1,
            status: ProjectRecommendationStatus.dismissed,
          ),
        ],
      ),
    );

    await tester.tap(find.text('Undo'));
    await settle(tester);

    expect(find.text('Dismissed'), findsOneWidget);
    expect(find.text(updateError), findsOneWidget);
  });

  testWidgets('a thrown dismissal is logged and reported without a crash', (
    tester,
  ) async {
    when(
      () => service.dismissRecommendation('s1'),
    ).thenThrow(StateError('offline'));
    await pumpSubject(tester, subject(items: steps.sublist(0, 1)));

    await tester.tap(find.text('Dismiss'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Add task'), findsOneWidget);
    expect(find.text(updateError), findsOneWidget);
  });

  testWidgets('Add all and Dismiss all act on every open step in order', (
    tester,
  ) async {
    final added = <String>[];
    when(() => service.createTask(any())).thenAnswer((call) async {
      added.add(call.positionalArguments.single as String);
      return const ToolExecutionResult(
        success: true,
        output: '',
        mutatedEntityId: 'task',
      );
    });
    final dismissed = <String>[];
    when(() => service.dismissRecommendation(any())).thenAnswer((call) async {
      dismissed.add(call.positionalArguments.single as String);
      return true;
    });
    await pumpSubject(
      tester,
      subject(
        width: 1000,
        items: [
          steps[0],
          steps[1],
          step(
            's3',
            'Brief the elders',
            position: 2,
            status: ProjectRecommendationStatus.dismissed,
          ),
          steps[3],
        ],
      ),
    );

    await tester.tap(find.text('Add all as tasks'));
    await settle(tester);
    await settle(tester);
    expect(added, ['s1', 's2', 's4']);
    expect(find.text('Added'), findsNWidgets(3));
    expect(find.text('Add all as tasks'), findsNothing);

    await pumpSubject(
      tester,
      subject(width: 1000, items: steps.sublist(0, 2)),
    );
    await tester.tap(find.text('Dismiss all'));
    await settle(tester);
    await settle(tester);
    expect(dismissed, ['s1', 's2']);
    expect(find.text('Dismissed'), findsNWidgets(2));
  });

  testWidgets('a phone shows three rows until Show more', (tester) async {
    await pumpSubject(tester, subject());

    expect(find.text('Confirm the escort'), findsOneWidget);
    expect(find.text('Brief the elders'), findsOneWidget);
    expect(find.text('Stage the krill'), findsNothing);
    expect(find.text('5 pending'), findsOneWidget);

    await tester.tap(find.text('Show 2 more'));
    await tester.pump();
    expect(find.text('Stage the krill'), findsOneWidget);
    expect(find.text('Tag the pathfinders'), findsOneWidget);
    expect(find.textContaining('more'), findsNothing);

    await pumpSubject(tester, subject(width: 1000));
    expect(find.text('Tag the pathfinders'), findsOneWidget);
    expect(find.textContaining('Show '), findsNothing);
  });

  testWidgets(
    'a run decided before the page opened collapses to a summary with history',
    (tester) async {
      await pumpSubject(
        tester,
        subject(
          run: now.subtract(const Duration(minutes: 40)),
          items: [
            step(
              's1',
              'Confirm the escort',
              status: ProjectRecommendationStatus.resolved,
              createdTaskId: 'task-1',
            ),
            step(
              's2',
              'Split the first wave',
              position: 1,
              status: ProjectRecommendationStatus.dismissed,
            ),
          ],
        ),
      );

      expect(
        find.text('Last run: 1 added, 1 dismissed · 40 min ago'),
        findsOneWidget,
      );
      expect(find.text('Confirm the escort'), findsNothing);
      expect(find.textContaining('pending'), findsNothing);

      await tester.tap(find.text('Show history'));
      await tester.pump();
      expect(find.text('Confirm the escort'), findsOneWidget);
      expect(find.text('Split the first wave'), findsOneWidget);
      expect(find.text('Hide history'), findsOneWidget);
    },
  );

  testWidgets('decisions made on the page keep their rows inline', (
    tester,
  ) async {
    when(
      () => service.dismissRecommendation(any()),
    ).thenAnswer((_) async => true);
    await pumpSubject(tester, subject(items: steps.sublist(0, 1)));

    await tester.tap(find.text('Dismiss'));
    await settle(tester);

    expect(find.textContaining('Last run:'), findsNothing);
    expect(find.text('Dismissed'), findsOneWidget);
    expect(find.text('Confirm the escort'), findsOneWidget);
  });

  testWidgets('an empty run explains itself with when the agent last looked', (
    tester,
  ) async {
    await pumpSubject(tester, subject(items: const []));
    expect(
      find.text('No open suggestions. Last looked 2 h ago.'),
      findsOneWidget,
    );

    await pumpSubject(tester, subject(items: const [], legacyRun: true));
    expect(find.text('No open suggestions.'), findsOneWidget);
  });

  testWidgets('without a snapshot and without proposals nothing renders', (
    tester,
  ) async {
    await pumpSubject(tester, subject(withoutSnapshot: true));
    expect(find.byType(ProjectRecommendationsPanel), findsOneWidget);
    expect(find.text('Recommended next steps'), findsNothing);
    expect(find.text('Proposed changes'), findsNothing);

    await pumpSubject(
      tester,
      subject(withoutSnapshot: true, sets: [proposals]),
    );
    expect(find.text('Proposed changes'), findsOneWidget);
    expect(find.text('Recommended next steps'), findsNothing);
  });

  testWidgets(
    'proposals apply or reject through the confirmation service and keep '
    'their tag',
    (tester) async {
      when(() => confirmation.confirmItem(any(), any())).thenAnswer(
        (_) async => const ToolExecutionResult(success: true, output: ''),
      );
      await pumpSubject(tester, subject(items: const [], sets: [proposals]));
      final readsBefore = pendingReads;

      await tester.tap(find.byTooltip('Confirm'));
      await settle(tester);

      verify(() => confirmation.confirmItem(proposals, 0)).called(1);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Create task: Pack fish'), findsOneWidget);
      expect(find.byTooltip('Confirm'), findsNothing);
      expect(
        pendingReads,
        greaterThan(readsBefore),
        reason: 'Only the proposal read is refreshed after a decision.',
      );
      expect(find.text('0 pending'), findsNothing);

      when(
        () => confirmation.rejectItem(any(), any()),
      ).thenAnswer((_) async => true);
      await pumpSubject(tester, subject(items: const [], sets: [proposals]));
      await tester.tap(find.byTooltip('Reject'));
      await settle(tester);
      verify(() => confirmation.rejectItem(proposals, 0)).called(1);
      expect(find.text('Dismissed'), findsOneWidget);
    },
  );

  testWidgets('a failed proposal decision keeps the rail and reports it', (
    tester,
  ) async {
    when(() => confirmation.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(success: false, output: 'no'),
    );
    await pumpSubject(tester, subject(items: const [], sets: [proposals]));

    await tester.tap(find.byTooltip('Confirm'));
    await settle(tester);

    expect(find.byTooltip('Confirm'), findsOneWidget);
    expect(find.text(updateError), findsOneWidget);
  });

  testWidgets('a disabled panel renders every control inert', (tester) async {
    await pumpSubject(
      tester,
      subject(
        width: 1000,
        enabled: false,
        items: [
          steps[0],
          steps[1],
          step(
            's3',
            'Brief the elders',
            position: 2,
            status: ProjectRecommendationStatus.dismissed,
          ),
        ],
        sets: [proposals],
      ),
    );

    for (final button in tester.widgetList<DesignSystemButton>(
      find.byType(DesignSystemButton),
    )) {
      expect(button.onPressed, isNull, reason: button.label);
    }
    expect(
      find.text('Undo'),
      findsNothing,
      reason: 'Nothing is undoable while disabled.',
    );
    expect(
      tester.widget<RowActions>(find.byType(RowActions)).enabled,
      isFalse,
      reason: 'The proposal rail is inert, not a no-op.',
    );
    await tester.tap(find.byTooltip('Confirm'));
    await tester.pump();
    verifyNever(() => confirmation.confirmItem(any(), any()));
  });

  testWidgets('bulk work disables the other rows until it finishes', (
    tester,
  ) async {
    final first = Completer<ToolExecutionResult>();
    when(() => service.createTask('s1')).thenAnswer((_) => first.future);
    when(() => service.createTask('s2')).thenAnswer(
      (_) async => const ToolExecutionResult(
        success: true,
        output: '',
        mutatedEntityId: 'task-2',
      ),
    );
    await pumpSubject(
      tester,
      subject(width: 1000, items: steps.sublist(0, 2), sets: [proposals]),
    );

    await tester.tap(find.text('Add all as tasks'));
    await tester.pump();

    expect(find.text('Creating task…'), findsOneWidget);
    final buttons = tester.widgetList<DesignSystemButton>(
      find.byType(DesignSystemButton),
    );
    expect(buttons.map((b) => b.onPressed), everyElement(isNull));
    expect(
      tester.widget<RowActions>(find.byType(RowActions)).enabled,
      isFalse,
    );

    first.complete(
      const ToolExecutionResult(
        success: true,
        output: '',
        mutatedEntityId: 'task-1',
      ),
    );
    await settle(tester);
    await settle(tester);
    expect(find.text('Added'), findsNWidgets(2));
    expect(
      tester.widget<RowActions>(find.byType(RowActions)).enabled,
      isTrue,
    );
  });

  testWidgets('a consumed creation failure shows its message without Retry', (
    tester,
  ) async {
    when(() => service.createTask('s1')).thenAnswer(
      (_) async => const ToolExecutionResult(
        success: false,
        output: 'rollback failed',
        errorMessage: 'Failed to link the new task; rollback failed for t-9',
        nonRetryable: true,
      ),
    );
    await pumpSubject(tester, subject(items: steps.sublist(0, 1)));

    await tester.tap(find.text('Add task'));
    await settle(tester);

    expect(
      find.text('Failed to link the new task; rollback failed for t-9'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets('a refused Undo of an addition keeps the window and the link', (
    tester,
  ) async {
    when(() => service.createTask('s1')).thenAnswer(
      (_) async => const ToolExecutionResult(
        success: true,
        output: '',
        mutatedEntityId: 'task-1',
      ),
    );
    when(
      () => service.restoreRecommendation('s1'),
    ).thenAnswer((_) async => false);
    final opened = <String>[];
    await pumpSubject(
      tester,
      subject(items: steps.sublist(0, 1), onOpenTask: opened.add),
    );
    await tester.tap(find.text('Add task'));
    await settle(tester);

    await tester.tap(find.text('Undo'));
    await settle(tester);

    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Open task'));
    expect(opened, ['task-1']);
    expect(find.text(updateError), findsOneWidget);
  });

  testWidgets('proposals decided in an earlier session stay out of the band', (
    tester,
  ) async {
    final mixed = makeTestChangeSet(
      id: 'set-2',
      agentId: 'agent-1',
      taskId: projectId,
      items: const [
        ChangeItem(
          toolName: 'create_task',
          args: {'title': 'Old decision'},
          humanSummary: 'Create task',
          status: ChangeItemStatus.confirmed,
        ),
        ChangeItem(
          toolName: 'create_task',
          args: {'title': 'Still open'},
          humanSummary: 'Create task',
        ),
      ],
    );
    await pumpSubject(tester, subject(items: const [], sets: [mixed]));

    expect(find.text('Create task: Still open'), findsOneWidget);
    expect(find.text('Create task: Old decision'), findsNothing);
    expect(find.text('1 pending'), findsOneWidget);
  });

  testWidgets('thrown service calls are reported without a crash', (
    tester,
  ) async {
    when(() => service.createTask('s1')).thenThrow(StateError('offline'));
    when(
      () => confirmation.confirmItem(any(), any()),
    ).thenThrow(StateError('offline'));
    await pumpSubject(
      tester,
      subject(width: 1000, items: steps.sublist(0, 1), sets: [proposals]),
    );

    await tester.tap(find.text('Add task'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.byTooltip('Confirm'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Confirm'), findsOneWidget);
    expect(find.text(updateError), findsOneWidget);
  });

  testWidgets(
    'disposing during a pending action completes without stale UI writes',
    (tester) async {
      final pending = Completer<bool>();
      when(
        () => service.dismissRecommendation('s1'),
      ).thenAnswer((_) => pending.future);
      await pumpSubject(tester, subject(items: steps.sublist(0, 1)));

      await tester.tap(find.text('Dismiss'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(true);
      await tester.pump();

      expect(tester.takeException(), isNull);
      verify(() => service.dismissRecommendation('s1')).called(1);
    },
  );
}
