import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/segmented_button.dart';

void main() {
  group('buttonSegment', () {
    testWidgets('creates a ButtonSegment with correct label and value',
        (WidgetTester tester) async {
      const testValue = 'test_value';
      const testLabel = 'Test Label';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
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
            }),
          ),
        ),
      );

      // Verify that the label text is rendered
      expect(find.text(testLabel), findsOneWidget);

      // Verify the segment has the correct value by inspecting the SegmentedButton
      final segmentedButton = tester.widget<SegmentedButton<String>>(
          find.byType(SegmentedButton<String>));
      expect(segmentedButton.segments.first.value, testValue);
    });
  });
}
