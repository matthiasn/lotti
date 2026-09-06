import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/sentiment.dart';
import 'package:lotti/features/relationships/ui/widgets/check_ins_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2026, 8, 13, 14);

  CheckInEntry checkIn(
    String id, {
    DateTime? at,
    Duration length = Duration.zero,
    CheckInInteractionType type = CheckInInteractionType.call,
    CheckInSentiment? sentiment,
    List<String> topics = const [],
    String? narrative,
  }) {
    final from = at ?? now.subtract(const Duration(hours: 2));
    return CheckInEntry(
      meta: Metadata(
        id: id,
        createdAt: from,
        updatedAt: from,
        dateFrom: from,
        dateTo: from.add(length),
      ),
      data: CheckInData(
        relationshipId: 'rel-1',
        interactionType: type,
        sentiment: sentiment,
        topics: topics,
      ),
      entryText: narrative == null ? null : EntryText(plainText: narrative),
    );
  }

  Future<List<CheckInEntry>> pump(
    WidgetTester tester,
    List<CheckInEntry> checkIns,
  ) async {
    final opened = <CheckInEntry>[];
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          CustomScrollView(
            slivers: [
              CheckInsCardSliver(checkIns: checkIns, onOpen: opened.add),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
    return opened;
  }

  group('the card', () {
    testWidgets('wears the section card surface, so it matches the boxed '
        'cards around it', (tester) async {
      await pump(tester, [checkIn('c1')]);

      final sliver = tester.widget<DecoratedSliver>(
        find.byKey(const ValueKey('person-check-ins-card')),
      );
      final tokens = tester
          .element(find.byKey(const ValueKey('person-check-ins-card')))
          .designTokens;
      expect(sliver.decoration, DesignSystemSectionCard.decoration(tokens));
    });

    testWidgets('counts the check-ins beside the title', (tester) async {
      await pump(tester, [checkIn('c1'), checkIn('c2'), checkIn('c3')]);

      expect(find.text('Check-ins'), findsOneWidget);
      final pill = tester.widget<DsPill>(
        find.byKey(const ValueKey('person-check-ins-count')),
      );
      expect(pill.label, '3');
    });

    testWidgets('an empty log shows the hint and no count', (tester) async {
      await pump(tester, const []);

      expect(
        find.text('No check-ins yet — log one after you next talk.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('person-check-ins-count')),
        findsNothing,
      );
      expect(find.byType(CheckInRow), findsNothing);
    });

    testWidgets('tapping a row hands that check-in back', (tester) async {
      final opened = await pump(tester, [
        checkIn('c1', narrative: 'First.'),
        checkIn('c2', narrative: 'Second.'),
      ]);

      await tester.tap(find.text('Second.'));
      await tester.pump();

      expect(opened.map((c) => c.meta.id), ['c2']);
    });
  });

  group('the row', () {
    testWidgets('meta line reads timestamp · type · duration in mono', (
      tester,
    ) async {
      await pump(tester, [
        checkIn(
          'c1',
          at: DateTime(2026, 8, 13, 12, 44),
          length: const Duration(minutes: 11),
        ),
      ]);

      final meta = tester.widget<Text>(
        find.byKey(const ValueKey('check-in-row-meta')),
      );
      expect(meta.data, 'Today 12:44 · Call · 11 min');
      expect(meta.style?.fontFamily, 'Inconsolata');
    });

    testWidgets('a check-in with no duration leaves the duration out', (
      tester,
    ) async {
      await pump(tester, [
        checkIn(
          'c1',
          at: DateTime(2026, 8, 12, 19, 5),
          type: CheckInInteractionType.videoCall,
        ),
      ]);

      final meta = tester.widget<Text>(
        find.byKey(const ValueKey('check-in-row-meta')),
      );
      expect(meta.data, 'Yesterday 19:05 · Video call');
    });

    testWidgets('the sentiment pill is tinted with the sentiment colour and '
        'absent when unset', (tester) async {
      await pump(tester, [
        checkIn('c1', sentiment: CheckInSentiment.delightful),
        checkIn('c2'),
      ]);

      final pills = tester
          .widgetList<DsPill>(
            find.byKey(const ValueKey('check-in-row-sentiment')),
          )
          .toList();
      expect(pills, hasLength(1));
      final tokens = tester.element(find.byType(CheckInRow).first).designTokens;
      expect(pills.single.label, 'Delightful');
      expect(pills.single.variant, DsPillVariant.tinted);
      expect(
        pills.single.color,
        sentimentColor(tokens, CheckInSentiment.delightful),
      );
    });

    testWidgets('each interaction type gets its own glyph', (tester) async {
      const glyphs = {
        CheckInInteractionType.inPerson: LottiIcons.people,
        CheckInInteractionType.call: LottiIcons.call,
        CheckInInteractionType.videoCall: LottiIcons.video,
        CheckInInteractionType.message: LottiIcons.chat,
        CheckInInteractionType.other: LottiIcons.forum,
      };
      setTestSurfaceSize(tester, const Size(1000, 1400));
      await pump(tester, [
        for (final type in glyphs.keys) checkIn('c-${type.name}', type: type),
      ]);

      for (final entry in glyphs.entries) {
        expect(
          find.byIcon(entry.value),
          findsOneWidget,
          reason: '${entry.key} row glyph',
        );
      }
    });

    testWidgets('narrative and topic tags render under the meta line', (
      tester,
    ) async {
      await pump(tester, [
        checkIn(
          'c1',
          narrative: 'Planned the summer trip.',
          topics: ['travel', 'Figma'],
        ),
      ]);

      expect(find.text('Planned the summer trip.'), findsOneWidget);
      final tags = tester
          .widgetList<DsPill>(find.byType(DsPill))
          .where((pill) => pill.bordered)
          .toList();
      expect(tags.map((pill) => pill.label), ['travel', 'Figma']);
      for (final tag in tags) {
        expect(tag.shape, DsPillShape.tag);
        expect(tag.variant, DsPillVariant.filled);
      }
    });
  });
}
