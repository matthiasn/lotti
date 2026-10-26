import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
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
    double width = 400,
    FrontChatThread thread = FrontChatThread.empty,
    FrontChatThread Function()? threadOf,
  }) async {
    await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: FrontChatHeader(onClose: onClose ?? () {}),
            ),
          ),
        ),
        overrides: [
          configFlagProvider.overrideWith(
            (ref, flag) =>
                Stream.value(companion && flag == enableCompanionFlag),
          ),
          // The internals panel resolves the identity; it may stay in flight.
          agentIdentityProvider.overrideWith(
            (ref, agentId) => Completer<AgentDomainEntity?>().future,
          ),
          agentStateProvider.overrideWith((ref, agentId) async => null),
          frontChatThreadProvider.overrideWith(
            (ref) async => threadOf?.call() ?? thread,
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

  testWidgets('the internals action opens her internals panel', (
    tester,
  ) async {
    await pumpHeader(tester);

    await tester.tap(find.byKey(FrontChatHeaderKeys.internals));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final panel = tester.widget<AgentInternalsPanel>(
      find.byType(AgentInternalsPanel),
    );
    expect(panel.agentId, frontAgentId);
    expect(panel.agentName, 'Companion');
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
    // In the sheet's width the pill sits under the subtitle, so what she
    // does is never squeezed into an ellipsis.
    expect(
      tester.getTopLeft(find.byKey(FrontChatHeaderKeys.cost)).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.byKey(FrontChatHeaderKeys.subtitle)).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(FrontChatHeaderKeys.cost)).dx,
      tester.getTopLeft(find.byKey(FrontChatHeaderKeys.subtitle)).dx,
    );
  });

  testWidgets('with room for a word beside it the pill rides the title line', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      width: 720,
      totals: makeConsumptionTotals(callCount: 1, totalTokens: 10),
    );
    final cost = tester.getRect(find.byKey(FrontChatHeaderKeys.cost));
    final title = tester.getRect(find.byKey(FrontChatHeaderKeys.title));
    expect(cost.left, greaterThan(title.right));
    expect(cost.top, lessThan(title.bottom));
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

  group('the inbox chip', () {
    FrontChatThread waiting(int count) => FrontChatThread(
      messages: const [],
      doorsByMessageId: {
        'u1': [
          for (var i = 0; i < count; i++)
            FrontDoorEntry(
              doorId: 'd:door:$i',
              record: FrontDoorRecord(
                segmentIndex: i,
                text: 'segment $i',
                kind: FrontDestinationKind.unrouted,
                status: FrontDoorStatus.done,
                claimedAt: DateTime.utc(2026, 10, 26),
                outcome: const FrontDoorInbox(),
              ),
            ),
        ],
      },
    );

    testWidgets('is absent while nothing waits on the user', (tester) async {
      await pumpHeader(tester);
      expect(find.byKey(FrontChatHeaderKeys.inbox), findsNothing);
    });

    testWidgets('counts the doors that wait and toggles the inbox filter', (
      tester,
    ) async {
      await pumpHeader(tester, thread: waiting(2));
      final chip = find.byKey(FrontChatHeaderKeys.inbox);
      expect(tester.widget<DesignSystemChip>(chip).label, 'Inbox 2');
      expect(tester.widget<DesignSystemChip>(chip).selected, isFalse);
      // Under the subtitle in the sheet's width, like the cost pill.
      expect(
        tester.getTopLeft(chip).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byKey(FrontChatHeaderKeys.subtitle)).dy,
        ),
      );

      await tester.tap(chip);
      await tester.pump();

      expect(tester.widget<DesignSystemChip>(chip).selected, isTrue);
      final container = ProviderScope.containerOf(tester.element(chip));
      expect(container.read(frontInboxFilterProvider), isTrue);
    });

    testWidgets('stays while the filter is on even when nothing waits any '
        'more, so it can be switched off', (tester) async {
      var thread = waiting(1);
      await pumpHeader(tester, threadOf: () => thread);
      final chip = find.byKey(FrontChatHeaderKeys.inbox);
      await tester.tap(chip);
      await tester.pump();
      final container = ProviderScope.containerOf(tester.element(chip));
      expect(container.read(frontInboxFilterProvider), isTrue);

      // The last item was taken somewhere.
      thread = waiting(0);
      container.invalidate(frontChatThreadProvider);
      await tester.pump();
      await tester.pump();

      expect(tester.widget<DesignSystemChip>(chip).label, 'Inbox 0');
      expect(tester.widget<DesignSystemChip>(chip).selected, isTrue);

      await tester.tap(chip);
      await tester.pump();

      expect(container.read(frontInboxFilterProvider), isFalse);
      expect(find.byKey(FrontChatHeaderKeys.inbox), findsNothing);
    });
  });
}
