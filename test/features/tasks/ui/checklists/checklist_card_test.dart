import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_full_list_modal.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

import '../../../../widget_test_utils.dart';
import 'checklist_card_fakes.dart';

/// Key used by the add-item field inside [ChecklistCard] when id='cl-1'.
const ValueKey<String> _addFieldKey = ValueKey('add-input-cl-1');

/// Pump a [ChecklistCard] with the minimal required props.
///
/// [itemIds] defaults to empty to avoid spinning up real item providers.
Future<void> _pump(
  WidgetTester tester, {
  String title = 'My Checklist',
  List<String> itemIds = const [],
  double completionRate = 0.0,
  int? completedCount,
  int? totalCount,
  bool isSortingMode = false,
  bool? initiallyExpanded,
  int? reorderIndex,
  void Function(String?)? onTitleSave,
  Future<String?> Function(String?)? onCreateItem,
  Future<void> Function(List<String>)? onReorder,
  VoidCallback? onDelete,
  VoidCallback? onExportMarkdown,
  VoidCallback? onShareMarkdown,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      ChecklistCard(
        id: 'cl-1',
        taskId: 'task-1',
        title: title,
        itemIds: itemIds,
        completionRate: completionRate,
        completedCount: completedCount,
        totalCount: totalCount,
        isSortingMode: isSortingMode,
        initiallyExpanded: initiallyExpanded,
        reorderIndex: reorderIndex,
        onTitleSave: onTitleSave ?? (_) {},
        onCreateItem: onCreateItem ?? (_) async => null,
        onReorder: onReorder ?? (_) async {},
        onDelete: onDelete,
        onExportMarkdown: onExportMarkdown,
        onShareMarkdown: onShareMarkdown,
      ),
      overrides: overrides,
    ),
  );
}

void main() {
  group('ChecklistCard', () {
    // ── Expansion ────────────────────────────────────────────────────────────

    testWidgets('renders title and chevron in expanded state', (tester) async {
      await _pump(tester, initiallyExpanded: true);

      expect(find.text('My Checklist'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('tapping chevron toggles expansion', (tester) async {
      await _pump(tester, initiallyExpanded: true);

      // Expanded → add field hit-testable (non-zero size)
      expect(find.byKey(_addFieldKey).hitTestable(), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump(const Duration(milliseconds: 400));

      // Collapsed → add field clipped to zero, not hit-testable
      expect(find.byKey(_addFieldKey).hitTestable(), findsNothing);

      // Tap again → expands
      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(_addFieldKey).hitTestable(), findsOneWidget);
    });

    testWidgets('shows add-item field when expanded', (tester) async {
      await _pump(tester, initiallyExpanded: true);
      expect(find.byKey(_addFieldKey).hitTestable(), findsOneWidget);
    });

    testWidgets('hides add-item field when collapsed', (tester) async {
      await _pump(tester, initiallyExpanded: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_addFieldKey).hitTestable(), findsNothing);
    });

    // ── Add-item field ───────────────────────────────────────────────────────

    testWidgets('add-item field is a clean TextField with no suffix icons', (
      tester,
    ) async {
      await _pump(tester, initiallyExpanded: true);

      // The inner TextField in _AddItemField must have no suffix icon —
      // proving TitleTextField's check/cancel icons are gone.
      final tf = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(_addFieldKey),
          matching: find.byType(TextField),
        ),
      );
      expect(tf.decoration?.suffixIcon, isNull);
    });

    testWidgets('add-item field shows hint text', (tester) async {
      await _pump(tester, initiallyExpanded: true);

      final tf = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(_addFieldKey),
          matching: find.byType(TextField),
        ),
      );
      expect(tf.decoration?.hintText, 'Add a new item');
    });

    testWidgets('onCreateItem is called with trimmed text on submit', (
      tester,
    ) async {
      String? capturedTitle;
      await _pump(
        tester,
        initiallyExpanded: true,
        onCreateItem: (title) async {
          capturedTitle = title;
          return 'new-id';
        },
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(_addFieldKey),
          matching: find.byType(TextField),
        ),
        '  Write tests  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(capturedTitle, 'Write tests');
    });

    // ── Progress ring ────────────────────────────────────────────────────────

    testWidgets('progress ring is visible when expanded', (tester) async {
      await _pump(
        tester,
        initiallyExpanded: true,
        completedCount: 1,
        totalCount: 3,
        completionRate: 1 / 3,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('1/3 done'), findsOneWidget);
    });

    testWidgets('progress ring is visible when collapsed', (tester) async {
      await _pump(
        tester,
        initiallyExpanded: false,
        completedCount: 2,
        totalCount: 5,
        completionRate: 0.4,
      );

      // Progress ring must be in the header row even when collapsed.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('2/5 done'), findsOneWidget);
    });

    // ── Filter strip ─────────────────────────────────────────────────────────

    testWidgets(
      'filter strip shows Open and All tabs when expanded with items',
      (tester) async {
        await _pump(
          tester,
          initiallyExpanded: true,
          completedCount: 0,
          totalCount: 2,
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Open'), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
      },
    );

    testWidgets('no filter strip when totalCount is zero', (tester) async {
      await _pump(
        tester,
        initiallyExpanded: true,
        completedCount: 0,
        totalCount: 0,
      );
      await tester.pump(const Duration(milliseconds: 300));

      // AnimatedCrossFade keeps both children in tree; hitTestable() checks
      // that the strip is clipped to zero size (not interactive).
      expect(find.text('Open').hitTestable(), findsNothing);
      expect(find.text('All').hitTestable(), findsNothing);
    });

    testWidgets('progress ring hidden when totalCount is zero', (tester) async {
      await _pump(
        tester,
        initiallyExpanded: true,
        completedCount: 0,
        totalCount: 0,
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('menu icon hidden when no actions provided', (tester) async {
      await _pump(tester, initiallyExpanded: true);
      // No onDelete / onExportMarkdown / onShareMarkdown → no more_vert button.
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('selected filter tab renders with bold text', (tester) async {
      await _pump(
        tester,
        initiallyExpanded: true,
        completedCount: 0,
        totalCount: 3,
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Default filter is openOnly → 'Open' tab bold, 'All' tab normal.
      final openTexts = tester.widgetList<Text>(find.text('Open')).toList();
      expect(
        openTexts.any((t) => t.style?.fontWeight == FontWeight.w600),
        isTrue,
        reason: 'Open tab should be bold when selected',
      );
      final allTexts = tester.widgetList<Text>(find.text('All')).toList();
      expect(
        allTexts.every((t) => t.style?.fontWeight != FontWeight.w600),
        isTrue,
        reason: 'All tab should not be bold when not selected',
      );
    });

    testWidgets('tapping All tab selects it and makes its text bold', (
      tester,
    ) async {
      await _pump(
        tester,
        initiallyExpanded: true,
        completedCount: 0,
        totalCount: 3,
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('All'));
      await tester.pump();

      final allTexts = tester.widgetList<Text>(find.text('All')).toList();
      expect(
        allTexts.any((t) => t.style?.fontWeight == FontWeight.w600),
        isTrue,
        reason: 'All tab should be bold after being tapped',
      );
    });

    // ── Title editing ────────────────────────────────────────────────────────

    testWidgets('title tap enters edit mode (TitleTextField for title only)', (
      tester,
    ) async {
      await _pump(tester, title: 'Editable', initiallyExpanded: true);

      await tester.tap(find.text('Editable'));
      await tester.pump();

      // Only one TitleTextField: for title editing.
      // The add-item field is no longer a TitleTextField.
      expect(find.byType(TitleTextField), findsOneWidget);
    });

    testWidgets('onTitleSave is called when title edit is submitted', (
      tester,
    ) async {
      String? saved;
      await _pump(
        tester,
        title: 'Old Title',
        initiallyExpanded: true,
        onTitleSave: (t) => saved = t,
      );

      await tester.tap(find.text('Old Title'));
      await tester.pump();

      final titleField = find.byType(TitleTextField).first;
      await tester.enterText(titleField, 'New Title');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(saved, 'New Title');
    });

    // ── Menu ─────────────────────────────────────────────────────────────────

    testWidgets('shows menu icon and delete option', (tester) async {
      var deleted = false;
      await _pump(
        tester,
        initiallyExpanded: true,
        onDelete: () => deleted = true,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Delete checklist?'), findsOneWidget);

      await tester.tap(find.text('Delete checklist?'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('tapping Cancel in the delete dialog does not call onDelete', (
      tester,
    ) async {
      var deleted = false;
      await _pump(
        tester,
        initiallyExpanded: true,
        onDelete: () => deleted = true,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete checklist?'));
      await tester.pumpAndSettle();

      // Tap the Cancel action on the confirmation dialog.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(deleted, isFalse);
    });

    testWidgets('menu shows export option when onExportMarkdown provided', (
      tester,
    ) async {
      var exported = false;
      await _pump(
        tester,
        initiallyExpanded: true,
        onExportMarkdown: () => exported = true,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Export checklist as Markdown'), findsOneWidget);

      await tester.tap(find.text('Export checklist as Markdown'));
      await tester.pump();

      expect(exported, isTrue);
    });

    testWidgets(
      'menu shows localized Share option when onShareMarkdown provided',
      (tester) async {
        var shared = false;
        await _pump(
          tester,
          initiallyExpanded: true,
          onShareMarkdown: () => shared = true,
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('Share'), findsOneWidget);

        await tester.tap(find.text('Share'));
        await tester.pump();

        expect(shared, isTrue);
      },
    );

    // ── Sorting mode ─────────────────────────────────────────────────────────

    testWidgets('sorting mode shows drag handle, hides body', (tester) async {
      await _pump(
        tester,
        isSortingMode: true,
        reorderIndex: 0,
        title: 'Sort Me',
        completedCount: 1,
        totalCount: 3,
        completionRate: 1 / 3,
      );

      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
      expect(find.byKey(_addFieldKey).hitTestable(), findsNothing);
    });

    // ── Empty list ───────────────────────────────────────────────────────────

    testWidgets('no item rows when itemIds is empty', (tester) async {
      await _pump(tester, initiallyExpanded: true);
      expect(find.byType(ChecklistItemRow), findsNothing);
    });

    // ── didUpdateWidget — itemIds change ──────────────────────────────────────

    testWidgets('didUpdateWidget updates item list when itemIds change', (
      tester,
    ) async {
      // Start with no items → no allDone message (allDone requires
      // itemIds.isNotEmpty).
      var itemIds = <String>[];
      var completionRate = 0.0;
      var completedCount = 0;
      var totalCount = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return ChecklistCard(
                id: 'cl-1',
                taskId: 'task-1',
                title: 'Dynamic',
                itemIds: itemIds,
                completionRate: completionRate,
                completedCount: completedCount,
                totalCount: totalCount,
                initiallyExpanded: true,
                onTitleSave: (_) {},
                onCreateItem: (_) async => null,
                onReorder: (_) async {},
              );
            },
          ),
        ),
      );

      expect(find.text('All items completed!'), findsNothing);

      // Rebuild with one completed item → triggers didUpdateWidget (itemIds
      // changes) and the allDone branch.
      outerSetState(() {
        itemIds = ['x'];
        completionRate = 1.0;
        completedCount = 1;
        totalCount = 1;
      });
      await tester.pump();

      expect(find.text('All items completed!'), findsOneWidget);
    });

    // ── didUpdateWidget — exiting sorting mode restores expansion ────────────

    testWidgets(
      'exiting sorting mode restores expansion from initiallyExpanded',
      (tester) async {
        // Start collapsed (not sorting). _isExpanded will be false.
        var isSorting = false;
        var initiallyExpanded = false;
        late StateSetter outerSetState;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            StatefulBuilder(
              builder: (context, setState) {
                outerSetState = setState;
                return ChecklistCard(
                  id: 'cl-1',
                  taskId: 'task-1',
                  title: 'Sortable',
                  itemIds: const [],
                  completionRate: 0,
                  isSortingMode: isSorting,
                  initiallyExpanded: initiallyExpanded,
                  onTitleSave: (_) {},
                  onCreateItem: (_) async => null,
                  onReorder: (_) async {},
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        // Card is collapsed — add field not visible.
        expect(find.byKey(_addFieldKey).hitTestable(), findsNothing);

        // Enter sorting mode.
        outerSetState(() => isSorting = true);
        await tester.pump(const Duration(milliseconds: 400));

        // Exit sorting mode with initiallyExpanded=true.
        // This triggers lines 119-122: _setExpanded(true).
        outerSetState(() {
          isSorting = false;
          initiallyExpanded = true;
        });
        // AnimatedCrossFade needs enough time to complete. Pump generously.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Card should now be expanded.
        expect(find.byKey(_addFieldKey).hitTestable(), findsOneWidget);
      },
    );

    // ── Title cancel ────────────────────────────────────────────────────────

    testWidgets('tapping cancel icon exits title edit mode', (tester) async {
      await _pump(tester, title: 'Cancel Me', initiallyExpanded: true);

      // Enter edit mode.
      await tester.tap(find.text('Cancel Me'));
      await tester.pump();
      expect(find.byType(TitleTextField), findsOneWidget);

      // The TitleTextField shows a cancel_outlined icon when onCancel is set.
      // Tap it to cancel editing.
      await tester.tap(find.byIcon(Icons.cancel_outlined));
      await tester.pump();

      // TitleTextField should be gone, title text re-appears.
      expect(find.byType(TitleTextField), findsNothing);
      expect(find.text('Cancel Me'), findsOneWidget);
    });

    // ── allDone message ─────────────────────────────────────────────────────

    testWidgets('shows allDone message when all items completed and filter is '
        'openOnly', (tester) async {
      await _pump(
        tester,
        initiallyExpanded: true,
        itemIds: const ['x'],
        completionRate: 1,
        completedCount: 1,
        totalCount: 1,
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('All items completed!'), findsOneWidget);
    });

    // ── Sorting header with reorderIndex=null ───────────────────────────────

    testWidgets('sorting header without reorderIndex shows plain drag handle', (
      tester,
    ) async {
      await _pump(
        tester,
        isSortingMode: true,
        title: 'No Index',
        completedCount: 0,
        totalCount: 2,
      );

      // drag_indicator is present but NOT wrapped in ReorderableDragStartListener.
      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNothing);
    });

    testWidgets(
      'sorting header with reorderIndex wraps handle in '
      'ReorderableDragStartListener',
      (tester) async {
        await _pump(
          tester,
          isSortingMode: true,
          reorderIndex: 0,
          title: 'Indexed',
          completedCount: 0,
          totalCount: 2,
        );

        expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
        expect(find.byType(ReorderableDragStartListener), findsOneWidget);
      },
    );

    // ── Expansion callback ───────────────────────────────────────────────────

    testWidgets('calls onExpansionChanged when expanded state changes', (
      tester,
    ) async {
      final states = <bool>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ChecklistCard(
            id: 'cl-1',
            taskId: 'task-1',
            title: 'Track',
            itemIds: const [],
            completionRate: 0,
            initiallyExpanded: true,
            onTitleSave: (_) {},
            onCreateItem: (_) async => null,
            onReorder: (_) async {},
            onExpansionChanged: states.add,
          ),
        ),
      );

      await tester.pump();
      expect(states, [true]);

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump(const Duration(milliseconds: 300));

      expect(states, [true, false]);
    });

    // ── Done filter tab ────────────────────────────────────────────────────

    testWidgets('filter strip shows Open, Done, and All tabs', (tester) async {
      await _pump(
        tester,
        initiallyExpanded: true,
        itemIds: const ['x'],
        completionRate: 0.5,
        completedCount: 1,
        totalCount: 2,
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets(
      'shows noneDone message when doneOnly filter and no items done',
      (tester) async {
        await _pump(
          tester,
          initiallyExpanded: true,
          itemIds: const ['x'],
          completedCount: 0,
          totalCount: 1,
        );
        await tester.pump(const Duration(milliseconds: 400));

        // Tap the Done tab
        await tester.tap(find.text('Done'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('No completed items yet.'), findsOneWidget);
      },
    );

    // ── Initial animation skip ─────────────────────────────────────────────

    testWidgets('body appears instantly on first render without animation', (
      tester,
    ) async {
      await _pump(tester, initiallyExpanded: true);

      // On the very first frame the add-field should already be visible
      // (no animation needed) because _hasRendered is false → Duration.zero.
      expect(find.byKey(_addFieldKey).hitTestable(), findsOneWidget);
    });

    testWidgets(
      'collapsed card shows no body on first render without animation',
      (tester) async {
        await _pump(tester, initiallyExpanded: false);

        // Collapsed immediately, no animation.
        expect(find.byKey(_addFieldKey).hitTestable(), findsNothing);
      },
    );

    testWidgets('subsequent toggle uses real animation duration', (
      tester,
    ) async {
      await _pump(tester, initiallyExpanded: true);

      // First frame — body is already visible.
      expect(find.byKey(_addFieldKey).hitTestable(), findsOneWidget);

      // Post-frame callback fires, _hasRendered = true.
      await tester.pump();

      // Now collapse — should use real animation duration (250ms).
      await tester.tap(find.byIcon(Icons.expand_less));

      // After only 50ms, the cross-fade should still be in progress.
      await tester.pump(const Duration(milliseconds: 50));
      // The AnimatedCrossFade is mid-transition — the add field is still
      // in the tree (even if fading) because the animation hasn't completed.
      expect(find.byKey(_addFieldKey), findsOneWidget);

      // After 400ms total, animation should be complete.
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(_addFieldKey).hitTestable(), findsNothing);
    });
  });

  // ── View all (truncation) ──────────────────────────────────────────────────

  group('ChecklistCard View all truncation', () {
    List<ChecklistItem> buildItems(int count) => [
      for (var i = 0; i < count; i++)
        buildTestChecklistItem(id: 'i$i', title: 'Item $i'),
    ];

    testWidgets(
      'short list does not render the View all button or truncate rows',
      (tester) async {
        final items = buildItems(5);
        await _pump(
          tester,
          initiallyExpanded: true,
          itemIds: items.map((i) => i.meta.id).toList(),
          completionRate: 0.2,
          completedCount: 1,
          totalCount: 5,
          overrides: checklistItemOverridesFor(
            items: items,
            taskId: 'task-1',
          ),
        );
        await tester.pump();

        expect(find.text('View all'), findsNothing);
        expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
        // All five rows render (under the 10-item threshold).
        expect(find.byType(ChecklistItemRow), findsNWidgets(5));
      },
    );

    testWidgets(
      'long list truncates to maxVisibleChecklistItems rows and adds the '
      'View all button',
      (tester) async {
        final items = buildItems(15);
        await _pump(
          tester,
          initiallyExpanded: true,
          itemIds: items.map((i) => i.meta.id).toList(),
          completionRate: 0.1,
          completedCount: 1,
          totalCount: 15,
          overrides: checklistItemOverridesFor(
            items: items,
            taskId: 'task-1',
          ),
        );
        await tester.pump();

        // Only the first 10 rows are instantiated inline.
        expect(find.byType(ChecklistItemRow), findsNWidgets(10));
        expect(find.text('View all'), findsOneWidget);
        expect(
          find.byIcon(Icons.keyboard_arrow_down_rounded),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'View all button is wired to a non-null onPressed so the modal '
      'can open',
      (tester) async {
        final items = buildItems(12);
        await _pump(
          tester,
          initiallyExpanded: true,
          itemIds: items.map((i) => i.meta.id).toList(),
          // ignore: avoid_redundant_argument_values
          completionRate: 0,
          completedCount: 0,
          totalCount: 12,
          overrides: checklistItemOverridesFor(
            items: items,
            taskId: 'task-1',
          ),
        );
        await tester.pump();

        // Locate the View-all DesignSystemButton specifically (ignoring any
        // other DS buttons elsewhere in the tree) by its label.
        final buttons = tester
            .widgetList<DesignSystemButton>(
              find.byWidgetPredicate(
                (w) => w is DesignSystemButton && w.label == 'View all',
              ),
            )
            .toList();
        expect(buttons, hasLength(1));
        expect(
          buttons.single.onPressed,
          isNotNull,
          reason:
              'View all button must have a tap handler attached so users '
              'can open the full-list modal',
        );
        expect(
          buttons.single.trailingIcon,
          Icons.keyboard_arrow_down_rounded,
        );
      },
    );

    testWidgets(
      'View all button is hidden when the filter forces the empty state',
      (tester) async {
        // With completionRate: 1.0 + openOnly filter, the body renders the
        // "allDone" message and no truncation logic kicks in — the View all
        // button must not appear because the rows it would sit below are not
        // rendered either.
        final items = buildItems(15);
        await _pump(
          tester,
          initiallyExpanded: true,
          itemIds: items.map((i) => i.meta.id).toList(),
          completionRate: 1,
          completedCount: 15,
          totalCount: 15,
          overrides: checklistItemOverridesFor(
            items: items,
            taskId: 'task-1',
          ),
        );
        await tester.pump();

        expect(find.text('All items completed!'), findsOneWidget);
        expect(find.text('View all'), findsNothing);
      },
    );

    testWidgets(
      'invoking the View all button opens the ChecklistFullListModal sheet',
      (tester) async {
        final items = buildItems(12);
        await _pump(
          tester,
          initiallyExpanded: true,
          itemIds: items.map((i) => i.meta.id).toList(),
          completionRate: 0.1,
          completedCount: 1,
          totalCount: 12,
          // Provide a checklist controller so the modal can read its
          // linkedChecklistItems list when it watches the controller.
          overrides: checklistItemOverridesFor(
            items: items,
            taskId: 'task-1',
            checklistId: 'cl-1',
          ),
        );
        await tester.pump();

        // Sanity: modal not yet on screen.
        expect(find.byType(ChecklistFullListModal), findsNothing);

        // The View all button can land below the test viewport depending
        // on how rows lay out, so invoke its onPressed directly rather
        // than relying on a pixel-coordinate tap. This still exercises
        // the contract — the wired callback opens the modal.
        final viewAllButton = tester.widget<DesignSystemButton>(
          find.byWidgetPredicate(
            (w) => w is DesignSystemButton && w.label == 'View all',
          ),
        );
        viewAllButton.onPressed!();
        await tester.pumpAndSettle();

        // Modal opened with its add-item field keyed for assertions.
        expect(find.byType(ChecklistFullListModal), findsOneWidget);
        expect(
          find.byKey(checklistFullListModalAddFieldKey),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'inline body onReorder persists the new order to the parent '
      'via widget.onReorder',
      (tester) async {
        final items = buildItems(4);
        final persisted = <List<String>>[];
        await _pump(
          tester,
          initiallyExpanded: true,
          itemIds: items.map((i) => i.meta.id).toList(),
          // ignore: avoid_redundant_argument_values
          completionRate: 0,
          completedCount: 0,
          totalCount: 4,
          onReorder: (ids) async => persisted.add(List<String>.of(ids)),
          overrides: checklistItemOverridesFor(
            items: items,
            taskId: 'task-1',
          ),
        );
        await tester.pump();

        // The card renders a single ReorderableListView for its items.
        // Driving a real drag through hit-testing is brittle; instead we
        // locate the widget and invoke its `onReorder` callback directly
        // so the state's `_persistReorder` path runs end-to-end.
        final reorder = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView),
        );
        // Move the first item to position 3 (ReorderableListView contract:
        // newIndex is the index *after* removal, hence 3 for "move to end").
        reorder.onReorder(0, 3);
        await tester.pump();

        expect(persisted, hasLength(1));
        expect(
          persisted.single,
          equals(['i1', 'i2', 'i0', 'i3']),
          reason: 'Item i0 moved to index 2 (before i3) after removal',
        );

        // Also exercise the proxyDecorator so its AnimatedBuilder/Material
        // branch is covered. Pump the decorated widget in a plain
        // MaterialApp — wrapping it back through `makeTestableWidgetWithScaffold`
        // would try to resize the outer `ProviderScope`'s overrides list,
        // which Riverpod refuses.
        const Key placeholderKey = ValueKey('proxy-child');
        final decorated = reorder.proxyDecorator!(
          const SizedBox(key: placeholderKey),
          0,
          kAlwaysCompleteAnimation,
        );
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: decorated)),
        );
        expect(find.byKey(placeholderKey), findsOneWidget);
        expect(find.byType(Material), findsWidgets);
      },
    );
  });
}
