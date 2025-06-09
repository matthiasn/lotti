import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/dismiss_background.dart';

void main() {
  group('DismissBackground', () {
    Widget createWidget() {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 100,
              child: DismissBackground(),
            ),
          ),
        ),
      );
    }

    testWidgets('displays delete icon and text', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('has gradient background', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());

      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors.length, 3);
      expect(gradient.stops, [0.0, 0.7, 1.0]);
    });

    testWidgets('has rounded corners and shadow', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.length, 1);
      expect(decoration.boxShadow!.first.blurRadius, 8);
      expect(decoration.boxShadow!.first.offset, const Offset(0, 2));
    });

    testWidgets('aligns content to the right', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final row = tester.widget<Row>(
        find.byType(Row),
      );
      expect(row.mainAxisAlignment, MainAxisAlignment.end);
    });

    testWidgets('centers delete indicator vertically',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final column = tester.widget<Column>(
        find.byType(Column),
      );
      expect(column.mainAxisAlignment, MainAxisAlignment.center);
    });

    testWidgets('delete icon has container with decoration',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Find the container that directly contains the icon
      final containers = find.ancestor(
        of: find.byIcon(Icons.delete_forever_rounded),
        matching: find.byType(Container),
      );

      // Find the container with padding
      Container? iconContainer;
      for (var i = 0; i < containers.evaluate().length; i++) {
        final container = tester.widget<Container>(containers.at(i));
        if (container.padding != null) {
          iconContainer = container;
          break;
        }
      }

      expect(iconContainer, isNotNull);

      expect(iconContainer!.decoration, isA<BoxDecoration>());
      final decoration = iconContainer.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(iconContainer.padding, const EdgeInsets.all(8));
    });

    testWidgets('has proper spacing between icon and text',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Find the specific SizedBox that's between the icon container and text
      final sizedBoxes = find.descendant(
        of: find.byType(Column),
        matching: find.byWidgetPredicate((widget) {
          return widget is SizedBox && widget.height == 4;
        }),
      );

      expect(sizedBoxes, findsOneWidget);
    });

    testWidgets('has horizontal padding', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Find all Padding widgets and check if any has the expected padding
      final paddings = find.descendant(
        of: find.byType(DismissBackground),
        matching: find.byType(Padding),
      );

      var foundExpectedPadding = false;
      for (final paddingFinder in paddings.evaluate()) {
        final padding = paddingFinder.widget as Padding;
        if (padding.padding == const EdgeInsets.symmetric(horizontal: 24)) {
          foundExpectedPadding = true;
          break;
        }
      }

      expect(foundExpectedPadding, isTrue);
    });

    testWidgets('delete text has proper font weight',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final text = tester.widget<Text>(find.text('Delete'));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('icon size is correct', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.delete_forever_rounded),
      );
      expect(icon.size, 24);
    });

    testWidgets('has vertical margin', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect(
        container.margin,
        const EdgeInsets.symmetric(vertical: 2),
      );
    });
  });
}
