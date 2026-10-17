import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/person_timeline.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/person_brief_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // Thursday 13 August 2026.
  final at = DateTime(2026, 8, 13, 10, 30);
  final now = DateTime(2026, 8, 13, 14);

  CheckInEntry checkIn({
    String? attention,
    String? avoid,
    String id = 'check-1',
  }) => CheckInEntry(
    meta: Metadata(
      id: id,
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
    ),
    data: CheckInData(
      relationshipId: 'rel-1',
      interactionType: CheckInInteractionType.call,
      payAttentionTo: attention,
      avoid: avoid,
    ),
  );

  final coffeeAt = DateTime(2026, 8, 16, 15);
  final coffee = TimelineMeeting(
    JournalEntity.event(
          meta: Metadata(
            id: 'meeting-1',
            createdAt: at,
            updatedAt: at,
            dateFrom: coffeeAt,
            dateTo: coffeeAt.add(const Duration(hours: 2)),
          ),
          data: const EventData(
            title: 'Coffee at the ice garden',
            stars: 0,
            status: EventStatus.planned,
          ),
        )
        as JournalEvent,
  );

  Future<void> pump(
    WidgetTester tester, {
    CheckInEntry? source,
    TimelineMeeting? meeting,
    VoidCallback? onOpenSource,
    VoidCallback? onOpenMeeting,
    bool showProvenance = true,
    bool showMeetingRow = true,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      PersonBriefCard(
        source: source,
        meeting: meeting,
        now: now,
        onOpenSource: onOpenSource,
        onOpenMeeting: onOpenMeeting,
        showProvenance: showProvenance,
        showMeetingRow: showMeetingRow,
      ),
    ),
  );

  group('which notes count', () {
    test('hasContent is false for no check-in or blank guidance', () {
      expect(PersonBriefCard.hasContent(null), isFalse);
      expect(PersonBriefCard.hasContent(checkIn()), isFalse);
      expect(PersonBriefCard.hasContent(checkIn(attention: '  ')), isFalse);
      expect(
        PersonBriefCard.hasContent(checkIn(attention: 'The move')),
        isTrue,
      );
      expect(PersonBriefCard.hasContent(checkIn(avoid: 'The coffee')), isTrue);
    });

    test('sourceOf is the newest check-in that has notes — a quick check-in '
        'with none must not erase the ones before it', () {
      final quick = checkIn(id: 'newest');
      final withNotes = checkIn(id: 'older', attention: 'The move');
      final oldest = checkIn(id: 'oldest', avoid: 'Politics');

      expect(PersonBriefCard.sourceOf([quick, withNotes, oldest]), withNotes);
      expect(PersonBriefCard.sourceOf([quick]), isNull);
      expect(PersonBriefCard.sourceOf(const []), isNull);
    });
  });

  testWidgets('the note to bring up leads, a size above everything else; '
      'what to avoid sits under it, quiet and marked by its glyph', (
    tester,
  ) async {
    await pump(
      tester,
      source: checkIn(
        attention: 'Ask how the fitting went.',
        avoid: 'The coffee incident.',
      ),
    );
    final tokens = tester.element(find.byType(PersonBriefCard)).designTokens;

    final headline = tester.widget<Text>(
      find.byKey(const ValueKey('person-next-time-attention')),
    );
    expect(headline.data, 'Ask how the fitting went.');
    expect(
      headline.style?.fontSize,
      tokens.typography.styles.heading.heading3.fontSize,
    );
    expect(
      headline.style!.fontSize,
      greaterThan(tokens.typography.styles.body.bodyMedium.fontSize!),
    );

    final avoid = tester.widget<Text>(
      find.byKey(const ValueKey('person-next-time-avoid')),
    );
    expect(avoid.data, 'The coffee incident.');
    expect(avoid.style?.color, tokens.colors.text.mediumEmphasis);
    expect(find.byIcon(LottiIcons.block), findsOneWidget);
    // One label, not one per line.
    expect(find.text('Better to avoid'), findsNothing);
  });

  testWidgets('what to avoid is read out under its own name', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, source: checkIn(avoid: '  Politics.  '));

    expect(
      find.bySemanticsLabel('Better to avoid: Politics.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('person-next-time-attention')),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('says which check-in the notes are from, and opens it', (
    tester,
  ) async {
    var opened = 0;
    await pump(
      tester,
      source: checkIn(attention: 'The move'),
      onOpenSource: () => opened++,
    );

    await tester.tap(find.text('From your check-in on Thu 13 Aug'));
    expect(opened, 1);
  });

  testWidgets('without a way in, the provenance is a dated line', (
    tester,
  ) async {
    await pump(tester, source: checkIn(attention: 'The move'));

    final line = tester.widget<RelationshipLineWithDate>(
      find.byKey(const ValueKey('person-next-time-from')),
    );
    expect(line.text, 'From your check-in on Thu 13 Aug');
    expect(line.date, 'Thu 13 Aug');
  });

  testWidgets('the next meeting is a row under the notes — what over when — '
      'that opens the meeting', (tester) async {
    var opened = 0;
    await pump(
      tester,
      source: checkIn(attention: 'The move'),
      meeting: coffee,
      onOpenMeeting: () => opened++,
    );

    final row = find.byKey(const ValueKey('person-next-meeting'));
    expect(
      find.descendant(of: row, matching: find.text('Coffee at the ice garden')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('person-next-meeting-when')))
          .data,
      'Sun 16 Aug 15:00',
    );
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('person-next-time-attention')),
            )
            .dy,
      ),
    );

    await tester.tap(row);
    expect(opened, 1);
  });

  testWidgets('with no meeting booked, the note is labelled Pay attention '
      'to', (tester) async {
    await pump(tester, source: checkIn(attention: 'The move'));

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('person-next-time-label')))
          .data,
      'Pay attention to',
    );
  });

  testWidgets('with a meeting booked, the note is for it: Bring up before '
      'its day — even where the meeting has no row of its own', (
    tester,
  ) async {
    await pump(
      tester,
      source: checkIn(attention: 'The move'),
      meeting: coffee,
      showMeetingRow: false,
    );

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('person-next-time-label')))
          .data,
      'Bring up before Sun 16 Aug',
    );
    expect(find.byKey(const ValueKey('person-next-meeting')), findsNothing);
    expect(find.text('Coffee at the ice garden'), findsNothing);
  });

  testWidgets('a meeting with no row of its own and no notes makes no card', (
    tester,
  ) async {
    await pump(tester, meeting: coffee, showMeetingRow: false);

    expect(find.byKey(const ValueKey('person-brief')), findsNothing);
  });

  testWidgets("on the check-in's own page it does not say which check-in "
      'its notes are from — the page is the answer', (tester) async {
    await pump(
      tester,
      source: checkIn(attention: 'The move'),
      showProvenance: false,
    );

    expect(find.text('The move'), findsOneWidget);
    expect(find.textContaining('From your check-in'), findsNothing);
  });

  testWidgets('a meeting alone still makes a card', (tester) async {
    await pump(tester, meeting: coffee);

    expect(find.byKey(const ValueKey('person-brief')), findsOneWidget);
    expect(find.text('Pay attention to'), findsNothing);
  });

  testWidgets('renders nothing with neither notes nor a meeting', (
    tester,
  ) async {
    await pump(tester, source: checkIn());

    expect(find.byKey(const ValueKey('person-brief')), findsNothing);
  });
}
