import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposals_section_part.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/widgets/event_suggestions_band.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';

void main() {
  const eventId = 'event-1';
  setUpAll(registerAllFallbackValues);

  late MockChangeSetConfirmationService service;
  late MockUpdateNotifications notifications;

  setUp(() async {
    await setUpTestGetIt();
    service = MockChangeSetConfirmationService();
    notifications = MockUpdateNotifications();
    when(() => notifications.notify(any())).thenReturn(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await tearDownTestGetIt();
  });

  PendingSuggestion proposal(String setId, ChangeItem item) {
    final set = makeTestChangeSet(id: setId, taskId: eventId, items: [item]);
    return PendingSuggestion(
      changeSet: set,
      itemIndex: 0,
      item: item,
      fingerprint: ChangeItem.fingerprint(item),
    );
  }

  final pip = proposal(
    'set-pip',
    const ChangeItem(
      toolName: EventAgentToolNames.suggestPerson,
      args: {
        'personId': 'pip',
        'personName': 'Pip Penguin',
        'mention': 'Pip brought the sardines',
      },
      humanSummary: 'Add Pip Penguin to the event',
    ),
  );
  final album = proposal(
    'set-album',
    const ChangeItem(
      toolName: EventAgentToolNames.suggestFollowUpTask,
      args: {'title': 'Share the album', 'notes': 'Everyone asked for photos'},
      humanSummary: 'Follow-up task: Share the album',
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    UnifiedSuggestionList list, {
    bool showHistory = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(
          child: EventSuggestionsBand(
            eventId: eventId,
            showHistory: showHistory,
          ),
        ),
        overrides: <Override>[
          eventSuggestionListProvider(eventId).overrideWith((ref) => list),
          eventChangeSetConfirmationServiceProvider.overrideWithValue(service),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets("rows are the task card's, saying what and why", (tester) async {
    await pump(
      tester,
      UnifiedSuggestionList(open: [pip, album], activity: const []),
    );

    expect(find.byType(ProposalsSection), findsOneWidget);
    expect(find.byType(ProposalRow), findsNWidgets(2));
    // The kind, then the sentence in the reader's language — never
    // "Add · Add …" — then what it came from.
    expect(find.text('Add · Pip Penguin was there'), findsOneWidget);
    expect(find.text('“Pip brought the sardines”'), findsOneWidget);
    expect(find.text('Everyone asked for photos'), findsOneWidget);
    // Never the wire tool ids.
    expect(find.text(EventAgentToolNames.suggestPerson), findsNothing);
    expect(find.text(EventAgentToolNames.suggestFollowUpTask), findsNothing);
  });

  testWidgets('nothing proposed, no section', (tester) async {
    await pump(tester, const UnifiedSuggestionList.empty());

    expect(find.byType(ProposalsSection), findsNothing);
    expect(find.byType(ProposalRow), findsNothing);
  });

  testWidgets('✓ confirms through the event confirmation service', (
    tester,
  ) async {
    when(() => service.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(success: true, output: 'Done'),
    );
    await pump(tester, UnifiedSuggestionList(open: [pip], activity: const []));

    await tester.tap(find.byIcon(LottiIcons.confirm).first);
    await tester.pumpAndSettle();

    verify(() => service.confirmItem(pip.changeSet, 0)).called(1);
    verify(() => notifications.notify({pip.changeSet.agentId})).called(1);
  });

  testWidgets('✕ dismisses through the event confirmation service', (
    tester,
  ) async {
    when(() => service.rejectItem(any(), any())).thenAnswer((_) async => true);
    await pump(tester, UnifiedSuggestionList(open: [pip], activity: const []));

    await tester.tap(find.byIcon(LottiIcons.close).first);
    await tester.pumpAndSettle();

    verify(() => service.rejectItem(pip.changeSet, 0)).called(1);
    verifyNever(() => service.confirmItem(any(), any()));
  });

  testWidgets('Confirm all confirms every open row in turn', (tester) async {
    when(() => service.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(success: true, output: 'Done'),
    );
    await pump(
      tester,
      UnifiedSuggestionList(open: [pip, album], activity: const []),
    );

    await tester.tap(find.text('Confirm all'));
    await tester.pumpAndSettle();

    verifyInOrder([
      () => service.confirmItem(pip.changeSet, 0),
      () => service.confirmItem(album.changeSet, 0),
    ]);
    verify(() => notifications.notify({pip.changeSet.agentId})).called(1);
  });

  testWidgets('a row Confirm all could not apply stays for another try', (
    tester,
  ) async {
    when(() => service.confirmItem(pip.changeSet, 0)).thenAnswer(
      (_) async => const ToolExecutionResult(
        success: false,
        output: 'Error',
        errorMessage: 'Person link failed',
      ),
    );
    when(() => service.confirmItem(album.changeSet, 0)).thenAnswer(
      (_) async => const ToolExecutionResult(success: true, output: 'Done'),
    );
    await pump(
      tester,
      UnifiedSuggestionList(open: [pip, album], activity: const []),
    );

    await tester.tap(find.text('Confirm all'));
    await tester.pumpAndSettle();

    // The provider still lists both (nothing re-read here): the failed row
    // is back in reach, the confirmed one has left.
    expect(find.text('Add · Pip Penguin was there'), findsOneWidget);
  });

  group('history', () {
    final resolved = makeLedgerEntry(
      changeSetId: 'set-old',
      toolName: EventAgentToolNames.suggestPerson,
      args: const {'personId': 'rocko', 'personName': 'Rocko'},
      humanSummary: 'Add Rocko to the event',
      status: ChangeItemStatus.confirmed,
    );

    testWidgets('shows with the full recap', (tester) async {
      await pump(
        tester,
        UnifiedSuggestionList(open: const [], activity: [resolved]),
        showHistory: true,
      );

      expect(find.byType(ProposalHistorySection), findsOneWidget);
    });

    testWidgets('stays out of the collapsed card', (tester) async {
      await pump(
        tester,
        UnifiedSuggestionList(open: const [], activity: [resolved]),
      );

      expect(find.byType(ProposalHistorySection), findsNothing);
    });
  });
}
