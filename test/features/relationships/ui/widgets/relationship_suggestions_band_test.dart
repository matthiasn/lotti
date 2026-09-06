import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/state/relationship_proposal_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_suggestions_band.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/change_set_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  late MockRelationshipProposalService service;
  setUp(() async {
    await setUpTestGetIt();
    service = MockRelationshipProposalService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await tearDownTestGetIt();
  });
  PendingSuggestion proposal(
    int index, {
    String tool = 'create_and_link_task',
    String runKey = 'run-1',
  }) {
    final item = ChangeItem(
      toolName: tool,
      args: {'title': 'Commitment $index'},
      humanSummary: 'Create task: Commitment $index',
    );
    final set = makeTestChangeSet(
      id: 'set-$index',
      runKey: runKey,
      agentId: relationshipAgentIdFor('person'),
      taskId: 'person',
      items: [item],
    );
    return PendingSuggestion(
      changeSet: set,
      itemIndex: 0,
      item: item,
      fingerprint: ChangeItem.fingerprint(item),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    RelationshipProposalSnapshot Function() snapshot, {
    String? runKey,
    bool showHistory = false,
    List<CheckInEntry> checkIns = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(
          child: RelationshipSuggestionsBand(
            relationshipId: 'person',
            checkIns: checkIns,
            runKey: runKey,
            showHistory: showHistory,
          ),
        ),
        overrides: [
          relationshipProposalServiceProvider.overrideWithValue(service),
          relationshipSuggestionListProvider(
            'person',
          ).overrideWith((ref) async => snapshot()),
        ],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('folds beyond three and offers Confirm all only for one kind', (
    tester,
  ) async {
    final rows = [for (var i = 0; i < 4; i++) proposal(i)];
    await pump(
      tester,
      () => RelationshipProposalSnapshot(
        suggestions: UnifiedSuggestionList(open: rows, activity: const []),
      ),
    );
    expect(find.byType(ProposalRow), findsNWidgets(3));
    expect(find.text('Show 1 more'), findsOneWidget);
    expect(find.text('Confirm all'), findsOneWidget);
    await tester.tap(find.text('Show 1 more'));
    await tester.pump();
    expect(find.byType(ProposalRow), findsNWidgets(4));
  });
  testWidgets('mixed proposal kinds have no bulk confirmation', (tester) async {
    await pump(
      tester,
      () => RelationshipProposalSnapshot(
        suggestions: UnifiedSuggestionList(
          open: [
            proposal(0),
            proposal(1, tool: 'set_task_status'),
          ],
          activity: const [],
        ),
      ),
    );
    final buttons = tester.widgetList<Widget>(
      find.text('Confirm all').hitTestable(),
    );
    expect(buttons, isEmpty);
  });
  testWidgets(
    'uses the relationship confirmation path and retains a row through refresh',
    (tester) async {
      final row = proposal(0);
      var snapshot = RelationshipProposalSnapshot(
        suggestions: UnifiedSuggestionList(open: [row], activity: const []),
      );
      final applied = Completer<ToolExecutionResult>();
      when(
        () => service.confirm(row.changeSet, 0),
      ).thenAnswer((_) => applied.future);
      await pump(tester, () => snapshot);
      await tester.tap(find.byIcon(LottiIcons.confirm).first);
      await tester.pump();
      verify(() => service.confirm(row.changeSet, 0)).called(1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RelationshipSuggestionsBand)),
      );
      snapshot = const RelationshipProposalSnapshot.empty();
      container.invalidate(relationshipSuggestionListProvider('person'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(ProposalRow),
        findsOneWidget,
        reason: 'the provider must not unmount an in-flight row',
      );
      applied.complete(
        const ToolExecutionResult(success: true, output: 'Created'),
      );
      await tester.pump();
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(ProposalRow), findsNothing);
      snapshot = RelationshipProposalSnapshot(
        suggestions: UnifiedSuggestionList(open: [row], activity: const []),
      );
      container.invalidate(relationshipSuggestionListProvider('person'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Commitment 0'),
        findsOneWidget,
        reason:
            'a peer undo must restore the same item after its ledger removal',
      );
    },
  );

  testWidgets(
    'bulk failure releases rows so an individual confirmation can retry',
    (tester) async {
      final rows = [proposal(0), proposal(1)];
      when(
        () => service.confirm(any(), any()),
      ).thenThrow(StateError('write failed'));
      await pump(
        tester,
        () => RelationshipProposalSnapshot(
          suggestions: UnifiedSuggestionList(open: rows, activity: const []),
        ),
      );
      await tester.tap(find.text('Confirm all'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verify(() => service.confirm(any(), any())).called(2);
      when(() => service.confirm(any(), any())).thenAnswer(
        (_) async =>
            const ToolExecutionResult(success: true, output: 'Created'),
      );
      await tester.tap(find.byIcon(LottiIcons.confirm).first);
      await tester.pump();
      verify(() => service.confirm(rows.first.changeSet, 0)).called(1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('chat filters pending and history to its own reply run', (
    tester,
  ) async {
    final row = proposal(0);
    final own = row.changeSet.runKey;
    final entry = LedgerEntry(
      changeSetId: 'old-set',
      itemIndex: 0,
      toolName: row.item.toolName,
      args: row.item.args,
      humanSummary: 'Older commitment',
      fingerprint: row.fingerprint,
      status: ChangeItemStatus.rejected,
      createdAt: row.changeSet.createdAt,
    );
    await pump(
      tester,
      () => RelationshipProposalSnapshot(
        suggestions: UnifiedSuggestionList(
          open: [
            row,
            proposal(1, runKey: 'other-run'),
          ],
          activity: [entry],
        ),
        runKeys: {'old-set': 'other-run'},
      ),
      runKey: own,
      showHistory: true,
    );
    expect(find.textContaining('Commitment 0'), findsOneWidget);
    expect(find.textContaining('Commitment 1'), findsNothing);
    expect(find.textContaining('History'), findsNothing);
    expect(find.textContaining('Older commitment'), findsNothing);
  });

  testWidgets('evidence opens the exact source narrative for review', (
    tester,
  ) async {
    final row = proposal(0);
    final source = CheckInEntry(
      meta: testRelationship.meta.copyWith(id: 'source'),
      data: const CheckInData(
        relationshipId: 'person',
        interactionType: CheckInInteractionType.call,
      ),
      entryText: const EntryText(
        plainText: 'I promised to send the launch checklist.',
      ),
    );
    final item = row.item.copyWith(
      args: {...row.item.args, 'sourceCheckInId': source.id},
    );
    final withSource = PendingSuggestion(
      changeSet: row.changeSet.copyWith(items: [item]),
      itemIndex: 0,
      item: item,
      fingerprint: ChangeItem.fingerprint(item),
    );
    await pump(
      tester,
      () => RelationshipProposalSnapshot(
        suggestions: UnifiedSuggestionList(
          open: [withSource],
          activity: const [],
        ),
      ),
      checkIns: [source],
    );
    await tester.tap(find.textContaining('From the check-in on'));
    await tester.pumpAndSettle();
    expect(
      find.text('I promised to send the launch checklist.'),
      findsOneWidget,
    );
    expect(find.text('Edit check-in'), findsOneWidget);
  });
  testWidgets(
    'handled task history opens its destination and delegates safe undo',
    (tester) async {
      final row = proposal(0);
      final entry = LedgerEntry(
        changeSetId: row.changeSet.id,
        itemIndex: 0,
        toolName: row.item.toolName,
        args: row.item.args,
        humanSummary: row.item.humanSummary,
        fingerprint: row.fingerprint,
        status: ChangeItemStatus.confirmed,
        createdAt: row.changeSet.createdAt,
      );
      final routes = <String>[];
      beamToNamedOverride = routes.add;
      addTearDown(() => beamToNamedOverride = null);
      when(
        () => service.undoById(row.changeSet.id, 0),
      ).thenAnswer((_) async => true);
      await pump(
        tester,
        () => RelationshipProposalSnapshot(
          suggestions: UnifiedSuggestionList(open: const [], activity: [entry]),
          receipts: {
            RelationshipProposalSnapshot.itemKey(row.changeSet.id, 0): testTask,
          },
        ),
        showHistory: true,
      );
      await tester.tap(find.textContaining('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Added → ${testTask.data.title}'));
      expect(routes, ['/tasks/${testTask.id}']);
      await tester.tap(find.text('Undo'));
      await tester.pump();
      verify(() => service.undoById(row.changeSet.id, 0)).called(1);
    },
  );
}
