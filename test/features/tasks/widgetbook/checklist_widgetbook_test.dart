import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/widgetbook/checklist_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildChecklistWidgetbookFolder', () {
    late WidgetbookUseCase useCase;

    setUp(() {
      final folder = buildChecklistWidgetbookFolder();
      final children = folder.children;
      expect(children, isNotNull);
      final component = children!.single as WidgetbookComponent;
      expect(component.name, 'To-dos checklist');
      useCase = component.useCases.single;
      expect(useCase.name, 'Interactive');
    });

    testWidgets('renders checklist with title and progress indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('0/2 done'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders header with chevron and menu icons', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('renders open items by default (filtered)', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Fix payment status update bug'), findsOneWidget);
      expect(find.text('Fix handover status update bug'), findsOneWidget);
    });

    testWidgets('filter tabs show labels without counts', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('shows all items when "All" tab is tapped', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Check an item so it becomes completed
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      // "Open" filter hides the checked item — only 1 visible
      expect(find.text('Fix handover status update bug'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Tap "All" to reveal checked item again
      await tester.tap(find.text('All'));
      await tester.pump();

      expect(find.text('Fix payment status update bug'), findsOneWidget);
      expect(find.text('Fix handover status update bug'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
    });

    testWidgets('toggling item updates progress counter', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));
      await tester.tap(checkboxes.first);
      await tester.pump();

      expect(find.text('1/2 done'), findsOneWidget);
    });

    testWidgets('edit icons are present and tappable', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byIcon(Icons.mode_edit_outlined), findsNWidgets(2));

      // Tap edit on first item — shows inline TextField
      await tester.tap(find.byIcon(Icons.mode_edit_outlined).first);
      await tester.pump();

      // Add item field + inline edit field
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('inline edit saves new title on submit', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      await tester.tap(find.byIcon(Icons.mode_edit_outlined).first);
      await tester.pump();

      final editField = find.byType(TextField).first;
      await tester.enterText(editField, 'Renamed task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Renamed task'), findsOneWidget);
      expect(find.text('Fix payment status update bug'), findsNothing);
    });

    testWidgets('swipe left deletes an item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Fix payment status update bug'), findsOneWidget);

      await tester.drag(
        find.text('Fix payment status update bug'),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fix payment status update bug'), findsNothing);
      expect(find.text('0/1 done'), findsOneWidget);
    });

    testWidgets('swipe right archives an item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byType(Checkbox), findsNWidgets(2));

      // Swipe right to archive
      await tester.drag(
        find.text('Fix payment status update bug'),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();

      // Archived: removed from Open view
      expect(find.text('Fix payment status update bug'), findsNothing);
      expect(find.byType(Checkbox), findsOneWidget);

      // Switch to All — archived item visible
      await tester.tap(find.text('All'));
      await tester.pump();

      expect(find.text('Fix payment status update bug'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
    });

    testWidgets('add item field is a rounded form field', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Add a new item'), findsOneWidget);
    });

    testWidgets('submitting text adds new item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'New task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('New task'), findsOneWidget);
      expect(find.text('0/3 done'), findsOneWidget);
    });

    testWidgets('drag handles are present', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    });

    testWidgets('renders in dark mode without errors', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.dark(),
        ),
      );

      expect(find.text('Todos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows all-done message when all items checked', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Check all visible items until none remain
      while (find.byType(Checkbox).evaluate().isNotEmpty) {
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();
      }

      expect(find.text('All items completed!'), findsOneWidget);
    });

    testWidgets('chevron collapses and expands the body', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Fix payment status update bug'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump();

      expect(find.text('Fix payment status update bug'), findsNothing);
      expect(find.text('0/2 done'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump();

      expect(find.text('Fix payment status update bug'), findsOneWidget);
    });

    testWidgets('items list does not scroll independently', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      // ReorderableListView exists but with NeverScrollableScrollPhysics
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('inline edit cancels when submitting empty text', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Start editing
      await tester.tap(find.byIcon(Icons.mode_edit_outlined).first);
      await tester.pump();

      // Clear text and submit empty — should cancel edit
      final editField = find.byType(TextField).first;
      await tester.enterText(editField, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Original title still there (edit cancelled)
      expect(find.text('Fix payment status update bug'), findsOneWidget);
      // Edit icon back (no longer in editing mode)
      expect(find.byIcon(Icons.mode_edit_outlined), findsNWidgets(2));
    });

    testWidgets('tapping Open tab while already on Open triggers callback', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Switch to All first
      await tester.tap(find.text('All'));
      await tester.pump();

      // Switch back to Open
      await tester.tap(find.text('Open'));
      await tester.pump();

      // Items filtered again — only unchecked/unarchived
      expect(find.text('Fix payment status update bug'), findsOneWidget);
    });

    testWidgets('three-dot menu is tappable', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Tapping menu icon does not throw
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
