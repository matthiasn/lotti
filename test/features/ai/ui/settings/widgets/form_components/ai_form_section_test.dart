import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/ai_form_section.dart';

void main() {
  group('AiFormSection', () {
    Widget buildTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets('renders title and icon', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const AiFormSection(
            title: 'Test Section',
            icon: Icons.settings,
            children: [
              Text('Child Widget'),
            ],
          ),
        ),
      );

      expect(find.text('Test Section'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const AiFormSection(
            title: 'Test',
            icon: Icons.info,
            description: 'This is a test description',
            children: [
              Text('Child'),
            ],
          ),
        ),
      );

      expect(find.text('This is a test description'), findsOneWidget);
    });

    testWidgets('renders children widgets', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const AiFormSection(
            title: 'Test',
            icon: Icons.list,
            children: [
              Text('Child 1'),
              Text('Child 2'),
              Text('Child 3'),
            ],
          ),
        ),
      );

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);
    });

    testWidgets('has proper gradient background', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const AiFormSection(
            title: 'Test',
            icon: Icons.palette,
            children: [
              Text('Content'),
            ],
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AiFormSection),
          matching: find.byType(Container).first,
        ),
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('has rounded corners and border', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const AiFormSection(
            title: 'Test',
            icon: Icons.rounded_corner,
            children: [
              Text('Content'),
            ],
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AiFormSection),
          matching: find.byType(Container).first,
        ),
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.border, isNotNull);
    });

    testWidgets('lays out header and children correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const AiFormSection(
            title: 'Layout Test',
            icon: Icons.view_column,
            description: 'Testing layout',
            children: [
              SizedBox(height: 50, child: Placeholder()),
              SizedBox(height: 50, child: Placeholder()),
            ],
          ),
        ),
      );

      // Verify Column structure
      final column = find.byType(Column);
      expect(column, findsWidgets);

      // Verify icon is within the header row
      final headerRow = find.ancestor(
        of: find.byIcon(Icons.view_column),
        matching: find.byType(Row),
      );
      expect(headerRow, findsOneWidget);
    });
  });
}
