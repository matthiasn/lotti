import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/sentiment.dart';
import 'package:lotti/features/relationships/ui/widgets/check_ins_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_data/test_data.dart';
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
    List<CheckInEntry> checkIns, {
    Map<String, List<JournalEntity>> entries = const {},
  }) async {
    final opened = <CheckInEntry>[];
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          CustomScrollView(
            slivers: [
              CheckInsCardSliver(
                checkIns: checkIns,
                entries: entries,
                onOpen: opened.add,
              ),
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

    // The owner's complaint: hovering drew a square grey slab inside the
    // card. Rows are the Tasks list's grouped rows now — the fill spans the
    // row, and the divider beside it gives way.
    testWidgets('hovering lights the whole row and hides the divider beside '
        'it', (tester) async {
      await pump(tester, [checkIn('c1'), checkIn('c2'), checkIn('c3')]);
      final tokens = tester
          .element(find.byType(CheckInsCardSliver))
          .designTokens;
      final divider = find.byKey(const ValueKey('check-in-row-divider-c1'));
      final background = find.byKey(
        const ValueKey('check-in-row-background-c1'),
      );
      expect(divider, findsOneWidget);
      expect(background, findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(
          find.byKey(const ValueKey('check-in-row-c1')),
        ),
      );
      addTearDown(mouse.removePointer);
      await tester.pump();

      expect(
        (tester.widget<DecoratedBox>(background).decoration as BoxDecoration)
            .color,
        tokens.colors.surface.hover,
      );
      expect(divider, findsNothing);
      expect(
        find.byKey(const ValueKey('check-in-row-divider-c2')),
        findsOneWidget,
        reason: 'rows away from the hover keep their divider',
      );

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(background, findsNothing);
      expect(divider, findsOneWidget);
    });

    testWidgets('the last row rounds into the card and has no divider; every '
        'row says it opens', (tester) async {
      await pump(tester, [checkIn('c1'), checkIn('c2')]);

      final lastRow = tester.widget<GroupedCardRowSurface>(
        find.ancestor(
          of: find.byKey(const ValueKey('check-in-row-surface-c2')),
          matching: find.byType(GroupedCardRowSurface),
        ),
      );
      final radius = tester
          .element(find.byType(CheckInsCardSliver))
          .designTokens
          .radii
          .sectionCards;
      expect(
        lastRow.backgroundBorderRadius,
        BorderRadius.vertical(bottom: Radius.circular(radius)),
      );
      expect(
        find.byKey(const ValueKey('check-in-row-divider-c2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('check-in-row-chevron')),
        findsNWidgets(2),
      );
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

  // Check-ins hold entries (ADR 0062): a new one has no text of its own, so
  // the row leads with the first words it holds and says what else is in it.
  group('what the row says a check-in holds', () {
    JournalEntity comment(String text) => testTextEntry.copyWith(
      entryText: EntryText(plainText: text),
    );
    JournalEntity recording({String? transcript}) => testAudioEntry.copyWith(
      entryText: transcript == null ? null : EntryText(plainText: transcript),
    );
    final photo = testImageEntry.copyWith(entryText: null);

    for (final (label, narrative, held, summary, holds) in [
      (
        'the text it was saved with leads, the rest is counted',
        'Called about the launch.',
        [recording(transcript: 'Krill memo.'), photo],
        'Called about the launch.',
        '1 recording · 1 photo',
      ),
      (
        'without its own text, the first words it holds',
        null,
        [photo, recording(transcript: 'Krill memo.'), comment('Send it.')],
        'Krill memo.',
        '1 recording · 1 photo · 1 comment',
      ),
      (
        'a recording still being transcribed says so',
        null,
        [recording()],
        'Transcribing…',
        '1 recording',
      ),
      // CodeRabbit review on #4348: a recording still waiting must not
      // hide a later comment that has words.
      (
        'a recording still waiting does not hide a comment with words',
        null,
        [recording(), comment('Send the krill memo.')],
        'Send the krill memo.',
        '1 recording · 1 comment',
      ),
      (
        'photos alone lead with nothing',
        null,
        [photo, photo],
        null,
        '2 photos',
      ),
      (
        'nothing held, nothing counted',
        'Short call.',
        <JournalEntity>[],
        'Short call.',
        null,
      ),
    ]) {
      testWidgets(label, (tester) async {
        await pump(
          tester,
          [checkIn('c-1', narrative: narrative)],
          entries: {'c-1': held},
        );

        final summaryFinder = find.byKey(
          const ValueKey('check-in-row-summary'),
        );
        if (summary == null) {
          expect(summaryFinder, findsNothing);
        } else {
          expect(tester.widget<Text>(summaryFinder).data, summary);
        }
        // What it holds rides the meta line, after when, how and how long.
        final meta = tester
            .widget<Text>(find.byKey(const ValueKey('check-in-row-meta')))
            .data!;
        if (holds == null) {
          expect(meta, isNot(matches(RegExp('recording|photo|comment'))));
        } else {
          expect(meta, endsWith(' · $holds'));
        }
      });
    }

    testWidgets('pending words are quieter than words', (tester) async {
      await pump(
        tester,
        [checkIn('c-1'), checkIn('c-2', narrative: 'Said hi.')],
        entries: {
          'c-1': [recording()],
        },
      );
      Color? colorOf(String id) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey('check-in-row-$id')),
              matching: find.byKey(const ValueKey('check-in-row-summary')),
            ),
          )
          .style
          ?.color;

      final tokens = tester
          .element(find.byType(CheckInsCardSliver))
          .designTokens;
      expect(colorOf('c-1'), tokens.colors.text.mediumEmphasis);
      expect(colorOf('c-2'), tokens.colors.text.highEmphasis);
    });
  });
}
