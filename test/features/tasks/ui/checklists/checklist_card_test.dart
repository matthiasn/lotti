import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/platform.dart' as platform_utils;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../widget_test_utils.dart';

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
  VoidCallback? onDelete,
  VoidCallback? onExportMarkdown,
  VoidCallback? onShareMarkdown,
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
        onDelete: onDelete,
        onExportMarkdown: onExportMarkdown,
        onShareMarkdown: onShareMarkdown,
      ),
    ),
  );
}

void main() {
  group('ChecklistCard', () {
    // ── Expansion ────────────────────────────────────────────────────────────

    testWidgets('renders title and chevron in expanded state', (tester) async {
      await _pump(tester, initiallyExpanded: true);

      expect(find.text('My Checklist'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('tapping chevron toggles expansion', (tester) async {
      await _pump(tester, initiallyExpanded: true);

      // Expanded → add field hit-testable (non-zero size)
      expect(find.byKey(_addFieldKey).hitTestable(), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump(const Duration(milliseconds: 400));

      // Collapsed → add field clipped to zero, not hit-testable
      expect(find.byKey(_addFieldKey).hitTestable(), findsNothing);

      // Tap again → expands
      await tester.tap(find.byIcon(Icons.expand_more));
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

    testWidgets(
      'outer pill border animates from decorative.level01 to '
      'interactive.enabled when the add-item field gains focus, and back '
      'when it loses focus',
      (tester) async {
        await _pump(tester, initiallyExpanded: true);

        Color readBorderColor() {
          final container = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byKey(_addFieldKey),
              matching: find.byType(AnimatedContainer),
            ),
          );
          final decoration = container.decoration! as BoxDecoration;
          return decoration.border!.top.color;
        }

        const tokens = dsTokensLight;

        // Initial: unfocused, so the hairline is the decorative level.
        expect(readBorderColor(), tokens.colors.decorative.level01);

        // Tap into the field → focus → border fades to the interactive
        // accent. The cross-fade is a fixed 200 ms AnimatedContainer, so a
        // bounded pump past that duration is enough — no open-ended
        // pumpAndSettle (which risks the 10 s timeout) is needed.
        await tester.tap(find.byKey(_addFieldKey));
        await tester.pump(const Duration(milliseconds: 250));
        expect(readBorderColor(), tokens.colors.interactive.enabled);

        // Defocus by tapping the header title area; the border should
        // fade back to the decorative hairline.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 250));
        expect(readBorderColor(), tokens.colors.decorative.level01);
      },
    );

    testWidgets(
      'focus cross-fade actually interpolates — mid-animation the painted '
      'border colour is neither idle nor focused',
      (tester) async {
        await _pump(tester, initiallyExpanded: true);

        // Read the *painted* decoration from the render object, not the
        // AnimatedContainer widget's target decoration. The widget's
        // `decoration` property is the end-state; the RenderDecoratedBox
        // the AnimatedContainer builds holds the interpolated decoration
        // at each frame.
        BoxDecoration readPaintedDecoration() {
          final render = tester.firstRenderObject<RenderDecoratedBox>(
            find.descendant(
              of: find.descendant(
                of: find.byKey(_addFieldKey),
                matching: find.byType(AnimatedContainer),
              ),
              matching: find.byType(DecoratedBox),
            ),
          );
          return render.decoration as BoxDecoration;
        }

        const tokens = dsTokensLight;
        final idle = tokens.colors.decorative.level01;
        final focused = tokens.colors.interactive.enabled;

        expect(readPaintedDecoration().border!.top.color, idle);

        // Focus the field to start the 200 ms cross-fade.
        await tester.tap(find.byKey(_addFieldKey));
        await tester.pump(); // commit the rebuild that starts the animation

        // Halfway through the fade: the painted colour must be neither
        // endpoint, proving the AnimatedContainer is interpolating rather
        // than snapping to the target.
        await tester.pump(const Duration(milliseconds: 100));
        final mid = readPaintedDecoration().border!.top.color;
        expect(mid, isNot(idle));
        expect(mid, isNot(focused));

        // Past the duration: settled on the focused colour.
        await tester.pump(const Duration(milliseconds: 120));
        expect(readPaintedDecoration().border!.top.color, focused);
      },
    );

    testWidgets(
      'outer pill border width stays at 1 px across the focus toggle so '
      'the row never breathes',
      (tester) async {
        await _pump(tester, initiallyExpanded: true);

        double readBorderWidth() {
          final container = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byKey(_addFieldKey),
              matching: find.byType(AnimatedContainer),
            ),
          );
          final decoration = container.decoration! as BoxDecoration;
          return decoration.border!.top.width;
        }

        expect(readBorderWidth(), 1.0);

        // Bounded pumps past the 200 ms focus cross-fade make the timing
        // intent explicit and avoid the pumpAndSettle 10 s timeout risk.
        await tester.tap(find.byKey(_addFieldKey));
        await tester.pump(const Duration(milliseconds: 250));
        expect(readBorderWidth(), 1.0);

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 250));
        expect(readBorderWidth(), 1.0);
      },
    );

    testWidgets(
      'add-item field silences every themed border so the pill does not '
      'sprout a second outline on focus',
      (tester) async {
        await _pump(tester, initiallyExpanded: true);

        final decoration = tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(_addFieldKey),
                matching: find.byType(TextField),
              ),
            )
            .decoration!;

        // Every state-specific border must be disabled — the outer
        // AnimatedContainer already draws the pill, and the themed
        // InputDecorationTheme would otherwise overlay a 2.5 px primary
        // outline on focus.
        expect(decoration.border, InputBorder.none);
        expect(decoration.enabledBorder, InputBorder.none);
        expect(decoration.focusedBorder, InputBorder.none);
        expect(decoration.disabledBorder, InputBorder.none);
        expect(decoration.errorBorder, InputBorder.none);
        expect(decoration.focusedErrorBorder, InputBorder.none);
        // Fill is off so the themed `fillColor` (a subtle primary tint)
        // doesn't leak into the pill either.
        expect(decoration.filled, isFalse);
      },
    );

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

    testWidgets('an all-whitespace submission never calls onCreateItem', (
      tester,
    ) async {
      var calls = 0;
      await _pump(
        tester,
        initiallyExpanded: true,
        onCreateItem: (title) async {
          calls++;
          return 'new-id';
        },
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(_addFieldKey),
          matching: find.byType(TextField),
        ),
        '   ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(calls, 0);
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
            onExpansionChanged: states.add,
          ),
        ),
      );

      await tester.pump();
      expect(states, [true]);

      await tester.tap(find.byIcon(Icons.expand_more));
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

    // ── Body padding ────────────────────────────────────────────────────────

    testWidgets(
      'body ListView opts out of ambient MediaQuery.padding so safe-area '
      'insets (e.g. iPhone notch) do not push items below the filter strip',
      (tester) async {
        // Wrap the card in a MediaQuery that simulates a 47px notch top
        // inset reaching the body. Without `padding: EdgeInsets.zero` on
        // the ListView, BoxScrollView absorbs MediaQuery.padding into its
        // resolved SliverPadding — which is what produced the spacing bug
        // when #3060 swapped ReorderableListView.builder for ListView.
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 47),
              ),
              child: ChecklistCard(
                id: 'cl-1',
                taskId: 'task-1',
                title: 'My Checklist',
                itemIds: const [],
                completionRate: 0,
                initiallyExpanded: true,
                onTitleSave: (_) {},
                onCreateItem: (_) async => null,
              ),
            ),
          ),
        );

        // The ListView resolves its slivers down through a SliverPadding.
        // With the fix in place, that resolved padding is zero — even with
        // a 47px top inset above the card. Without the fix, BoxScrollView
        // would build SliverPadding(EdgeInsets.only(top: 47)) here.
        final sliverPadding = tester.widget<SliverPadding>(
          find.descendant(
            of: find.descendant(
              of: find.byType(ChecklistCard),
              matching: find.byType(ListView),
            ),
            matching: find.byType(SliverPadding),
          ),
        );
        expect(sliverPadding.padding, EdgeInsets.zero);
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
      await tester.tap(find.byIcon(Icons.expand_more));

      // After only 50ms, the cross-fade should still be in progress.
      await tester.pump(const Duration(milliseconds: 50));
      // The AnimatedCrossFade is mid-transition — the add field is still
      // in the tree (even if fading) because the animation hasn't completed.
      expect(find.byKey(_addFieldKey), findsOneWidget);

      // After 400ms total, animation should be complete.
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(_addFieldKey).hitTestable(), findsNothing);
    });

    // ── Open filter tab onTap ───────────────────────────────────────────────

    testWidgets(
      'tapping the Open tab restores the openOnly filter (its text goes bold '
      'and the Done tab loses bold)',
      (tester) async {
        // Empty itemIds keeps the row ListView empty (real ChecklistItemRow
        // providers are not wired in this test), while totalCount > 0 keeps
        // the filter strip visible.
        await _pump(
          tester,
          initiallyExpanded: true,
          completedCount: 0,
          totalCount: 3,
        );
        await tester.pump(const Duration(milliseconds: 400));

        // Move off the default openOnly filter by selecting Done, so Open is
        // no longer bold.
        await tester.tap(find.text('Done'));
        await tester.pump(const Duration(milliseconds: 400));

        final openWhileDone = tester
            .widgetList<Text>(find.text('Open'))
            .toList();
        expect(
          openWhileDone.every((t) => t.style?.fontWeight != FontWeight.w600),
          isTrue,
          reason: 'Open tab should not be bold while Done is selected',
        );

        // Tap the Open tab — exercises its onTap → onFilterChanged(openOnly).
        await tester.tap(find.text('Open'));
        await tester.pump(const Duration(milliseconds: 400));

        // The openOnly callback fired: the Open tab is bold again and Done is
        // no longer bold.
        final openAfter = tester.widgetList<Text>(find.text('Open')).toList();
        expect(
          openAfter.any((t) => t.style?.fontWeight == FontWeight.w600),
          isTrue,
          reason: 'Open tab should be bold after being re-selected',
        );
        final doneAfter = tester.widgetList<Text>(find.text('Done')).toList();
        expect(
          doneAfter.every((t) => t.style?.fontWeight != FontWeight.w600),
          isTrue,
          reason: 'Done tab should not be bold after Open is re-selected',
        );
      },
    );

    // ── Delete dialog cancel ────────────────────────────────────────────────

    testWidgets(
      'tapping Cancel in the delete dialog dismisses it without invoking '
      'onDelete',
      (tester) async {
        var deleted = false;
        await _pump(
          tester,
          initiallyExpanded: true,
          onDelete: () => deleted = true,
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Open the confirmation dialog via the Delete menu entry.
        await tester.tap(find.text('Delete checklist?'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);

        // Tap Cancel → Navigator.pop(false) → onDelete must NOT be called.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(deleted, isFalse);
      },
    );

    // ── Filter preference string-path migration ─────────────────────────────

    testWidgets(
      'restores a persisted string filter preference on first build',
      (tester) async {
        // In the normal test env, makeSharedPrefsService().getString returns
        // null unconditionally, so the string-parse path in
        // _loadFilterPreference is never taken. Temporarily disable the test
        // env so the real SharedPreferences-backed getString runs and returns
        // the seeded value.
        SharedPreferences.setMockInitialValues({
          'checklist_filter_mode_cl-1': ChecklistFilter.doneOnly.name,
        });
        final prevIsTestEnv = platform_utils.isTestEnv;
        platform_utils.isTestEnv = false;
        addTearDown(() => platform_utils.isTestEnv = prevIsTestEnv);

        await _pump(
          tester,
          initiallyExpanded: true,
          itemIds: const ['x'],
          completedCount: 0,
          totalCount: 1,
        );
        // Let the async _loadFilterPreference future resolve and the filter
        // strip animation settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The persisted doneOnly filter must now be active: the Done tab is
        // bold and the doneOnly empty state is shown.
        final doneTexts = tester.widgetList<Text>(find.text('Done')).toList();
        expect(
          doneTexts.any((t) => t.style?.fontWeight == FontWeight.w600),
          isTrue,
          reason: 'Done tab should be bold from the persisted preference',
        );
        expect(find.text('No completed items yet.'), findsOneWidget);
      },
    );

    testWidgets(
      'migrates a legacy bool=false preference to ChecklistFilter.all',
      (tester) async {
        // Only the legacy bool key exists: false → ChecklistFilter.all, and
        // the preference is rewritten in the new string form.
        SharedPreferences.setMockInitialValues({
          'checklist_filter_mode_cl-1': false,
        });
        final prevIsTestEnv = platform_utils.isTestEnv;
        platform_utils.isTestEnv = false;
        addTearDown(() => platform_utils.isTestEnv = prevIsTestEnv);

        await _pump(
          tester,
          initiallyExpanded: true,
          completedCount: 0,
          totalCount: 0,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The preference is rewritten as the new string form with the
        // migrated `all` value.
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('checklist_filter_mode_cl-1'),
          ChecklistFilter.all.name,
        );
      },
    );

    testWidgets(
      'migrates a legacy bool=true preference to ChecklistFilter.openOnly',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'checklist_filter_mode_cl-1': true,
        });
        final prevIsTestEnv = platform_utils.isTestEnv;
        platform_utils.isTestEnv = false;
        addTearDown(() => platform_utils.isTestEnv = prevIsTestEnv);

        await _pump(
          tester,
          initiallyExpanded: true,
          completedCount: 0,
          totalCount: 0,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The preference is rewritten in the new string form with the
        // migrated openOnly value.
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('checklist_filter_mode_cl-1'),
          ChecklistFilter.openOnly.name,
        );
      },
    );
  });

  group('resolveCompletedCount — properties', () {
    glados.Glados2(
      glados.any.intInRange(0, 1001),
      glados.any.intInRange(0, 101),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'derived count is rounded rate*total, bounded by [0, total], and an '
      'explicit completedCount always wins',
      (ratePermille, total) {
        final rate = ratePermille / 1000;

        final derived = resolveCompletedCount(
          completedCount: null,
          completionRate: rate,
          total: total,
        );
        expect(derived, (rate * total).round(), reason: 'rate=$rate t=$total');
        expect(derived, inInclusiveRange(0, total == 0 ? 0 : total));

        // Explicit override dominates regardless of the rate math.
        expect(
          resolveCompletedCount(
            completedCount: 7,
            completionRate: rate,
            total: total,
          ),
          7,
        );

        // Empty checklist short-circuits to zero even at full rate.
        expect(
          resolveCompletedCount(
            completedCount: null,
            completionRate: rate,
            total: 0,
          ),
          0,
        );
      },
      tags: 'glados',
    );
  });

  group('buildChecklistProgressRing — properties', () {
    // The helper is a pure widget factory: no BuildContext is needed, so it
    // can be invoked directly and the returned tree inspected without pumping.
    //
    // NOTE on "clamping": the `CircularProgressIndicator.value` field stores
    // the raw input verbatim — Flutter only clamps to [0, 1] internally via its
    // private `_effectiveValue`/painter when rendering. Asserting that private
    // render-time clamp would be testing a third-party implementation detail.
    // The invariant that belongs to *our* code is that the helper forwards
    // `completionRate` to the indicator unmodified for ANY input (including
    // out-of-range / NaN-adjacent extremes); a future provider arithmetic bug
    // that mangles the rate before it reaches the ring would break this.
    glados.Glados<int>(
      // ‰ steps spanning well past both ends of [0, 1] to cover negative and
      // > 1 inputs the provider could theoretically emit.
      glados.any.intInRange(-500, 2001),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'forwards completionRate verbatim to the indicator value and always '
      'paints the success color',
      (ratePermille) {
        final rate = ratePermille / 1000;

        final ring = buildChecklistProgressRing(
          completionRate: rate,
          lowEmphasisColor: dsTokensLight.colors.text.lowEmphasis,
          semanticsLabel: 'progress',
        );

        final sizedBox = ring as SizedBox;
        final indicator = sizedBox.child! as CircularProgressIndicator;

        expect(indicator.value, rate, reason: 'rate=$rate was not forwarded');
        expect(indicator.color, successColor);
        expect(indicator.semanticsLabel, 'progress');
      },
      tags: 'glados',
    );
  });
}
