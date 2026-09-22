import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_controller.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_chat_approval_caption.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart' show makeTestChecklistApproval;

void main() {
  final approval = makeTestChecklistApproval();
  const scope = QueryScope(kind: QueryScopeKind.task, id: 'task');
  final key = (agentId: approval.agentId, scope: scope);

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool chatEnabled = true,
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        ChecklistChatApprovalCaption(approval: approval, taskId: 'task'),
        locale: locale,
        overrides: [
          queryChatEnabledProvider.overrideWithValue(chatEnabled),
          // The real build subscribes to config and lockdown state that this
          // widget never touches; selection is all that is under test.
          queryChatControllerProvider(
            key,
          ).overrideWithBuild((ref, notifier) => const QueryChatSession()),
        ],
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(ChecklistChatApprovalCaption)),
    );
  }

  testWidgets('credits the user with the localized approval date', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.textContaining(
        'Approved by you in chat · Sep 13, 2026',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('follows the reader locale', (tester) async {
    await pump(tester, locale: const Locale('de'));
    expect(
      find.textContaining(
        'Von dir im Chat bestätigt · 13. Sept',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens the task chat on the conversation it came from', (
    tester,
  ) async {
    final container = await pump(tester);
    expect(container.read(queryPaneOpenProvider(scope)), isFalse);
    await tester.tap(find.byType(ChecklistChatApprovalCaption));
    await tester.pump();
    expect(container.read(queryPaneOpenProvider(scope)), isTrue);
    expect(
      container.read(queryChatControllerProvider(key)).selectedId,
      approval.conversationId,
    );
  });

  testWidgets('with task chat disabled it is a plain caption', (tester) async {
    final container = await pump(tester, chatEnabled: false);
    expect(find.byType(GestureDetector), findsNothing);
    await tester.tap(find.byType(ChecklistChatApprovalCaption));
    await tester.pump();
    expect(container.read(queryPaneOpenProvider(scope)), isFalse);
  });
}
