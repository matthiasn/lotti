import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_grid.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('MetricsGrid', () {
    final testEntries = [
      const MapEntry('processed', 10),
      const MapEntry('skipped', 2),
      const MapEntry('failures', 1),
    ];

    testWidgets('renders labels and values for each entry', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: testEntries,
              labelFor: (k) => k.toUpperCase(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('PROCESSED'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('SKIPPED'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('FAILURES'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('applies correct Key to each tile', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: testEntries,
              labelFor: (k) => k,
            ),
          ),
        ),
      );
      await tester.pump();

      for (final e in testEntries) {
        expect(
          find.byKey(Key('metric:${e.key}')),
          findsOneWidget,
          reason: 'tile for ${e.key} should have correct key',
        );
      }
    });

    testWidgets('renders empty grid when entries is empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: const [],
              labelFor: (k) => k,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MetricTile), findsNothing);
    });

    testWidgets('transforms labels using labelFor function', (tester) async {
      final labelMap = {'processed': 'Synced', 'failures': 'Errors'};
      final entries = [
        const MapEntry('processed', 42),
        const MapEntry('failures', 3),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: entries,
              labelFor: (k) => labelMap[k] ?? k,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Synced'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Errors'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // Raw keys should not appear as labels
      expect(find.text('processed'), findsNothing);
      expect(find.text('failures'), findsNothing);
    });

    testWidgets('uses 2 columns at narrow width (< 380)', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 370,
            child: MetricsGrid(
              entries: testEntries,
              labelFor: (k) => k,
            ),
          ),
        ),
      );
      await tester.pump();

      // With 2 columns and 3 items, all tiles should still render
      expect(find.byType(MetricTile), findsNWidgets(3));

      // Verify tile width is based on 2-column layout:
      // The gap is the spacing token, not a literal, so the expectation is
      // derived the same way the widget derives it.
      final gap = tester
          .element(find.byType(MetricTile).first)
          .designTokens
          .spacing
          .step3;
      final firstTile = tester.getSize(
        find.byKey(const Key('metric:processed')),
      );
      expect(firstTile.width, closeTo((370 - gap) / 2, 1));
    });

    testWidgets('uses 3 columns at medium width (380-559)', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: testEntries,
              labelFor: (k) => k,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MetricTile), findsNWidgets(3));

      final gap = tester
          .element(find.byType(MetricTile).first)
          .designTokens
          .spacing
          .step3;
      final firstTile = tester.getSize(
        find.byKey(const Key('metric:processed')),
      );
      expect(firstTile.width, closeTo((400 - 2 * gap) / 3, 1));
    });
  });

  // The tile used to carry a raw 12/10 inset, a raw 6 gap, a bare 0.08 alpha
  // and an `onSurface` fade — four values with no owner. These pin them to
  // the tokens they now bind, so a revert to any literal fails here rather
  // than passing review as "looks about the same".
  group('MetricTile design-system bindings', () {
    const oneTile = [MapEntry('processed', 10)];

    Future<DsTokens> pumpTile(WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 400,
            child: MetricsGrid(entries: oneTile, labelFor: _identity),
          ),
        ),
      );
      await tester.pump();
      return tester.element(find.byType(MetricTile)).designTokens;
    }

    testWidgets('the inset is a symmetric step-4 box, not 12 by 10', (
      tester,
    ) async {
      final tokens = await pumpTile(tester);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(MetricTile),
          matching: find.byType(Container),
        ),
      );

      expect(
        container.padding,
        EdgeInsets.all(tokens.spacing.step4),
        reason: 'the vertical 10 was off the spacing ramp entirely',
      );
    });

    testWidgets('the label-to-value gap is a step-3 rhythm, not 6', (
      tester,
    ) async {
      final tokens = await pumpTile(tester);

      final gap = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(MetricTile),
          matching: find.byType(SizedBox),
        ),
      );

      expect(gap.height, tokens.spacing.step3);
    });

    // Note this pair cannot catch a revert to the bare `0.08` literal — the
    // token holds that same number, so the rendered colour is identical. What
    // it does cover is `_tone`'s branch table, which nothing else exercised:
    // the three outcomes must stay visually distinguishable, which is the
    // property that stopped a `colorScheme.*Container` mapping being viable.
    testWidgets('each outcome takes its own tone at the tint alpha', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: [
                MapEntry('processed', 10),
                MapEntry('conflictsCreated', 2),
                MapEntry('droppedByType.foo', 1),
              ],
              labelFor: _identity,
            ),
          ),
        ),
      );
      await tester.pump();

      final tokens = tester.element(find.byType(MetricTile).first).designTokens;

      Color fillOf(String key) {
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byKey(Key('metric:$key')),
            matching: find.byType(Container),
          ),
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      // Asserted against the token tree, not `colorScheme`. The two agree in
      // production because the app theme *is* DesignSystemTheme, but this
      // harness builds a stock Material scheme with the tokens attached — so
      // a `colorScheme` expectation here would have been checking a palette
      // the user never sees.
      for (final (key, tone) in [
        ('processed', tokens.colors.interactive.enabled),
        ('conflictsCreated', tokens.colors.alert.error.defaultColor),
        ('droppedByType.foo', tokens.colors.alert.info.defaultColor),
      ]) {
        expect(
          fillOf(key),
          tone.withValues(alpha: SurfaceAlphas.tint),
          reason: '$key should carry its own tone',
        );
      }
    });

    testWidgets('the three tones stay distinguishable from one another', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 400,
            child: MetricsGrid(
              entries: [
                MapEntry('processed', 10),
                MapEntry('conflictsCreated', 2),
                MapEntry('droppedByType.foo', 1),
              ],
              labelFor: _identity,
            ),
          ),
        ),
      );
      await tester.pump();

      final fills = <Color>{
        for (final key in [
          'processed',
          'conflictsCreated',
          'droppedByType.foo',
        ])
          (tester
                      .widget<Container>(
                        find.descendant(
                          of: find.byKey(Key('metric:$key')),
                          matching: find.byType(Container),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!,
      };

      // Collapsing these onto neutral container colours would make conflicts
      // and drops indistinguishable from routine throughput — the categorising
      // the tint exists to carry.
      expect(fills, hasLength(3));
    });

    testWidgets('a full row of tiles fits inside its constraint', (
      tester,
    ) async {
      // The Wrap's spacing and the tileWidth arithmetic read the same `gap`
      // local. If they ever diverge the last tile in a row is pushed onto its
      // own line, silently halving the grid's density — which a width
      // assertion on a single tile cannot see.
      const width = 400.0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: width,
            child: MetricsGrid(
              entries: [
                MapEntry('a', 1),
                MapEntry('b', 2),
                MapEntry('c', 3),
              ],
              labelFor: _identity,
            ),
          ),
        ),
      );
      await tester.pump();

      // Three tiles at this width means three columns: all share a row, so
      // every tile's vertical centre is identical.
      final tops = [
        'a',
        'b',
        'c',
      ].map((k) => tester.getTopLeft(find.byKey(Key('metric:$k'))).dy).toSet();
      expect(tops, hasLength(1), reason: 'a tile wrapped onto a second row');

      final right = tester.getBottomRight(find.byKey(const Key('metric:c'))).dx;
      final left = tester.getTopLeft(find.byKey(const Key('metric:a'))).dx;
      expect(right - left, lessThanOrEqualTo(width + 0.5));
    });

    testWidgets('the label and value take their tiers from the type scale', (
      tester,
    ) async {
      final tokens = await pumpTile(tester);

      final label = tester.widget<Text>(find.text('processed'));
      final value = tester.widget<Text>(find.text('10'));

      // A metric label is caption-tier; its value is the subtitle tier the
      // sibling backfill status cells already use, so the two surfaces read
      // as one family rather than two.
      expect(
        label.style!.fontSize,
        tokens.typography.styles.others.caption.fontSize,
      );
      expect(
        value.style!.fontSize,
        tokens.typography.styles.subtitle.subtitle1.fontSize,
      );
      expect(value.style!.fontWeight, tokens.typography.weight.semiBold);
      // The value changes on every poll, so its digits must not reflow the
      // tile around them.
      expect(
        value.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(
        label.style!.fontSize,
        lessThan(value.style!.fontSize!),
        reason: 'the value must outrank its label',
      );
    });

    testWidgets('the tile frame binds the radius and divider tokens', (
      tester,
    ) async {
      final tokens = await pumpTile(tester);

      final decoration =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(MetricTile),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;

      expect(decoration.borderRadius, BorderRadius.circular(tokens.radii.m));
      expect(
        decoration.border,
        Border.all(color: tokens.colors.decorative.level02),
      );
    });

    testWidgets('the label binds the emphasis ramp, not a faded onSurface', (
      tester,
    ) async {
      final tokens = await pumpTile(tester);

      final element = tester.element(find.byType(MetricTile));
      final label = tester.widget<Text>(find.text('processed'));

      expect(label.style!.color, tokens.colors.text.mediumEmphasis);
      // The ramp fades via its own alpha, so "is it faded" cannot tell the two
      // apart. Naming the exact colour it must no longer be can.
      expect(
        label.style!.color,
        isNot(Theme.of(element).colorScheme.onSurface.withValues(alpha: 0.8)),
      );
    });
  });
}

String _identity(String key) => key;
