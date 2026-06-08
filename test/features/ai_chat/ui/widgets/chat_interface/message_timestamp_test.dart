import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/message_timestamp.dart';

/// Mirrors the zero-padded `HH:mm` expression in [MessageTimestamp.build]. The
/// concrete widget tests below anchor this formula to the real rendered text, so
/// the Glados property can assert the format invariants over arbitrary
/// [DateTime]s without re-pumping a widget on every run.
String _formatTime(DateTime ts) =>
    '${ts.hour.toString().padLeft(2, '0')}:'
    '${ts.minute.toString().padLeft(2, '0')}';

void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? ThemeData.light(),
    home: Scaffold(body: Center(child: child)),
  );

  group('MessageTimestamp', () {
    testWidgets('formats time as HH:mm', (tester) async {
      final ts = DateTime(2025, 1, 2, 3, 4);
      await tester.pumpWidget(
        wrap(
          MessageTimestamp(timestamp: ts, isUser: false),
        ),
      );

      // Anchors `_formatTime` to the actual widget rendering: the widget must
      // produce exactly what the property formula predicts for this timestamp.
      expect(find.text('03:04'), findsOneWidget);
      expect(find.text(_formatTime(ts)), findsOneWidget);
    });

    testWidgets('renders single-digit hours and minutes zero-padded', (
      tester,
    ) async {
      // Boundary case the property cares about: pre-noon, single-digit minute.
      final ts = DateTime(2025, 1, 2, 9, 5);
      await tester.pumpWidget(
        wrap(MessageTimestamp(timestamp: ts, isUser: false)),
      );

      expect(find.text('09:05'), findsOneWidget);
      expect(find.text(_formatTime(ts)), findsOneWidget);
    });

    testWidgets('aligns left for user and right for assistant', (tester) async {
      final ts = DateTime(2025, 1, 2, 12, 30);

      await tester.pumpWidget(
        wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MessageTimestamp(timestamp: ts, isUser: true),
              MessageTimestamp(timestamp: ts, isUser: false),
            ],
          ),
        ),
      );

      final texts = tester.widgetList<Text>(find.text('12:30')).toList();
      expect(texts.length, 2);
      expect(texts[0].textAlign, TextAlign.left);
      expect(texts[1].textAlign, TextAlign.right);
    });

    // The widget renders a fixed-width `HH:mm` clock. For every valid wall-clock
    // hour/minute the formatted label is exactly 5 chars, splits on a single
    // ':', round-trips back to the same numbers, and stays zero-padded. The
    // generators span the full clock domain [00:00..23:59] (the exact input
    // space the format covers), so this exercises padding on every combination a
    // real message could carry.
    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(0, 24),
      glados.IntAnys(glados.any).intInRange(0, 60),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'formatted clock is well-formed HH:mm for any wall-clock time',
      (
        hour,
        minute,
      ) {
        final ts = DateTime(2024, 3, 15, hour, minute);
        final label = _formatTime(ts);

        expect(label.length, 5, reason: 'label "$label" is not 5 chars');
        expect(label[2], ':', reason: 'separator missing in "$label"');

        final parts = label.split(':');
        expect(parts.length, 2);
        expect(
          parts[0].length,
          2,
          reason: 'hour field not zero-padded: "$label"',
        );
        expect(
          parts[1].length,
          2,
          reason: 'min field not zero-padded: "$label"',
        );

        final parsedHour = int.parse(parts[0]);
        final parsedMinute = int.parse(parts[1]);
        expect(parsedHour, hour);
        expect(parsedMinute, minute);
        expect(
          parsedHour,
          inInclusiveRange(0, 23),
          reason: 'hour out of range',
        );
        expect(
          parsedMinute,
          inInclusiveRange(0, 59),
          reason: 'min out of range',
        );
      },
      tags: 'glados',
    );
  });
}
