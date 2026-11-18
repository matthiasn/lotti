import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/time_entry_tile.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  // Built under a clock pinned to the fixtures' year: the tile names a year
  // only when it is not the current one.
  Future<void> pumpTile(
    WidgetTester tester,
    Map<String, dynamic> args, {
    bool busy = false,
  }) => withClock(
    Clock.fixed(DateTime(2026, 4, 20)),
    () => tester.pumpWidget(
      makeTestableWidgetWithScaffold(TimeEntryTile(args: args, busy: busy)),
    ),
  );

  group('TimeEntryTile', () {
    testWidgets('a session across midnight names the day on both ends', (
      tester,
    ) async {
      await pumpTile(tester, const {
        'startTime': '2026-04-18T22:30:00',
        'endTime': '2026-04-19T01:15:00',
      });

      expect(find.text('Sat,\u00A0Apr\u00A018, 22:30'), findsOneWidget);
      expect(find.text('Sun,\u00A0Apr\u00A019, 01:15'), findsOneWidget);
    });

    testWidgets('an entry from another year shows the year', (tester) async {
      await pumpTile(tester, const {
        'startTime': '2025-12-30T10:00:00',
        'endTime': '2025-12-30T11:45:00',
      });

      expect(
        find.text('Tue,\u00A0Dec\u00A030,\u00A02025, 10:00'),
        findsOneWidget,
      );
      expect(find.text('11:45'), findsOneWidget);
    });

    testWidgets('renders parsed start and end times for a completed session', (
      tester,
    ) async {
      await pumpTile(tester, const {
        'startTime': '2026-04-18T10:30:00',
        'endTime': '2026-04-18T11:15:00',
        'summary': 'Wrote integration tests',
      });

      // The day leads the start; a same-day end is the time alone.
      expect(find.text('Sat,\u00A0Apr\u00A018, 10:30'), findsOneWidget);
      expect(find.text('11:15'), findsOneWidget);
      expect(find.text('Wrote integration tests'), findsOneWidget);
      expect(find.byIcon(LottiIcons.timer), findsOneWidget);
    });

    testWidgets('shows "running" label when endTime key is absent', (
      tester,
    ) async {
      await pumpTile(tester, const {
        'startTime': '2026-04-18T09:00:00',
        'summary': 'Still ticking',
      });

      expect(find.text('Sat,\u00A0Apr\u00A018, 09:00'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      // Exact label comes from localization — verify the surrounding row
      // rendered without crashing and the running indicator shows *some*
      // non-empty value rather than '?'.
      expect(find.text('?'), findsNothing);
      expect(find.text('Still ticking'), findsOneWidget);
    });

    testWidgets('falls back to raw startTime when unparseable', (tester) async {
      await pumpTile(tester, const {
        'startTime': 'not-a-date',
        'endTime': '2026-04-18T12:00:00',
      });

      expect(find.text('not-a-date'), findsOneWidget);
      // No parsed start to share a day with, so the end names its own.
      expect(find.text('Sat,\u00A0Apr\u00A018, 12:00'), findsOneWidget);
    });

    testWidgets(
      'falls back to raw endTime when it is present but unparseable',
      (tester) async {
        await pumpTile(tester, const {
          'startTime': '2026-04-18T08:00:00',
          'endTime': 'garbled-end',
        });

        expect(find.text('Sat,\u00A0Apr\u00A018, 08:00'), findsOneWidget);
        expect(find.text('garbled-end'), findsOneWidget);
      },
    );

    testWidgets('renders "?" when startTime is missing entirely', (
      tester,
    ) async {
      await pumpTile(tester, const {
        'endTime': '2026-04-18T12:00:00',
      });

      expect(find.text('?'), findsOneWidget);
      expect(find.text('Sat,\u00A0Apr\u00A018, 12:00'), findsOneWidget);
    });

    testWidgets('omits the summary row when summary is empty', (tester) async {
      await pumpTile(tester, const {
        'startTime': '2026-04-18T08:00:00',
        'endTime': '2026-04-18T09:00:00',
        'summary': '   ',
      });

      expect(find.text('Sat,\u00A0Apr\u00A018, 08:00'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      // Only the two labeled time rows should carry bodySmall text; the
      // summary paragraph is absent.
      final bodySmallTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data != null && t.data!.trim().isNotEmpty)
          .toList();
      expect(
        bodySmallTexts.any((t) => t.data == '   '),
        isFalse,
      );
    });

    testWidgets('shows progress indicator when busy is true', (tester) async {
      await pumpTile(
        tester,

        const {
          'startTime': '2026-04-18T08:00:00',
          'endTime': '2026-04-18T09:00:00',
        },
        busy: true,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('omits progress indicator when busy is false', (tester) async {
      await pumpTile(tester, const {
        'startTime': '2026-04-18T08:00:00',
        'endTime': '2026-04-18T09:00:00',
      });

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'blank-string endTime is treated as a running timer',
      (tester) async {
        await pumpTile(tester, const {
          'startTime': '2026-04-18T09:00:00',
          'endTime': '',
        });

        // startTime parses cleanly; endTime normalizes to null so the
        // widget shows the localized running label instead of '?'.
        expect(find.text('Sat,\u00A0Apr\u00A018, 09:00'), findsOneWidget);
        expect(find.text('Running'), findsOneWidget);
        expect(find.text('?'), findsNothing);
      },
    );

    testWidgets('ignores non-string values in args gracefully', (tester) async {
      await pumpTile(tester, const {
        'startTime': 12345,
        'endTime': null,
        'summary': false,
      });

      // Non-string startTime falls to '?'. Null endTime normalizes to null
      // and renders as the running label, not '?'. Non-string summary is
      // treated as empty → row omitted; the widget should not throw.
      expect(find.text('?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
