import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/widgets/people_list_row.dart';
import 'package:lotti/features/relationships/ui/widgets/people_list_view.dart';
import 'package:lotti/features/relationships/ui/widgets/people_summary_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/test_app.dart';

void main() {
  // A Thursday, mid-morning.
  final now = DateTime(2026, 8, 13, 10, 30);
  final trackingStart = DateTime(2026, 7, 1, 9);

  RelationshipListItem item(
    String id, {
    required String title,
    String? nickname,
    bool important = true,
    DateTime? lastCheckInAt,
  }) => (
    relationship: RelationshipEntry(
      meta: Metadata(
        id: id,
        createdAt: trackingStart,
        updatedAt: trackingStart,
        dateFrom: trackingStart,
        dateTo: trackingStart,
      ),
      data: RelationshipData(
        title: title,
        nickname: nickname,
        important: important,
        checkInCadenceDays: 7,
        status: RelationshipStatus.active(
          id: 'status-$id',
          createdAt: trackingStart,
          utcOffset: 0,
        ),
      ),
    ),
    lastCheckIn: lastCheckInAt == null
        ? null
        : CheckInEntry(
            meta: Metadata(
              id: 'check-$id',
              createdAt: lastCheckInAt,
              updatedAt: lastCheckInAt,
              dateFrom: lastCheckInAt,
              dateTo: lastCheckInAt,
            ),
            data: CheckInData(
              relationshipId: id,
              interactionType: CheckInInteractionType.call,
            ),
          ),
  );

  // Two on track (contacted this week), one without reminders.
  final crew = [
    item(
      'rel-pip',
      title: 'Commander Pip Frostbeak',
      nickname: 'Pip',
      lastCheckInAt: DateTime(2026, 8, 12, 9),
    ),
    item(
      'rel-skua',
      title: 'Dr. Skua Brightwing',
      lastCheckInAt: DateTime(2026, 8, 11, 9),
    ),
    item('rel-mo', title: 'Mo Krillson', important: false),
  ];

  group('PeopleListSliver', () {
    Future<void> pumpList(
      WidgetTester tester, {
      String query = '',
      String? selected,
      ValueChanged<String>? onOpen,
      VoidCallback? onClearSearch,
      List<RelationshipListItem>? items,
    }) => withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: CustomScrollView(
              slivers: [
                PeopleListSliver(
                  items: items ?? crew,
                  query: query,
                  selectedRelationshipId: selected,
                  onOpen: onOpen ?? (_) {},
                  onSpeak: (_) {},
                  onClearSearch: onClearSearch ?? () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    Finder segment(String id) => find.byKey(ValueKey('people-row-$id'));

    testWidgets('each band is one rows card: the first row takes the top '
        'corners, the last the bottom ones, a divider between rows', (
      tester,
    ) async {
      await pumpList(tester);
      final tokens = tester.element(find.byType(PeopleListSliver)).designTokens;
      final corner = Radius.circular(tokens.radii.l);

      BorderRadius radiusOf(String id) {
        final shape =
            tester
                    .widget<Material>(
                      find
                          .descendant(
                            of: segment(id),
                            matching: find.byType(Material),
                          )
                          .first,
                    )
                    .shape!
                as RoundedRectangleBorder;
        return shape.borderRadius as BorderRadius;
      }

      // On track, nearest deadline first: Skua (due the 18th) over Pip
      // (the 19th).
      expect(radiusOf('rel-skua'), BorderRadius.vertical(top: corner));
      expect(radiusOf('rel-pip'), BorderRadius.vertical(bottom: corner));
      // No reminders: one row, both ends rounded.
      expect(radiusOf('rel-mo'), BorderRadius.all(corner));

      Finder dividerIn(String id) => find.descendant(
        of: segment(id),
        matching: find.byType(DesignSystemDivider),
      );
      expect(dividerIn('rel-skua'), findsNothing);
      expect(dividerIn('rel-pip'), findsOneWidget);
      expect(dividerIn('rel-mo'), findsNothing);

      // The card is one tonal step above the page, with no border.
      final card = tester.widget<Material>(
        find
            .descendant(of: segment('rel-mo'), matching: find.byType(Material))
            .first,
      );
      expect(card.color, tokens.colors.background.level02);
      expect(
        (card.shape! as RoundedRectangleBorder).side,
        BorderSide.none,
      );
    });

    testWidgets('the summary card heads the list while nobody is searching', (
      tester,
    ) async {
      await pumpList(tester);
      expect(find.byType(PeopleSummaryCard), findsOneWidget);
      expect(find.text('On track · 2'), findsOneWidget);
      expect(find.text('No reminders · 1'), findsOneWidget);
    });

    testWidgets('a query keeps the bands to the people it matches — by name '
        'or nickname, any case — and the summary steps aside', (tester) async {
      await pumpList(tester, query: 'PIP');

      expect(find.byType(PeopleListRow), findsOneWidget);
      expect(find.text('Commander Pip Frostbeak'), findsOneWidget);
      expect(find.text('On track · 1'), findsOneWidget);
      expect(find.textContaining('No reminders'), findsNothing);
      expect(
        find.byType(PeopleSummaryCard),
        findsNothing,
        reason: 'its counts describe everyone, not the matches',
      );

      await pumpList(tester, query: 'krill');
      expect(find.text('Mo Krillson'), findsOneWidget);
      expect(find.text('No reminders · 1'), findsOneWidget);
    });

    testWidgets('a query that matches nobody says so with the words typed, '
        'and Clear search is the way back', (tester) async {
      var cleared = 0;
      await pumpList(tester, query: ' walrus ', onClearSearch: () => cleared++);

      expect(find.byType(PeopleListRow), findsNothing);
      expect(find.byKey(const ValueKey('people-search-miss')), findsOneWidget);
      expect(find.text('Nobody matches “walrus”'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('people-search-clear')));
      expect(cleared, 1);
    });

    testWidgets('the selected person wears the selection, and a tap opens a '
        'person by id', (tester) async {
      final opened = <String>[];
      await pumpList(tester, selected: 'rel-skua', onOpen: opened.add);

      PeopleListRow row(String id) => tester.widget<PeopleListRow>(
        find.descendant(of: segment(id), matching: find.byType(PeopleListRow)),
      );
      expect(row('rel-skua').selected, isTrue);
      expect(row('rel-pip').selected, isFalse);

      await tester.tap(find.text('Mo Krillson'));
      expect(opened, ['rel-mo']);
    });
  });

  group('PeopleListHeader', () {
    Future<void> pumpHeader(
      WidgetTester tester, {
      required int? itemCount,
      VoidCallback? onImport,
      ValueChanged<String>? onQueryChanged,
    }) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          PeopleListHeader(
            itemCount: itemCount,
            searchController: controller,
            onQueryChanged: onQueryChanged ?? (_) {},
            onImport: onImport,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the title carries the count, and the search field takes the '
        'full width with nothing beside it', (tester) async {
      final queries = <String>[];
      await pumpHeader(tester, itemCount: 5, onQueryChanged: queries.add);

      expect(find.text('People'), findsOneWidget);
      expect(find.text('· 5'), findsOneWidget);
      final search = find.byKey(const ValueKey('people-search'));
      expect(search, findsOneWidget);
      // Nothing narrows the field: it spans the header's content width.
      final header = tester.getRect(find.byType(PeopleListHeader));
      final field = tester.getRect(search);
      final tokens = tester.element(search).designTokens;
      expect(field.left, header.left + tokens.spacing.step5);
      expect(field.right, header.right - tokens.spacing.step5);

      await tester.enterText(
        find.descendant(of: search, matching: find.byType(TextField)),
        'pip',
      );
      expect(queries.last, 'pip');
    });

    testWidgets('no search before there is anyone to find, and no count '
        'before the first load', (tester) async {
      await pumpHeader(tester, itemCount: 0);
      expect(find.byKey(const ValueKey('people-search')), findsNothing);

      await pumpHeader(tester, itemCount: null);
      expect(find.byKey(const ValueKey('people-search')), findsNothing);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('the import door appears only where there is an address '
        'book, and opens import', (tester) async {
      await pumpHeader(tester, itemCount: 1);
      expect(find.byIcon(LottiIcons.contactImport), findsNothing);

      var opened = 0;
      await pumpHeader(tester, itemCount: 1, onImport: () => opened++);
      await tester.tap(find.byIcon(LottiIcons.contactImport));
      expect(opened, 1);
    });
  });
}
