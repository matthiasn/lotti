import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
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
      item.title!,
  ];

  Future<void> openMenu(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(FrontConversationListKeys.menu(id)));
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

  testWidgets('a new chat first, the live ones newest first with the open '
      'one marked, the archived folded away', (tester) async {
    // Every frame of this test reads the fixed day.
    await withClock(Clock.fixed(now), () async {
      await pumpList(tester);

      expect(titles(tester), [
        'New chat',
        'Count the hatchlings',
        'Plan the census',
        'Archived chats · 1',
      ]);
      DesignSystemListItem itemOf(String id) => tester.widget(
        find.descendant(
          of: find.byKey(FrontConversationListKeys.row(id)),
          matching: find.byType(DesignSystemListItem),
        ),
      );
      expect(itemOf('c-1').selected, isTrue);
      expect(itemOf('c-2').selected, isFalse);
      // Today's by the time, another day's by the date.
      expect(
        itemOf('c-2').subtitle,
        DateFormat.jm('en-US').format(DateTime(2026, 10, 31, 9)),
      );
      expect(itemOf('c-1').subtitle, 'Oct 29, 2026');

      await tester.tap(find.byKey(FrontConversationListKeys.archived));
      await tester.pump();

      expect(titles(tester).last, 'Feeding rota');
    });
  });

  testWidgets('search narrows by title, and says when nothing matches', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.enterText(find.byType(TextField), 'CENSUS');
    await tester.pump();
    expect(titles(tester), ['New chat', 'Plan the census']);

    await tester.enterText(find.byType(TextField), 'krill');
    await tester.pump();
    expect(titles(tester), ['New chat']);
    expect(find.text('No chat matches.'), findsOne);
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
    await tester.tap(find.byKey(FrontConversationListKeys.rename('c-1')));
    await tester.pumpAndSettle();
    final input = find.byKey(const Key('front-conversation-title-input'));
    await tester.enterText(
      find.descendant(of: input, matching: find.byType(TextField)),
      '   ',
    );
    await tester.tap(find.byKey(const Key('front-conversation-title-save')));
    await tester.pumpAndSettle();
    verifyNever(() => service.rename(any(), any()));

    await tester.enterText(
      find.descendant(of: input, matching: find.byType(TextField)),
      '  Colony census ',
    );
    await tester.tap(find.byKey(const Key('front-conversation-title-save')));
    await tester.pumpAndSettle();

    verify(() => service.rename('c-1', 'Colony census')).called(1);
  });

  testWidgets('archiving says so; restoring an archived one does not', (
    tester,
  ) async {
    await pumpList(tester);

    await openMenu(tester, 'c-2');
    await tester.tap(find.byKey(FrontConversationListKeys.archive('c-2')));
    await tester.pumpAndSettle();
    verify(() => service.archive('c-2', archived: true)).called(1);
    expect(find.text('Chat archived.'), findsOne);

    await tester.tap(find.byKey(FrontConversationListKeys.archived));
    await tester.pump();
    await openMenu(tester, 'c-0');
    await tester.tap(find.byKey(FrontConversationListKeys.archive('c-0')));
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
    await tester.tap(find.byKey(FrontConversationListKeys.archive('c-2')));
    await tester.pumpAndSettle();

    expect(find.text("That didn't go through. Try again."), findsOne);
    expect(find.text('Chat archived.'), findsNothing);
    expect(find.text('Count the hatchlings'), findsOne);
  });

  testWidgets('delete asks first, says what it does, and only deletes on '
      'the confirmation', (tester) async {
    await pumpList(tester);

    await openMenu(tester, 'c-2');
    await tester.tap(find.byKey(FrontConversationListKeys.delete('c-2')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Its messages leave every device.'),
      findsOne,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => service.delete(any()));

    await openMenu(tester, 'c-2');
    await tester.tap(find.byKey(FrontConversationListKeys.delete('c-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('front-conversation-delete-confirm')),
    );
    await tester.pumpAndSettle();

    verify(() => service.delete('c-2')).called(1);
  });
}
