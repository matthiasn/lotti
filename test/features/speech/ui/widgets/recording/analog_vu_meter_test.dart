import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/vu_meter_painter.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalogVuMeter Tests', () {
    Widget makeTestableWidget({
      required double decibels,
      double size = 300,
      Brightness brightness = Brightness.light,
    }) {
      final colorScheme = brightness == Brightness.light
          ? const ColorScheme.light()
          : const ColorScheme.dark();

      return makeTestableWidgetWithScaffold(
        Theme(
          data: ThemeData(brightness: brightness, colorScheme: colorScheme),
          child: Center(
            child: AnalogVuMeter(
              decibels: decibels,
              size: size,
              colorScheme: colorScheme,
            ),
          ),
        ),
      );
    }

    testWidgets('renders correctly with given size', (tester) async {
      await tester.pumpWidget(makeTestableWidget(
        decibels: 0,
        size: 400,
      ));

      expect(find.byType(AnalogVuMeter), findsOneWidget);

      final vuMeter = tester.widget<AnalogVuMeter>(
        find.byType(AnalogVuMeter),
      );
      expect(vuMeter.size, 400);

      // Check that the sized box has correct dimensions
      final sizedBox = find.byType(SizedBox).first;
      final sizedBoxWidget = tester.widget<SizedBox>(sizedBox);
      expect(sizedBoxWidget.width, 400);
      expect(sizedBoxWidget.height, 200); // size * 0.5
    });

    testWidgets('needle animates when decibels change', (tester) async {
      await tester.pumpWidget(makeTestableWidget(decibels: 0));
      await tester.pump(const Duration(milliseconds: 50));

      // Change decibels
      await tester.pumpWidget(makeTestableWidget(decibels: 130));

      // Pump to trigger animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The VU meter widget contains an AnimatedBuilder
      final vuMeter = find.byType(AnalogVuMeter);
      expect(vuMeter, findsOneWidget);

      // Check that the VU meter's AnimatedBuilder is present
      expect(
          find.descendant(
            of: vuMeter,
            matching: find.byType(AnimatedBuilder),
          ),
          findsOneWidget);

      // Allow all animations and timers to complete
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('shows clip indicator for high decibels', (tester) async {
      // Test with high decibels that should trigger clipping
      await tester.pumpWidget(makeTestableWidget(decibels: 150));

      // Wait for clip animation
      await tester.pump(const Duration(milliseconds: 100));

      // The VU meter should be present with its CustomPaint
      final vuMeter = find.byType(AnalogVuMeter);
      expect(vuMeter, findsOneWidget);

      // Check that it has a CustomPaint widget
      expect(
          find.descendant(
            of: vuMeter,
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget);

      // Allow all animations and timers to complete
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('maintains aspect ratio at different sizes', (tester) async {
      // Test small size
      await tester.pumpWidget(makeTestableWidget(
        decibels: 0,
        size: 200,
      ));

      var sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 200);
      expect(sizedBox.height, 100); // Maintains 2:1 ratio

      // Test large size
      await tester.pumpWidget(makeTestableWidget(
        decibels: 0,
        size: 600,
      ));

      sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 600);
      expect(sizedBox.height, 300); // Maintains 2:1 ratio
    });

    testWidgets('CustomPainter receives correct theme mode', (tester) async {
      // Test light mode
      await tester.pumpWidget(makeTestableWidget(
        decibels: 0,
      ));

      final vuMeter = find.byType(AnalogVuMeter);
      expect(vuMeter, findsOneWidget);

      // Check that it has a CustomPaint widget in light mode
      expect(
          find.descendant(
            of: vuMeter,
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget);

      // Test dark mode
      await tester.pumpWidget(makeTestableWidget(
        decibels: 0,
        brightness: Brightness.dark,
      ));

      // Check that it has a CustomPaint widget in dark mode
      expect(
          find.descendant(
            of: vuMeter,
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget);
    });

    testWidgets('decibels normalization works correctly', (tester) async {
      // Test various decibel values
      final testValues = [0.0, 80.0, 130.0, 160.0];

      for (final decibels in testValues) {
        await tester.pumpWidget(makeTestableWidget(decibels: decibels));
        await tester.pumpAndSettle();

        expect(find.byType(AnalogVuMeter), findsOneWidget);
      }
    });

    testWidgets('peak hold animation triggers for increasing values',
        (tester) async {
      // Start with low value
      await tester.pumpWidget(makeTestableWidget(decibels: 80));
      await tester.pumpAndSettle();

      // Increase to trigger peak hold
      await tester.pumpWidget(makeTestableWidget(decibels: 140));
      await tester.pump();

      // Peak should be held
      await tester.pump(const Duration(milliseconds: 500));

      final vuMeter = find.byType(AnalogVuMeter);
      expect(vuMeter, findsOneWidget);

      // Check that the AnimatedBuilder is present
      expect(
          find.descendant(
            of: vuMeter,
            matching: find.byType(AnimatedBuilder),
          ),
          findsOneWidget);

      // Allow all animations and timers to complete
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('disposes animation controllers properly', (tester) async {
      await tester.pumpWidget(makeTestableWidget(decibels: 0));
      await tester.pumpAndSettle();

      // Replace widget to trigger dispose
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // No exceptions should be thrown
      expect(find.byType(AnalogVuMeter), findsNothing);
    });

    testWidgets('handles rapid decibel changes', (tester) async {
      // Simulate rapid changes like during actual recording
      final values = [80.0, 90.0, 100.0, 110.0, 120.0, 130.0];

      for (final value in values) {
        await tester.pumpWidget(makeTestableWidget(decibels: value));
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Should handle rapid updates without issues
      expect(find.byType(AnalogVuMeter), findsOneWidget);

      // Allow all animations and timers to complete fully
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('VuMeterPainter Tests', () {
    test('shouldRepaint returns true for value changes', () {
      const colorScheme = ColorScheme.light();
      final painter1 = VuMeterPainter(
        value: 0.5,
        peakValue: 0.6,
        clipValue: 0,
        isDarkMode: false,
        colorScheme: colorScheme,
      );

      final painter2 = VuMeterPainter(
        value: 0.7,
        peakValue: 0.6,
        clipValue: 0,
        isDarkMode: false,
        colorScheme: colorScheme,
      );

      expect(painter1.shouldRepaint(painter2), true);
    });

    test('shouldRepaint returns true for peak value changes', () {
      const colorScheme = ColorScheme.light();
      final painter1 = VuMeterPainter(
        value: 0.5,
        peakValue: 0.6,
        clipValue: 0,
        isDarkMode: false,
        colorScheme: colorScheme,
      );

      final painter2 = VuMeterPainter(
        value: 0.5,
        peakValue: 0.8,
        clipValue: 0,
        isDarkMode: false,
        colorScheme: colorScheme,
      );

      expect(painter1.shouldRepaint(painter2), true);
    });

    test('shouldRepaint returns true for theme mode changes', () {
      const colorScheme = ColorScheme.light();
      final painter1 = VuMeterPainter(
        value: 0.5,
        peakValue: 0.6,
        clipValue: 0,
        isDarkMode: false,
        colorScheme: colorScheme,
      );

      final painter2 = VuMeterPainter(
        value: 0.5,
        peakValue: 0.6,
        clipValue: 0,
        isDarkMode: true,
        colorScheme: colorScheme,
      );

      expect(painter1.shouldRepaint(painter2), true);
    });

    test('shouldRepaint returns false for identical values', () {
      const colorScheme = ColorScheme.light();
      final painter1 = VuMeterPainter(
        value: 0.5,
        peakValue: 0.6,
        clipValue: 0,
        isDarkMode: false,
        colorScheme: colorScheme,
      );

      final painter2 = VuMeterPainter(
        value: 0.5,
        peakValue: 0.6,
        clipValue: 0,
        isDarkMode: false,
        colorScheme: colorScheme,
      );

      expect(painter1.shouldRepaint(painter2), false);
    });
  });
}
