import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/features/front_agent/ui/front_chat_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  Future<void> openSheet(WidgetTester tester, Size window) async {
    await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);
    setTestSurfaceSize(tester, window);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFrontChatSheet(context),
            child: const Text('Ask'),
          ),
        ),
        mediaQueryData: MediaQueryData(size: window),
        overrides: [
          frontChatThreadProvider.overrideWith(
            (ref) async => FrontChatThread.empty,
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

  testWidgets('on a wide window opens her chat as the agent-chat side sheet, '
      'docked at the window edge', (tester) async {
    const desktop = Size(1400, 900);
    await openSheet(tester, desktop);

    final rect = tester.getRect(find.byType(FrontChatPane));
    expect(rect.width, moreOrLessEquals(kAgentChatSheetWidth, epsilon: 1));
    expect(rect.right, moreOrLessEquals(desktop.width, epsilon: 1));
  });

  testWidgets('on a phone the same call opens her as a bottom sheet the '
      'width of the window', (tester) async {
    const phone = Size(390, 844);
    await openSheet(tester, phone);

    final rect = tester.getRect(find.byType(FrontChatPane));
    expect(rect.width, moreOrLessEquals(phone.width, epsilon: 1));
    expect(rect.bottom, moreOrLessEquals(phone.height, epsilon: 1));
  });

  testWidgets("the pane's close dismisses the sheet", (tester) async {
    await openSheet(tester, const Size(1400, 900));

    await tester.tap(find.byKey(FrontChatHeaderKeys.close));
    await tester.pumpAndSettle();

    expect(find.byType(FrontChatPane), findsNothing);
    expect(find.text('Ask'), findsOneWidget);
  });
}
