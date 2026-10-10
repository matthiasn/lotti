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
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CheckInMetaSummaryLine(
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
    'check-in-topics',
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
      ('check-in-topics', 'krill contract, launch'),
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
    expect(glyph(tester, 'check-in-topics').icon, LottiIcons.label);
    // The lane ends on its one lever, the task's dashed round Details pill.
    final edit = tag(tester, 'check-in-detail-edit');
    expect(edit.variant, DsPillVariant.muted);
    expect(edit.shape, DsPillShape.pill);
    expect(edit.label, 'Edit check-in');
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('check-in-detail-edit'))).dx,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('check-in-topics'))).dx,
      ),
    );

    for (final key in [...facts, 'check-in-detail-edit']) {
      await tester.tap(find.byKey(ValueKey(key)));
    }
    expect(calls, ['type', 'start', 'duration', 'sentiment', 'edit', 'edit']);
  });

  testWidgets('more topics than the task labels tag names fold into "+N"', (
    tester,
  ) async {
    await pump(tester, topics: const ['krill', 'launch', 'pad 3', 'freeze']);
    expect(tag(tester, 'check-in-topics').label, 'krill, launch +2');
  });

  testWidgets('without topics there is no topics tag', (tester) async {
    await pump(tester, topics: const []);
    expect(find.byKey(const ValueKey('check-in-topics')), findsNothing);
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

  testWidgets('held while a take is live: the facts stay, drop to the low '
      'ink, and take no tap', (tester) async {
    await pump(tester, enabled: false);

    final colors = tokensOf(tester).colors;
    final low = colors.text.lowEmphasis;
    for (final key in [...facts, 'check-in-detail-edit']) {
      final pill = tag(tester, key);
      expect(pill.onTap, isNull, reason: key);
      expect(pill.labelColor, low, reason: key);
      expect(glyph(tester, key).color, low, reason: key);
      await tester.tap(find.byKey(ValueKey(key)), warnIfMissed: false);
    }
    // The bordered facts' frames recede with their ink.
    for (final key in [
      'check-in-type',
      'check-in-started',
      'check-in-duration',
      'check-in-topics',
    ]) {
      expect(
        tag(tester, key).borderColor,
        colors.decorative.level01,
        reason: key,
      );
    }
    expect(calls, isEmpty);
    expect(find.text('Call'), findsOneWidget);
  });

  testWidgets('a live fact keeps its own ink and frame — high for how, when '
      'and how long, medium for the topics and the lever', (tester) async {
    await pump(tester);

    final text = tokensOf(tester).colors.text;
    for (final key in [
      'check-in-type',
      'check-in-started',
      'check-in-duration',
    ]) {
      expect(tag(tester, key).labelColor, text.highEmphasis, reason: key);
      expect(tag(tester, key).borderColor, isNull, reason: key);
    }
    expect(tag(tester, 'check-in-topics').labelColor, text.mediumEmphasis);
    expect(tag(tester, 'check-in-detail-edit').labelColor, text.mediumEmphasis);
  });

  testWidgets('each read-out announces itself as the button it is, by what it '
      'holds', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    for (final (key, label) in [
      ('check-in-type', 'Interaction: Call. Change'),
      ('check-in-sentiment-chip', 'Feeling: Good'),
      ('check-in-topics', 'Topics: krill contract, launch'),
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
}
