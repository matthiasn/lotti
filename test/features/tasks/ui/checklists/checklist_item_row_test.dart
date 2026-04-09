import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

import '../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _meta = Metadata(
  id: 'item-1',
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
  dateFrom: DateTime(2025),
  dateTo: DateTime(2025),
);

ChecklistItem _makeItem({
  String title = 'Do the thing',
  bool isChecked = false,
  bool isArchived = false,
}) => ChecklistItem(
  meta: _meta,
  data: ChecklistItemData(
    title: title,
    isChecked: isChecked,
    isArchived: isArchived,
    linkedChecklists: const ['checklist-1'],
  ),
);

// ---------------------------------------------------------------------------
// Fake controllers (extend real classes — required for overrideWith)
// ---------------------------------------------------------------------------

class FakeChecklistItemController extends ChecklistItemController {
  FakeChecklistItemController(ChecklistItem? item)
    : _item = item,
      super(const (id: 'fake', taskId: null));

  ChecklistItem? _item;
  bool deleteCalled = false;
  bool archiveCalled = false;
  bool unarchiveCalled = false;
  bool? checkedValue;
  String? updatedTitle;

  @override
  Future<ChecklistItem?> build() async => _item;

  @override
  Future<bool> delete() async {
    deleteCalled = true;
    state = const AsyncData(null);
    return true;
  }

  @override
  void archive() {
    archiveCalled = true;
    if (_item == null) return;
    _item = _item!.copyWith(data: _item!.data.copyWith(isArchived: true));
    state = AsyncData(_item);
  }

  @override
  void unarchive() {
    unarchiveCalled = true;
    if (_item == null) return;
    _item = _item!.copyWith(data: _item!.data.copyWith(isArchived: false));
    state = AsyncData(_item);
  }

  @override
  void updateChecked({required bool checked}) {
    checkedValue = checked;
    if (_item == null) return;
    _item = _item!.copyWith(data: _item!.data.copyWith(isChecked: checked));
    state = AsyncData(_item);
  }

  @override
  void updateTitle(String? title) {
    updatedTitle = title;
    if (_item == null || title == null) return;
    _item = _item!.copyWith(data: _item!.data.copyWith(title: title));
    state = AsyncData(_item);
  }
}

/// Shared state holder for [FakeChecklistController] instances.
class ChecklistControllerCallTracker {
  String? unlinkedItemId;
  String? relinkedItemId;
}

class FakeChecklistController extends ChecklistController {
  FakeChecklistController([this._tracker])
    : super(const (id: 'fake', taskId: null));

  final ChecklistControllerCallTracker? _tracker;

  @override
  Future<Checklist?> build() async => null;

  @override
  Future<void> unlinkItem(String checklistItemId) async {
    _tracker?.unlinkedItemId = checklistItemId;
  }

  @override
  Future<void> relinkItem(String checklistItemId) async {
    _tracker?.relinkedItemId = checklistItemId;
  }
}

class FakeChecklistCompletionService extends ChecklistCompletionService {
  FakeChecklistCompletionService([this._suggestions = const []]);

  final List<ChecklistCompletionSuggestion> _suggestions;
  String? clearedItemId;

  @override
  FutureOr<List<ChecklistCompletionSuggestion>> build() async => _suggestions;

  @override
  void clearSuggestion(String itemId) {
    clearedItemId = itemId;
  }
}

// ---------------------------------------------------------------------------
// Widget pump helpers
// ---------------------------------------------------------------------------

Future<void> _pump(
  WidgetTester tester, {
  ChecklistItem? item,
  bool hideIfChecked = false,
  bool showDivider = false,
  List<ChecklistCompletionSuggestion> suggestions = const [],
}) async {
  final testItem = item ?? _makeItem();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        checklistItemControllerProvider((
          id: 'item-1',
          taskId: 'task-1',
        )).overrideWith(() => FakeChecklistItemController(testItem)),
        checklistControllerProvider((
          id: 'checklist-1',
          taskId: 'task-1',
        )).overrideWith(FakeChecklistController.new),
        checklistCompletionServiceProvider.overrideWith(
          () => FakeChecklistCompletionService(suggestions),
        ),
      ],
      child: makeTestableWidgetWithScaffold(
        ChecklistItemRow(
          itemId: 'item-1',
          checklistId: 'checklist-1',
          taskId: 'task-1',
          index: 0,
          hideIfChecked: hideIfChecked,
          showDivider: showDivider,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Pump variant that returns the injected fake controllers for assertions.
Future<
  ({
    FakeChecklistItemController itemController,
    ChecklistControllerCallTracker checklistTracker,
    FakeChecklistCompletionService completionService,
  })
>
_pumpWithControllers(
  WidgetTester tester, {
  ChecklistItem? item,
  bool hideIfChecked = false,
  List<ChecklistCompletionSuggestion> suggestions = const [],
}) async {
  final testItem = item ?? _makeItem();
  final itemCtrl = FakeChecklistItemController(testItem);
  final tracker = ChecklistControllerCallTracker();
  final completionSvc = FakeChecklistCompletionService(suggestions);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        checklistItemControllerProvider((
          id: 'item-1',
          taskId: 'task-1',
        )).overrideWith(() => itemCtrl),
        checklistControllerProvider.overrideWith(
          () => FakeChecklistController(tracker),
        ),
        checklistCompletionServiceProvider.overrideWith(
          () => completionSvc,
        ),
      ],
      child: makeTestableWidgetWithScaffold(
        ChecklistItemRow(
          itemId: 'item-1',
          checklistId: 'checklist-1',
          taskId: 'task-1',
          index: 0,
          hideIfChecked: hideIfChecked,
        ),
      ),
    ),
  );
  await tester.pump();

  return (
    itemController: itemCtrl,
    checklistTracker: tracker,
    completionService: completionSvc,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChecklistItemRow', () {
    setUpAll(setUpTestGetIt);

    tearDownAll(() async {
      await tearDownTestGetIt();
    });

    // ── Rendering ──────────────────────────────────────────────────────────

    testWidgets('renders title and checkbox', (tester) async {
      await _pump(tester, item: _makeItem(title: 'Buy milk'));

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('unchecked item shows unchecked Checkbox', (tester) async {
      await _pump(tester, item: _makeItem());

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('checked item shows checked Checkbox', (tester) async {
      await _pump(tester, item: _makeItem(isChecked: true));

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('checked item shows strikethrough text style', (tester) async {
      await _pump(tester, item: _makeItem(title: 'Done item', isChecked: true));

      final textWidget = tester.widget<Text>(find.text('Done item'));
      expect(textWidget.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('unchecked item does not show strikethrough', (tester) async {
      await _pump(tester, item: _makeItem(title: 'Open item'));

      final textWidget = tester.widget<Text>(find.text('Open item'));
      expect(textWidget.style?.decoration, isNot(TextDecoration.lineThrough));
    });

    testWidgets('drag handle icon is present', (tester) async {
      await _pump(tester);
      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    });

    testWidgets(
      'row expands beyond minimum height for multi-line text',
      (tester) async {
        final longTitle = List.generate(5, (i) => 'Line $i').join('\n');
        await _pump(tester, item: _makeItem(title: longTitle));

        // The row should grow taller than the 44px minimum to fit
        // multi-line content without clipping.
        final rowBox = tester.renderObject<RenderBox>(
          find.byType(ChecklistItemRow),
        );
        expect(rowBox.size.height, greaterThan(44));
      },
    );

    testWidgets(
      'inline editor expands beyond minimum height for multi-line text',
      (tester) async {
        final longTitle = List.generate(5, (i) => 'Line $i').join('\n');
        await _pump(tester, item: _makeItem(title: longTitle));

        // Enter edit mode.
        await tester.tap(find.byIcon(Icons.mode_edit_outlined));
        await tester.pump();

        final rowBox = tester.renderObject<RenderBox>(
          find.byType(ChecklistItemRow),
        );
        expect(rowBox.size.height, greaterThan(44));
      },
    );

    testWidgets('edit icon is present', (tester) async {
      await _pump(tester);
      expect(find.byIcon(Icons.mode_edit_outlined), findsOneWidget);
    });

    // ── Edit mode ──────────────────────────────────────────────────────────

    testWidgets('tapping edit icon switches to edit mode', (tester) async {
      await _pump(tester, item: _makeItem(title: 'Edit me'));

      await tester.tap(find.byIcon(Icons.mode_edit_outlined));
      await tester.pump();

      expect(find.byType(TitleTextField), findsOneWidget);
      // Pencil icon hidden while editing.
      expect(find.byIcon(Icons.mode_edit_outlined), findsNothing);
    });

    testWidgets('tapping title text does NOT enter edit mode', (tester) async {
      await _pump(tester, item: _makeItem(title: 'Just text'));

      await tester.tap(find.text('Just text'));
      await tester.pump();

      // Only the pencil icon triggers editing — not a tap on the title.
      expect(find.byType(TitleTextField), findsNothing);
      expect(find.byIcon(Icons.mode_edit_outlined), findsOneWidget);
    });

    testWidgets('edit mode calls updateTitle on save', (tester) async {
      final controller = FakeChecklistItemController(
        _makeItem(title: 'Old title'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider((
              id: 'item-1',
              taskId: 'task-1',
            )).overrideWith(() => controller),
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).overrideWith(FakeChecklistController.new),
            checklistCompletionServiceProvider.overrideWith(
              FakeChecklistCompletionService.new,
            ),
          ],
          child: makeTestableWidgetWithScaffold(
            const ChecklistItemRow(
              itemId: 'item-1',
              checklistId: 'checklist-1',
              taskId: 'task-1',
              index: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.mode_edit_outlined));
      await tester.pump();

      await tester.enterText(find.byType(TitleTextField), 'New title');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.updatedTitle, 'New title');
    });

    // ── Divider ────────────────────────────────────────────────────────────

    testWidgets('shows divider when showDivider is true', (tester) async {
      await _pump(tester, showDivider: true);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('no divider when showDivider is false', (tester) async {
      await _pump(tester);
      expect(find.byType(Divider), findsNothing);
    });

    // ── Null item ──────────────────────────────────────────────────────────

    testWidgets('returns SizedBox.shrink for null item', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider((
              id: 'item-1',
              taskId: 'task-1',
            )).overrideWith(() => FakeChecklistItemController(null)),
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).overrideWith(FakeChecklistController.new),
            checklistCompletionServiceProvider.overrideWith(
              FakeChecklistCompletionService.new,
            ),
          ],
          child: makeTestableWidgetWithScaffold(
            const ChecklistItemRow(
              itemId: 'item-1',
              checklistId: 'checklist-1',
              taskId: 'task-1',
              index: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Checkbox), findsNothing);
    });

    // ── Checkbox interaction ───────────────────────────────────────────────

    testWidgets('tapping checkbox calls updateChecked', (tester) async {
      final ctrls = await _pumpWithControllers(tester);
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(ctrls.itemController.checkedValue, isTrue);
    });

    testWidgets('checkbox is disabled when item is archived', (tester) async {
      await _pump(tester, item: _makeItem(isArchived: true));

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNull);
    });

    // ── Swipe to archive ───────────────────────────────────────────────────

    testWidgets('swipe right archives item and shows snackbar', (
      tester,
    ) async {
      final ctrls = await _pumpWithControllers(tester);
      await tester.pump();

      // Swipe right (startToEnd)
      await tester.drag(
        find.byType(Dismissible),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();

      expect(ctrls.itemController.archiveCalled, isTrue);
      expect(find.text('Item archived'), findsOneWidget);
    });

    testWidgets('swipe right on archived item calls unarchive', (
      tester,
    ) async {
      final ctrls = await _pumpWithControllers(
        tester,
        item: _makeItem(isArchived: true),
      );
      await tester.pump();

      await tester.drag(
        find.byType(Dismissible),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();

      expect(ctrls.itemController.unarchiveCalled, isTrue);
    });

    // ── Swipe to delete ────────────────────────────────────────────────────

    testWidgets('swipe left dismisses and shows delete snackbar', (
      tester,
    ) async {
      final ctrls = await _pumpWithControllers(tester);
      await tester.pump();

      // Swipe left (endToStart)
      await tester.drag(
        find.byType(Dismissible),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      expect(ctrls.checklistTracker.unlinkedItemId, 'item-1');
      expect(find.text('Item deleted'), findsOneWidget);
    });

    testWidgets(
      'checking item with active suggestion clears it',
      (tester) async {
        final completionSvc = FakeChecklistCompletionService([
          const ChecklistCompletionSuggestion(
            checklistItemId: 'item-1',
            confidence: ChecklistCompletionConfidence.medium,
            reason: 'Looks done',
          ),
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              checklistItemControllerProvider((
                id: 'item-1',
                taskId: 'task-1',
              )).overrideWith(
                () => FakeChecklistItemController(_makeItem()),
              ),
              checklistControllerProvider((
                id: 'checklist-1',
                taskId: 'task-1',
              )).overrideWith(FakeChecklistController.new),
              checklistCompletionServiceProvider.overrideWith(
                () => completionSvc,
              ),
            ],
            child: makeTestableWidgetWithScaffold(
              const ChecklistItemRow(
                itemId: 'item-1',
                checklistId: 'checklist-1',
                taskId: 'task-1',
                index: 0,
              ),
            ),
          ),
        );
        // Two pumps: one to resolve async providers, one to rebuild.
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        expect(completionSvc.clearedItemId, 'item-1');
      },
    );

    // ── Hide-state machine ──────────────────────────────────────────────

    group('hide-state machine', () {
      testWidgets(
        'item checked while hideIfChecked=true triggers fade-out',
        (tester) async {
          final _ = await _pumpWithControllers(
            tester,
            hideIfChecked: true,
          );
          await tester.pump();

          // Verify initially visible (showFirst).
          final crossFadeBefore = tester.widget<AnimatedCrossFade>(
            find.byType(AnimatedCrossFade),
          );
          expect(crossFadeBefore.crossFadeState, CrossFadeState.showFirst);

          // Tap checkbox to check the item.
          await tester.tap(find.byType(Checkbox));
          await tester.pump();

          // After 1100ms the hold timer (1000ms) fires and hides the row.
          await tester.pump(const Duration(milliseconds: 1100));

          final crossFadeAfter = tester.widget<AnimatedCrossFade>(
            find.byType(AnimatedCrossFade),
          );
          expect(crossFadeAfter.crossFadeState, CrossFadeState.showSecond);
        },
      );

      testWidgets(
        'filter toggled to show-all reveals hidden items',
        (tester) async {
          // Start with a checked item and hideIfChecked=true.
          var hideIfChecked = true;
          late StateSetter outerSetState;

          final itemCtrl = FakeChecklistItemController(
            _makeItem(isChecked: true),
          );
          final tracker = ChecklistControllerCallTracker();
          final completionSvc = FakeChecklistCompletionService();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                checklistItemControllerProvider((
                  id: 'item-1',
                  taskId: 'task-1',
                )).overrideWith(() => itemCtrl),
                checklistControllerProvider.overrideWith(
                  () => FakeChecklistController(tracker),
                ),
                checklistCompletionServiceProvider.overrideWith(
                  () => completionSvc,
                ),
              ],
              child: makeTestableWidgetWithScaffold(
                StatefulBuilder(
                  builder: (context, setState) {
                    outerSetState = setState;
                    return ChecklistItemRow(
                      itemId: 'item-1',
                      checklistId: 'checklist-1',
                      taskId: 'task-1',
                      index: 0,
                      hideIfChecked: hideIfChecked,
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pump();

          // The checked item with hideIfChecked starts hidden immediately
          // because the ref.listen fires on first data load.
          // Pump to let the timer-based or immediate hide take effect.
          await tester.pump(const Duration(milliseconds: 1100));

          final crossFadeHidden = tester.widget<AnimatedCrossFade>(
            find.byType(AnimatedCrossFade),
          );
          expect(crossFadeHidden.crossFadeState, CrossFadeState.showSecond);

          // Toggle filter to show all.
          outerSetState(() => hideIfChecked = false);
          await tester.pump();

          // hideIfChecked is now false, so no AnimatedCrossFade should be
          // present (the widget only wraps in AnimatedCrossFade when
          // hideIfChecked is true).
          expect(find.byType(AnimatedCrossFade), findsNothing);

          // The row content should be visible.
          expect(find.byType(Checkbox), findsOneWidget);
        },
      );

      testWidgets(
        'item unchecked restores visibility',
        (tester) async {
          final ctrls = await _pumpWithControllers(
            tester,
            item: _makeItem(isChecked: true),
            hideIfChecked: true,
          );
          await tester.pump();

          // The checked item starts and the ref.listen fires, triggering hide.
          await tester.pump(const Duration(milliseconds: 1100));

          final crossFadeHidden = tester.widget<AnimatedCrossFade>(
            find.byType(AnimatedCrossFade),
          );
          expect(crossFadeHidden.crossFadeState, CrossFadeState.showSecond);

          // Uncheck the item.
          // The checkbox is inside the hidden branch of AnimatedCrossFade,
          // so we call the controller directly.
          ctrls.itemController.updateChecked(checked: false);
          await tester.pump();

          final crossFadeVisible = tester.widget<AnimatedCrossFade>(
            find.byType(AnimatedCrossFade),
          );
          expect(crossFadeVisible.crossFadeState, CrossFadeState.showFirst);
        },
      );
    });

    // ── AnimatedCrossFade wrapping ──────────────────────────────────────

    group('AnimatedCrossFade wrapping', () {
      testWidgets(
        'hideIfChecked=true wraps in AnimatedCrossFade',
        (tester) async {
          await _pump(tester, hideIfChecked: true);
          expect(find.byType(AnimatedCrossFade), findsOneWidget);
        },
      );

      testWidgets(
        'hideIfChecked=false does not use AnimatedCrossFade',
        (tester) async {
          await _pump(tester);
          expect(find.byType(AnimatedCrossFade), findsNothing);
        },
      );
    });

    // ── Suggestion animation ────────────────────────────────────────────

    group('suggestion animation', () {
      testWidgets(
        'suggestion present wraps content in Stack with Positioned bar',
        (tester) async {
          await _pumpWithControllers(
            tester,
            suggestions: [
              const ChecklistCompletionSuggestion(
                checklistItemId: 'item-1',
                confidence: ChecklistCompletionConfidence.high,
                reason: 'Looks done',
              ),
            ],
          );
          // Extra pump so the completion-service async provider resolves.
          await tester.pump();

          // When a suggestion is present, the row content is wrapped in a
          // Stack. Verify the suggestion bar container (8px wide with
          // BoxDecoration) exists.
          final barFinder = find.descendant(
            of: find.byType(GestureDetector),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  w.constraints?.maxWidth == 8,
            ),
          );
          expect(barFinder, findsOneWidget);
        },
      );

      testWidgets(
        'no suggestion means no suggestion bar container',
        (tester) async {
          await _pumpWithControllers(tester);
          await tester.pump();

          // Without suggestion, no 8px bar container.
          final barFinder = find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                w.constraints?.maxWidth == 8,
          );
          expect(barFinder, findsNothing);
        },
      );
    });

    // ── Suggestion dialog ───────────────────────────────────────────────

    group('suggestion dialog', () {
      const testSuggestion = ChecklistCompletionSuggestion(
        checklistItemId: 'item-1',
        confidence: ChecklistCompletionConfidence.high,
        reason: 'Journal mentions completion',
      );

      Future<void> openSuggestionDialog(WidgetTester tester) async {
        // The suggestion bar is a Container with width: 8 and a BoxDecoration,
        // inside a GestureDetector within a Positioned. The Container
        // constructor stores width as BoxConstraints.tightFor internally.
        final barFinder = find.descendant(
          of: find.byType(GestureDetector),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                w.constraints?.maxWidth == 8,
          ),
        );
        expect(barFinder, findsOneWidget);
        await tester.tap(barFinder);
        // Use pump (not pumpAndSettle) because the suggestion animation
        // repeats forever and would cause pumpAndSettle to time out.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      testWidgets(
        'tapping suggestion bar opens dialog with correct content',
        (tester) async {
          await _pumpWithControllers(
            tester,
            suggestions: [testSuggestion],
          );
          await tester.pump();

          await openSuggestionDialog(tester);

          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text('AI Suggestion'), findsOneWidget);
          expect(find.text('Journal mentions completion'), findsOneWidget);
          expect(find.text('Confidence: high'), findsOneWidget);
          expect(find.byIcon(Icons.insights), findsOneWidget);
        },
      );

      testWidgets(
        'Cancel button in dialog clears suggestion',
        (tester) async {
          final ctrls = await _pumpWithControllers(
            tester,
            suggestions: [testSuggestion],
          );
          await tester.pump();

          await openSuggestionDialog(tester);

          await tester.tap(find.text('Cancel'));
          await tester.pump();

          expect(ctrls.completionService.clearedItemId, 'item-1');
        },
      );

      testWidgets(
        'Mark Complete button checks item and clears suggestion',
        (tester) async {
          final ctrls = await _pumpWithControllers(
            tester,
            suggestions: [testSuggestion],
          );
          await tester.pump();

          await openSuggestionDialog(tester);

          await tester.tap(find.text('Mark Complete'));
          await tester.pump();

          expect(ctrls.itemController.checkedValue, isTrue);
          expect(ctrls.completionService.clearedItemId, 'item-1');
        },
      );
    });
  });
}
