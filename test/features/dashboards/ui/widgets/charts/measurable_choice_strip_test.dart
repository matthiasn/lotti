import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/measurable_choice_series.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/measurable_choice_strip.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  final days = <ChoiceDay>[
    (day: DateTime(2022, 7, 5), choiceId: hydrationClear.id),
    (day: DateTime(2022, 7, 6), choiceId: null),
    (day: DateTime(2022, 7, 7), choiceId: hydrationDark.id),
    (day: DateTime(2022, 7, 8), choiceId: 'gone'),
  ];

  const stripKey = ValueKey('measurable-choice-strip');
  const tooltipKey = ValueKey('measurable-choice-strip-tooltip');

  ChoiceStripPainter painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(stripKey)).painter!
          as ChoiceStripPainter;

  Future<DsTokens> pumpStrip(
    WidgetTester tester, {
    List<ChoiceDay>? strip,
    MeasurableDataType? dataType,
    double width = 400,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 40,
            child: MeasurableChoiceStrip(
              days: strip ?? days,
              dataType: dataType ?? measurableHydration,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.element(find.byType(MeasurableChoiceStrip)).designTokens;
  }

  /// A mouse pointer over the [index]th day of a strip [n] days long.
  Future<TestGesture> hoverDay(
    WidgetTester tester, {
    required int index,
    required int n,
  }) async {
    final box = tester.getRect(find.byKey(stripKey));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      Offset(box.left + box.width * (index + 0.5) / n, box.center.dy),
    );
    await tester.pump();
    return gesture;
  }

  group('choiceColorsFor', () {
    testWidgets(
      'steps the accent from faint to full across every choice, archived '
      'ones included, in the definition order',
      (tester) async {
        final tokens = await pumpStrip(tester);
        final colors = choiceColorsFor(measurableHydration, tokens);
        final faint = tokens.colors.background.level03;
        final full = tokens.colors.interactive.enabled;

        expect(colors.keys, [
          hydrationClear.id,
          hydrationPale.id,
          hydrationDark.id,
          hydrationBrown.id,
        ]);
        expect(colors[hydrationClear.id], Color.lerp(faint, full, 0.25));
        expect(colors[hydrationPale.id], Color.lerp(faint, full, 0.5));
        expect(colors[hydrationDark.id], Color.lerp(faint, full, 0.75));
        // The last choice is the full accent; an archived choice keeps the
        // step its history was drawn in.
        expect(colors[hydrationBrown.id], full);
      },
    );

    testWidgets('a single choice is the full accent; none is empty', (
      tester,
    ) async {
      final tokens = await pumpStrip(tester);
      expect(
        choiceColorsFor(
          measurableHydration.copyWith(choices: const [hydrationClear]),
          tokens,
        ),
        {hydrationClear.id: tokens.colors.interactive.enabled},
      );
      expect(
        choiceColorsFor(measurableHydration.copyWith(choices: null), tokens),
        isEmpty,
      );
    });
  });

  group('MeasurableChoiceStrip', () {
    testWidgets(
      'hands the painter one colour per day: the choice ramp, the track '
      'colour for an empty day, the neutral step for an unknown choice',
      (tester) async {
        final tokens = await pumpStrip(tester);
        final colors = choiceColorsFor(measurableHydration, tokens);
        expect(painter(tester).colors, [
          colors[hydrationClear.id],
          tokens.colors.background.level03,
          colors[hydrationDark.id],
          tokens.colors.decorative.level02,
        ]);
        expect(painter(tester).gap, tokens.spacing.step1);
        expect(painter(tester).radius, tokens.radii.xs);
      },
    );

    testWidgets('sits under the shared left axis inset', (tester) async {
      await pumpStrip(tester);
      final outer = tester.getTopLeft(find.byType(MeasurableChoiceStrip));
      final canvas = tester.getTopLeft(find.byKey(stripKey));
      expect(canvas.dx - outer.dx, kChartLeftAxisWidth);
    });

    testWidgets(
      'hovering a recorded day names its date and choice; a removed choice '
      'is named as such; an empty day has no tooltip',
      (tester) async {
        await pumpStrip(tester);
        expect(find.byKey(tooltipKey), findsNothing);

        final gesture = await hoverDay(tester, index: 0, n: days.length);
        expect(find.byTooltip('Jul 5, 2022 · Clear'), findsOneWidget);

        final box = tester.getRect(find.byKey(stripKey));
        await gesture.moveTo(
          Offset(box.left + box.width * 1.5 / days.length, box.center.dy),
        );
        await tester.pump();
        expect(find.byKey(tooltipKey), findsNothing);

        await gesture.moveTo(
          Offset(box.left + box.width * 3.5 / days.length, box.center.dy),
        );
        await tester.pump();
        expect(find.byTooltip('Jul 8, 2022 · Removed choice'), findsOneWidget);
      },
    );

    testWidgets('a touch on a day words the tooltip for that day too', (
      tester,
    ) async {
      await pumpStrip(tester);
      final box = tester.getRect(find.byKey(stripKey));
      final gesture = await tester.startGesture(
        Offset(box.left + box.width * 2.5 / days.length, box.center.dy),
      );
      await tester.pump();
      expect(find.byTooltip('Jul 7, 2022 · Dark'), findsOneWidget);
      await gesture.up();
    });

    testWidgets(
      'a year at phone width paints without overflowing: gaps dropped, '
      'every day still has width',
      (tester) async {
        final year = [
          for (var i = 0; i < 365; i++)
            (
              day: DateTime(2022).add(Duration(days: i)),
              choiceId: i % 3 == 0 ? hydrationClear.id : hydrationDark.id,
            ),
        ];
        await pumpStrip(tester, strip: year, width: 300);
        expect(tester.takeException(), isNull);

        final p = painter(tester);
        final width = tester.getSize(find.byKey(stripKey)).width;
        expect(p.colors, hasLength(365));
        expect(p.gapFor(width), 0);
        expect(p.cellWidthFor(width), greaterThan(0));
        expect(p.cellWidthFor(width) * 365, closeTo(width, 0.001));
      },
    );

    testWidgets('a short range keeps its gaps', (tester) async {
      await pumpStrip(tester);
      final p = painter(tester);
      final width = tester.getSize(find.byKey(stripKey)).width;
      expect(p.gapFor(width), p.gap);
      expect(
        p.cellWidthFor(width) * days.length + p.gap * (days.length - 1),
        closeTo(width, 0.001),
      );
    });
  });

  group('ChoiceStripPainter', () {
    const a = Color(0xFF111111);
    const b = Color(0xFF222222);

    test('a single cell or none needs no gap', () {
      expect(
        const ChoiceStripPainter(colors: [a], gap: 2, radius: 4).gapFor(100),
        0,
      );
      const empty = ChoiceStripPainter(colors: [], gap: 2, radius: 4);
      expect(empty.gapFor(100), 0);
      expect(empty.cellWidthFor(100), 0);
    });

    test('repaints only when colours, gap or radius change', () {
      const base = ChoiceStripPainter(colors: [a, b], gap: 2, radius: 4);
      expect(
        base.shouldRepaint(
          const ChoiceStripPainter(colors: [a, b], gap: 2, radius: 4),
        ),
        isFalse,
      );
      expect(
        base.shouldRepaint(
          const ChoiceStripPainter(colors: [b, a], gap: 2, radius: 4),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const ChoiceStripPainter(colors: [a], gap: 2, radius: 4),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const ChoiceStripPainter(colors: [a, b], gap: 1, radius: 4),
        ),
        isTrue,
      );
    });

    test('paints one rect per cell with gaps, one per run without', () {
      final recorder = _RecordingCanvas();
      const gapped = ChoiceStripPainter(
        colors: [a, a, b],
        gap: 2,
        radius: 4,
      );
      gapped.paint(recorder, const Size(304, 10));
      expect(recorder.rects, hasLength(3));
      expect(recorder.rects[0].left, 0);
      expect(recorder.rects[1].left, closeTo(102, 0.001));

      final merged = _RecordingCanvas();
      const tight = ChoiceStripPainter(
        colors: [a, a, b],
        gap: 200,
        radius: 4,
      );
      tight.paint(merged, const Size(30, 10));
      // Two cells of `a` become one run; the corner radius shrinks to fit.
      expect(merged.rects, hasLength(2));
      expect(merged.rects[0].width, closeTo(20, 0.001));
      expect(merged.rects[1].left, closeTo(20, 0.001));
      expect(merged.corners.every((r) => r.x <= 4), isTrue);

      // Nothing to paint paints nothing.
      final none = _RecordingCanvas();
      const ChoiceStripPainter(
        colors: [],
        gap: 2,
        radius: 4,
      ).paint(none, const Size(30, 10));
      expect(none.rects, isEmpty);
    });
  });

  group('MeasurableChoiceLegend', () {
    Future<DsTokens> pumpLegend(
      WidgetTester tester,
      List<ChoiceDay> strip,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurableChoiceLegend(days: strip, dataType: measurableHydration),
        ),
      );
      await tester.pump();
      return tester.element(find.byType(MeasurableChoiceLegend)).designTokens;
    }

    Finder entry(MeasurableChoice choice) =>
        find.byKey(ValueKey('choice-legend-${choice.id}'));

    testWidgets('lists the active choices in order with their swatches', (
      tester,
    ) async {
      final tokens = await pumpLegend(tester, days);
      final colors = choiceColorsFor(measurableHydration, tokens);

      expect(entry(hydrationClear), findsOneWidget);
      expect(entry(hydrationPale), findsOneWidget);
      expect(entry(hydrationDark), findsOneWidget);
      expect(entry(hydrationBrown), findsNothing);
      expect(find.text('Brown'), findsNothing);

      final swatch =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: entry(hydrationPale),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(swatch.color, colors[hydrationPale.id]);
      expect(
        find.descendant(of: entry(hydrationPale), matching: find.text('Pale')),
        findsOneWidget,
      );
    });

    testWidgets('an archived choice appears only while a day still shows it', (
      tester,
    ) async {
      await pumpLegend(tester, [
        (day: DateTime(2022, 7, 5), choiceId: hydrationBrown.id),
      ]);
      expect(entry(hydrationBrown), findsOneWidget);
      expect(find.text('Brown'), findsOneWidget);
    });
  });
}

/// Records the rounded rects a painter draws, ignoring everything else.
class _RecordingCanvas implements Canvas {
  final rects = <Rect>[];
  final corners = <Radius>[];

  @override
  void drawRRect(RRect rrect, Paint paint) {
    rects.add(rrect.outerRect);
    corners.add(rrect.tlRadius);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
