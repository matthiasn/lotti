import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';

import '../../widget_test_utils.dart';

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

    group('theming', () {
      testWidgets('label uses primary color and weight when enabled', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            LottiSecondaryButton(label: 'Enabled', onPressed: () {}),
          ),
        );

        final scheme = Theme.of(
          tester.element(find.text('Enabled')),
        ).colorScheme;
        final text = tester.widget<Text>(find.text('Enabled'));
        expect(text.style?.color, scheme.primary);
        expect(text.style?.fontWeight, FontWeight.w600);
        expect(text.style?.fontSize, 16);
      });

      testWidgets('label dims to onSurfaceVariant @0.5 when disabled', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const LottiSecondaryButton(
              label: 'Disabled',
              onPressed: null,
            ),
          ),
        );

        final scheme = Theme.of(
          tester.element(find.text('Disabled')),
        ).colorScheme;
        final text = tester.widget<Text>(find.text('Disabled'));
        expect(
          text.style?.color,
          scheme.onSurfaceVariant.withValues(alpha: 0.5),
        );
      });

      testWidgets('icon shares the label color when provided', (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            LottiSecondaryButton(
              label: 'Icon',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        );

        final scheme = Theme.of(
          tester.element(find.byIcon(Icons.add)),
        ).colorScheme;
        final icon = tester.widget<Icon>(find.byIcon(Icons.add));
        expect(icon.color, scheme.primary);
        expect(icon.size, 20);
      });

      testWidgets('outlined border resolves to primary @0.5 when enabled', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            LottiSecondaryButton(label: 'Border', onPressed: () {}),
          ),
        );

        final scheme = Theme.of(
          tester.element(find.byType(OutlinedButton)),
        ).colorScheme;
        final button = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        final side = button.style?.side?.resolve(<WidgetState>{});
        expect(side?.color, scheme.primary.withValues(alpha: 0.5));
      });

      testWidgets('outlined border dims to primaryContainer @0.2 disabled', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const LottiSecondaryButton(label: 'Border', onPressed: null),
          ),
        );

        final scheme = Theme.of(
          tester.element(find.byType(OutlinedButton)),
        ).colorScheme;
        final button = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        final side = button.style?.side?.resolve(<WidgetState>{});
        expect(
          side?.color,
          scheme.primaryContainer.withValues(alpha: 0.2),
        );
      });

      testWidgets('uses a 12px rounded shape and symmetric padding', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            LottiSecondaryButton(label: 'Shape', onPressed: () {}),
          ),
        );

        final button = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        final shape =
            button.style?.shape?.resolve(<WidgetState>{})
                as RoundedRectangleBorder?;
        expect(
          shape?.borderRadius,
          BorderRadius.circular(12),
        );
        expect(
          button.style?.padding?.resolve(<WidgetState>{}),
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        );
      });
    });
  });
}
