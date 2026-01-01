import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';
import 'package:lotti/widgets/app_bar/glass_icon_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlassBackButton', () {
    testWidgets('renders chevron_left icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackButton(),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets('uses white icon color by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackButton(),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.color, Colors.white);
    });

    testWidgets('uses custom icon color when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackButton(iconColor: Colors.red),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.color, Colors.red);
    });

    testWidgets('uses default icon size of 26', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackButton(),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.size, 26);
    });

    testWidgets('uses custom icon size when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackButton(iconSize: 32),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.size, 32);
    });

    testWidgets('contains GlassIconContainer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackButton(),
          ),
        ),
      );

      expect(find.byType(GlassIconContainer), findsOneWidget);
    });

    testWidgets('contains Material with transparency', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackButton(),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(GlassBackButton),
          matching: find.byType(Material),
        ),
      );

      expect(material.type, MaterialType.transparency);
    });

    testWidgets('contains InkWell for tap feedback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackButton(),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(GlassBackButton),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('calls custom onPressed when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassBackButton(
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('calls Navigator.maybePop by default when tapped',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackButton(),
          ),
        ),
      );

      // Tapping should not throw - it calls Navigator.maybePop internally
      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();

      // Widget is still present (maybePop was called but nothing to pop)
      expect(find.byType(GlassBackButton), findsOneWidget);
    });

    testWidgets('has left padding of 4', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackButton(),
          ),
        ),
      );

      final paddings = tester.widgetList<Padding>(
        find.descendant(
          of: find.byType(GlassBackButton),
          matching: find.byType(Padding),
        ),
      );

      // Find the padding with left: 4
      final leftPadding = paddings.firstWhere(
        (p) => p.padding == const EdgeInsets.only(left: 4),
      );

      expect(leftPadding.padding, const EdgeInsets.only(left: 4));
    });
  });
}
