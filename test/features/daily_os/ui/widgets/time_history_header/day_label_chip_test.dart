import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/day_label_chip.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpChip(WidgetTester tester, {required String label}) {
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Center(child: DayLabelChip(label: label)),
      ),
    );
  }

  group('DayLabelChip', () {
    testWidgets('renders the label inside a rounded, tinted pill', (
      tester,
    ) async {
      await pumpChip(tester, label: 'Deep work');

      expect(find.text('Deep work'), findsOneWidget);

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Deep work'),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.color, isNotNull);
      // Half-transparent primaryContainer tint.
      expect(decoration.color!.a, closeTo(0.5, 0.01));

      final text = tester.widget<Text>(find.text('Deep work'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('clamps long labels to maxWidth and ellipsizes', (
      tester,
    ) async {
      const longLabel = 'A very long day intent label that cannot possibly fit';
      await pumpChip(tester, label: longLabel);

      expect(
        tester.getSize(find.byType(DayLabelChip)).width,
        DayLabelChip.maxWidth,
      );
      // The single-line ellipsized text never exceeds the chip bounds.
      expect(tester.takeException(), isNull);
    });
  });
}
