import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_actions.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2026, 10, 31, 15);
  late MockFrontConversationService service;

  setUp(() {
    service = MockFrontConversationService();
    when(() => service.rename(any(), any())).thenAnswer((_) async {});
    when(
      () => service.archive(any(), archived: any(named: 'archived')),
    ).thenAnswer((_) async {});
    when(() => service.delete(any())).thenAnswer((_) async {});
  });

  FrontConversation conversation(
    String id,
    String title, {
    required DateTime at,
    bool archived = false,
  }) => FrontConversation(
    id: id,
    title: title,
    lastActivity: at,
    archived: archived,
  );

  final colony = FrontConversationIndex(
    conversations: [
      conversation(
        'c-2',
        'Count the hatchlings',
        at: DateTime(2026, 10, 31, 9),
      ),
      conversation('c-1', 'Plan the census', at: DateTime(2026, 10, 29, 9)),
      conversation(
        'c-0',
        'Feeding rota',
        at: DateTime(2026, 10, 20, 9),
        archived: true,
      ),
    ],
  );

  /// Pumps the list for [index] with `c-1` open and the list shown.
  Future<ProviderContainer> pumpList(
    WidgetTester tester, {
    FrontConversationIndex? index,
    bool beside = false,
    FrontChatThread? allChats,
  }) async {
    await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);
    // Every frame on the fixtures' day, the ones after the list opens too:
    // a rebuild on the real clock re-groups the rows and re-labels their
    // times, so the suite would pass only on the day it was written.
    return withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(body: FrontConversationList(beside: beside)),
          overrides: [
            frontConversationsProvider.overrideWith(
              (ref) async => index ?? colony,
            ),
            frontConversationServiceProvider.overrideWithValue(service),
            if (allChats != null)
              frontAllChatsThreadProvider.overrideWith((ref) async => allChats),
          ],
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FrontConversationList)),
      );
      // Both auto-dispose otherwise; the list is open while it shows.
      final open = container.listen(
        frontConversationListOpenProvider,
        (_, _) {},
      );
      addTearDown(open.close);
      container
        ..read(frontPickedConversationProvider.notifier).picked = 'c-1'
        ..read(frontConversationListOpenProvider.notifier).toggle();
      await tester.pump();
      await tester.pump();
      return container;
    });
  }

  List<String> titles(WidgetTester tester) => [
    for (final item in tester.widgetList<DesignSystemListItem>(
      find.byType(DesignSystemListItem),
    ))
      _textOf(item.titleContent!),
  ];

  /// Opens a row's menu: its ⋯ when the row shows one (the open row),
  /// else the long press every row answers.
  Future<void> openMenu(WidgetTester tester, String id) async {
    final dots = find.byKey(FrontConversationListKeys.menu(id));
    if (tester
        .widget<Visibility>(
          find.ancestor(of: dots, matching: find.byType(Visibility)).first,
        )
        .visible) {
      await tester.tap(dots);
    } else {
      await tester.longPress(find.byKey(FrontConversationListKeys.row(id)));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing said yet, the band offers a new chat and no '
      'search, and the list only invites', (tester) async {
    await pumpList(tester, index: FrontConversationIndex.empty, beside: true);

    expect(titles(tester), isEmpty);
    expect(find.text('No chats yet. Ask something to start one.'), findsOne);
    expect(find.byKey(FrontConversationListKeys.newChat), findsOne);
    expect(find.byKey(FrontConversationListKeys.search), findsNothing);
    expect(find.byType(DesignSystemSearch), findsNothing);
  });

  testWidgets('beside the conversation the list has a band of its own: '
      "Chats, its search and a new chat, as tall as her header's", (
    tester,
  ) async {
    await pumpList(tester, beside: true);

    expect(find.text('Chats'), findsOne);
    final band = find.ancestor(
      of: find.text('Chats'),
      matching: find.byType(DecoratedBox),
    );
    final search = tester.getRect(find.byKey(FrontConversationListKeys.search));
    final newChat = tester.getRect(
      find.byKey(FrontConversationListKeys.newChat),
    );
    // One row: the title, then the search, then the new chat at the end.
    expect(search.center.dy, newChat.center.dy);
    expect(search.right, lessThanOrEqualTo(newChat.left));
    // Her header's height: a tap target over a title line, and the band's
    // inset above and below it.
    final tokens = tester
        .element(find.byType(FrontConversationList))
        .designTokens;
    expect(
      tester.getRect(band.first).height,
      TapTargets.minimum +
          tokens.typography.lineHeight.bodySmall +
          2 * tokens.spacing.step2,
    );
    // The page's one action wears the accent.
    expect(
      tester
          .widget<DesignSystemIconAction>(
            find.byKey(FrontConversationListKeys.newChat),
          )
          .tone,
      tokens.colors.interactive.enabled,
    );
  });

  testWidgets('as a page, the list leaves its actions to the page header', (
    tester,
  ) async {
    await pumpList(tester);

    expect(find.text('Chats'), findsNothing);
    expect(find.byKey(FrontConversationListKeys.newChat), findsNothing);
    expect(find.byKey(FrontConversationListKeys.search), findsNothing);
  });

  testWidgets('the live ones newest first under recency sections with the '
      'open one marked, the archived folded away', (
    tester,
  ) async {
    // Every frame of this test reads the fixed day.
    await withClock(Clock.fixed(now), () async {
      await pumpList(tester);

      expect(titles(tester), [
        'Count the hatchlings',
        'Plan the census',
        'Archived chats · 1',
      ]);
      // The date is said once per section, not on every row.
      expect(find.text('Today'), findsOne);
      expect(find.text('Previous 7 days'), findsOne);
      expect(find.text('Yesterday'), findsNothing);
      final today = tester.getRect(find.text('Today'));
      final week = tester.getRect(find.text('Previous 7 days'));
      final first = tester.getRect(find.text('Count the hatchlings'));
      final second = tester.getRect(find.text('Plan the census'));
      expect(today.top, lessThan(first.top));
      expect(first.top, lessThan(week.top));
      expect(week.top, lessThan(second.top));
      DesignSystemListItem itemOf(String id) => tester.widget(
        find.descendant(
          of: find.byKey(FrontConversationListKeys.row(id)),
          matching: find.byType(DesignSystemListItem),
        ),
      );
      expect(itemOf('c-1').activated, isTrue);
      expect(itemOf('c-2').activated, isFalse);

      await tester.tap(find.byKey(FrontConversationListKeys.archived));
      await tester.pump();

      expect(titles(tester).last, 'Feeding rota');
    });
  });

  testWidgets('older conversations are sectioned by yesterday and older', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      await pumpList(
        tester,
        index: FrontConversationIndex(
          conversations: [
            conversation('c-y', 'Seal watch', at: DateTime(2026, 10, 30, 22)),
            conversation('c-o', 'Moult log', at: DateTime(2026, 9)),
          ],
        ),
      );

      // The section says when; its rows say no time of their own.
      expect(find.text('Yesterday'), findsOne);
      expect(find.text('Older'), findsOne);
      expect(find.text('Today'), findsNothing);
    });
  });

  testWidgets('search looks through the archived ones too, drops the '
      'sections, and says when nothing matches', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pumpList(tester, beside: true);

      // The search opens in place from the band's glyph.
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byKey(FrontConversationListKeys.search));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'CENSUS');
      await tester.pump();
      expect(titles(tester), ['Plan the census']);
      expect(find.text('Today'), findsNothing);

      await tester.enterText(find.byType(TextField), 'rota');
      await tester.pump();
      expect(titles(tester), ['Feeding rota']);

      await tester.enterText(find.byType(TextField), 'krill');
      await tester.pump();
      expect(titles(tester), isEmpty);
      expect(find.text('No chat title matches.'), findsOne);

      // Clearing closes it again, and the list is back as it was.
      await tester.tap(find.byIcon(LottiIcons.closeCircled));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Today'), findsOne);
    });
  });

  testWidgets('with something in the inbox, the first letter typed stays in '
      'the search, and the field keeps focus', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pumpList(
        tester,
        beside: true,
        allChats: FrontChatThread(
          messages: const [],
          doorsByMessageId: {
            'u1': [
              FrontDoorEntry(
                doorId: 'd:door:0',
                record: FrontDoorRecord(
                  segmentIndex: 0,
                  text: 'A loose thought',
                  kind: FrontDestinationKind.unrouted,
                  status: FrontDoorStatus.done,
                  claimedAt: DateTime.utc(2026, 10, 26),
                  outcome: const FrontDoorInbox(),
                ),
              ),
            ],
          },
        ),
      );
      expect(find.byKey(FrontConversationListKeys.inbox), findsOne);

      await tester.tap(find.byKey(FrontConversationListKeys.search));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'c');
      await tester.pump();

      // Searching hides the inbox row above the field; the field stays.
      expect(find.byKey(FrontConversationListKeys.inbox), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'c');
      expect(field.focusNode!.hasFocus, isTrue);
      expect(titles(tester), contains('Plan the census'));
    });
  });

  testWidgets('the open conversation is always on the page: an archived '
      'one opens its group', (tester) async {
    final container = await pumpList(tester);
    container.read(frontPickedConversationProvider.notifier).picked = 'c-0';
    await tester.pump();
    await tester.pump();

    expect(titles(tester).last, 'Feeding rota');
  });

  testWidgets("a row says where its conversation got to: her last answer's "
      'first line, under the title', (tester) async {
    await pumpList(
      tester,
      index: FrontConversationIndex(
        conversations: [
          FrontConversation(
            id: 'c-1',
            title: 'Plan the census',
            lastActivity: now,
            archived: false,
            preview: 'Saturday works.',
          ),
          FrontConversation(
            id: 'c-2',
            title: 'Feeding rota',
            lastActivity: now,
            archived: false,
          ),
        ],
      ),
    );
    // Her last answer under the title; a conversation not answered yet has
    // no words there.
    expect(
      find.descendant(
        of: find.byKey(FrontConversationListKeys.row('c-1')),
        matching: find.text('Saturday works.'),
      ),
      findsOne,
    );
    final rotaTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(FrontConversationListKeys.row('c-2')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .whereType<String>()
        .where((t) => t.isNotEmpty);
    expect(rotaTexts, isNot(contains('Saturday works.')));
    expect(rotaTexts.first, 'Feeding rota');
  });

  testWidgets('the groups are flat: a neutral label over its rows, no card '
      'and no hairlines, each row dense and rounded for its own fill', (
    tester,
  ) async {
    await pumpList(tester);
    expect(find.byType(DesignSystemGroupedList), findsNothing);
    final rows = tester.widgetList<DesignSystemListItem>(
      find.descendant(
        of: find.byKey(FrontConversationListKeys.row('c-1')),
        matching: find.byType(DesignSystemListItem),
      ),
    );
    expect(rows.single.showDivider, isFalse);
    expect(rows.single.borderRadius, isNotNull);
    expect(rows.single.size, DesignSystemListItemSize.small);

    // The day is said quietly: the accent means "press", and a day is not
    // pressed.
    final quiet = tester
        .element(find.byType(FrontConversationList))
        .designTokens
        .colors
        .text
        .lowEmphasis;
    final days = tester.widgetList<Text>(
      find.textContaining(RegExp(r'^(Today|Yesterday|Previous 7 days|Older)$')),
    );
    expect(days, isNotEmpty);
    expect(days.map((t) => t.style!.color), everyElement(quiet));
  });

  testWidgets('a row says no time of its own — its section says when — and '
      "her answer runs the row's width on one line; the open row says it a "
      'step brighter', (tester) async {
    // Every frame of this test reads the fixed day: "today at 11:58" is
    // today only while the clock says it is that day.
    await withClock(Clock.fixed(now), () async {
      FrontConversation chat(String id, DateTime at) => FrontConversation(
        id: id,
        title: 'Chat $id',
        lastActivity: at,
        archived: false,
        preview:
            'Saturday works: low tide is early, so the census starts '
            'at the north colony and moves south along the shelf.',
      );
      await pumpList(
        tester,
        index: FrontConversationIndex(
          conversations: [
            chat('c-1', DateTime(2026, 10, 31, 11, 58)),
            chat('c-2', DateTime(2026, 10, 27, 9)),
          ],
        ),
      );
      Finder inRow(String id, Finder finder) => find.descendant(
        of: find.byKey(FrontConversationListKeys.row(id)),
        matching: finder,
      );
      // Neither the clock today nor the weekday this week.
      expect(find.text('11:58 AM'), findsNothing);
      expect(find.text('Tue'), findsNothing);
      expect(find.text('Today'), findsOne);
      expect(find.text('Previous 7 days'), findsOne);

      Text preview(String id) =>
          tester.widget<Text>(inRow(id, find.textContaining('Saturday works')));
      Rect previewBox(String id) =>
          tester.getRect(inRow(id, find.textContaining('Saturday works')));
      Rect titleBox(String id) =>
          tester.getRect(inRow(id, find.text('Chat $id')));
      expect(previewBox('c-1').right, previewBox('c-2').right);
      expect(previewBox('c-1').left, titleBox('c-1').left);
      expect(preview('c-1').overflow, TextOverflow.ellipsis);
      expect(preview('c-1').maxLines, 1);

      final colors = tester
          .element(find.byKey(FrontConversationListKeys.row('c-1')))
          .designTokens
          .colors
          .text;
      expect(preview('c-1').style!.color, colors.mediumEmphasis);
      expect(preview('c-2').style!.color, colors.lowEmphasis);
      // The title takes one line too, so every row is the same height.
      expect(
        tester.widget<Text>(inRow('c-1', find.text('Chat c-1'))).maxLines,
        1,
      );
    });
  });

  testWidgets("on a wide window a row's menu shows on hover and focus", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpList(tester);
    bool shown(String id) => tester
        .widget<Visibility>(
          find
              .ancestor(
                of: find.byKey(FrontConversationListKeys.menu(id)),
                matching: find.byType(Visibility),
              )
              .first,
        )
        .visible;
    expect(shown('c-2'), isFalse);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(FrontConversationListKeys.row('c-2'))),
    );
    await tester.pump();
    expect(shown('c-2'), isTrue);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(shown('c-2'), isFalse);
  });

  testWidgets('beside the open conversation its row keeps its menu out of '
      'shows its menu only on hover like any other', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpList(tester, beside: true);
    bool shown(String id) => tester
        .widget<Visibility>(
          find
              .ancestor(
                of: find.byKey(FrontConversationListKeys.menu(id)),
                matching: find.byType(Visibility),
              )
              .first,
        )
        .visible;
    expect(shown('c-1'), isFalse);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(FrontConversationListKeys.row('c-1'))),
    );
    await tester.pump();
    expect(shown('c-1'), isTrue);
  });

  testWidgets('not beside it, the open row shows its menu at rest', (
    tester,
  ) async {
    await pumpList(tester);
    expect(
      tester
          .widget<Visibility>(
            find
                .ancestor(
                  of: find.byKey(FrontConversationListKeys.menu('c-1')),
                  matching: find.byType(Visibility),
                )
                .first,
          )
          .visible,
      isTrue,
    );
  });

  testWidgets('an empty search closes when focus leaves it', (tester) async {
    await pumpList(tester, beside: true);

    await tester.tap(find.byKey(FrontConversationListKeys.search));
    await tester.pump();
    expect(find.byType(TextField), findsOne);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets("a row's menu sits on its title's first line, at its end — a "
      "wrapped title and her answer below — and the menu's whole target "
      'stays inside the row', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pumpList(
        tester,
        index: FrontConversationIndex(
          conversations: [
            FrontConversation(
              id: 'c-1',
              title:
                  'Plan the census along the northern shelf before the '
                  'tide turns and the colony wakes',
              lastActivity: DateTime(2026, 10, 29, 9),
              archived: false,
              preview: 'Saturday works: low tide is early.',
            ),
            FrontConversation(
              id: 'c-2',
              title: 'Count the hatchlings',
              lastActivity: DateTime(2026, 10, 31, 9),
              archived: false,
              preview: 'Forty-two across the three colonies.',
            ),
            // Not answered yet: one line, and no answer under it.
            FrontConversation(
              id: 'c-3',
              title: 'Feeding rota',
              lastActivity: DateTime(2026, 10, 31, 8),
              archived: false,
            ),
          ],
        ),
      );
      Finder inRow(String id, Finder finder) => find.descendant(
        of: find.byKey(FrontConversationListKeys.row(id)),
        matching: finder,
      );

      // A one-line title over her answer, both from the same edge.
      final title = tester.getRect(
        inRow('c-2', find.text('Count the hatchlings')),
      );
      final answer = tester.getRect(
        inRow('c-2', find.textContaining('Forty-two')),
      );
      expect(title.bottom, lessThanOrEqualTo(answer.top));
      expect(answer.left, title.left);

      // The open row's wrapped title: the menu on its first line, in the
      // room kept for it at its end — never over the title, and not on the
      // line of her answer.
      final wrapped = tester.getRect(
        inRow('c-1', find.textContaining('Plan the census')),
      );
      final glyph = tester.getCenter(
        find.descendant(
          of: find.byKey(FrontConversationListKeys.menu('c-1')),
          matching: find.byIcon(LottiIcons.more),
        ),
      );
      final firstLine = wrapped.top + wrapped.height / 4;
      expect(glyph.dy, closeTo(firstLine, 3));
      expect(
        tester
            .getRect(
              find.descendant(
                of: find.byKey(FrontConversationListKeys.menu('c-1')),
                matching: find.byIcon(LottiIcons.more),
              ),
            )
            .left,
        greaterThan(wrapped.right),
      );
      expect(
        glyph.dy,
        lessThan(
          tester.getRect(inRow('c-1', find.textContaining('Saturday'))).top,
        ),
      );
      final target = tester.getRect(
        find.byKey(FrontConversationListKeys.menu('c-1')),
      );
      final row = tester.getRect(
        find.byKey(FrontConversationListKeys.row('c-1')),
      );
      expect(row.top, lessThanOrEqualTo(target.top));
      expect(row.bottom, greaterThanOrEqualTo(target.bottom));

      // The shortest row — one line, nothing under it — still holds its
      // menu's whole target.
      final short = tester.getRect(
        find.byKey(FrontConversationListKeys.row('c-3')),
      );
      final shortTarget = tester.getRect(
        find.byKey(FrontConversationListKeys.menu('c-3')),
      );
      expect(short.top, lessThanOrEqualTo(shortTarget.top));
      expect(short.bottom, greaterThanOrEqualTo(shortTarget.bottom));
    });
  });

  testWidgets("a tap at the edge of a row's menu opens the menu, never the "
      'conversation', (tester) async {
    final container = await pumpList(tester);

    // The open row shows its menu.
    final menu = tester.getRect(
      find.byKey(FrontConversationListKeys.menu('c-1')),
    );
    // Just inside the menu's own corner.
    await tester.tapAt(menu.topLeft + const Offset(1, 1));
    await tester.pumpAndSettle();

    expect(find.byKey(FrontConversationActionKeys.rename('c-1')), findsOne);
    // A tap on the row itself would have opened it and closed the list.
    expect(container.read(frontConversationListOpenProvider), isTrue);
  });

  testWidgets("a long press offers any row's menu, which acts on that "
      'conversation', (tester) async {
    await pumpList(tester);
    // Not the open row: its menu does not show.
    expect(
      tester
          .widget<Visibility>(
            find
                .ancestor(
                  of: find.byKey(FrontConversationListKeys.menu('c-2')),
                  matching: find.byType(Visibility),
                )
                .first,
          )
          .visible,
      isFalse,
    );

    await tester.longPress(find.byKey(FrontConversationListKeys.row('c-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FrontConversationActionKeys.archive('c-2')));
    await tester.pumpAndSettle();

    verify(() => service.archive('c-2', archived: true)).called(1);
  });

  testWidgets('a tap opens that conversation and closes the list; a new '
      'chat opens an empty one', (tester) async {
    final container = await pumpList(tester, beside: true);

    await tester.tap(find.text('Count the hatchlings'));
    await tester.pump();
    expect(container.read(frontPickedConversationProvider), 'c-2');
    expect(container.read(frontConversationListOpenProvider), isFalse);

    container.read(frontConversationListOpenProvider.notifier).toggle();
    await tester.pump();
    await tester.tap(find.byKey(FrontConversationListKeys.newChat));
    await tester.pump();
    expect(
      container.read(frontPickedConversationProvider),
      isNot(anyOf('c-0', 'c-1', 'c-2')),
    );
    expect(container.read(frontConversationListOpenProvider), isFalse);
  });

  testWidgets('rename saves the new title; a blank one is not saved', (
    tester,
  ) async {
    await pumpList(tester);

    await openMenu(tester, 'c-1');
    await tester.tap(find.byKey(FrontConversationActionKeys.rename('c-1')));
    await tester.pumpAndSettle();
    final input = find.byKey(FrontConversationActionKeys.titleInput);
    // Renaming is usually replacing: the whole title opens selected.
    final field = tester.widget<TextField>(
      find.descendant(of: input, matching: find.byType(TextField)),
    );
    expect(
      field.controller!.selection,
      const TextSelection(
        baseOffset: 0,
        extentOffset: 'Plan the census'.length,
      ),
    );
    await tester.enterText(
      find.descendant(of: input, matching: find.byType(TextField)),
      '   ',
    );
    await tester.pump();
    // Nothing to save until there is a title.
    expect(
      tester
          .widget<DesignSystemButton>(
            find.byKey(FrontConversationActionKeys.titleSave),
          )
          .onPressed,
      isNull,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    verifyNever(() => service.rename(any(), any()));

    await tester.enterText(
      find.descendant(of: input, matching: find.byType(TextField)),
      '  Colony census ',
    );
    await tester.pump();
    await tester.tap(find.byKey(FrontConversationActionKeys.titleSave));
    await tester.pumpAndSettle();

    verify(() => service.rename('c-1', 'Colony census')).called(1);

    // Enter saves too.
    await openMenu(tester, 'c-1');
    await tester.tap(find.byKey(FrontConversationActionKeys.rename('c-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: input, matching: find.byType(TextField)),
      'Census',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    verify(() => service.rename('c-1', 'Census')).called(1);

    // Cancel leaves the title as it was.
    await openMenu(tester, 'c-1');
    await tester.tap(find.byKey(FrontConversationActionKeys.rename('c-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => service.rename('c-1', 'Plan the census'));
    expect(find.byKey(FrontConversationActionKeys.titleInput), findsNothing);
  });

  testWidgets('archiving the open one moves on; its undo opens it again', (
    tester,
  ) async {
    final container = await pumpList(tester);

    await openMenu(tester, 'c-1');
    await tester.tap(find.byKey(FrontConversationActionKeys.archive('c-1')));
    await tester.pumpAndSettle();
    expect(
      container.read(frontPickedConversationProvider),
      isNot(anyOf(isNull, 'c-1')),
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    verify(() => service.archive('c-1', archived: false)).called(1);
    expect(container.read(frontPickedConversationProvider), 'c-1');
  });

  testWidgets('archiving says so; restoring an archived one does not', (
    tester,
  ) async {
    await pumpList(tester);

    await openMenu(tester, 'c-2');
    await tester.tap(find.byKey(FrontConversationActionKeys.archive('c-2')));
    await tester.pumpAndSettle();
    verify(() => service.archive('c-2', archived: true)).called(1);
    expect(find.text('Chat archived.'), findsOne);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    verify(() => service.archive('c-2', archived: false)).called(1);

    await tester.tap(find.byKey(FrontConversationListKeys.archived));
    await tester.pump();
    await openMenu(tester, 'c-0');
    await tester.tap(find.byKey(FrontConversationActionKeys.archive('c-0')));
    await tester.pumpAndSettle();
    verify(() => service.archive('c-0', archived: false)).called(1);
  });

  testWidgets('a write that fails says so and leaves the list', (
    tester,
  ) async {
    when(
      () => service.archive(any(), archived: any(named: 'archived')),
    ).thenThrow(Exception('outbox closed'));
    await pumpList(tester);

    await openMenu(tester, 'c-2');
    await tester.tap(find.byKey(FrontConversationActionKeys.archive('c-2')));
    await tester.pumpAndSettle();

    expect(find.text("That didn't go through. Try again."), findsOne);
    expect(find.text('Chat archived.'), findsNothing);
    expect(find.text('Count the hatchlings'), findsOne);
  });

  testWidgets("a row's ⋯ opens the agent pages' menu over the scrim — "
      'rounded, raised, Delete in a group of its own — and a tap on the '
      'scrim closes it without acting', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byKey(FrontConversationListKeys.menu('c-1')));
    await tester.pumpAndSettle();

    // The page steps back behind the shared scrim, not under a bare
    // dropdown.
    final menuContext = tester.element(find.byType(DesignSystemContextMenu));
    final scrim = ModalUtils.getModalBarrierColor(
      isDark: Theme.of(menuContext).brightness == Brightness.dark,
      context: menuContext,
    );
    expect(
      tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .map((barrier) => barrier.color),
      contains(scrim),
    );
    final menu = tester.widget<DesignSystemContextMenu>(
      find.byType(DesignSystemContextMenu),
    );
    expect(menu.surfaceColor, dsCardSurface(menuContext));
    // It says which chat it acts on, above Delete.
    expect(menu.header, 'Plan the census');
    expect(
      [
        for (final item in menu.items)
          if (item.startsGroup) item.label,
      ],
      ['Delete chat'],
    );

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(DesignSystemContextMenu), findsNothing);
    verifyNever(() => service.delete(any()));
    verifyNever(() => service.archive(any(), archived: any(named: 'archived')));
  });

  testWidgets('delete asks first, says what it does, and only deletes on '
      'the confirmation', (tester) async {
    await pumpList(tester);

    await openMenu(tester, 'c-2');
    await tester.tap(find.byKey(FrontConversationActionKeys.delete('c-2')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('hidden on every device, not erased'),
      findsOne,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => service.delete(any()));

    await openMenu(tester, 'c-2');
    await tester.tap(find.byKey(FrontConversationActionKeys.delete('c-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Delete chat'));
    await tester.pumpAndSettle();

    verify(() => service.delete('c-2')).called(1);
  });
}

/// A row's label: the text itself, or the title leading a conversation
/// row (its title, in the room it leaves its menu, over its preview, in a
/// box no shorter than its menu's target).
String _textOf(Widget content) => switch (content) {
  Text(:final data) => data!,
  ConstrainedBox(:final child?) => _textOf(child),
  Padding(:final child?) => _textOf(child),
  Column(:final children) => _textOf(children.first),
  Row(:final children) => _textOf(
    switch (children.first) {
      Expanded(:final child) => child,
      final other => other,
    },
  ),
  _ => throw StateError('unexpected title content $content'),
};
