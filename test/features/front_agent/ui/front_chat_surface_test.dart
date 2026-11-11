import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/ui/front_chat_drawer.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/features/front_agent/ui/front_chat_surface.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Size window, {
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
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
        mediaQueryData: MediaQueryData(
          size: window,
          padding: padding,
          viewPadding: padding,
        ),
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
    final drawer = tester.getRect(find.byType(FrontChatDrawer));
    expect(
      drawer.width,
      moreOrLessEquals(rect.width * FrontChatPane.listShare, epsilon: 1),
    );
    expect(drawer.left, moreOrLessEquals(rect.left, epsilon: 1));
    // The drawer carries a new conversation, and needs no toggle.
    expect(find.byKey(FrontChatHeaderKeys.drawer), findsNothing);
    expect(find.byKey(FrontChatHeaderKeys.newChat), findsNothing);
    expect(find.byKey(FrontChatDrawerKeys.newChat), findsOne);
    expect(find.byKey(FrontChatDrawerKeys.close), findsNothing);

    // The list is the sheet's sidebar, a step off the conversation's ground.
    final tokens = tester.element(find.byType(FrontChatPane)).designTokens;
    final ground = tester.widget<ColoredBox>(
      find
          .ancestor(
            of: find.byType(FrontChatDrawer),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(ground.color, tokens.colors.background.level02);
    // Its top row and her header end on one line: one hairline across.
    // The drawer's band: a hairline under it and nothing over it.
    final band = find.ancestor(
      of: find.byKey(FrontChatDrawerKeys.search),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            switch ((widget.decoration as BoxDecoration).border) {
              Border(:final top, :final bottom) =>
                top == BorderSide.none && bottom != BorderSide.none,
              _ => false,
            },
      ),
    );
    expect(
      tester.getRect(band).bottom,
      tester.getRect(find.byType(FrontChatHeader)).bottom,
    );
  });

  testWidgets('between a phone and a desktop she is a panel with the drawer '
      'a tap away', (tester) async {
    const tablet = Size(800, 900);
    await open(tester, tablet);

    final rect = tester.getRect(find.byType(FrontChatPane));
    expect(rect.width, lessThan(tablet.width));
    expect(find.byType(FrontChatDrawer), findsNothing);
    expect(find.byKey(FrontChatHeaderKeys.drawer), findsOne);
  });

  testWidgets('on a phone she takes the whole screen', (tester) async {
    const phone = Size(390, 844);
    await open(tester, phone);

    final rect = tester.getRect(find.byType(FrontChatPane));
    expect(rect.width, moreOrLessEquals(phone.width, epsilon: 1));
    expect(rect.height, moreOrLessEquals(phone.height, epsilon: 1));
  });

  testWidgets('on a phone with a notch and a home indicator she still reaches '
      'both edges, her header and composer clear of them', (tester) async {
    const phone = Size(390, 844);
    const insets = EdgeInsets.only(top: 47, bottom: 34);
    await open(tester, phone, padding: insets);

    // No strip of barrier above or below her.
    final surface = tester.getRect(find.byType(Scaffold).last);
    expect(surface.top, 0);
    expect(surface.bottom, phone.height);
    // What she draws keeps clear of the status bar and the home indicator.
    expect(
      tester.getRect(find.byType(FrontChatHeader)).top,
      greaterThanOrEqualTo(insets.top),
    );
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThanOrEqualTo(phone.height - insets.bottom),
    );
  });

  testWidgets('a panel stands clear of the system bars, its header at its '
      'own top', (tester) async {
    const tablet = Size(800, 900);
    const insets = EdgeInsets.only(top: 24, bottom: 20);
    await open(tester, tablet, padding: insets);

    final panel = tester.getRect(find.byType(FrontChatPane));
    expect(panel.top, greaterThan(insets.top));
    expect(panel.bottom, lessThan(tablet.height - insets.bottom));
    // Not padded a second time inside the panel.
    expect(tester.getRect(find.byType(FrontChatHeader)).top, panel.top);
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
