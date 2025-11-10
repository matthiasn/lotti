import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import '../../../test_helper.dart';

void main() {
  testWidgets('TitleTextField calls onTapOutside when not dirty',
      (tester) async {
    var tappedOutside = false;

    await tester.pumpWidget(
      const WidgetTestBench(
        child: SizedBox.shrink(),
      ),
    );

    await tester.pumpWidget(
      WidgetTestBench(
        child: Center(
          child: TitleTextField(
            initialValue: '',
            onSave: (_) {},
            onTapOutside: (_) {
              tappedOutside = true;
            },
          ),
        ),
      ),
    );

    // Focus field, but do not change text so _dirty stays false
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // Tap outside area
    await tester.sendEventToBinding(const PointerDownEvent());
    await tester.pump();

    expect(tappedOutside, isTrue);
  });
}
