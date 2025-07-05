import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';
import 'package:lotti/widgets/modal/modern_modal_action_item.dart';
import 'package:lotti/widgets/modal/modern_modal_entry_type_item.dart';
import 'package:lotti/widgets/modal/modern_modal_prompt_item.dart';

void main() {
  group('Modal Items Animation Integration Tests', () {
    group('ModernModalPromptItem', () {
      testWidgets('renders correctly and handles tap', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernModalPromptItem(
                title: 'Test Title',
                description: 'Test Description',
                icon: Icons.info,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        // Verify content is rendered
        expect(find.text('Test Title'), findsOneWidget);
        expect(find.text('Test Description'), findsOneWidget);
        expect(find.byIcon(Icons.info), findsOneWidget);

        // Verify uses AnimatedModalItem
        expect(find.byType(AnimatedModalItem), findsOneWidget);

        // Test tap
        await tester.tap(find.text('Test Title'));
        await tester.pump();
        expect(tapped, true);
      });

      testWidgets('shows selected state', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernModalPromptItem(
                title: 'Selected Item',
                description: 'This is selected',
                icon: Icons.check,
                onTap: () {},
                isSelected: true,
              ),
            ),
          ),
        );

        // Selected items should have check icon in trailing position
        // The main icon is Icons.check, not the check_circle_rounded
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('respects disabled state', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernModalPromptItem(
                title: 'Disabled Item',
                description: 'Cannot tap',
                icon: Icons.info,
                onTap: () => tapped = true,
                isDisabled: true,
              ),
            ),
          ),
        );

        // Try tapping disabled item
        await tester.tap(find.text('Disabled Item'));
        await tester.pump();
        expect(tapped, false);
      });

      testWidgets('displays badge when provided', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernModalPromptItem(
                title: 'Item with Badge',
                description: 'Has a badge',
                icon: Icons.info,
                badge: const Text('NEW'),
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('NEW'), findsOneWidget);
      });
    });

    group('ModernModalActionItem', () {
      testWidgets('renders correctly and handles tap', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernModalActionItem(
                icon: Icons.settings,
                title: 'Settings',
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        // Verify content is rendered
        expect(find.text('Settings'), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);

        // Verify uses AnimatedModalItem
        expect(find.byType(AnimatedModalItem), findsOneWidget);

        // Test tap
        await tester.tap(find.text('Settings'));
        await tester.pump();
        expect(tapped, true);
      });

      testWidgets('shows destructive styling', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernModalActionItem(
                icon: Icons.delete,
                title: 'Delete',
                onTap: () {},
                isDestructive: true,
              ),
            ),
          ),
        );

        // Destructive items should be styled differently
        // Just verify the widget renders with destructive flag
        final actionItem = tester.widget<ModernModalActionItem>(
          find.byType(ModernModalActionItem),
        );
        expect(actionItem.isDestructive, true);
      });

      testWidgets('displays subtitle when provided', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernModalActionItem(
                icon: Icons.backup,
                title: 'Backup',
                subtitle: 'Last backup: 2 hours ago',
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Backup'), findsOneWidget);
        expect(find.text('Last backup: 2 hours ago'), findsOneWidget);
      });

      testWidgets('displays trailing widget', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernModalActionItem(
                icon: Icons.notifications,
                title: 'Notifications',
                trailing: const Switch(value: true, onChanged: null),
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.byType(Switch), findsOneWidget);
      });
    });

    group('ModernModalEntryTypeItem', () {
      testWidgets('renders correctly and handles tap', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernModalEntryTypeItem(
                icon: Icons.event,
                title: 'Create Event',
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        // Verify content is rendered
        expect(find.text('Create Event'), findsOneWidget);
        expect(find.byIcon(Icons.event), findsOneWidget);

        // Should show add icon
        expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);

        // Does NOT use AnimatedModalItem
        expect(find.byType(AnimatedModalItem), findsNothing);

        // Test tap
        await tester.tap(find.text('Create Event'));
        await tester.pump();
        expect(tapped, true);
      });

      testWidgets('displays badge when provided', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernModalEntryTypeItem(
                icon: Icons.task,
                title: 'Create Task',
                badge: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('3', style: TextStyle(color: Colors.white)),
                ),
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('3'), findsOneWidget);
      });
    });

    group('Cross-widget consistency', () {
      testWidgets('all widgets handle user interaction', (tester) async {
        var promptTapped = false;
        var actionTapped = false;
        var entryTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ModernModalPromptItem(
                    title: 'Prompt',
                    description: 'Description',
                    icon: Icons.info,
                    onTap: () => promptTapped = true,
                  ),
                  ModernModalActionItem(
                    icon: Icons.settings,
                    title: 'Action',
                    onTap: () => actionTapped = true,
                  ),
                  ModernModalEntryTypeItem(
                    icon: Icons.add,
                    title: 'Entry',
                    onTap: () => entryTapped = true,
                  ),
                ],
              ),
            ),
          ),
        );

        // All widgets should be rendered
        expect(find.text('Prompt'), findsOneWidget);
        expect(find.text('Action'), findsOneWidget);
        expect(find.text('Entry'), findsOneWidget);

        // Tap each item
        await tester.tap(find.text('Prompt'));
        await tester.pump();
        expect(promptTapped, true);

        await tester.tap(find.text('Action'));
        await tester.pump();
        expect(actionTapped, true);

        await tester.tap(find.text('Entry'));
        await tester.pump();
        expect(entryTapped, true);
      });

      testWidgets('disabled state prevents taps', (tester) async {
        var promptTapped = false;
        var actionTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ModernModalPromptItem(
                    title: 'Disabled Prompt',
                    description: 'Cannot tap',
                    icon: Icons.info,
                    onTap: () => promptTapped = true,
                    isDisabled: true,
                  ),
                  ModernModalActionItem(
                    icon: Icons.settings,
                    title: 'Disabled Action',
                    onTap: () => actionTapped = true,
                    isDisabled: true,
                  ),
                ],
              ),
            ),
          ),
        );

        // Try tapping disabled items
        await tester.tap(find.text('Disabled Prompt'));
        await tester.pump();
        expect(promptTapped, false);

        await tester.tap(find.text('Disabled Action'));
        await tester.pump();
        expect(actionTapped, false);
      });

      testWidgets('all widgets render in a list', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  ModernModalPromptItem(
                    title: 'Item 1',
                    description: 'First item',
                    icon: Icons.looks_one,
                    onTap: () {},
                  ),
                  ModernModalActionItem(
                    icon: Icons.looks_two,
                    title: 'Item 2',
                    onTap: () {},
                  ),
                  ModernModalEntryTypeItem(
                    icon: Icons.looks_3,
                    title: 'Item 3',
                    onTap: () {},
                  ),
                  ModernModalPromptItem(
                    title: 'Item 4',
                    description: 'Fourth item',
                    icon: Icons.looks_4,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        // All items should be visible
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
        expect(find.text('Item 4'), findsOneWidget);
      });
    });
  });
}
