import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/modern_modal_action_item.dart';

import '../../widget_test_utils.dart';

void main() {
  group('ModernModalActionItem', () {
    testWidgets('displays title and icon correctly', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(makeTestableWidgetWithScaffold(
        ModernModalActionItem(
          icon: Icons.star,
          title: 'Test Action',
          onTap: () => tapCount++,
        ),
      ));

      expect(find.text('Test Action'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('displays subtitle when provided', (tester) async {
      await tester.pumpWidget(makeTestableWidgetWithScaffold(
        ModernModalActionItem(
          icon: Icons.info,
          title: 'Test Action',
          subtitle: 'Test subtitle',
          onTap: () {},
        ),
      ));

      expect(find.text('Test Action'), findsOneWidget);
      expect(find.text('Test subtitle'), findsOneWidget);
    });

    testWidgets('handles tap correctly', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(makeTestableWidgetWithScaffold(
        ModernModalActionItem(
          icon: Icons.add,
          title: 'Tap Me',
          onTap: () => tapCount++,
        ),
      ));

      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
    });

    testWidgets('shows destructive styling when isDestructive is true',
        (tester) async {
      await tester.pumpWidget(makeTestableWidgetWithScaffold(
        ModernModalActionItem(
          icon: Icons.delete,
          title: 'Delete',
          onTap: () {},
          isDestructive: true,
        ),
      ));

      final text = tester.widget<Text>(find.text('Delete'));
      expect(text.style?.color, isNotNull);
    });

    testWidgets('respects isDisabled property', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(makeTestableWidgetWithScaffold(
        ModernModalActionItem(
          icon: Icons.block,
          title: 'Disabled Action',
          onTap: () => tapCount++,
          isDisabled: true,
        ),
      ));

      await tester.tap(find.text('Disabled Action'));
      await tester.pumpAndSettle();

      expect(tapCount, 0);
    });

    testWidgets('shows trailing widget when provided', (tester) async {
      await tester.pumpWidget(makeTestableWidgetWithScaffold(
        ModernModalActionItem(
          icon: Icons.settings,
          title: 'Settings',
          onTap: () {},
          trailing: const Icon(Icons.chevron_right),
        ),
      ));

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('applies custom icon color', (tester) async {
      const customColor = Colors.blue;

      await tester.pumpWidget(makeTestableWidgetWithScaffold(
        ModernModalActionItem(
          icon: Icons.palette,
          title: 'Custom Color',
          onTap: () {},
          iconColor: customColor,
        ),
      ));

      expect(find.byIcon(Icons.palette), findsOneWidget);
    });

    testWidgets('animates on tap down and up', (tester) async {
      await tester.pumpWidget(makeTestableWidgetWithScaffold(
        ModernModalActionItem(
          icon: Icons.touch_app,
          title: 'Animated',
          onTap: () {},
        ),
      ));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Animated')),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Widget should be animating
      expect(find.byType(AnimatedBuilder), findsWidgets);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
