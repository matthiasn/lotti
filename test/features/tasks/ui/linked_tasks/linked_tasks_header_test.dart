import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_header.dart';

import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

// Larger size to avoid overflow in popup menus
const _largeMediaQuery = MediaQueryData(size: Size(800, 600));

void main() {
  group('LinkedTasksHeader', () {
    setUp(() async {
      await setUpTestGetIt();
    });

    tearDown(() async {
      await tearDownTestGetIt();
    });

    testWidgets('renders title "Linked Tasks"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      expect(find.text('Linked Tasks'), findsOneWidget);
    });

    testWidgets('renders menu button with more_vert icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('opens popup menu when menu button is tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Menu items should be visible
      expect(find.text('Link existing task...'), findsOneWidget);
      expect(find.text('Create new linked task...'), findsOneWidget);
    });

    testWidgets('shows Manage links menu item when hasLinkedTasks is true',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Manage links...'), findsOneWidget);
    });

    testWidgets(
        'does not show Manage links menu item when hasLinkedTasks is false',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Manage links...'), findsNothing);
    });

    testWidgets('menu has link icon for Link existing task', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('menu has add icon for Create new linked task', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('manage mode toggle changes icon and text', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: true,
            ),
          ),
        ),
      );

      // Open menu and verify initial state
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Initially shows "Manage links..." with edit icon
      expect(find.text('Manage links...'), findsOneWidget);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

      // Tap to enter manage mode
      await tester.tap(find.text('Manage links...'));
      await tester.pumpAndSettle();

      // Open menu again
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Now shows "Done" with check icon
      expect(find.text('Done'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('header is laid out in a Row with Spacer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      // The header uses Row with Spacer
      expect(find.byType(Row), findsWidgets);
      expect(find.byType(Spacer), findsOneWidget);
    });

    testWidgets('PopupMenuButton has correct tooltip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-1').overrideWith(
              LinkedTasksController.new,
            ),
          ],
          child: const WidgetTestBench(
            mediaQueryData: _largeMediaQuery,
            child: LinkedTasksHeader(
              taskId: 'task-1',
              hasLinkedTasks: false,
            ),
          ),
        ),
      );

      final popupMenuButton = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(popupMenuButton.tooltip, 'Linked tasks options');
    });
  });
}
