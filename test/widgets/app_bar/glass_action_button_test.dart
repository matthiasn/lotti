import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_icon_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlassActionButton', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassActionButton(
              onTap: () {},
              child: const Icon(Icons.more_horiz),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('calls onTap when pressed', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassActionButton(
              onTap: () => tapped = true,
              child: const Icon(Icons.settings),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GlassActionButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('contains GlassIconContainer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassActionButton(
              onTap: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      expect(find.byType(GlassIconContainer), findsOneWidget);
    });

    testWidgets('uses default size of 40', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassActionButton(
              onTap: () {},
              child: const Icon(Icons.star),
            ),
          ),
        ),
      );

      final glassContainer = tester.widget<GlassIconContainer>(
        find.byType(GlassIconContainer),
      );

      expect(glassContainer.size, 40);
    });

    testWidgets('uses custom size when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassActionButton(
              onTap: () {},
              size: 50,
              child: const Icon(Icons.favorite),
            ),
          ),
        ),
      );

      final glassContainer = tester.widget<GlassIconContainer>(
        find.byType(GlassIconContainer),
      );

      expect(glassContainer.size, 50);
    });

    testWidgets('contains Material with transparency', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassActionButton(
              onTap: () {},
              child: const Icon(Icons.menu),
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(GlassActionButton),
          matching: find.byType(Material),
        ),
      );

      expect(material.type, MaterialType.transparency);
    });

    testWidgets('contains InkWell for tap feedback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassActionButton(
              onTap: () {},
              child: const Icon(Icons.edit),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(GlassActionButton),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Material has rounded border radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassActionButton(
              onTap: () {},
              child: const Icon(Icons.close),
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(GlassActionButton),
          matching: find.byType(Material),
        ),
      );

      expect(material.borderRadius, BorderRadius.circular(20));
    });

    testWidgets('renders any widget as child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassActionButton(
              onTap: () {},
              child: const Text('A'),
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });
  });
}
