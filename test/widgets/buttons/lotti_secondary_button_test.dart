import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';

void main() {
  group('LottiSecondaryButton', () {
    testWidgets('renders label and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiSecondaryButton(
              label: 'Test',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Test'), findsOneWidget);
      await tester.tap(find.byType(LottiSecondaryButton));
      expect(tapped, isTrue);
    });

    testWidgets('renders icon if provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiSecondaryButton(
              label: 'With Icon',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('With Icon'), findsOneWidget);
    });

    testWidgets('is disabled when enabled is false', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiSecondaryButton(
              label: 'Disabled',
              onPressed: () => tapped = true,
              enabled: false,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(LottiSecondaryButton));
      expect(tapped, isFalse);
    });

    testWidgets('is full width when fullWidth is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: LottiSecondaryButton(
                label: 'Full Width',
                onPressed: () {},
                fullWidth: true,
              ),
            ),
          ),
        ),
      );
      final buttonFinder = find.byType(LottiSecondaryButton);
      final box = tester.renderObject(buttonFinder) as RenderBox;
      expect(box.size.width, 300);
    });
  });
}
