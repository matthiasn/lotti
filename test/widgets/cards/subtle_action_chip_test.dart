import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/cards/subtle_action_chip.dart';

import '../../test_helper.dart';

void main() {
  group('SubtleActionChip', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SubtleActionChip(label: 'Test Label'),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SubtleActionChip(
            label: 'With Icon',
            icon: Icons.calendar_today,
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.text('With Icon'), findsOneWidget);
    });

    testWidgets('renders child widget instead of label', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SubtleActionChip(
            child: Text('Custom Child'),
          ),
        ),
      );

      expect(find.text('Custom Child'), findsOneWidget);
    });

    testWidgets('uses urgent color when isUrgent is true', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SubtleActionChip(
            label: 'Urgent',
            icon: Icons.warning,
            isUrgent: true,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.warning));
      // Urgent state should apply error-based color (with alpha)
      expect(icon.color, isNotNull);
    });

    testWidgets('uses custom urgentColor when provided', (tester) async {
      const customColor = Colors.purple;

      await tester.pumpWidget(
        const WidgetTestBench(
          child: SubtleActionChip(
            label: 'Custom Urgent',
            icon: Icons.warning,
            isUrgent: true,
            urgentColor: customColor,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.warning));
      // Custom urgent color should be used (with alpha applied)
      expect(icon.color?.r, customColor.r);
      expect(icon.color?.g, customColor.g);
      expect(icon.color?.b, customColor.b);
    });

    testWidgets('renders without icon when only label provided',
        (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SubtleActionChip(label: 'Label Only'),
        ),
      );

      expect(find.text('Label Only'), findsOneWidget);
      // No icon finder should match
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('has correct border radius', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SubtleActionChip(label: 'Styled'),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(SubtleActionChip),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('has border', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SubtleActionChip(label: 'Bordered'),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(SubtleActionChip),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        const DarkWidgetTestBench(
          child: SubtleActionChip(
            label: 'Dark Mode',
            icon: Icons.dark_mode,
          ),
        ),
      );

      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('Row has mainAxisSize.min for proper sizing', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SubtleActionChip(
            label: 'Compact',
            icon: Icons.check,
          ),
        ),
      );

      final row = tester.widget<Row>(
        find.descendant(
          of: find.byType(SubtleActionChip),
          matching: find.byType(Row),
        ),
      );

      expect(row.mainAxisSize, MainAxisSize.min);
    });
  });
}
