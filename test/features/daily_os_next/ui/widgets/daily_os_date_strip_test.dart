// The production width cache must start with the fonts this suite measures.
// Other bundled suites can populate it before loading the app fonts.
@Tags(['skip_very_good_optimization'])
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_date_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../test_utils/screenshot_harness.dart';
import '../../../../widget_test_utils.dart';

void main() {
  setUpAll(loadAppFonts);

  final selected = DateTime(2026, 5, 27);

  Widget host({
    required double width,
    required bool compact,
    required bool isToday,
    VoidCallback? onPrev,
    VoidCallback? onNext,
    VoidCallback? onPick,
    VoidCallback? onToday,
  }) {
    return makeTestableWidget2(
      Material(
        child: Center(
          child: SizedBox(
            width: width,
            height: 80,
            child: DailyOsDateStrip(
              selected: selected,
              isToday: isToday,
              compact: compact,
              onPrev: onPrev ?? () {},
              onNext: onNext ?? () {},
              onPick: onPick ?? () {},
              onToday: onToday ?? () {},
            ),
          ),
        ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
    );
  }

  void setView(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  String locale(WidgetTester tester) => Localizations.localeOf(
    tester.element(find.byType(DailyOsDateStrip)),
  ).toString();

  group('DailyOsDateStrip (regular)', () {
    testWidgets(
      'wide: full date with year, and a Today button once off today',
      (tester) async {
        setView(tester);
        var todayTaps = 0;
        await tester.pumpWidget(
          host(
            width: 600,
            compact: false,
            isToday: false,
            onToday: () => todayTaps++,
          ),
        );
        await tester.pump();

        expect(
          find.text(DateFormat.yMMMEd(locale(tester)).format(selected)),
          findsOneWidget,
        );
        final today = find.byKey(const Key('daily_os_date_strip_today'));
        expect(today, findsOneWidget);
        await tester.tap(today);
        expect(todayTaps, 1);

        // Full-size chevrons.
        expect(
          tester.getSize(find.byIcon(LottiIcons.chevronLeft).first).width,
          lessThanOrEqualTo(kMinInteractiveDimension),
        );
        expect(
          tester.getSize(find.byType(IconButton).first).width,
          kMinInteractiveDimension,
        );
      },
    );

    testWidgets('on today the label reads Today and no Today button shows', (
      tester,
    ) async {
      setView(tester);
      await tester.pumpWidget(host(width: 600, compact: false, isToday: true));
      await tester.pump();

      final messages = tester.element(find.byType(DailyOsDateStrip)).messages;
      expect(find.text(messages.dailyOsTodayButton), findsOneWidget);
      expect(find.byKey(const Key('daily_os_date_strip_today')), findsNothing);
    });

    testWidgets(
      'narrow: drops the year, drops the Today button, and long-press on '
      'the label still returns to today',
      (tester) async {
        setView(tester);
        var todayCalls = 0;
        var picks = 0;
        await tester.pumpWidget(
          host(
            width: 240,
            compact: false,
            isToday: false,
            onToday: () => todayCalls++,
            onPick: () => picks++,
          ),
        );
        await tester.pump();

        final label = find.text(
          DateFormat.MMMEd(locale(tester)).format(selected),
        );
        expect(label, findsOneWidget);
        expect(
          find.byKey(const Key('daily_os_date_strip_today')),
          findsNothing,
        );
        await tester.longPress(label);
        expect(todayCalls, 1);
        await tester.tap(label);
        expect(picks, 1);
      },
    );

    testWidgets('chevrons fire prev and next', (tester) async {
      setView(tester);
      var prev = 0;
      var next = 0;
      await tester.pumpWidget(
        host(
          width: 600,
          compact: false,
          isToday: true,
          onPrev: () => prev++,
          onNext: () => next++,
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(LottiIcons.chevronLeft));
      await tester.tap(find.byIcon(LottiIcons.chevronRight));
      expect(prev, 1);
      expect(next, 1);
    });
  });

  group('DailyOsDateStrip (compact)', () {
    testWidgets(
      'compact: chevrons keep the 48dp floor, the wide tier has no year, and '
      'there is never a Today button',
      (tester) async {
        setView(tester);
        await tester.pumpWidget(
          host(width: 600, compact: true, isToday: false),
        );
        await tester.pump();

        expect(
          find.text(DateFormat.MMMEd(locale(tester)).format(selected)),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('daily_os_date_strip_today')),
          findsNothing,
        );
        final buttons = find.byType(IconButton);
        expect(buttons, findsNWidgets(2));
        // A glyph-only control owes TapTargets.minimum even when compact.
        expect(tester.getSize(buttons.first), const Size(48, 48));
      },
    );

    testWidgets('compact narrow tier is month + day', (tester) async {
      setView(tester);
      await tester.pumpWidget(host(width: 150, compact: true, isToday: false));
      await tester.pump();

      expect(
        find.text(DateFormat.MMMd(locale(tester)).format(selected)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'compact strip is narrower than the regular one at the same width',
      (tester) async {
        setView(tester);
        await tester.pumpWidget(
          host(width: 600, compact: false, isToday: false),
        );
        await tester.pump();
        // Chevron to chevron: the extent the strip actually occupies.
        double extent() =>
            tester.getRect(find.byIcon(LottiIcons.chevronRight)).right -
            tester.getRect(find.byIcon(LottiIcons.chevronLeft)).left;
        final regular = extent();

        await tester.pumpWidget(
          host(width: 600, compact: true, isToday: false),
        );
        await tester.pump();
        final compact = extent();

        expect(compact, lessThan(regular));
      },
    );
  });

  group('showDailyOsDayPicker', () {
    testWidgets(
      'keeps today inside the window even when the selection is far off, '
      'and returns the picked day',
      (tester) async {
        setView(tester);
        final today = DateTime(2026, 5, 27);
        // Two years out: without the guard today would fall outside the
        // ±1-year window anchored on the selection.
        final farSelection = DateTime(2028, 5, 27);
        DateTime? result;
        late BuildContext hostContext;

        await withClock(Clock.fixed(today), () async {
          await tester.pumpWidget(
            ProviderScope(
              child: makeTestableWidget2(
                Builder(
                  builder: (context) {
                    hostContext = context;
                    return const SizedBox.shrink();
                  },
                ),
                mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
              ),
            ),
          );
          final future = showDailyOsDayPicker(
            hostContext,
            selected: farSelection,
          ).then((value) => result = value);
          await tester.pumpAndSettle();

          final picker = tester.widget<CalendarDatePicker>(
            find.byType(CalendarDatePicker),
          );
          expect(picker.firstDate.isAfter(today), isFalse);
          expect(picker.lastDate.isBefore(farSelection), isFalse);

          picker.onDateChanged(DateTime(2028, 5, 20));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();
          await future;
        });

        expect(result, DateTime(2028, 5, 20));
      },
    );
  });
}
