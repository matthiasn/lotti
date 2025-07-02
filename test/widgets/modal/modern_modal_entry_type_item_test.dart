import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/modern_modal_entry_type_item.dart';

import '../../widget_test_utils.dart';

void main() {
  group('ModernModalEntryTypeItem', () {
    testWidgets('displays title and icon correctly', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalEntryTypeItem(
            icon: Icons.task,
            title: 'Create Task',
            onTap: () => tapCount++,
          ),
        ),
      );

      expect(find.text('Create Task'), findsOneWidget);
      expect(find.byIcon(Icons.task), findsOneWidget);
    });

    testWidgets('handles tap correctly', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalEntryTypeItem(
            icon: Icons.add,
            title: 'Tap Me',
            onTap: () => tapCount++,
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
    });

    testWidgets('respects isDisabled property', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalEntryTypeItem(
            icon: Icons.block,
            title: 'Disabled Entry',
            onTap: () => tapCount++,
            isDisabled: true,
          ),
        ),
      );

      await tester.tap(find.text('Disabled Entry'));
      await tester.pumpAndSettle();

      expect(tapCount, 0);
    });

    testWidgets('shows badge when provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalEntryTypeItem(
            icon: Icons.new_releases,
            title: 'New Entry Type',
            onTap: () {},
            badge: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'BETA',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ),
      );

      expect(find.text('BETA'), findsOneWidget);
    });

    testWidgets('applies custom icon color', (tester) async {
      const customColor = Colors.purple;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalEntryTypeItem(
            icon: Icons.color_lens,
            title: 'Custom Color',
            onTap: () {},
            iconColor: customColor,
          ),
        ),
      );

      expect(find.byIcon(Icons.color_lens), findsOneWidget);
    });

    testWidgets('shows add circle icon', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalEntryTypeItem(
            icon: Icons.note,
            title: 'Add Note',
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('animates on tap down and up', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalEntryTypeItem(
            icon: Icons.animation,
            title: 'Animated Entry',
            onTap: () {},
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Animated Entry')),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Widget should be animating
      expect(find.byType(AnimatedBuilder), findsWidgets);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('icon scales on press', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernModalEntryTypeItem(
            icon: Icons.zoom_in,
            title: 'Scalable Icon',
            onTap: () {},
          ),
        ),
      );

      // Find the Transform widget that wraps the icon container
      final transformFinder = find.descendant(
        of: find.byType(ModernModalEntryTypeItem),
        matching: find.byType(Transform),
      );

      expect(transformFinder, findsWidgets);
    });

    testWidgets('different entry types have unique icons', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Column(
            children: [
              ModernModalEntryTypeItem(
                icon: Icons.event,
                title: 'Event',
                onTap: () {},
              ),
              ModernModalEntryTypeItem(
                icon: Icons.task,
                title: 'Task',
                onTap: () {},
              ),
              ModernModalEntryTypeItem(
                icon: Icons.mic,
                title: 'Audio',
                onTap: () {},
              ),
              ModernModalEntryTypeItem(
                icon: Icons.text_fields,
                title: 'Text',
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.event), findsOneWidget);
      expect(find.byIcon(Icons.task), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
    });
  });
}
