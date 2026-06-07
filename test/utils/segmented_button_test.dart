import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/segmented_button.dart';

void main() {
  group('buttonSegment', () {
    testWidgets('creates a ButtonSegment with correct label and value', (
      WidgetTester tester,
    ) async {
      const testValue = 'test_value';
      const testLabel = 'Test Label';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return SegmentedButton<String>(
                  segments: [
                    buttonSegment(
                      context: context,
                      value: testValue,
                      selected: testValue,
                      label: testLabel,
                    ),
                  ],
                  onSelectionChanged: (Set<String> newSelection) {},
                  selected: const <String>{testValue},
                );
              },
            ),
          ),
        ),
      );

      // Verify that the label text is rendered
      expect(find.text(testLabel), findsOneWidget);

      // Verify the segment has the correct value by inspecting the SegmentedButton
      final segmentedButton = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(segmentedButton.segments.first.value, testValue);
    });

    // -------------------------------------------------------------------------
    // semanticsLabel coverage
    //
    // buttonSegment applies `semanticsLabel ?? label` to the Text widget.
    // The two tests below verify both branches of that expression.
    // -------------------------------------------------------------------------

    testWidgets(
      'uses label as semanticsLabel when semanticsLabel is not provided',
      (WidgetTester tester) async {
        const testValue = 'val';
        const testLabel = 'My Label';
        late ButtonSegment<String> segment;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  segment = buttonSegment(
                    context: context,
                    value: testValue,
                    selected: testValue,
                    label: testLabel,
                    // semanticsLabel omitted — should default to label
                  );
                  return SegmentedButton<String>(
                    segments: [segment],
                    onSelectionChanged: (_) {},
                    selected: const {testValue},
                  );
                },
              ),
            ),
          ),
        );

        // The Text widget inside the label should carry semanticsLabel == label.
        final textWidget = tester.widget<Text>(find.text(testLabel));
        expect(
          textWidget.semanticsLabel,
          testLabel,
          reason:
              'when semanticsLabel is omitted, it should fall back to label',
        );
      },
    );

    testWidgets(
      'uses explicit semanticsLabel when provided',
      (WidgetTester tester) async {
        const testValue = 'val2';
        const testLabel = 'Visible Label';
        const customSemantics = 'Accessible Description';
        late ButtonSegment<String> segment;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  segment = buttonSegment(
                    context: context,
                    value: testValue,
                    selected: testValue,
                    label: testLabel,
                    semanticsLabel: customSemantics,
                  );
                  return SegmentedButton<String>(
                    segments: [segment],
                    onSelectionChanged: (_) {},
                    selected: const {testValue},
                  );
                },
              ),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text(testLabel));
        expect(
          textWidget.semanticsLabel,
          customSemantics,
          reason: 'when semanticsLabel is supplied it must override the label',
        );
        expect(
          segment.value,
          testValue,
          reason: 'segment value must always match the input value',
        );
      },
    );

    testWidgets(
      'value passes through and semanticsLabel defaults to label for the '
      'full input matrix',
      (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        const labels = ['Day', 'Week', 'Month with spaces', '7d', 'Ümläut'];
        const semanticsLabels = [null, 'Show by day', 'Show by week', ''];

        // Exhaustive 5x4 matrix — the whole input space of the contract.
        for (final label in labels) {
          for (final semanticsLabel in semanticsLabels) {
            final segment = buttonSegment<int>(
              context: capturedContext,
              value: 42,
              selected: 42,
              label: label,
              semanticsLabel: semanticsLabel,
            );

            expect(segment.value, 42, reason: '$label / $semanticsLabel');
            final text = segment.label! as Text;
            expect(text.data, label);
            expect(
              text.semanticsLabel,
              semanticsLabel ?? label,
              reason: '$label / $semanticsLabel',
            );
          }
        }
      },
    );
  });
}
