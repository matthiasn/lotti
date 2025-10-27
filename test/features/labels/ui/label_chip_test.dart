import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';

import '../../../test_data/test_data.dart';

void main() {
  testWidgets('renders label name with contrast (no dot)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LabelChip(label: testLabelDefinition1),
          ),
        ),
      ),
    );

    expect(find.text(testLabelDefinition1.name), findsOneWidget);
    final text = tester.widget<Text>(find.text(testLabelDefinition1.name));
    expect(text.style?.color, equals(Colors.black));

    // No circular color dot is rendered in presentation anymore
    final dotFinder = find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
    });
    expect(dotFinder, findsNothing);
  });

  testWidgets('does not render dot and keeps spacing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LabelChip(label: testLabelDefinition1),
          ),
        ),
      ),
    );

    expect(find.text(testLabelDefinition1.name), findsOneWidget);

    // No circular dot decoration present
    final dotFinder = find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
    });
    expect(dotFinder, findsNothing);
  });
}
