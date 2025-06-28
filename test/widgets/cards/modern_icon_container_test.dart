import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModernIconContainer Tests', () {
    testWidgets('renders icon with default colors', (tester) async {
      const testIcon = Icons.star;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernIconContainer(
            icon: testIcon,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the icon
      expect(find.byIcon(testIcon), findsOneWidget);

      // Check icon properties
      final icon = tester.widget<Icon>(find.byIcon(testIcon));
      expect(icon.size, AppTheme.iconSize);
      expect(icon.color, isNotNull);
    });

    testWidgets('custom icon color is applied', (tester) async {
      const testIcon = Icons.star;
      const customColor = Colors.red;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernIconContainer(
            icon: testIcon,
            iconColor: customColor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(testIcon));
      expect(icon.color, customColor);
    });

    testWidgets('child widget is rendered instead of icon', (tester) async {
      const testText = 'A';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernIconContainer(
            child: Text(testText),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testText), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('assert fails when neither icon nor child provided',
        (tester) async {
      expect(
        ModernIconContainer.new,
        throwsAssertionError,
      );
    });

    testWidgets('compact mode uses smaller size', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernIconContainer(
            icon: Icons.star,
            isCompact: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check container size
      final container = tester.widget<Container>(find.byType(Container));
      expect(
          container.constraints?.maxWidth, AppTheme.iconContainerSizeCompact);
      expect(
          container.constraints?.maxHeight, AppTheme.iconContainerSizeCompact);

      // Check icon size
      final icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.size, AppTheme.iconSizeCompact);
    });

    testWidgets('normal mode uses standard size', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernIconContainer(
            icon: Icons.star,
            // isCompact defaults to false
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check container size
      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth, AppTheme.iconContainerSize);
      expect(container.constraints?.maxHeight, AppTheme.iconContainerSize);

      // Check icon size
      final icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.size, AppTheme.iconSize);
    });

    testWidgets('custom gradient overrides default', (tester) async {
      const customGradient = LinearGradient(
        colors: [Colors.red, Colors.blue],
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernIconContainer(
            icon: Icons.star,
            gradient: customGradient,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, customGradient);
    });

    testWidgets('custom border color overrides default', (tester) async {
      const customBorderColor = Colors.green;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernIconContainer(
            icon: Icons.star,
            borderColor: customBorderColor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect((decoration.border! as Border).top.color, customBorderColor);
    });

    testWidgets('child widget has correct sizing constraints', (tester) async {
      final testChild = Container(
        color: Colors.red,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernIconContainer(
            child: testChild,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the SizedBox that wraps the child
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, AppTheme.iconSize);
      expect(sizedBox.height, AppTheme.iconSize);
    });

    testWidgets('compact mode child has smaller constraints', (tester) async {
      final testChild = Container(
        color: Colors.red,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernIconContainer(
            isCompact: true,
            child: testChild,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, AppTheme.iconSizeCompact);
      expect(sizedBox.height, AppTheme.iconSizeCompact);
    });

    testWidgets('gradient is applied correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernIconContainer(
            icon: Icons.star,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.gradient, isNotNull);
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('border radius is applied correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernIconContainer(
            icon: Icons.star,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;

      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppTheme.iconContainerBorderRadius),
      );
    });

    testWidgets('icon is centered in container', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernIconContainer(
            icon: Icons.star,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that the container has a Center widget as child
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      // The Container's child should be a Center widget
      expect(container.child, isA<Center>());
    });
  });
}
