import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_hero.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    VoidCallback? onClose,
    bool companion = false,
    double width = 400,
    FrontChatThread thread = FrontChatThread.empty,
    FrontChatThread Function()? threadOf,
    FrontConversationIndex conversations = FrontConversationIndex.empty,
  }) async {
    await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              // The header over the hero, as the pane lays them out.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FrontChatHeader(onClose: onClose ?? () {}),
                  const FrontChatHero(),
                ],
              ),
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
          // The inbox counts across every conversation.
          frontAllChatsThreadProvider.overrideWith(
            (ref) async => threadOf?.call() ?? thread,
          ),
          frontConversationsProvider.overrideWith((ref) async => conversations),
        ],
      ),
    );
    // Her face animates, so no settle: a few frames let the flag and the
    // thread land.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('conversations', () {
    final census = FrontConversationIndex(
      conversations: [
        FrontConversation(
          id: 'c-1',
          title: 'Plan the census',
          lastActivity: DateTime(2026, 10, 31, 9),
          archived: false,
        ),
      ],
    );
    String titleOf(WidgetTester tester) => tester
        .widget<Text>(
          find.byKey(FrontChatHeaderKeys.title).evaluate().isNotEmpty
              ? find.byKey(FrontChatHeaderKeys.title)
              : find.byKey(FrontChatHeroKeys.title),
        )
        .data!;
    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(FrontChatHeader)),
        );

    testWidgets('names the open conversation by its title, whole on hover '
        'however much of it fades', (tester) async {
      await pumpHeader(tester, conversations: census);
      expect(titleOf(tester), 'Plan the census');
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(FrontChatHeroKeys.title),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, 'Plan the census');
    });

    testWidgets('once her hero has scrolled away the header carries her '
        'and the title in a line', (tester) async {
      await pumpHeader(tester, conversations: census);
      expect(find.byKey(FrontChatHeaderKeys.title), findsNothing);

      containerOf(tester).read(frontHeroScrolledProvider.notifier).follow(500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final compact = find.byKey(FrontChatHeaderKeys.title);
      expect(tester.widget<Text>(compact).data, 'Plan the census');
      final more = tester.getRect(find.byKey(FrontChatHeaderKeys.more));
      expect(tester.getRect(compact).top, lessThan(more.bottom));

      // Back at the top, the line gives way to the hero again.
      containerOf(tester).read(frontHeroScrolledProvider.notifier).follow(0);
      await tester.pump();
      expect(find.byKey(FrontChatHeaderKeys.title), findsNothing);
    });

    testWidgets('names her for a conversation not begun, whose new-chat '
        'action has nothing to start', (tester) async {
      await pumpHeader(tester);
      expect(titleOf(tester), 'Companion');
      expect(
        tester
            .widget<DesignSystemIconAction>(
              find.byKey(FrontChatHeaderKeys.newChat),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('the title opens the list, whose header is back, Chats and '
        'close; back returns to the conversation', (tester) async {
      await pumpHeader(tester, conversations: census);
      final container = containerOf(tester);
      final listOpen = container.listen(
        frontConversationListOpenProvider,
        (_, _) {},
      );
      addTearDown(listOpen.close);

      await tester.tap(find.byKey(FrontChatHeaderKeys.chats));
      await tester.pump();
      expect(listOpen.read(), isTrue);
      expect(titleOf(tester), 'Chats');
      // Nothing that would duplicate the list's own new-chat row.
      expect(find.byKey(FrontChatHeaderKeys.newChat), findsNothing);
      expect(find.byKey(FrontChatHeaderKeys.more), findsNothing);
      expect(find.byKey(FrontChatHeaderKeys.close), findsOneWidget);

      await tester.tap(find.byKey(FrontChatHeaderKeys.back));
      await tester.pump();
      expect(listOpen.read(), isFalse);
      expect(titleOf(tester), 'Plan the census');
    });

    testWidgets('the overflow holds her internals, then the open '
        "conversation's own ways out, the destructive one last", (
      tester,
    ) async {
      await pumpHeader(tester, conversations: census);

      final items = tester
          .widget<DesignSystemContextMenuButton>(
            find.byKey(FrontChatHeaderKeys.more),
          )
          .items
          .map((item) => item.label)
          .toList();

      expect(items, [
        'Agent internals',
        'Rename chat',
        'Archive chat',
        'Delete chat',
      ]);
    });

    testWidgets('a conversation not begun has only her internals in the '
        'overflow', (tester) async {
      await pumpHeader(tester);

      final items = tester
          .widget<DesignSystemContextMenuButton>(
            find.byKey(FrontChatHeaderKeys.more),
          )
          .items;

      expect(items.map((item) => item.label), ['Agent internals']);
    });

    testWidgets('the inbox, which gathers every conversation, is named and '
        "offers no single conversation's actions", (tester) async {
      await pumpHeader(tester, conversations: census);
      final container = containerOf(tester);
      final filter = container.listen(frontInboxFilterProvider, (_, _) {});
      addTearDown(filter.close);

      container.read(frontInboxFilterProvider.notifier).toggle();
      await tester.pump();

      expect(titleOf(tester), 'Inbox');
      expect(
        tester
            .widget<DesignSystemContextMenuButton>(
              find.byKey(FrontChatHeaderKeys.more),
            )
            .items
            .map((item) => item.label),
        ['Agent internals'],
      );
    });

    testWidgets('an archived conversation says so before its title', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        conversations: FrontConversationIndex(
          conversations: [
            FrontConversation(
              id: 'c-0',
              title: 'Ice shelf survey',
              lastActivity: DateTime(2026, 9, 2),
              archived: true,
            ),
          ],
        ),
      );
      containerOf(
        tester,
      ).read(frontPickedConversationProvider.notifier).picked = 'c-0';
      await tester.pump();
      await tester.pump();

      expect(titleOf(tester), 'Ice shelf survey');
      final glyph = tester.getRect(find.byKey(FrontChatHeroKeys.archived));
      final title = tester.getRect(find.byKey(FrontChatHeroKeys.title));
      expect(glyph.right, lessThanOrEqualTo(title.left));
    });

    testWidgets('a new chat starts an empty conversation', (tester) async {
      await pumpHeader(tester, conversations: census);
      final container = containerOf(tester);

      await tester.tap(find.byKey(FrontChatHeaderKeys.newChat));
      await tester.pump();
      await tester.pump();

      final picked = container.read(frontPickedConversationProvider);
      expect(picked, isNot(anyOf(isNull, 'c-1')));
      expect(titleOf(tester), 'Companion');
    });
  });

  testWidgets('a row of controls — the ways to another conversation lead, '
      "this conversation's overflow and close trail — over her and the "
      'title, centred', (tester) async {
    var closed = 0;
    await pumpHeader(tester, onClose: () => closed++);

    Rect at(Key key) => tester.getRect(find.byKey(key));
    final order = [
      FrontChatHeaderKeys.chats,
      FrontChatHeaderKeys.newChat,
      FrontChatHeaderKeys.more,
      FrontChatHeaderKeys.close,
    ].map(at).toList();
    for (var i = 1; i < order.length; i++) {
      expect(order[i].left, greaterThanOrEqualTo(order[i - 1].right));
      expect(order[i].top, lessThan(order[0].bottom));
    }
    final figure = at(FrontChatHeroKeys.figure);
    final title = at(FrontChatHeroKeys.title);
    expect(figure.top, greaterThanOrEqualTo(order[0].bottom));
    expect(title.top, greaterThanOrEqualTo(figure.bottom));
    expect(title.center.dx, closeTo(figure.center.dx, 1));

    await tester.tap(find.byKey(FrontChatHeaderKeys.close));
    expect(closed, 1);
  });

  testWidgets('her internals open from the overflow', (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byKey(FrontChatHeaderKeys.more));
    await tester.pumpAndSettle();
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

  testWidgets('with the companion off the spark every agent wears stands '
      'in for her', (tester) async {
    await pumpHeader(tester);
    expect(find.byType(CompanionView), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(FrontChatHeroKeys.figure),
        matching: find.byIcon(LottiIcons.aiSpark),
      ),
      findsOneWidget,
    );
  });

  testWidgets('wears her face when the companion is on', (tester) async {
    await pumpHeader(tester, companion: true);
    expect(
      find.descendant(
        of: find.byKey(FrontChatHeroKeys.figure),
        matching: find.byType(CompanionView),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(LottiIcons.aiSpark), findsNothing);
  });

  group('the inbox dot', () {
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

    testWidgets('a dot on the way to the list says something waits', (
      tester,
    ) async {
      await pumpHeader(tester, thread: waiting(2));

      final dot = tester.getRect(find.byKey(FrontChatHeaderKeys.inbox));
      final list = tester.getRect(find.byKey(FrontChatHeaderKeys.chats));
      expect(list.overlaps(dot), isTrue);
      expect(
        tester
            .widget<DesignSystemBadge>(find.byKey(FrontChatHeaderKeys.inbox))
            .semanticLabel,
        'Inbox 2',
      );
    });
  });
}
