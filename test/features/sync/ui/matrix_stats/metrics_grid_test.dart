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
      // (370 - (2-1)*8) / 2 = 181
      final firstTile = tester.getSize(
        find.byKey(const Key('metric:processed')),
      );
      expect(firstTile.width, closeTo(181, 1));
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

      // (400 - (3-1)*8) / 3 = 128
      final firstTile = tester.getSize(
        find.byKey(const Key('metric:processed')),
      );
      expect(firstTile.width, closeTo(128, 1));
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

      final scheme = Theme.of(
        tester.element(find.byType(MetricTile).first),
      ).colorScheme;

      Color fillOf(String key) {
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byKey(Key('metric:$key')),
            matching: find.byType(Container),
          ),
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      for (final (key, tone) in [
        ('processed', scheme.primary),
        ('conflictsCreated', scheme.error),
        ('droppedByType.foo', scheme.tertiary),
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
