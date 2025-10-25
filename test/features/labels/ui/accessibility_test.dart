import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';

import '../../../test_data/test_data.dart';

void main() {
  testWidgets('LabelChip exposes semantics label for screen readers',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LabelChip(label: testLabelDefinition1),
          ),
        ),
      ),
    );

    final semanticsFinder = find.descendant(
      of: find.byType(LabelChip),
      matching: find.byType(Semantics),
    );
    final semanticsNode = tester.getSemantics(semanticsFinder.first);
    expect(
      semanticsNode.label,
      contains('Label ${testLabelDefinition1.name}'),
    );
    handle.dispose();
  });
}
