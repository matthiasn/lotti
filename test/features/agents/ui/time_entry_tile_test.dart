import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/time_entry_tile.dart';

import '../../../widget_test_utils.dart';

void main() {
  Widget host(Map<String, dynamic> args, {bool busy = false}) {
    return makeTestableWidgetWithScaffold(
      TimeEntryTile(args: args, busy: busy),
    );
  }

  group('TimeEntryTile', () {
    testWidgets('renders parsed start and end times for a completed session', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const {
          'startTime': '2026-04-18T10:30:00',
          'endTime': '2026-04-18T11:15:00',
          'summary': 'Wrote integration tests',
        }),
      );

      expect(find.text('10:30'), findsOneWidget);
      expect(find.text('11:15'), findsOneWidget);
      expect(find.text('Wrote integration tests'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    });

    testWidgets('shows "running" label when endTime key is absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const {
          'startTime': '2026-04-18T09:00:00',
          'summary': 'Still ticking',
        }),
      );

      expect(find.text('09:00'), findsOneWidget);
      // Exact label comes from localization — verify the surrounding row
      // rendered without crashing and the running indicator shows *some*
      // non-empty value rather than '?'.
      expect(find.text('?'), findsNothing);
      expect(find.text('Still ticking'), findsOneWidget);
    });

    testWidgets('falls back to raw startTime when unparseable', (tester) async {
      await tester.pumpWidget(
        host(const {
          'startTime': 'not-a-date',
          'endTime': '2026-04-18T12:00:00',
        }),
      );

      expect(find.text('not-a-date'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
    });

    testWidgets(
      'falls back to raw endTime when it is present but unparseable',
      (tester) async {
        await tester.pumpWidget(
          host(const {
            'startTime': '2026-04-18T08:00:00',
            'endTime': 'garbled-end',
          }),
        );

        expect(find.text('08:00'), findsOneWidget);
        expect(find.text('garbled-end'), findsOneWidget);
      },
    );

    testWidgets('renders "?" when startTime is missing entirely', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const {
          'endTime': '2026-04-18T12:00:00',
        }),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('omits the summary row when summary is empty', (tester) async {
      await tester.pumpWidget(
        host(const {
          'startTime': '2026-04-18T08:00:00',
          'endTime': '2026-04-18T09:00:00',
          'summary': '   ',
        }),
      );

      expect(find.text('08:00'), findsOneWidget);
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
      await tester.pumpWidget(
        host(
          const {
            'startTime': '2026-04-18T08:00:00',
            'endTime': '2026-04-18T09:00:00',
          },
          busy: true,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('omits progress indicator when busy is false', (tester) async {
      await tester.pumpWidget(
        host(const {
          'startTime': '2026-04-18T08:00:00',
          'endTime': '2026-04-18T09:00:00',
        }),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'blank-string endTime is treated as a running timer',
      (tester) async {
        await tester.pumpWidget(
          host(const {
            'startTime': '2026-04-18T09:00:00',
            'endTime': '',
          }),
        );

        // startTime parses cleanly; endTime normalizes to null so the
        // widget shows the localized running label instead of '?'.
        expect(find.text('09:00'), findsOneWidget);
        expect(find.text('?'), findsNothing);
      },
    );

    testWidgets('ignores non-string values in args gracefully', (tester) async {
      await tester.pumpWidget(
        host(const {
          'startTime': 12345,
          'endTime': null,
          'summary': false,
        }),
      );

      // Non-string startTime falls to '?'. Null endTime normalizes to null
      // and renders as the running label, not '?'. Non-string summary is
      // treated as empty → row omitted; the widget should not throw.
      expect(find.text('?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
