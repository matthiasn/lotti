import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../../../test_data/test_data.dart';

void main() {
  group('LabelChip Linear-style design', () {
    testWidgets('always renders colored dot regardless of showDot parameter',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LabelChip(label: testLabelDefinition1),
            ),
          ),
        ),
      );

      // Colored dot should always be present
      final dotFinder = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle;
      });
      expect(dotFinder, findsOneWidget);

      // Verify dot dimensions (8x8)
      final dotContainer = tester.widget<Container>(dotFinder);
      expect(dotContainer.constraints?.minWidth, equals(8.0));
      expect(dotContainer.constraints?.minHeight, equals(8.0));
    });

    testWidgets('renders colored dot even when showDot=false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LabelChip(label: testLabelDefinition1, showDot: false),
            ),
          ),
        ),
      );

      // Dot should still be present (showDot parameter ignored in new design)
      final dotFinder = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle;
      });
      expect(dotFinder, findsOneWidget);
    });

    testWidgets('renders label name with theme-based text color',
        (tester) async {
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

      // Text color should be theme-based with alpha 0.85, not hardcoded black
      // Alpha values are 0-255, so 0.85 * 255 = 217
      final alpha = (text.style!.color!.a * 255.0).round() & 0xff;
      expect(alpha, closeTo(217, 2));
      expect(text.style?.fontWeight, equals(FontWeight.w500));
      expect(text.style?.letterSpacing, equals(0.1));
    });

    testWidgets('uses neutral background and border in light theme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: LabelChip(label: testLabelDefinition1),
            ),
          ),
        ),
      );

      // Find the outer container with decoration
      final containerFinder = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.border != null && decoration.borderRadius != null;
      });

      expect(containerFinder, findsOneWidget);
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration! as BoxDecoration;

      // Background should use surfaceContainerHighest with alpha 0.4 (light)
      // Alpha values are 0-255, so 0.4 * 255 = 102
      final bgAlpha = (decoration.color!.a * 255.0).round() & 0xff;
      expect(bgAlpha, closeTo(102, 2));

      // Border should use outline with alpha 0.2 (light)
      // Alpha values are 0-255, so 0.2 * 255 = 51
      final border = decoration.border! as Border;
      final borderAlpha = (border.top.color.a * 255.0).round() & 0xff;
      expect(borderAlpha, closeTo(51, 2));
      expect(border.top.width, equals(1.0));
    });

    testWidgets('uses neutral background and border in dark theme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: LabelChip(label: testLabelDefinition1),
            ),
          ),
        ),
      );

      // Find the outer container with decoration
      final containerFinder = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.border != null && decoration.borderRadius != null;
      });

      expect(containerFinder, findsOneWidget);
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration! as BoxDecoration;

      // Background should use surfaceContainerHighest with alpha 0.3 (dark)
      // Alpha values are 0-255, so 0.3 * 255 = 77
      final bgAlpha = (decoration.color!.a * 255.0).round() & 0xff;
      expect(bgAlpha, closeTo(77, 2));

      // Border should use outline with alpha 0.25 (dark)
      // Alpha values are 0-255, so 0.25 * 255 = 64
      final border = decoration.border! as Border;
      final borderAlpha = (border.top.color.a * 255.0).round() & 0xff;
      expect(borderAlpha, closeTo(64, 2));
    });

    testWidgets('dot color matches label color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LabelChip(label: testLabelDefinition1),
            ),
          ),
        ),
      );

      // Find the dot container
      final dotFinder = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle;
      });

      final dotContainer = tester.widget<Container>(dotFinder);
      final dotDecoration = dotContainer.decoration! as BoxDecoration;

      // Dot should be solid color (not gradient) matching label color
      expect(dotDecoration.color, isNotNull);
      expect(dotDecoration.gradient, isNull);
      // testLabelDefinition1 has color '#FF0000' (red channel = 255)
      final red = (dotDecoration.color!.r * 255.0).round() & 0xff;
      final green = (dotDecoration.color!.g * 255.0).round() & 0xff;
      final blue = (dotDecoration.color!.b * 255.0).round() & 0xff;
      expect(red, equals(255));
      expect(green, equals(0));
      expect(blue, equals(0));
    });

    testWidgets('tooltip shows description when present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LabelChip(label: testLabelDefinition1),
            ),
          ),
        ),
      );

      // testLabelDefinition1 has description
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);

      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(
        tooltip.message,
        equals(testLabelDefinition1.description),
      );
    });

    testWidgets('tooltip shows label name when description is empty',
        (tester) async {
      // testLabelDefinition2 has no description
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LabelChip(label: testLabelDefinition2),
            ),
          ),
        ),
      );

      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);

      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltip.message, equals(testLabelDefinition2.name));
    });

    testWidgets('handles long label names with ellipsis', (tester) async {
      final longLabel = LabelDefinition(
        id: 'label-long',
        name: 'Very Long Label Name That Should Be Truncated With Ellipsis',
        color: '#00FF00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: const VectorClock(<String, int>{}),
        private: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              child: LabelChip(label: longLabel),
            ),
          ),
        ),
      );

      final textFinder = find.text(longLabel.name);
      expect(textFinder, findsOneWidget);

      final text = tester.widget<Text>(textFinder);
      expect(text.maxLines, equals(1));
      expect(text.overflow, equals(TextOverflow.ellipsis));
    });

    testWidgets('handles invalid color with fallback', (tester) async {
      final invalidColorLabel = LabelDefinition(
        id: 'label-invalid',
        name: 'Invalid Color',
        color: 'invalid-hex',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: const VectorClock(<String, int>{}),
        private: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LabelChip(label: invalidColorLabel),
            ),
          ),
        ),
      );

      // Should not crash and should render with fallback color (blue)
      expect(find.text(invalidColorLabel.name), findsOneWidget);

      final dotFinder = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle;
      });
      expect(dotFinder, findsOneWidget);

      final dotContainer = tester.widget<Container>(dotFinder);
      final dotDecoration = dotContainer.decoration! as BoxDecoration;
      // Fallback color is Colors.blue (blue channel varies by theme)
      final blue = (dotDecoration.color!.b * 255.0).round() & 0xff;
      expect(blue, greaterThan(200));
    });

    testWidgets('has proper semantic labels for accessibility', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LabelChip(label: testLabelDefinition1),
            ),
          ),
        ),
      );

      // Find the Semantics widget with our specific label
      final semanticsFinder = find.byWidgetPredicate((widget) {
        if (widget is! Semantics) return false;
        final properties = widget.properties;
        return properties.label == 'Label ${testLabelDefinition1.name}';
      });

      expect(semanticsFinder, findsOneWidget);
    });
  });
}
