import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';

import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModernStatusChip Tests', () {
    testWidgets('label is rendered correctly', (tester) async {
      const testLabel = 'In Progress';
      const testColor = Colors.blue;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testLabel), findsOneWidget);
    });

    testWidgets('color is applied to background, border, and text',
        (tester) async {
      const testLabel = 'Done';
      const testColor = Colors.green;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
          ),
          theme: ThemeData.light(),
        ),
      );

      await tester.pumpAndSettle();

      // Check container decoration
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;

      // Background should have color with alpha
      expect(decoration.color,
          testColor.withValues(alpha: AppTheme.alphaPrimaryContainerLight));

      // Border should have color with alpha
      expect((decoration.border! as Border).top.color,
          testColor.withValues(alpha: AppTheme.alphaStatusIndicatorBorder));

      // Text should have color with alpha
      final text = tester.widget<Text>(find.text(testLabel));
      expect(text.style?.color, testColor.withValues(alpha: 0.8));
    });

    testWidgets('icon is displayed when provided', (tester) async {
      const testLabel = 'Blocked';
      const testColor = Colors.red;
      const testIcon = Icons.block;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
            icon: testIcon,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(testIcon), findsOneWidget);
      expect(find.text(testLabel), findsOneWidget);

      // Check icon color
      final icon = tester.widget<Icon>(find.byIcon(testIcon));
      expect(
          icon.color, testColor.withValues(alpha: AppTheme.alphaPrimaryIcon));
    });

    testWidgets('no icon space when icon is null', (tester) async {
      const testLabel = 'Open';
      const testColor = Colors.orange;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Icon), findsNothing);

      // Check that row only contains text
      final row = tester.widget<Row>(find.byType(Row));
      expect(row.children.length, 1);
      expect(row.children.first, isA<Text>());
    });

    testWidgets('dark mode adjusts alpha values correctly', (tester) async {
      const testLabel = 'In Progress';
      const testColor = Colors.blue;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
          ),
          theme: ThemeData.dark(),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;

      // Dark mode should use different alpha
      expect(decoration.color,
          testColor.withValues(alpha: AppTheme.alphaPrimaryContainerDark));

      // Text alpha should be different in dark mode
      final text = tester.widget<Text>(find.text(testLabel));
      expect(text.style?.color, testColor.withValues(alpha: 0.9));
    });

    testWidgets('light mode adjusts alpha values correctly', (tester) async {
      const testLabel = 'Open';
      const testColor = Colors.orange;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
          ),
          theme: ThemeData.light(),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color,
          testColor.withValues(alpha: AppTheme.alphaPrimaryContainerLight));

      final text = tester.widget<Text>(find.text(testLabel));
      expect(text.style?.color, testColor.withValues(alpha: 0.8));
    });

    testWidgets('custom isDark parameter overrides theme', (tester) async {
      const testLabel = 'Done';
      const testColor = Colors.green;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
            isDark: true, // Force dark mode behavior
          ),
          theme: ThemeData.light(), // But use light theme
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;

      // Should use dark mode alpha despite light theme
      expect(decoration.color,
          testColor.withValues(alpha: AppTheme.alphaPrimaryContainerDark));
    });


    testWidgets('normal mode uses standard sizes', (tester) async {
      const testLabel = 'On Hold';
      const testColor = Colors.red;
      const testIcon = Icons.pause;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
            icon: testIcon,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check padding
      final container = tester.widget<Container>(find.byType(Container));
      expect(
          container.padding,
          const EdgeInsets.symmetric(
            horizontal: AppTheme.statusIndicatorPaddingHorizontal,
            vertical: AppTheme.statusIndicatorPaddingVertical,
          ));

      // Check border radius
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius,
          BorderRadius.circular(AppTheme.statusIndicatorBorderRadius));

      // Check icon size
      final icon = tester.widget<Icon>(find.byIcon(testIcon));
      expect(icon.size, AppTheme.statusIndicatorIconSize);

      // Check text size
      final text = tester.widget<Text>(find.text(testLabel));
      expect(text.style?.fontSize, AppTheme.statusIndicatorFontSize);
    });

    testWidgets('border width is correct', (tester) async {
      const testLabel = 'Rejected';
      const testColor = Colors.red;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      expect(border.top.width, AppTheme.statusIndicatorBorderWidth);
    });

    testWidgets('text has correct font weight', (tester) async {
      const testLabel = 'In Progress';
      const testColor = Colors.blue;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text(testLabel));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('row uses minimum size', (tester) async {
      const testLabel = 'A';
      const testColor = Colors.green;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.mainAxisSize, MainAxisSize.min);
    });

    testWidgets('spacing between icon and text is correct', (tester) async {
      const testLabel = 'Done';
      const testColor = Colors.green;
      const testIcon = Icons.check_circle;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernStatusChip(
            label: testLabel,
            color: testColor,
            icon: testIcon,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.children.length, 3); // Icon, SizedBox, Text
      expect(row.children[1], isA<SizedBox>());

      final spacer = row.children[1] as SizedBox;
      expect(spacer.width, 4);
    });
  });
}
