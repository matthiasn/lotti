import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/person_page_cards.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 8, 13, 10, 30);

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

  group('PersonCardHeader', () {
    testWidgets('lays out title, caption and trailing action', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const PersonCardHeader(
            title: 'Tasks',
            caption: Text('2 linked'),
            trailing: Text('Link task'),
          ),
        ),
      );

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('2 linked'), findsOneWidget);
      expect(find.text('Link task'), findsOneWidget);
      // The action is pushed to the far edge; the caption stays by the title.
      expect(
        tester.getTopLeft(find.text('Link task')).dx,
        greaterThan(tester.getTopRight(find.text('2 linked')).dx),
      );
    });
  });

  group('NextTimeLead', () {
    test('hasContent is false for no check-in or blank guidance', () {
      expect(NextTimeLead.hasContent(null), isFalse);
      expect(NextTimeLead.hasContent(checkIn()), isFalse);
      expect(NextTimeLead.hasContent(checkIn(attention: '  ')), isFalse);
      expect(NextTimeLead.hasContent(checkIn(attention: 'The move')), isTrue);
      expect(NextTimeLead.hasContent(checkIn(avoid: 'The coffee')), isTrue);
    });

    test('sourceOf is the newest check-in that has notes — a quick check-in '
        'with none must not erase the ones before it', () {
      final quick = checkIn(id: 'newest');
      final withNotes = checkIn(id: 'older', attention: 'The move');
      final oldest = checkIn(id: 'oldest', avoid: 'Politics');

      expect(NextTimeLead.sourceOf([quick, withNotes, oldest]), withNotes);
      expect(NextTimeLead.sourceOf([quick]), isNull);
      expect(NextTimeLead.sourceOf(const []), isNull);
    });

    // On the page, undated notes would read as written after a conversation
    // they predate: the heading's caption says which check-in they are from.
    testWidgets('provenanceOf names the check-in the notes are from, the date '
        'in the timestamp style', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => NextTimeLead.provenanceOf(
              context,
              checkIn(attention: 'The move'),
            ),
          ),
        ),
      );

      final line = tester.widget<RelationshipLineWithDate>(
        find.byKey(const ValueKey('person-next-time-from')),
      );
      expect(line.text, 'From your check-in on Thu 13 Aug');
      expect(line.date, 'Thu 13 Aug');
    });

    testWidgets('shows both notes — what to avoid is never folded away — '
        'with no disclosure to open', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          NextTimeLead(
            source: checkIn(attention: 'The move', avoid: 'Politics.'),
          ),
        ),
      );

      expect(find.text('The move'), findsOneWidget);
      expect(find.text('Politics.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('person-next-time-toggle')),
        findsNothing,
      );
    });

    testWidgets('renders nothing when the source carries no guidance', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(NextTimeLead(source: checkIn())),
      );

      expect(find.byKey(const ValueKey('person-next-time')), findsNothing);
    });

    testWidgets('shows both facts with their captions, and no card or title '
        'of its own — it leads the briefing card', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          NextTimeLead(
            source: checkIn(
              attention: 'Ask how the fitting went.',
              avoid: 'The coffee incident.',
            ),
          ),
        ),
      );

      expect(find.text('Pay attention to'), findsOneWidget);
      expect(find.text('Ask how the fitting went.'), findsOneWidget);
      expect(find.text('Better to avoid'), findsOneWidget);
      expect(find.text('The coffee incident.'), findsOneWidget);
      expect(find.text('Next time'), findsNothing);
      expect(find.byType(DesignSystemSectionCard), findsNothing);
    });

    testWidgets('a single field renders alone, its words trimmed', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          NextTimeLead(source: checkIn(avoid: '  Politics.  ')),
        ),
      );

      expect(
        find.byKey(const ValueKey('person-next-time-attention')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('person-next-time-avoid')), findsOne);
      expect(find.text('Politics.'), findsOneWidget);
    });
  });
}
