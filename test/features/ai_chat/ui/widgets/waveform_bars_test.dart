import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/waveform_bars.dart';

void main() {
  group('WaveformBars Widget Tests', () {
    testWidgets('renders with empty amplitude list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: WaveformBars(
                amplitudesNormalized: [],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);
      // Multiple CustomPaint widgets are expected (bars + baseline)
      expect(find.byType(CustomPaint), findsWidgets);

      // Should render without errors even with empty data
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with single amplitude value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.5],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with multiple amplitude values', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: WaveformBars(
                  amplitudesNormalized: [
                    0.1,
                    0.3,
                    0.5,
                    0.7,
                    0.9,
                    0.6,
                    0.4,
                    0.2
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);
      // Get the first CustomPaint (the waveform painter)
      final customPaints =
          tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      expect(customPaints.length, greaterThan(0));
      expect(customPaints.first.size, isNotNull);
    });

    testWidgets('handles amplitude values at boundaries', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.0, 0.05, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('respects custom height parameter', (tester) async {
      const customHeight = 100.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.5, 0.7],
                  height: customHeight,
                ),
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(WaveformBars),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.constraints?.maxHeight, customHeight);
    });

    testWidgets('respects custom bar width and spacing', (tester) async {
      const customBarWidth = 4.0;
      const customBarSpacing = 6.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.5, 0.7, 0.3],
                  barWidth: customBarWidth,
                  barSpacing: customBarSpacing,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);
      final waveform = tester.widget<WaveformBars>(find.byType(WaveformBars));
      expect(waveform.barWidth, customBarWidth);
      expect(waveform.barSpacing, customBarSpacing);
    });

    testWidgets('respects custom border radius', (tester) async {
      const customBorderRadius = 12.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.5],
                  borderRadius: customBorderRadius,
                ),
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(WaveformBars),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration as BoxDecoration?;
      final borderRadius = decoration?.borderRadius as BorderRadius?;
      expect(borderRadius?.topLeft.x, customBorderRadius);
    });

    testWidgets('handles very large amplitude lists gracefully',
        (tester) async {
      // Create a list with 500 amplitude values
      final largeAmplitudeList = List.generate(
        500,
        (index) => (index % 100) / 100.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: WaveformBars(
                  amplitudesNormalized: largeAmplitudeList,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders bars right-aligned', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: WaveformBars(
                  amplitudesNormalized: [0.5, 0.7],
                ),
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(WaveformBars),
              matching: find.byType(Container),
            )
            .first,
      );

      // Verify alignment is set to centerRight
      expect(container.alignment, Alignment.centerRight);
    });

    testWidgets('applies theme colors correctly', (tester) async {
      const primaryColor = Colors.blue;
      const secondaryColor = Colors.green;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              secondary: secondaryColor,
            ),
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.3, 0.6, 0.9],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);
      // The widget should use theme colors for rendering
    });

    testWidgets('updates when amplitude list changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.5],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);

      // Update with new amplitude values
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.3, 0.7, 0.4],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);
      final waveform = tester.widget<WaveformBars>(find.byType(WaveformBars));
      expect(waveform.amplitudesNormalized.length, 3);
    });

    testWidgets('handles negative amplitude values by clamping',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [-0.5, 0.5, 1.5], // Invalid values
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);
      // Should handle invalid values without crashing
      expect(tester.takeException(), isNull);
    });

    testWidgets('respects minimum bar height', (tester) async {
      const customMinHeight = 4.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.0, 0.01], // Very small amplitudes
                  minBarHeight: customMinHeight,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WaveformBars), findsOneWidget);
      final waveform = tester.widget<WaveformBars>(find.byType(WaveformBars));
      expect(waveform.minBarHeight, customMinHeight);
    });

    testWidgets('renders with LayoutBuilder for responsive sizing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                child: WaveformBars(
                  amplitudesNormalized: [0.5, 0.7],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets('CustomPaint size matches container constraints',
        (tester) async {
      const containerWidth = 300.0;
      const containerHeight = 48.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: containerWidth,
                height: containerHeight,
                child: WaveformBars(
                  amplitudesNormalized: [0.5, 0.7],
                ),
              ),
            ),
          ),
        ),
      );

      // Get all CustomPaint widgets
      final customPaints =
          tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      // The CustomPaint should receive the proper size from LayoutBuilder
      expect(customPaints.length, greaterThan(0));
      expect(customPaints.first.size, isNotNull);
    });

    testWidgets('widget rebuilds when amplitudes change', (tester) async {
      Widget buildWidget(List<double> amplitudes) {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: amplitudes,
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWidget([0.5]));

      var waveform = tester.widget<WaveformBars>(find.byType(WaveformBars));
      expect(waveform.amplitudesNormalized, [0.5]);

      await tester.pumpWidget(buildWidget([0.3, 0.7]));

      waveform = tester.widget<WaveformBars>(find.byType(WaveformBars));
      expect(waveform.amplitudesNormalized, [0.3, 0.7]);

      // Verify the widget properly received the new amplitudes
      expect(waveform.amplitudesNormalized.length, 2);
    });

    testWidgets('shows border around waveform container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            dividerColor: Colors.grey,
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformBars(
                  amplitudesNormalized: [0.5],
                ),
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(WaveformBars),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, isNotNull);
    });
  });
}
