import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_actions.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
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
  }) async {
    await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(body: FrontConversationList()),
          overrides: [
            frontConversationsProvider.overrideWith(
              (ref) async => index ?? colony,
            ),
            frontConversationServiceProvider.overrideWithValue(service),
          ],
        ),
      );
      await tester.pump();
    });
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FrontConversationList)),
    );
    // Both auto-dispose otherwise; the list is open while it shows.
    final open = container.listen(frontConversationListOpenProvider, (_, _) {});
    addTearDown(open.close);
    container
      ..read(frontPickedConversationProvider.notifier).picked = 'c-1'
      ..read(frontConversationListOpenProvider.notifier).toggle();
    await tester.pump();
    await tester.pump();
    return container;
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

  testWidgets('with nothing said yet, a new chat and the invitation only', (
    tester,
  ) async {
    await pumpList(tester, index: FrontConversationIndex.empty);

    expect(titles(tester), ['New chat']);
    expect(find.text('No chats yet. Ask something to start one.'), findsOne);
    expect(find.byType(DesignSystemSearch), findsNothing);
  });

  testWidgets('a new chat first, then the live ones newest first under '
      'recency sections with the open one marked, the archived folded away', (
    tester,
  ) async {
    // Every frame of this test reads the fixed day.
    await withClock(Clock.fixed(now), () async {
      await pumpList(tester);

      expect(titles(tester), [
        'New chat',
        'Search chats',
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

      // The section names the day; its rows say the time.
      expect(find.text('Yesterday'), findsOne);
      expect(find.text('Older'), findsOne);
      expect(find.text('Today'), findsNothing);
    });
  });

  testWidgets('search looks through the archived ones too, keeps the new '
      'chat, drops the sections, and says when nothing matches', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      await pumpList(tester);

      // The search opens in place from its row.
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byKey(FrontConversationListKeys.search));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'CENSUS');
      await tester.pump();
      expect(titles(tester), ['New chat', 'Plan the census']);
      expect(find.text('Today'), findsNothing);

      await tester.enterText(find.byType(TextField), 'rota');
      await tester.pump();
      expect(titles(tester), ['New chat', 'Feeding rota']);

      await tester.enterText(find.byType(TextField), 'krill');
      await tester.pump();
      expect(titles(tester), ['New chat']);
      expect(find.text('No chat title matches.'), findsOne);

      // Clearing closes it again, and the list is back as it was.
      await tester.tap(find.byIcon(LottiIcons.closeCircled));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(titles(tester), contains('Search chats'));
      expect(find.text('Today'), findsOne);
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
    final census = tester.widget<DesignSystemListItem>(
      find.descendant(
        of: find.byKey(FrontConversationListKeys.row('c-1')),
        matching: find.byType(DesignSystemListItem),
      ),
    );
    final rota = tester.widget<DesignSystemListItem>(
      find.descendant(
        of: find.byKey(FrontConversationListKeys.row('c-2')),
        matching: find.byType(DesignSystemListItem),
      ),
    );
    expect(census.subtitle, 'Saturday works.');
    expect(rota.subtitle, isNull, reason: 'not answered yet');
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

  testWidgets('an empty search closes when focus leaves it', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byKey(FrontConversationListKeys.search));
    await tester.pump();
    expect(find.byType(TextField), findsOne);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(titles(tester), contains('Search chats'));
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
    final container = await pumpList(tester);

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
/// row's title-and-time line.
String _textOf(Widget content) => switch (content) {
  Text(:final data) => data!,
  Row(:final children) => _textOf(
    switch (children.first) {
      Expanded(:final child) => child,
      final other => other,
    },
  ),
  _ => throw StateError('unexpected title content $content'),
};
