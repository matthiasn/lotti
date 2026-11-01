import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/features/front_agent/ui/front_chat_surface.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  Future<void> open(WidgetTester tester, Size window) async {
    await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);
    setTestSurfaceSize(tester, window);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFrontChat(context),
            child: const Text('Ask'),
          ),
        ),
        mediaQueryData: MediaQueryData(size: window),
        overrides: [
          frontChatThreadProvider.overrideWith(
            (ref) async => FrontChatThread.empty,
          ),
          frontAllChatsThreadProvider.overrideWith(
            (ref) async => FrontChatThread.empty,
          ),
          frontConversationsProvider.overrideWith(
            (ref) async => FrontConversationIndex.empty,
          ),
          configFlagProvider.overrideWith((ref, _) => Stream.value(false)),
          agentConsumptionTotalsProvider(
            frontAgentId,
          ).overrideWith((ref) => const Stream<ConsumptionTotals>.empty()),
        ],
      ),
    );
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
  }

  testWidgets('on a desktop window she opens as a large panel over the app, '
      'her conversations beside the one open', (tester) async {
    const desktop = Size(1400, 900);
    await open(tester, desktop);

    final rect = tester.getRect(find.byType(FrontChatPane));
    expect(rect.width, moreOrLessEquals(kDetailContentMaxWidth, epsilon: 1));
    expect(rect.center.dx, moreOrLessEquals(desktop.width / 2, epsilon: 1));
    final list = tester.getRect(find.byType(FrontConversationList));
    expect(
      list.width,
      moreOrLessEquals(rect.width * FrontChatSurface.listShare, epsilon: 1),
    );
    expect(list.left, moreOrLessEquals(rect.left, epsilon: 1));
    // The list carries the way to it and a new conversation.
    expect(find.byKey(FrontChatHeaderKeys.chats), findsNothing);
    expect(find.byKey(FrontChatHeaderKeys.newChat), findsNothing);
  });

  testWidgets('between a phone and a desktop she is a panel with the list a '
      'tap away', (tester) async {
    const tablet = Size(800, 900);
    await open(tester, tablet);

    final rect = tester.getRect(find.byType(FrontChatPane));
    expect(rect.width, lessThan(tablet.width));
    expect(find.byType(FrontConversationList), findsNothing);
    expect(find.byKey(FrontChatHeaderKeys.chats), findsOne);
  });

  testWidgets('on a phone she takes the whole screen', (tester) async {
    const phone = Size(390, 844);
    await open(tester, phone);

    final rect = tester.getRect(find.byType(FrontChatPane));
    expect(rect.width, moreOrLessEquals(phone.width, epsilon: 1));
    expect(rect.height, moreOrLessEquals(phone.height, epsilon: 1));
  });

  testWidgets("the pane's close dismisses her", (tester) async {
    await open(tester, const Size(1400, 900));

    await tester.tap(find.byKey(FrontChatHeaderKeys.close));
    await tester.pumpAndSettle();

    expect(find.byType(FrontChatPane), findsNothing);
    expect(find.text('Ask'), findsOneWidget);
  });

  testWidgets('Escape closes her', (tester) async {
    await open(tester, const Size(1400, 900));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(FrontChatPane), findsNothing);
  });
}
