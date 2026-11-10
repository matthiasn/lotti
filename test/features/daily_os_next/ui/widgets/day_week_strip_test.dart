import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_week_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

// Tuesday, May 26 2026. In the en-US test locale the week runs Sunday,
// May 24 to Saturday, May 30.
final _tuesday = DateTime(2026, 5, 26);

Finder _cell(DateTime day) =>
    find.byKey(ValueKey('daily_os_week_strip_${day.toIso8601String()}'));

Future<void> _pump(
  WidgetTester tester, {
  DateTime? selected,
  DateTime? today,
  ValueChanged<DateTime>? onSelect,
  bool showWeekChevrons = false,
  double width = 390,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Center(
        child: SizedBox(
          width: width,
          // Loose, as in the header: the strip takes only the width it needs.
          child: Align(
            alignment: Alignment.centerLeft,
            child: DayWeekStrip(
              selected: selected ?? _tuesday,
              today: today ?? _tuesday,
              onSelect: onSelect ?? (_) {},
              showWeekChevrons: showWeekChevrons,
            ),
          ),
        ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
      overrides: overrides,
    ),
  );
  await tester.pump();
}

DsTokens _tokens(WidgetTester tester) =>
    tester.element(find.byType(DayWeekStrip)).designTokens;

/// The fill behind a day cell.
Color? _fillOf(WidgetTester tester, DateTime day) {
  final ink = tester.widget<Ink>(
    find.descendant(of: _cell(day), matching: find.byType(Ink)),
  );
  return (ink.decoration! as BoxDecoration).color;
}

Color? _dayNumberColor(WidgetTester tester, DateTime day) => tester
    .widget<Text>(
      find.descendant(of: _cell(day), matching: find.text('${day.day}')),
    )
    .style
    ?.color;

void main() {
  group('DayWeekStrip.weekOf', () {
    test('starts on Sunday when the locale does', () {
      final week = DayWeekStrip.weekOf(_tuesday, 0);

      expect(week.first, DateTime(2026, 5, 24));
      expect(week.last, DateTime(2026, 5, 30));
      expect(week, hasLength(7));
    });

    test('starts on Monday when the locale does', () {
      final week = DayWeekStrip.weekOf(_tuesday, 1);

      expect(week.first, DateTime(2026, 5, 25));
      expect(week.last, DateTime(2026, 5, 31));
    });

    test('a day that is the first weekday starts its own week', () {
      final sunday = DateTime(2026, 5, 24);

      expect(DayWeekStrip.weekOf(sunday, 0).first, sunday);
    });

    test('a Sunday in a Monday-first week ends it', () {
      final sunday = DateTime(2026, 5, 31);

      expect(DayWeekStrip.weekOf(sunday, 1).last, sunday);
      expect(DayWeekStrip.weekOf(sunday, 1).first, DateTime(2026, 5, 25));
    });

    test('crosses a month and a year boundary', () {
      final week = DayWeekStrip.weekOf(DateTime(2026, 12, 31), 1);

      expect(week.first, DateTime(2026, 12, 28));
      expect(week.last, DateTime(2027, 1, 3));
    });

    test('every day is a midnight, one calendar day apart', () {
      // March 29 2026 is a DST change in much of Europe; constructor
      // arithmetic keeps each day at midnight regardless.
      final week = DayWeekStrip.weekOf(DateTime(2026, 3, 29), 1);

      for (final (i, day) in week.indexed) {
        expect((day.hour, day.minute), (0, 0));
        expect(day, DateTime(2026, 3, 23 + i));
      }
    });
  });

  group('DayWeekStrip cells', () {
    testWidgets('shows the seven days, weekday initial over day number', (
      tester,
    ) async {
      await _pump(tester);

      for (var day = 24; day <= 30; day++) {
        expect(_cell(DateTime(2026, 5, day)), findsOneWidget);
        expect(
          find.descendant(
            of: _cell(DateTime(2026, 5, day)),
            matching: find.text('$day'),
          ),
          findsOneWidget,
        );
      }
      // en-US narrow weekdays, Sunday first.
      final initials = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d != null && RegExp(r'^[A-Z]$').hasMatch(d))
          .toList();
      expect(initials, ['S', 'M', 'T', 'W', 'T', 'F', 'S']);
    });

    testWidgets('the selected day is a surface.selected pill with teal text', (
      tester,
    ) async {
      await _pump(tester);
      final tokens = _tokens(tester);

      expect(_fillOf(tester, _tuesday), tokens.colors.surface.selected);
      expect(
        _dayNumberColor(tester, _tuesday),
        tokens.colors.interactive.enabled,
      );
    });

    testWidgets('the other days have no fill and medium-emphasis numbers', (
      tester,
    ) async {
      await _pump(tester);
      final tokens = _tokens(tester);
      final monday = DateTime(2026, 5, 25);

      expect(_fillOf(tester, monday), isNull);
      expect(
        _dayNumberColor(tester, monday),
        tokens.colors.text.mediumEmphasis,
      );
    });

    testWidgets('day numbers use tabular figures', (tester) async {
      await _pump(tester);

      final style = tester
          .widget<Text>(
            find.descendant(of: _cell(_tuesday), matching: find.text('26')),
          )
          .style!;
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('DayWeekStrip today dot', () {
    final dot = find.byKey(const Key('daily_os_week_strip_today_dot'));

    testWidgets('marks today when another day is selected', (tester) async {
      await _pump(tester, selected: DateTime(2026, 5, 28));

      expect(dot, findsOneWidget);
      expect(
        find.descendant(of: _cell(_tuesday), matching: dot),
        findsOneWidget,
      );
      final decoration =
          tester.widget<DecoratedBox>(dot).decoration as BoxDecoration;
      expect(decoration.color, _tokens(tester).colors.interactive.enabled);
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('is left out when today is the selected day', (tester) async {
      await _pump(tester);

      expect(dot, findsNothing);
    });

    testWidgets('is left out when today is in another week', (tester) async {
      await _pump(tester, today: DateTime(2026, 6, 9));

      expect(dot, findsNothing);
    });

    testWidgets("today's cell is as tall as its neighbours", (tester) async {
      await _pump(tester, selected: DateTime(2026, 5, 28));

      expect(
        tester.getSize(_cell(_tuesday)).height,
        tester.getSize(_cell(DateTime(2026, 5, 27))).height,
      );
    });
  });

  group('DayWeekStrip selection', () {
    testWidgets('a tapped day is selected', (tester) async {
      final picked = <DateTime>[];
      await _pump(tester, onSelect: picked.add);

      await tester.tap(_cell(DateTime(2026, 5, 29)));

      expect(picked, [DateTime(2026, 5, 29)]);
    });

    testWidgets('a fling to the left pages to the next week', (tester) async {
      final picked = <DateTime>[];
      await _pump(tester, onSelect: picked.add);

      await tester.fling(find.byType(DayWeekStrip), const Offset(-200, 0), 800);

      expect(picked, [DateTime(2026, 6, 2)]);
    });

    testWidgets('a fling to the right pages to the previous week', (
      tester,
    ) async {
      final picked = <DateTime>[];
      await _pump(tester, onSelect: picked.add);

      await tester.fling(find.byType(DayWeekStrip), const Offset(200, 0), 800);

      expect(picked, [DateTime(2026, 5, 19)]);
    });

    testWidgets('a slow drag does not page', (tester) async {
      final picked = <DateTime>[];
      await _pump(tester, onSelect: picked.add);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(DayWeekStrip)),
      );
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await gesture.up();

      expect(picked, isEmpty);
    });
  });

  group('DayWeekStrip chevrons', () {
    testWidgets('are left out by default', (tester) async {
      await _pump(tester);

      expect(find.byIcon(LottiIcons.chevronLeft), findsNothing);
      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);
    });

    testWidgets('page a week each way when shown', (tester) async {
      final picked = <DateTime>[];
      await _pump(
        tester,
        onSelect: picked.add,
        showWeekChevrons: true,
        width: 800,
      );

      await tester.tap(find.byKey(const Key('daily_os_week_strip_previous')));
      await tester.tap(find.byKey(const Key('daily_os_week_strip_next')));

      expect(picked, [DateTime(2026, 5, 19), DateTime(2026, 6, 2)]);
    });

    testWidgets('carry week tooltips', (tester) async {
      await _pump(tester, showWeekChevrons: true, width: 800);

      expect(find.byTooltip('Previous week'), findsOneWidget);
      expect(find.byTooltip('Next week'), findsOneWidget);
    });
  });

  group('DayWeekStrip geometry', () {
    testWidgets('cells share a phone width evenly', (tester) async {
      await _pump(tester, width: 350);

      expect(tester.getSize(_cell(_tuesday)).width, closeTo(50, 0.01));
    });

    testWidgets('cells stop growing on a wide pane', (tester) async {
      await _pump(tester, width: 1200);

      final cap = TapTargets.minimum + _tokens(tester).spacing.step3;
      expect(tester.getSize(_cell(_tuesday)).width, cap);
      expect(tester.getSize(find.byType(DayWeekStrip)).width, cap * 7);
    });

    testWidgets('every cell meets the touch-target height', (tester) async {
      await _pump(tester);

      expect(
        tester.getSize(_cell(_tuesday)).height,
        greaterThanOrEqualTo(TapTargets.minimum),
      );
    });
  });

  group('DayWeekStrip semantics', () {
    testWidgets('names each day and flags the selected one', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      expect(
        tester.getSemantics(_cell(_tuesday)),
        matchesSemantics(
          label: 'Select Tuesday, May 26',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(_cell(DateTime(2026, 5, 27))),
        matchesSemantics(
          label: 'Select Wednesday, May 27',
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('DayWeekStrip week start', () {
    testWidgets(
      "starts on the device region's first day, as the sidebar calendar "
      "does, not the app locale's",
      (tester) async {
        // The en-US test locale starts on Sunday; a Monday-first region wins.
        await _pump(
          tester,
          overrides: [
            firstDayOfWeekIndexProvider.overrideWith(
              (ref) async => DateTime.monday % 7,
            ),
          ],
        );

        expect(_cell(DateTime(2026, 5, 24)), findsNothing);
        expect(_cell(DateTime(2026, 5, 31)), findsOneWidget);
        expect(
          tester.getTopLeft(_cell(DateTime(2026, 5, 25))).dx,
          lessThan(tester.getTopLeft(_cell(DateTime(2026, 5, 31))).dx),
        );
      },
    );

    testWidgets("falls back to the locale's first day until the region "
        'resolves', (tester) async {
      await _pump(
        tester,
        overrides: [
          firstDayOfWeekIndexProvider.overrideWith(
            (ref) => Completer<int>().future,
          ),
        ],
      );

      // en-US: Sunday, May 24 to Saturday, May 30.
      expect(_cell(DateTime(2026, 5, 24)), findsOneWidget);
      expect(_cell(DateTime(2026, 5, 31)), findsNothing);
    });
  });
}
