import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';
import '../../ai_consumption/test_utils.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    VoidCallback? onClose,
    ConsumptionTotals? totals,
    bool companion = false,
  }) async {
    await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(body: FrontChatHeader(onClose: onClose ?? () {})),
        overrides: [
          configFlagProvider.overrideWith(
            (ref, flag) =>
                Stream.value(companion && flag == enableCompanionFlag),
          ),
          agentConsumptionTotalsProvider(frontAgentId).overrideWith(
            (ref) => totals == null
                ? const Stream<ConsumptionTotals>.empty()
                : Stream.value(totals),
          ),
        ],
      ),
    );
    // Her face animates, so no settle: a few frames let the flag and the
    // totals streams deliver.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('names her, says what she does, and offers close and the '
      'internals', (tester) async {
    var closed = 0;
    await pumpHeader(tester, onClose: () => closed++);

    expect(
      tester.widget<Text>(find.byKey(FrontChatHeaderKeys.title)).data,
      'Companion',
    );
    expect(
      tester.widget<Text>(find.byKey(FrontChatHeaderKeys.subtitle)).data,
      'Ask anything — she finds who knows',
    );
    expect(find.byKey(FrontChatHeaderKeys.internals), findsOneWidget);
    expect(find.byTooltip('Agent internals'), findsOneWidget);

    await tester.tap(find.byKey(FrontChatHeaderKeys.close));
    expect(closed, 1);
  });

  testWidgets('shows no cost before the totals are known', (tester) async {
    await pumpHeader(tester);
    expect(find.byKey(FrontChatHeaderKeys.cost), findsNothing);
  });

  testWidgets('shows what the thread has cost once the totals are known', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      totals: makeConsumptionTotals(
        callCount: 3,
        totalTokens: 2000,
        credits: 0.42,
        energyKwh: 0.012,
        carbonGCo2: 3.4,
      ),
    );
    final pill = tester.widget<ConsumptionSummaryPill>(
      find.byKey(FrontChatHeaderKeys.cost),
    );
    expect(pill.totals.credits, 0.42);
    expect(pill.totals.totalTokens, 2000);
  });

  testWidgets('wears the spark tile when the companion is off', (
    tester,
  ) async {
    await pumpHeader(tester);
    expect(find.byType(CompanionView), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(FrontChatHeaderKeys.figure),
        matching: find.byIcon(LottiIcons.aiSpark),
      ),
      findsOneWidget,
    );
  });

  testWidgets('wears her face when the companion is on', (tester) async {
    await pumpHeader(tester, companion: true);
    expect(
      find.descendant(
        of: find.byKey(FrontChatHeaderKeys.figure),
        matching: find.byType(CompanionView),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(LottiIcons.aiSpark), findsNothing);
  });
}
