import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';

import '../../../test_data/test_data.dart';

void main() {
  testWidgets('renders label name and avatar color', (tester) async {
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
    final chip = tester.widget<Chip>(find.byType(Chip));
    expect(chip.label, isA<Text>());
  });
}
