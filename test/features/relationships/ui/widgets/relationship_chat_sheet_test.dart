import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_chat_pane.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_chat_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const desktop = Size(1400, 900);

  Future<void> openSheet(WidgetTester tester) async {
    setTestSurfaceSize(tester, desktop);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showRelationshipChatSheet(context, relationshipId: 'rel-1'),
            child: const Text('Talk'),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: desktop),
        overrides: [
          agentIdentityProvider.overrideWith((ref, agentId) async => null),
        ],
      ),
    );
    await tester.tap(find.text('Talk'));
    await tester.pumpAndSettle();
  }

  testWidgets("opens the person's conversation at the agent-chat width, "
      'docked at the window edge, offering the internals', (tester) async {
    await openSheet(tester);

    final pane = tester.widget<RelationshipChatPane>(
      find.byType(RelationshipChatPane),
    );
    expect(pane.relationshipId, 'rel-1');
    expect(pane.showInternalsAction, isTrue);
    final rect = tester.getRect(find.byType(RelationshipChatPane));
    expect(rect.width, moreOrLessEquals(kAgentChatSheetWidth, epsilon: 1));
    expect(rect.right, moreOrLessEquals(desktop.width, epsilon: 1));
  });

  testWidgets("the pane's close button dismisses the sheet", (tester) async {
    await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('person-chat-close')));
    await tester.pumpAndSettle();

    expect(find.byType(RelationshipChatPane), findsNothing);
    expect(find.text('Talk'), findsOneWidget);
  });
}
