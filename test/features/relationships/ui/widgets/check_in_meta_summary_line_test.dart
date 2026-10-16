import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/sentiment.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_meta_summary_line.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final calls = <String>[];
  setUp(calls.clear);

  Future<void> pump(
    WidgetTester tester, {
    Duration duration = const Duration(minutes: 11),
    CheckInSentiment? sentiment = CheckInSentiment.good,
    List<String> topics = const ['krill contract', 'launch'],
    bool enabled = true,
    bool readOut = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CheckInMetaSummaryLine(
          readOut: readOut,
          type: CheckInInteractionType.call,
          startedLabel: 'Sat 1 Aug · 12:44',
          duration: duration,
          sentiment: sentiment,
          topics: topics,
          enabled: enabled,
          onPickType: () => calls.add('type'),
          onPickStart: () => calls.add('start'),
          onPickDuration: () => calls.add('duration'),
          onPickSentiment: () => calls.add('sentiment'),
          onEdit: () => calls.add('edit'),
        ),
      ),
    );
    await tester.pump();
  }

  DsPill tag(WidgetTester tester, String key) => tester.widget<DsPill>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(DsPill),
    ),
  );

  Icon glyph(WidgetTester tester, String key) =>
      tag(tester, key).leading! as Icon;

  DsTokens tokensOf(WidgetTester tester) => tester
      .element(find.byKey(const ValueKey('check-in-meta-line')))
      .designTokens;

  const facts = [
    'check-in-type',
    'check-in-started',
    'check-in-duration',
    'check-in-sentiment-chip',
    'check-in-topics-tag',
  ];

  testWidgets('every set fact is a square-cornered task read-out that opens '
      'its own picker; the topics and the closing lever open the sheet', (
    tester,
  ) async {
    await pump(tester);

    for (final (key, label) in [
      ('check-in-type', 'Call'),
      ('check-in-started', 'Sat 1 Aug · 12:44'),
      ('check-in-duration', '11 min'),
      ('check-in-sentiment-chip', 'Good'),
      ('check-in-topics-tag', 'krill contract, launch'),
    ]) {
      final pill = tag(tester, key);
      expect(pill.label, label);
      expect(
        pill.shape,
        DsPillShape.tag,
        reason: '$key is a fact, not a lever',
      );
    }
    // The neutral facts wear the task lane's filled, bordered shell.
    expect(tag(tester, 'check-in-type').variant, DsPillVariant.filled);
    expect(tag(tester, 'check-in-type').bordered, isTrue);
    expect(glyph(tester, 'check-in-topics-tag').icon, LottiIcons.label);
    // The lane ends on its one lever, the task's dashed round Details pill.
    final edit = tag(tester, 'check-in-detail-edit');
    expect(edit.variant, DsPillVariant.muted);
    expect(edit.shape, DsPillShape.pill);
    expect(edit.label, 'Edit check-in');
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('check-in-detail-edit'))).dx,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('check-in-topics-tag'))).dx,
      ),
    );

    for (final key in [...facts, 'check-in-detail-edit']) {
      await tester.tap(find.byKey(ValueKey(key)));
    }
    expect(calls, ['type', 'start', 'duration', 'sentiment', 'edit', 'edit']);
  });

  testWidgets('every tag keeps the full touch target around its 28px face: '
      'a tap above the pill still opens its picker', (tester) async {
    await pump(tester, duration: Duration.zero);

    for (final (key, call) in [
      ('check-in-type', 'type'),
      ('check-in-started', 'start'),
      ('check-in-duration', 'duration'),
      ('check-in-sentiment-chip', 'sentiment'),
      ('check-in-topics-tag', 'edit'),
      ('check-in-detail-edit', 'edit'),
    ]) {
      final target = tester.getRect(find.byKey(ValueKey(key)));
      final face = tester.getRect(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(DsPill),
        ),
      );
      expect(
        target.height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
        reason: key,
      );
      expect(face.height, lessThan(target.height), reason: key);
      calls.clear();
      // Inside the target, above the pill's own face.
      await tester.tapAt(Offset(face.center.dx, target.top + 2));
      expect(calls, [call], reason: key);
    }
  });

  testWidgets('a held tag takes no tap anywhere in its target', (
    tester,
  ) async {
    await pump(tester, enabled: false);

    final target = tester.getRect(
      find.byKey(const ValueKey('check-in-type')),
    );
    await tester.tapAt(Offset(target.center.dx, target.top + 2));
    expect(calls, isEmpty);
  });

  testWidgets('more topics than the task labels tag names fold into "+N"', (
    tester,
  ) async {
    await pump(tester, topics: const ['krill', 'launch', 'pad 3', 'freeze']);
    expect(tag(tester, 'check-in-topics-tag').label, 'krill, launch +2');
  });

  testWidgets('without topics there is no topics tag', (tester) async {
    await pump(tester, topics: const []);
    expect(find.byKey(const ValueKey('check-in-topics-tag')), findsNothing);
    expect(find.byKey(const ValueKey('check-in-detail-edit')), findsOneWidget);
  });

  for (final (sentiment, face) in [
    (CheckInSentiment.delightful, LottiIcons.moodGood),
    (CheckInSentiment.good, LottiIcons.moodGood),
    (CheckInSentiment.neutral, LottiIcons.moodNeutral),
    (CheckInSentiment.strained, LottiIcons.moodNeutral),
    (CheckInSentiment.difficult, LottiIcons.moodNeutral),
  ]) {
    testWidgets('${sentiment.name} is tinted and led by a face in the '
        'sentiment colour the person page row uses', (tester) async {
      await pump(tester, sentiment: sentiment);

      final tokens = tokensOf(tester);
      final accent = sentimentColor(tokens, sentiment);
      final pill = tag(tester, 'check-in-sentiment-chip');
      expect(pill.variant, DsPillVariant.tinted);
      expect(pill.color, accent);
      expect(pill.labelColor, tokens.colors.text.highEmphasis);
      expect(glyph(tester, 'check-in-sentiment-chip').icon, face);
      expect(glyph(tester, 'check-in-sentiment-chip').color, accent);
    });
  }

  testWidgets('a missing length or feeling is offered on the muted round '
      'pill, not dressed as a fact', (tester) async {
    await pump(tester, duration: Duration.zero, sentiment: null);

    for (final (key, label) in [
      ('check-in-duration', 'Duration'),
      ('check-in-sentiment-chip', 'How did it feel?'),
    ]) {
      final pill = tag(tester, key);
      expect(pill.variant, DsPillVariant.muted);
      expect(pill.shape, DsPillShape.pill);
      expect(pill.label, label);
    }
    await tester.tap(find.byKey(const ValueKey('check-in-duration')));
    await tester.tap(find.byKey(const ValueKey('check-in-sentiment-chip')));
    expect(calls, ['duration', 'sentiment']);
  });

  testWidgets('held while a take is live: the facts stay, the lane fades '
      "as one by the low ink's alpha — the recorder's inert look — and "
      'nothing takes a tap', (tester) async {
    double laneOpacity() => tester
        .widget<AnimatedOpacity>(
          find.byKey(const ValueKey('check-in-meta-line-hold')),
        )
        .opacity;

    await pump(tester);
    expect(laneOpacity(), 1);

    await pump(tester, enabled: false);
    expect(laneOpacity(), tokensOf(tester).colors.text.lowEmphasis.a);
    for (final key in [...facts, 'check-in-detail-edit']) {
      expect(tag(tester, key).onTap, isNull, reason: key);
      await tester.tap(find.byKey(ValueKey(key)), warnIfMissed: false);
    }
    expect(calls, isEmpty);
    expect(find.text('Call'), findsOneWidget);
  });

  testWidgets('a live fact keeps its own ink — high for how, when '
      'and how long, medium for the topics and the lever', (tester) async {
    await pump(tester);

    final text = tokensOf(tester).colors.text;
    for (final key in [
      'check-in-type',
      'check-in-started',
      'check-in-duration',
    ]) {
      expect(tag(tester, key).labelColor, text.highEmphasis, reason: key);
    }
    expect(tag(tester, 'check-in-topics-tag').labelColor, text.mediumEmphasis);
    expect(tag(tester, 'check-in-detail-edit').labelColor, text.mediumEmphasis);
  });

  testWidgets('each read-out announces itself as the button it is, by what it '
      'holds', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    for (final (key, label) in [
      ('check-in-type', 'Interaction: Call. Change'),
      ('check-in-sentiment-chip', 'Feeling: Good'),
      ('check-in-topics-tag', 'Topics: krill contract, launch'),
      ('check-in-detail-edit', 'Edit check-in'),
    ]) {
      expect(
        tester.getSemantics(find.byKey(ValueKey(key))),
        matchesSemantics(
          label: label,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
        reason: key,
      );
    }
    semantics.dispose();
  });

  group("read out (a saved check-in's page)", () {
    testWidgets('the facts are words with their glyphs — no tag around any — '
        'and the lane has no lever', (tester) async {
      await pump(tester, readOut: true);

      expect(find.byType(DsPill), findsNothing);
      for (final label in [
        'Call',
        'Sat 1 Aug · 12:44',
        '11 min',
        'Good',
        'krill contract, launch',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Edit check-in'), findsNothing);
    });

    testWidgets('each fact still opens its own picker, the topics the sheet', (
      tester,
    ) async {
      await pump(tester, readOut: true);

      for (final key in facts) {
        await tester.tap(find.byKey(ValueKey(key)));
      }
      expect(calls, ['type', 'start', 'duration', 'sentiment', 'edit']);
    });

    testWidgets('the feeling reads by glyph and word, the glyph in its '
        "colour, the word in the fact's ink", (tester) async {
      await pump(tester, readOut: true);
      final tokens = tokensOf(tester);
      final chip = find.byKey(const ValueKey('check-in-sentiment-chip'));

      final icon = tester.widget<Icon>(
        find.descendant(of: chip, matching: find.byType(Icon)),
      );
      expect(icon.icon, sentimentGlyph(CheckInSentiment.good));
      expect(icon.color, sentimentColor(tokens, CheckInSentiment.good));
      expect(
        tester
            .widget<Text>(
              find.descendant(of: chip, matching: find.text('Good')),
            )
            .style
            ?.color,
        tokens.colors.text.highEmphasis,
      );
    });

    testWidgets('a fact not set yet is still an offer — the dashed slot', (
      tester,
    ) async {
      await pump(tester, readOut: true, duration: Duration.zero);

      expect(
        tag(tester, 'check-in-duration').variant,
        DsPillVariant.muted,
      );
    });

    testWidgets('held while a take is live, no fact takes a tap', (
      tester,
    ) async {
      await pump(tester, readOut: true, enabled: false);

      for (final key in facts) {
        await tester.tap(find.byKey(ValueKey(key)), warnIfMissed: false);
      }
      expect(calls, isEmpty);
    });
  });
}
