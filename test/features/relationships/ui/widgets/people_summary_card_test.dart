import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/widgets/people_summary_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 8);

  RelationshipListItem person(String title, {String? nickname}) => (
    relationship: RelationshipEntry(
      meta: Metadata(
        id: 'rel-$title',
        createdAt: at,
        updatedAt: at,
        dateFrom: at,
        dateTo: at,
      ),
      data: RelationshipData(
        title: title,
        nickname: nickname,
        important: true,
        status: RelationshipStatus.active(id: 's', createdAt: at, utcOffset: 0),
      ),
    ),
    lastCheckIn: null,
  );

  PeopleSummary summary({
    int dueNow = 0,
    int enrolled = 4,
    int notEnrolled = 0,
    RelationshipListItem? nextDue,
    DateTime? nextDueAt,
  }) => (
    dueNow: dueNow,
    enrolled: enrolled,
    notEnrolled: notEnrolled,
    nextDue: nextDue,
    nextDueAt: nextDueAt,
  );

  Future<void> pump(WidgetTester tester, PeopleSummary summary) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(PeopleSummaryCard(summary: summary)),
    );
    await tester.pumpAndSettle();
  }

  Color numeralColor(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('people-summary-due-count')))
      .style!
      .color!;

  testWidgets('names the due count over the enrolled count, who is due next '
      'and on which day, and how many are not enrolled', (tester) async {
    await pump(
      tester,
      summary(
        dueNow: 1,
        notEnrolled: 1,
        nextDue: person('Bo'),
        nextDueAt: DateTime(2026, 7, 23),
      ),
    );

    expect(find.text('Due now'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('/ 4 enrolled'), findsOneWidget);
    // 2026-07-23 is a Thursday; the day carries no time — it is a deadline.
    expect(find.text('Next due Bo · Thu 23 Jul'), findsOneWidget);
    expect(find.text('1 person not enrolled'), findsOneWidget);
    // A non-zero due count is the one thing on the card that may shout.
    final tokens = tester.element(find.byType(PeopleSummaryCard)).designTokens;
    expect(numeralColor(tester), tokens.colors.alert.warning.defaultColor);
  });

  testWidgets('a calm morning reads as a quiet zero — no warning ink, and '
      'no not-enrolled line when everyone is enrolled', (tester) async {
    await pump(
      tester,
      summary(nextDue: person('Mira'), nextDueAt: DateTime(2026, 8, 24)),
    );

    expect(find.text('0'), findsOneWidget);
    final tokens = tester.element(find.byType(PeopleSummaryCard)).designTokens;
    expect(numeralColor(tester), tokens.colors.text.highEmphasis);
    expect(find.textContaining('not enrolled'), findsNothing);
    expect(find.text('Next due Mira · Mon 24 Aug'), findsOneWidget);
  });

  testWidgets('names the next-due person by nickname when they have one — '
      'the way the user talks about them', (tester) async {
    await pump(
      tester,
      summary(
        nextDue: person('Captain Bo Glacier', nickname: 'Bo'),
        nextDueAt: DateTime(2026, 7, 23),
      ),
    );

    expect(find.text('Next due Bo · Thu 23 Jul'), findsOneWidget);
    expect(find.textContaining('Captain'), findsNothing);
  });

  testWidgets('with nobody ahead on a cadence it says so instead of naming '
      'no one', (tester) async {
    await pump(tester, summary(enrolled: 2, notEnrolled: 3));

    expect(find.text('No one due'), findsOneWidget);
    expect(find.text('3 people not enrolled'), findsOneWidget);
  });
}
