import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/query/query_action_review.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  const key = (
    agentId: 'agent',
    scope: QueryScope(kind: QueryScopeKind.task, id: 'task'),
  );
  const answer = QueryChatAnswer(
    questionId: 'question',
    text: 'Review these changes.',
    coverage: QueryCoverage(),
    proposedActions: [
      ChangeItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Inspect feeder'},
        humanSummary: 'Wrong model description',
      ),
      ChangeItem(
        toolName: 'create_time_entry',
        args: {
          'startTime': '2026-09-13T10:00:00',
          'endTime': '2026-09-13T10:30:00',
          'summary': 'Habitat maintenance',
        },
        humanSummary: 'Wrong model description',
      ),
    ],
  );
  late MockQueryChatActionService service;
  ChangeSetEntity? saved;
  setUp(() async {
    await setUpTestGetIt();
    service = MockQueryChatActionService();
    saved = null;
  });
  tearDown(tearDownTestGetIt);

  // ignore: avoid_positional_boolean_parameters
  void stub(Future<List<ToolExecutionResult>> Function(bool) callback) {
    when(
      () => service.resolve(
        agentId: 'agent',
        chatId: 'chat',
        questionId: 'question',
        approved: any(named: 'approved'),
      ),
    ).thenAnswer(
      (invocation) => callback(invocation.namedArguments[#approved] as bool),
    );
  }

  void applied({bool partial = false}) {
    saved =
        AgentDomainEntity.changeSet(
              id: 'query-chat:question:actions',
              agentId: 'agent',
              taskId: 'task',
              threadId: 'chat',
              runKey: 'query-chat:question',
              status: partial
                  ? ChangeSetStatus.partiallyResolved
                  : ChangeSetStatus.resolved,
              items: [
                answer.proposedActions.first.copyWith(
                  status: ChangeItemStatus.confirmed,
                ),
                answer.proposedActions.last.copyWith(
                  status: partial
                      ? ChangeItemStatus.pending
                      : ChangeItemStatus.confirmed,
                ),
              ],
              createdAt: DateTime(2026, 9, 13),
              vectorClock: null,
            )
            as ChangeSetEntity;
  }

  Future<void> pump(
    WidgetTester tester, {
    bool? approved,
    QueryChatAnswer response = answer,
    QueryAccessSnapshot? access,
    bool canApply = true,
    Locale? locale,
    bool privateLabel = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        QueryActionReview(
          chatKey: key,
          chatId: 'chat',
          answer: response,
          approved: approved,
          access: access,
          canApply: canApply,
        ),
        locale: locale,
        overrides: [
          labelsStreamProvider.overrideWith(
            (ref) => Stream.value([
              testLabelDefinition1.copyWith(private: privateLabel),
            ]),
          ),
          queryChatActionServiceProvider.overrideWithValue(service),
          queryActionChangeSetProvider((
            agentId: 'agent',
            questionId: 'question',
          )).overrideWith((ref) => Stream.value(saved)),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('label preview uses the live name and reader locale', (
    tester,
  ) async {
    await pump(
      tester,
      locale: const Locale('de'),
      response: answer.copyWith(
        proposedActions: [
          ChangeItem(
            toolName: 'assign_task_label',
            args: {'id': testLabelDefinition1.id},
            humanSummary: 'Assign label: stale secret name',
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Label „Urgent“ zuweisen'), findsOneWidget);
    expect(find.textContaining('stale secret name'), findsNothing);
    expect(find.textContaining('Assign label:'), findsNothing);
  });

  testWidgets('a stale private label cannot be shown after privacy closes', (
    tester,
  ) async {
    await pump(
      tester,
      privateLabel: true,
      locale: const Locale('de'),
      response: answer.copyWith(
        proposedActions: [
          ChangeItem(
            toolName: 'assign_task_label',
            args: {'id': testLabelDefinition1.id},
            humanSummary: 'Assign label: Urgent',
          ),
        ],
      ),
    );
    expect(find.textContaining('Urgent'), findsNothing);
    expect(find.text('Label „label-1“ zuweisen'), findsOneWidget);
  });

  testWidgets('previews actual arguments and applies only on inline Accept', (
    tester,
  ) async {
    stub((approved) async {
      expect(approved, isTrue);
      applied();
      return [const ToolExecutionResult(success: true, output: 'Applied')];
    });
    await pump(tester);
    verifyNever(
      () => service.resolve(
        agentId: any(named: 'agentId'),
        chatId: any(named: 'chatId'),
        questionId: any(named: 'questionId'),
        approved: any(named: 'approved'),
      ),
    );
    expect(find.textContaining('Inspect feeder'), findsOneWidget);
    expect(find.textContaining('Sep 13, 2026'), findsOneWidget);
    expect(find.textContaining('10:00'), findsOneWidget);
    expect(find.textContaining('10:30'), findsOneWidget);
    expect(find.textContaining('Habitat maintenance'), findsOneWidget);
    expect(find.text('Wrong model description'), findsNothing);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Change applied'), findsNWidgets(2));
    expect(find.text('Accept'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    verify(
      () => service.resolve(
        agentId: 'agent',
        chatId: 'chat',
        questionId: 'question',
        approved: true,
      ),
    ).called(1);
  });

  testWidgets('Dismiss stays in place and never approves', (tester) async {
    stub((approved) async {
      expect(approved, isFalse);
      return [];
    });
    await pump(tester);
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.text('Dismissed'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.textContaining('Inspect feeder'), findsOneWidget);
    verify(
      () => service.resolve(
        agentId: 'agent',
        chatId: 'chat',
        questionId: 'question',
        approved: false,
      ),
    ).called(1);
    verifyNever(
      () => service.resolve(
        agentId: 'agent',
        chatId: 'chat',
        questionId: 'question',
        approved: true,
      ),
    );
  });

  testWidgets('partial failure shows applied items and Retry', (tester) async {
    stub((approved) async {
      applied(partial: true);
      return [
        const ToolExecutionResult(
          success: false,
          output: 'sensitive provider error',
        ),
      ];
    });
    await pump(tester);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Change applied'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Dismiss'), findsNothing);
    expect(find.textContaining('sensitive'), findsNothing);
    stub((approved) async {
      applied();
      return [const ToolExecutionResult(success: true, output: 'Applied')];
    });
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Change applied'), findsNWidgets(2));
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('busy controls prevent another approval or dismissal', (
    tester,
  ) async {
    final gate = Completer<List<ToolExecutionResult>>();
    stub((_) => gate.future);
    await pump(tester);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Accept'),
          )
          .isLoading,
      isTrue,
    );
    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Dismiss'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Accept'));
    await tester.pump();
    applied();
    gate.complete([
      const ToolExecutionResult(success: true, output: 'Applied'),
    ]);
    await tester.pump();
    await tester.pump();
    verify(
      () => service.resolve(
        agentId: 'agent',
        chatId: 'chat',
        questionId: 'question',
        approved: true,
      ),
    ).called(1);
  });

  testWidgets(
    'reopened completed changes stay applied without another dispatch',
    (tester) async {
      applied();
      await pump(tester, approved: true);
      expect(find.text('Change applied'), findsNWidgets(2));
      expect(find.byType(DesignSystemButton), findsNothing);
      verifyZeroInteractions(service);
    },
  );

  testWidgets('archived chat cannot accept or dismiss a proposal', (
    tester,
  ) async {
    await pump(tester, canApply: false);
    for (final button in tester.widgetList<DesignSystemButton>(
      find.byType(DesignSystemButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(find.textContaining('Inspect feeder'), findsOneWidget);
    verifyZeroInteractions(service);
  });

  testWidgets(
    'shows follow-up options and every simultaneous checklist change',
    (tester) async {
      final response = answer.copyWith(
        proposedActions: const [
          ChangeItem(
            toolName: 'create_follow_up_task',
            args: {
              'title': 'Feeder repair',
              'description': 'Replace the inlet seal.',
              'dueDate': '2026-09-15',
              'priority': 'P1',
            },
            humanSummary: 'Omitted details',
          ),
          ChangeItem(
            toolName: 'update_checklist_item',
            args: {
              'id': 'item',
              'title': 'Updated feeder check',
              'isChecked': true,
              'isArchived': true,
            },
            humanSummary: 'Omitted details',
          ),
        ],
      );
      await pump(tester, response: response);
      expect(find.textContaining('Replace the inlet seal.'), findsOneWidget);
      expect(find.textContaining('High'), findsOneWidget);
      expect(find.textContaining('2026'), findsOneWidget);
      final proposal = tester.widget<SelectableText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              (widget.data?.contains('Updated feeder check') ?? false),
        ),
      );
      expect(proposal.data!.split('\n'), hasLength(3));
      expect(find.text('Omitted details'), findsNothing);
    },
  );

  testWidgets(
    'restoring and migrating items show current names and all edits',
    (tester) async {
      final checklist = ChecklistItem(
        meta: testTask.meta.copyWith(id: 'item'),
        data: const ChecklistItemData(
          title: 'Inspect feeder',
          isChecked: true,
          linkedChecklists: [],
        ),
      );
      final target = testTask.copyWith(
        data: testTask.data.copyWith(title: 'Feeder repair'),
      );
      await pump(
        tester,
        access: QueryAccessSnapshot(
          showPrivate: false,
          entries: {'item': checklist, 'target': target},
          categories: {},
        ),
        response: answer.copyWith(
          proposedActions: const [
            ChangeItem(
              toolName: 'update_checklist_item',
              args: {'id': 'item', 'isChecked': false, 'isArchived': false},
              humanSummary: 'Wrong text',
            ),
            ChangeItem(
              toolName: 'migrate_checklist_item',
              args: {
                'id': 'item',
                'title': 'Inspect feeder',
                'targetTaskId': 'target',
              },
              humanSummary: 'Wrong target',
            ),
          ],
        ),
      );
      final texts = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.data!)
          .toList();
      expect(texts.first, contains('Uncheck'));
      expect(texts.first, contains('Restore'));
      expect(texts.first, contains('Inspect feeder'));
      expect(texts.last, contains('Feeder repair'));
      expect(find.textContaining('Wrong'), findsNothing);
    },
  );

  testWidgets(
    'retracted items show rejection and unknown shapes retain their fallback',
    (tester) async {
      applied();
      saved = saved!.copyWith(
        items: [
          const ChangeItem(
            toolName: 'unknown_older_tool',
            args: {},
            humanSummary: 'Original proposed change',
            status: ChangeItemStatus.rejected,
          ),
        ],
      );
      await pump(tester, approved: true);
      expect(find.text('Original proposed change'), findsOneWidget);
      expect(find.text('Change rejected'), findsOneWidget);
      expect(find.byType(DesignSystemButton), findsNothing);
      verifyZeroInteractions(service);
    },
  );

  testWidgets('link and time edits identify actual live targets', (
    tester,
  ) async {
    final target = testTask.copyWith(
      data: testTask.data.copyWith(title: 'Feeder supplies'),
    );
    final time = testTextEntry.copyWith(
      meta: testTextEntry.meta.copyWith(
        dateFrom: DateTime(2026, 9, 12, 10),
        dateTo: DateTime(2026, 9, 12, 11),
      ),
    );
    final access = QueryAccessSnapshot(
      showPrivate: false,
      entries: {'target': target, 'time': time},
      categories: {},
    );
    final response = answer.copyWith(
      proposedActions: const [
        ChangeItem(
          toolName: 'link_task',
          args: {'relation': 'blocks', 'targetTaskId': 'target'},
          humanSummary: 'Wrong model target',
        ),
        ChangeItem(
          toolName: 'update_time_entry',
          args: {
            'entryId': 'time',
            'summary': 'Corrected maintenance description',
          },
          humanSummary: 'Wrong model target',
        ),
      ],
    );
    await pump(tester, response: response, access: access);
    expect(find.textContaining('Feeder supplies'), findsOneWidget);
    expect(find.textContaining('Sep 12, 2026'), findsOneWidget);
    expect(
      find.textContaining('Corrected maintenance description'),
      findsOneWidget,
    );
    expect(find.text('Wrong model target'), findsNothing);
  });

  testWidgets('a saved dismissal stays inert after reopening', (tester) async {
    await pump(tester, approved: false);
    expect(find.text('Dismissed'), findsOneWidget);
    expect(find.byType(DesignSystemButton), findsNothing);
    verifyZeroInteractions(service);
  });

  testWidgets(
    'authorization failure hides raw errors and keeps review retryable',
    (tester) async {
      stub((_) async => throw StateError('private title'));
      await pump(tester);
      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(
        find.textContaining('Some changes could not be applied'),
        findsOneWidget,
      );
      expect(find.textContaining('private title'), findsNothing);
      expect(find.text('Accept'), findsOneWidget);
    },
  );
}
