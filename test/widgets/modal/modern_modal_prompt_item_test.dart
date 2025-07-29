import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/modern_modal_prompt_item.dart';

import '../../widget_test_utils.dart';

void main() {
  group('ModernModalPromptItem', () {
    testWidgets('displays title, description and icon correctly',
        (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalPromptItem(
            icon: Icons.auto_awesome,
            title: 'AI Prompt',
            description: 'This is a test description for the prompt',
            onTap: () => tapCount++,
          ),
        ),
      );

      expect(find.text('AI Prompt'), findsOneWidget);
      expect(
        find.text('This is a test description for the prompt'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('handles tap correctly', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalPromptItem(
            icon: Icons.smart_toy,
            title: 'Tap Me',
            description: 'Description',
            onTap: () => tapCount++,
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
    });

    testWidgets('shows badge when provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalPromptItem(
            icon: Icons.new_releases,
            title: 'New Feature',
            description: 'Try our new feature',
            onTap: () {},
            badge: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ),
      );

      expect(find.text('NEW'), findsOneWidget);
    });

    testWidgets('shows selected state styling', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalPromptItem(
            icon: Icons.check_circle,
            title: 'Selected Item',
            description: 'This item is selected',
            onTap: () {},
            isSelected: true,
          ),
        ),
      );

      expect(find.text('Selected Item'), findsOneWidget);
      // The selected state will have different styling
    });

    testWidgets('respects isDisabled property', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalPromptItem(
            icon: Icons.block,
            title: 'Disabled Prompt',
            description: 'This prompt is disabled',
            onTap: () => tapCount++,
            isDisabled: true,
          ),
        ),
      );

      await tester.tap(find.text('Disabled Prompt'));
      await tester.pumpAndSettle();

      expect(tapCount, 0);
    });

    testWidgets('shows trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalPromptItem(
            icon: Icons.arrow_forward,
            title: 'With Trailing',
            description: 'Has a trailing widget',
            onTap: () {},
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });

    testWidgets('animates on hover', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalPromptItem(
            icon: Icons.mouse,
            title: 'Hover Me',
            description: 'Hover animation test',
            onTap: () {},
          ),
        ),
      );

      // Simulate hover
      // Find the gesture detector
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Hover Me')),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Widget should be animating
      expect(find.byType(AnimatedBuilder), findsWidgets);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('truncates long description', (tester) async {
      const longDescription = 'This is a very long description that should '
          'be truncated after four lines. It contains a lot of text to ensure '
          'that the overflow behavior works correctly. Adding more text here '
          'to make sure it would overflow after four lines.';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalPromptItem(
            icon: Icons.description,
            title: 'Long Description',
            description: longDescription,
            onTap: () {},
          ),
        ),
      );

      final textWidget = tester.widget<Text>(
        find.text(longDescription),
      );
      expect(textWidget.overflow, TextOverflow.ellipsis);
      expect(textWidget.maxLines, 4);
    });
  });
}
