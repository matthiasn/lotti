import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_display.dart';

void main() {
  group('CategoryIconDisplay', () {
    late CategoryDefinition testCategory;

    setUp(() {
      testCategory = CategoryDefinition(
        id: 'test-id',
        name: 'Test Category',
        color: '#FF0000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
      );
    });

    testWidgets('should display icon when category has an icon',
        (tester) async {
      final categoryWithIcon =
          testCategory.copyWith(icon: CategoryIcon.fitness);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryIconDisplay(category: categoryWithIcon),
          ),
        ),
      );

      // Should find the fitness icon
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      // Should not find fallback text
      expect(find.text(CategoryIconStrings.fallbackCharacter), findsNothing);
    });

    testWidgets('should display first letter when category has no icon',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryIconDisplay(category: testCategory),
          ),
        ),
      );

      // Should find the first letter 'T'
      expect(find.text('T'), findsOneWidget);
      // Should not find any icon
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('should display fallback character for empty category name',
        (tester) async {
      final emptyNameCategory = testCategory.copyWith(name: '');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryIconDisplay(category: emptyNameCategory),
          ),
        ),
      );

      // Should find the fallback character
      expect(find.text(CategoryIconStrings.fallbackCharacter), findsOneWidget);
    });

    testWidgets('should respect custom size parameter', (tester) async {
      const customSize = 64.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryIconDisplay(
              category: testCategory,
              size: customSize,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.minWidth, equals(customSize));
      expect(container.constraints?.minHeight, equals(customSize));
    });

    testWidgets('should show border by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryIconDisplay(category: testCategory),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('should hide border when showBorder is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryIconDisplay(
              category: testCategory,
              showBorder: false,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
    });

    testWidgets('should use category color for border and text/icon',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryIconDisplay(category: testCategory),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      // Border should use the category color (red in this case)
      expect(border.top.color.r, equals(1.0));
      expect(border.top.color.g, equals(0.0));
      expect(border.top.color.b, equals(0.0));

      final text = tester.widget<Text>(find.text('T'));
      final textStyle = text.style!;

      // Text color should also use the category color
      expect(textStyle.color!.r, equals(1.0));
      expect(textStyle.color!.g, equals(0.0));
      expect(textStyle.color!.b, equals(0.0));
    });

    testWidgets('should handle uppercase conversion correctly', (tester) async {
      final lowercaseCategory = testCategory.copyWith(name: 'test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryIconDisplay(category: lowercaseCategory),
          ),
        ),
      );

      // Should find uppercase 'T'
      expect(find.text('T'), findsOneWidget);
      // Should not find lowercase 't'
      expect(find.text('t'), findsNothing);
    });

    testWidgets('should use correct icon size ratio', (tester) async {
      const customSize = 100.0;
      final categoryWithIcon =
          testCategory.copyWith(icon: CategoryIcon.fitness);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryIconDisplay(
              category: categoryWithIcon,
              size: customSize,
            ),
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.fitness_center));
      const expectedIconSize =
          customSize * CategoryIconConstants.iconSizeMultiplier;
      expect(iconWidget.size, equals(expectedIconSize));
    });

    testWidgets('should use correct text size ratio', (tester) async {
      const customSize = 100.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryIconDisplay(
              category: testCategory,
              size: customSize,
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('T'));
      const expectedFontSize =
          customSize * CategoryIconConstants.textSizeMultiplier;
      expect(text.style!.fontSize, equals(expectedFontSize));
    });
  });
}
