import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_capacity_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

/// Width of the bar the tests lay out, so shares read as whole pixels.
const _width = 400.0;

DayCapacitySegment _segment(Color color, int minutes, [String? label]) =>
    DayCapacitySegment(
      color: color,
      minutes: minutes,
      label: label ?? '$minutes',
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<DayCapacitySegment> segments,
  required int capacityMinutes,
  String? semanticsLabel,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Center(
        child: SizedBox(
          width: _width,
          child: DayCapacityBar(
            segments: segments,
            capacityMinutes: capacityMinutes,
            semanticsLabel: semanticsLabel,
          ),
        ),
      ),
    ),
  );
}

Finder _segmentAt(int index) =>
    find.byKey(ValueKey('daily_os_capacity_segment_$index'));

double _widthOf(WidgetTester tester, int index) =>
    tester.getSize(_segmentAt(index)).width;

DsTokens _tokens(WidgetTester tester) =>
    tester.element(find.byType(DayCapacityBar)).designTokens;

void main() {
  group('DayCapacityBar shares', () {
    testWidgets('draws each segment as its share of the capacity', (
      tester,
    ) async {
      await _pump(
        tester,
        segments: [_segment(_red, 120), _segment(_blue, 60)],
        capacityMinutes: 480,
      );

      expect(_widthOf(tester, 0), closeTo(_width * 120 / 480, 0.5));
      expect(_widthOf(tester, 1), closeTo(_width * 60 / 480, 0.5));
    });

    testWidgets('leaves the rest of the capacity as bare track', (
      tester,
    ) async {
      await _pump(
        tester,
        segments: [_segment(_red, 240)],
        capacityMinutes: 480,
      );

      expect(find.byType(Spacer), findsOneWidget);
      expect(
        tester.getSize(find.byType(Spacer)).width,
        closeTo(_width / 2, 0.5),
      );
    });

    testWidgets('a full day leaves no track', (tester) async {
      await _pump(
        tester,
        segments: [_segment(_red, 300), _segment(_blue, 180)],
        capacityMinutes: 480,
      );

      expect(find.byType(Spacer), findsNothing);
      expect(
        _widthOf(tester, 0) + _widthOf(tester, 1),
        closeTo(_width, 0.5),
      );
    });

    testWidgets(
      'over capacity, the segments fill the bar scaled to their own total',
      (tester) async {
        await _pump(
          tester,
          segments: [_segment(_red, 400), _segment(_blue, 200)],
          capacityMinutes: 480,
        );

        expect(find.byType(Spacer), findsNothing);
        expect(_widthOf(tester, 0), closeTo(_width * 400 / 600, 0.5));
        expect(_widthOf(tester, 1), closeTo(_width * 200 / 600, 0.5));
      },
    );

    testWidgets('without a capacity the segments fill the bar as a mix', (
      tester,
    ) async {
      await _pump(
        tester,
        segments: [_segment(_red, 30), _segment(_blue, 90)],
        capacityMinutes: 0,
      );

      expect(_widthOf(tester, 0), closeTo(_width / 4, 0.5));
      expect(_widthOf(tester, 1), closeTo(_width * 3 / 4, 0.5));
    });

    testWidgets('segments of no minutes take no room', (tester) async {
      await _pump(
        tester,
        segments: [_segment(_red, 0), _segment(_blue, 120)],
        capacityMinutes: 480,
      );

      // Only the blue segment is laid out, as the first one.
      expect(_segmentAt(1), findsNothing);
      final box = tester.widget<ColoredBox>(
        find.descendant(of: _segmentAt(0), matching: find.byType(ColoredBox)),
      );
      expect(box.color, _blue);
    });

    testWidgets('with nothing planned the bar is all track', (tester) async {
      await _pump(tester, segments: const [], capacityMinutes: 480);

      expect(_segmentAt(0), findsNothing);
      expect(tester.getSize(find.byType(DayCapacityBar)).width, _width);
    });
  });

  group('DayCapacityBar paint', () {
    testWidgets('segments are their own colour over a decorative track', (
      tester,
    ) async {
      await _pump(
        tester,
        segments: [_segment(_red, 60)],
        capacityMinutes: 480,
      );
      final tokens = _tokens(tester);

      final boxes = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(DayCapacityBar),
              matching: find.byType(ColoredBox),
            ),
          )
          .map((b) => b.color)
          .toList();
      expect(boxes, [tokens.colors.decorative.level01, _red]);
    });

    testWidgets('every segment spans the full height of the line', (
      tester,
    ) async {
      await _pump(
        tester,
        segments: [_segment(_red, 60), _segment(_blue, 30)],
        capacityMinutes: 480,
      );
      final height = _tokens(tester).spacing.step2;

      for (final index in [0, 1]) {
        final paint = find.descendant(
          of: _segmentAt(index),
          matching: find.byType(ColoredBox),
        );
        expect(tester.getSize(paint).height, height);
      }
    });

    testWidgets('is a step2-tall line with radii.xs ends', (tester) async {
      await _pump(
        tester,
        segments: [_segment(_red, 60)],
        capacityMinutes: 480,
      );
      final tokens = _tokens(tester);

      expect(
        tester.getSize(find.byType(DayCapacityBar)).height,
        tokens.spacing.step2,
      );
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
        BorderRadius.circular(tokens.radii.xs),
      );
    });
  });

  group('DayCapacityBar labels', () {
    testWidgets('each segment carries its label as a tooltip', (
      tester,
    ) async {
      await _pump(
        tester,
        segments: [
          _segment(_red, 60, 'Deep work · 1h'),
          _segment(_blue, 30, 'Admin · 30m'),
        ],
        capacityMinutes: 480,
      );

      final tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => t.message)
          .toList();
      expect(tooltips, ['Deep work · 1h', 'Admin · 30m']);
    });

    testWidgets('the bar is one semantics node with the given label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        segments: [_segment(_red, 60, 'Deep work · 1h')],
        capacityMinutes: 480,
        semanticsLabel: 'Planned time by category: Deep work 1h',
      );

      expect(
        find.bySemanticsLabel('Planned time by category: Deep work 1h'),
        findsOneWidget,
      );
      // The tooltips do not add nodes of their own.
      expect(find.bySemanticsLabel('Deep work · 1h'), findsNothing);
      handle.dispose();
    });
  });
}
