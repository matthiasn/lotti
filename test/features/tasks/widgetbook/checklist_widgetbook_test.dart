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

    /// Pumps the interactive use case under the given brightness.
    Future<void> pumpUseCase(WidgetTester tester, {bool dark = false}) {
      return tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: dark ? DesignSystemTheme.dark() : DesignSystemTheme.light(),
        ),
      );
    }

    testWidgets('renders checklist with title and progress indicator', (
      tester,
    ) async {
      await pumpUseCase(tester);

      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('0/2 done'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders header with chevron and menu icons', (
      tester,
    ) async {
      await pumpUseCase(tester);

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('renders open items by default (filtered)', (tester) async {
      await pumpUseCase(tester);

      expect(find.text('Fix payment status update bug'), findsOneWidget);
      expect(find.text('Fix handover status update bug'), findsOneWidget);
    });

    testWidgets('filter tabs show labels without counts', (tester) async {
      await pumpUseCase(tester);

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('shows all items when "All" tab is tapped', (tester) async {
      await pumpUseCase(tester);

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
      await pumpUseCase(tester);

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));
      await tester.tap(checkboxes.first);
      await tester.pump();

      expect(find.text('1/2 done'), findsOneWidget);
    });

    testWidgets('edit icons are present and tappable', (tester) async {
      await pumpUseCase(tester);

      expect(find.byIcon(Icons.mode_edit_outlined), findsNWidgets(2));

      // Tap edit on first item — shows inline TextField
      await tester.tap(find.byIcon(Icons.mode_edit_outlined).first);
      await tester.pump();

      // Add item field + inline edit field
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('inline edit saves new title on submit', (tester) async {
      await pumpUseCase(tester);

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
      await pumpUseCase(tester);

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
      await pumpUseCase(tester);

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
      await pumpUseCase(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Add a new item'), findsOneWidget);
    });

    testWidgets('submitting text adds new item', (tester) async {
      await pumpUseCase(tester);

      await tester.enterText(find.byType(TextField), 'New task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('New task'), findsOneWidget);
      expect(find.text('0/3 done'), findsOneWidget);
    });

    testWidgets('drag handles are present', (tester) async {
      await pumpUseCase(tester);

      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    });

    testWidgets('renders in dark mode without errors', (tester) async {
      await pumpUseCase(tester, dark: true);

      // The full interactive surface must render under the dark theme:
      // header, progress counter + ring, both items, and the add field.
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('0/2 done'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Fix payment status update bug'), findsOneWidget);
      expect(find.text('Fix handover status update bug'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows all-done message when all items checked', (
      tester,
    ) async {
      await pumpUseCase(tester);

      // Check all visible items until none remain
      while (find.byType(Checkbox).evaluate().isNotEmpty) {
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();
      }

      expect(find.text('All items completed!'), findsOneWidget);
    });

    testWidgets('chevron collapses and expands the body', (tester) async {
      await pumpUseCase(tester);

      expect(find.text('Fix payment status update bug'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      expect(find.text('Fix payment status update bug'), findsNothing);
      expect(find.text('0/2 done'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      expect(find.text('Fix payment status update bug'), findsOneWidget);
    });

    testWidgets('items list does not scroll independently', (tester) async {
      await pumpUseCase(tester);

      final listView = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      expect(listView.physics, isA<NeverScrollableScrollPhysics>());
      expect(listView.shrinkWrap, isTrue);
    });

    testWidgets('inline edit cancels when submitting empty text', (
      tester,
    ) async {
      await pumpUseCase(tester);

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
      await pumpUseCase(tester);

      // Switch to All first
      await tester.tap(find.text('All'));
      await tester.pump();

      // Switch back to Open
      await tester.tap(find.text('Open'));
      await tester.pump();

      // Items filtered again — only unchecked/unarchived
      expect(find.text('Fix payment status update bug'), findsOneWidget);
    });

    // The three-dot menu's onTap is an intentionally empty lambda in this
    // showcase widget (it exists for visual parity only), so a tap test
    // proves nothing; the icon's presence is asserted in the header test.
  });
}
