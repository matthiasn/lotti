import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../widget_test_utils.dart';
import 'drag_test_fakes.dart';

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
  Object? droppedLocalData;
  int? droppedTargetIndex;
  String? droppedTargetItemId;
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

  @override
  Future<void> dropChecklistItem(
    Object? localData, {
    String? categoryId,
    int? targetIndex,
    String? targetItemId,
  }) async {
    _tracker
      ?..droppedLocalData = localData
      ..droppedTargetIndex = targetIndex
      ..droppedTargetItemId = targetItemId;
  }
}

/// Minimal [DropSession] fake holding a fixed item list (avoids Mock +
/// Diagnosticable inheritance issues).
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

  /// Expose the Notifier's [state] setter so tests can push new data.
  void setSuggestions(List<ChecklistCompletionSuggestion> suggestions) {
    state = AsyncData(suggestions);
  }
}

// ---------------------------------------------------------------------------
// Widget pump helpers
// ---------------------------------------------------------------------------

/// Controller whose async build throws, to exercise the row's error branch.
class _ErrorChecklistItemController extends ChecklistItemController {
  _ErrorChecklistItemController() : super(const (id: 'fake', taskId: null));

  @override
  Future<ChecklistItem?> build() async => throw Exception('load failed');
}

Future<void> _pump(
  WidgetTester tester, {
  ChecklistItem? item,
  bool hideIfChecked = false,
  bool hideIfUnchecked = false,
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
          hideIfUnchecked: hideIfUnchecked,
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
  bool hideIfUnchecked = false,
  List<ChecklistCompletionSuggestion> suggestions = const [],
  List<Override> extraOverrides = const [],
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
        ...extraOverrides,
      ],
      child: makeTestableWidgetWithScaffold(
        ChecklistItemRow(
          itemId: 'item-1',
          checklistId: 'checklist-1',
          taskId: 'task-1',
          index: 0,
          hideIfChecked: hideIfChecked,
          hideIfUnchecked: hideIfUnchecked,
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

    testWidgets('surfaces an ErrorWidget when the item fails to load', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistItemControllerProvider((
              id: 'item-1',
              taskId: 'task-1',
            )).overrideWith(_ErrorChecklistItemController.new),
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

      expect(find.byType(ErrorWidget), findsOneWidget);
    });

    testWidgets('checked item shows checked Checkbox', (tester) async {
      await _pump(tester, item: _makeItem(isChecked: true));

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('checked item shows strikethrough text style', (tester) async {
      await _pump(tester, item: _makeItem(title: 'Done item', isChecked: true));
      // The title is rendered by StrikethroughWipe as two glyph-aligned layers
      // (an un-struck base and a struck overlay). A checked item reveals the
      // struck layer, so a lineThrough decoration is present among them.
      final decorations = tester
          .widgetList<Text>(find.text('Done item'))
          .map((t) => t.style?.decoration)
          .toList();
      expect(decorations, contains(TextDecoration.lineThrough));
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
      final ctrls = await _pumpWithControllers(
        tester,
        item: _makeItem(title: 'Old title'),
      );

      await tester.tap(find.byIcon(Icons.mode_edit_outlined));
      await tester.pump();

      await tester.enterText(find.byType(TitleTextField), 'New title');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(ctrls.itemController.updatedTitle, 'New title');
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

    testWidgets('divider sits above the row content (leading)', (tester) async {
      // The separator is a leading child of the row, not a trailing one, so it
      // is bound to the same widget as the item below it — an appended row and
      // the line above it always mount together.
      await _pump(tester, showDivider: true);
      final dividerTop = tester.getTopLeft(find.byType(Divider)).dy;
      final checkboxTop = tester.getTopLeft(find.byType(Checkbox)).dy;
      expect(dividerTop, lessThan(checkboxTop));
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

    testWidgets(
      'tapping the enlarged tap target off the checkbox also toggles it',
      (tester) async {
        final ctrls = await _pumpWithControllers(tester);
        await tester.pump();

        // The 20x20 checkbox is centred in a 44x44 InkWell. Tap the ring
        // around the box (outside the central Checkbox) to exercise the
        // enlarged motor-friendly hit target rather than the box itself.
        final inkWell = find
            .ancestor(
              of: find.byType(Checkbox),
              matching: find.byType(InkWell),
            )
            .first;
        // The enlarged target lights up on hover/press so it is visible, not
        // just promised.
        expect(
          tester.widget<InkWell>(inkWell).hoverColor,
          isNotNull,
          reason: 'the 44px tap target highlights on hover',
        );
        final rect = tester.getRect(inkWell);
        await tester.tapAt(Offset(rect.left + 3, rect.center.dy));
        await tester.pump();

        expect(ctrls.itemController.checkedValue, isTrue);
      },
    );

    testWidgets('checking an item fires a light haptic and pops the checkbox', (
      tester,
    ) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String? ?? '');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final popFinder = find.ancestor(
        of: find.byType(Checkbox),
        matching: find.byType(ScaleTransition),
      );

      await _pumpWithControllers(tester);
      await tester.pump();

      double popScale() =>
          tester.widget<ScaleTransition>(popFinder).scale.value;

      // At rest the checkbox sits at its natural scale.
      expect(popScale(), moreOrLessEquals(1, epsilon: 0.001));

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // A light-impact haptic fired on the not-checked → checked edge.
      expect(haptics, contains('HapticFeedbackType.lightImpact'));

      // The check "pop" is mid-flight: the checkbox has scaled past rest.
      await tester.pump(const Duration(milliseconds: 150));
      expect(popScale(), greaterThan(1.05));

      // …and settles back to its natural scale.
      await tester.pumpAndSettle();
      expect(popScale(), moreOrLessEquals(1, epsilon: 0.01));
    });

    testWidgets('checking an item fires a spark burst at the checkbox', (
      tester,
    ) async {
      await _pumpWithControllers(tester);
      await tester.pump();

      // No celebration at rest.
      expect(find.byType(CompletionBurst), findsNothing);

      await tester.tap(find.byType(Checkbox));
      await tester.pump(); // process the check → schedule the overlay burst
      // The burst spawns into the app overlay a frame later and runs its own
      // ~850ms timeline; pump into its spark window (0.12–0.96 of it).
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // build + start burst
      await tester.pump(
        const Duration(milliseconds: 300),
      ); // advance into window
      expect(find.byType(CompletionBurst), findsOneWidget);

      await tester.pumpAndSettle();
      // The burst clears once the timeline completes.
      expect(find.byType(CompletionBurst), findsNothing);
    });

    testWidgets(
      'an external check-off (accepted AI proposal / sync) also fires the burst',
      (tester) async {
        final ctrls = await _pumpWithControllers(tester);
        await tester.pump();
        expect(find.byType(CompletionBurst), findsNothing);

        // No tap on the checkbox: the item becomes checked from outside — an
        // accepted AI "check off" proposal (or a sync) updating the controller.
        // The data listener celebrates it just like a direct tap would.
        ctrls.itemController.updateChecked(checked: true);
        await tester.pump(); // listener fires → schedule the overlay burst
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CompletionBurst), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byType(CompletionBurst), findsNothing);
      },
    );

    testWidgets(
      'an external check-off on a row scrolled out of view spawns no burst',
      (tester) async {
        final itemCtrl = FakeChecklistItemController(_makeItem());
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
            // A tall spacer pushes the row far below the visible viewport, but
            // a SingleChildScrollView still builds it (so its data listener
            // runs) — the burst must be suppressed by the on-screen check.
            child: makeTestableWidgetWithScaffold(
              const SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 2000),
                    ChecklistItemRow(
                      itemId: 'item-1',
                      checklistId: 'checklist-1',
                      taskId: 'task-1',
                      index: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        // The row is built but sits well below the ~800px test viewport.
        expect(tester.getRect(find.byType(Checkbox)).top, greaterThan(800));
        expect(find.byType(CompletionBurst), findsNothing);

        itemCtrl.updateChecked(checked: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 300));
        // Off-screen checkbox → no sparks erupting over unrelated content.
        expect(find.byType(CompletionBurst), findsNothing);

        await tester.pumpAndSettle();
      },
    );

    testWidgets('no spark burst when checklist celebrations are off', (
      tester,
    ) async {
      await _pumpWithControllers(
        tester,
        extraOverrides: [
          celebrationPreferencesProvider.overrideWithValue(
            const CelebrationPreferences.allEnabled().copyWith(
              checklistItems: false,
            ),
          ),
        ],
      );
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      // The item still checks (the controller was called) but no sparks fly.
      expect(find.byType(CompletionBurst), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('no spark burst when the master switch is off (checklist on)', (
      tester,
    ) async {
      await _pumpWithControllers(
        tester,
        extraOverrides: [
          celebrationPreferencesProvider.overrideWithValue(
            const CelebrationPreferences.allEnabled().copyWith(enabled: false),
          ),
        ],
      );
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CompletionBurst), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('flows the selected variant into the spark burst', (
      tester,
    ) async {
      await _pumpWithControllers(
        tester,
        extraOverrides: [
          celebrationPreferencesProvider.overrideWithValue(
            const CelebrationPreferences.allEnabled().copyWith(
              checklistItemsVariant: CelebrationVariant.embers,
            ),
          ),
        ],
      );
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      final burst = tester.widget<CompletionBurst>(
        find.byType(CompletionBurst),
      );
      expect(burst.variant, CelebrationVariant.embers);

      await tester.pumpAndSettle();
    });

    testWidgets('tap haptic honours the independent haptics switch', (
      tester,
    ) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String? ?? '');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      // Haptics off: visuals can still play, but the tap must not buzz.
      await _pumpWithControllers(
        tester,
        extraOverrides: [
          celebrationPreferencesProvider.overrideWithValue(
            const CelebrationPreferences.allEnabled().copyWith(haptics: false),
          ),
        ],
      );
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(haptics, isEmpty);

      await tester.pumpAndSettle();
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
        final ctrls = await _pumpWithControllers(
          tester,
          suggestions: const [
            ChecklistCompletionSuggestion(
              checklistItemId: 'item-1',
              confidence: ChecklistCompletionConfidence.medium,
              reason: 'Looks done',
            ),
          ],
        );
        // Second pump: rebuild after async providers resolved.
        await tester.pump();

        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        expect(ctrls.completionService.clearedItemId, 'item-1');
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

          // After the hold timer (1150ms) fires, the row hides. Pump past it.
          await tester.pump(const Duration(milliseconds: 1250));

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

      testWidgets(
        'synchronous first-frame hides pre-checked item via post-frame callback',
        (tester) async {
          // Exercises the synchronous first-frame fix (lines 218-229):
          // when the provider already has data before the first build,
          // ref.listen hasn't fired yet, so the build method checks
          // _receivedInitialData and schedules a post-frame callback.
          final itemCtrl = FakeChecklistItemController(
            _makeItem(isChecked: true),
          );

          // Pre-resolve the provider so it has data before the widget
          // mounts. A ProviderContainer reads the provider eagerly.
          final container = ProviderContainer(
            overrides: [
              checklistItemControllerProvider((
                id: 'item-1',
                taskId: 'task-1',
              )).overrideWith(() => itemCtrl),
              checklistControllerProvider.overrideWith(
                FakeChecklistController.new,
              ),
              checklistCompletionServiceProvider.overrideWith(
                FakeChecklistCompletionService.new,
              ),
            ],
          );
          // Force the provider to resolve before the widget tree mounts.
          await container.read(
            checklistItemControllerProvider((
              id: 'item-1',
              taskId: 'task-1',
            )).future,
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: makeTestableWidgetWithScaffold(
                const ChecklistItemRow(
                  itemId: 'item-1',
                  checklistId: 'checklist-1',
                  taskId: 'task-1',
                  index: 0,
                  hideIfChecked: true,
                ),
              ),
            ),
          );
          // First build — the post-frame callback is scheduled.
          await tester.pump();
          // Second pump — the callback fires and sets _showRow = false.
          await tester.pump();

          final crossFade = tester.widget<AnimatedCrossFade>(
            find.byType(AnimatedCrossFade),
          );
          expect(crossFade.crossFadeState, CrossFadeState.showSecond);

          container.dispose();
        },
      );
    });

    // ── Done-only filter (hideIfUnchecked) ──────────────────────────────

    group('done-only filter (hideIfUnchecked)', () {
      testWidgets(
        'unchecked item is hidden immediately when hideIfUnchecked=true',
        (tester) async {
          // Unchecked item with done-only filter → should be hidden.
          await _pump(tester, hideIfUnchecked: true);
          await tester.pump();

          final crossFade = tester.widget<AnimatedCrossFade>(
            find.byType(AnimatedCrossFade),
          );
          expect(crossFade.crossFadeState, CrossFadeState.showSecond);
        },
      );

      testWidgets(
        'checked item remains visible when hideIfUnchecked=true',
        (tester) async {
          await _pump(
            tester,
            item: _makeItem(isChecked: true),
            hideIfUnchecked: true,
          );
          await tester.pump();

          final crossFade = tester.widget<AnimatedCrossFade>(
            find.byType(AnimatedCrossFade),
          );
          expect(crossFade.crossFadeState, CrossFadeState.showFirst);
        },
      );

      testWidgets(
        'archived item remains visible when hideIfUnchecked=true',
        (tester) async {
          await _pump(
            tester,
            item: _makeItem(isArchived: true),
            hideIfUnchecked: true,
          );
          await tester.pump();

          final crossFade = tester.widget<AnimatedCrossFade>(
            find.byType(AnimatedCrossFade),
          );
          expect(crossFade.crossFadeState, CrossFadeState.showFirst);
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
        'hideIfUnchecked=true wraps in AnimatedCrossFade',
        (tester) async {
          await _pump(tester, hideIfUnchecked: true);
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

      testWidgets(
        'low-confidence suggestion shows tertiary color in dialog',
        (tester) async {
          const lowSuggestion = ChecklistCompletionSuggestion(
            checklistItemId: 'item-1',
            confidence: ChecklistCompletionConfidence.low,
            reason: 'Low confidence reason',
          );
          await _pumpWithControllers(tester, suggestions: [lowSuggestion]);
          await tester.pump();

          // Open suggestion dialog.
          final barFinder = find.descendant(
            of: find.byType(GestureDetector),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  w.constraints?.maxWidth == 8,
            ),
          );
          await tester.tap(barFinder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Verify the dialog shows the 'low' confidence label.
          expect(find.text('Confidence: low'), findsOneWidget);
          // Verify the reason text is shown.
          expect(find.text('Low confidence reason'), findsOneWidget);
        },
      );
    });

    // ── Edit mode cancel ────────────────────────────────────────────────────

    testWidgets('cancel icon in edit mode exits editing without saving', (
      tester,
    ) async {
      final ctrls = await _pumpWithControllers(
        tester,
        item: _makeItem(title: 'Original title'),
      );
      final controller = ctrls.itemController;

      // Enter edit mode.
      await tester.tap(find.byIcon(Icons.mode_edit_outlined));
      await tester.pump();
      expect(find.byType(TitleTextField), findsOneWidget);

      // Type some text so the field is dirty and the cancel button is visible.
      await tester.enterText(find.byType(TitleTextField), 'Changed text');
      await tester.pump();

      // Tap the cancel icon (cancel_outlined) to discard changes.
      final cancelIcon = find.byIcon(Icons.cancel_outlined);
      await tester.ensureVisible(cancelIcon);
      await tester.tap(cancelIcon);
      await tester.pump();

      // Edit mode should be exited and no title update should have been called.
      expect(find.byType(TitleTextField), findsNothing);
      expect(find.byIcon(Icons.mode_edit_outlined), findsOneWidget);
      expect(controller.updatedTitle, isNull);
    });

    // ── Oncancel via TitleTextField resetToInitialValue ──────────────────────

    testWidgets('edit mode cancel with pristine field exits editing', (
      tester,
    ) async {
      final ctrls = await _pumpWithControllers(
        tester,
        item: _makeItem(title: 'Pristine title'),
      );
      final controller = ctrls.itemController;

      // Enter edit mode.
      await tester.tap(find.byIcon(Icons.mode_edit_outlined));
      await tester.pump();
      expect(find.byType(TitleTextField), findsOneWidget);

      // The cancel icon is present since initialValue is non-null and
      // resetToInitialValue=true → _showClearButton starts true.
      final cancelIcon = find.byIcon(Icons.cancel_outlined);
      await tester.ensureVisible(cancelIcon);
      await tester.tap(cancelIcon);
      await tester.pump();

      // Edit mode should be exited.
      expect(find.byType(TitleTextField), findsNothing);
      expect(controller.updatedTitle, isNull);
    });

    // ── Archive undo action ─────────────────────────────────────────────────

    testWidgets(
      'tapping Undo in archive snackbar calls unarchive',
      (tester) async {
        final ctrls = await _pumpWithControllers(tester);
        await tester.pump();

        // Swipe right to archive.
        await tester.drag(find.byType(Dismissible), const Offset(300, 0));
        await tester.pumpAndSettle();

        expect(ctrls.itemController.archiveCalled, isTrue);
        expect(find.text('Item archived'), findsOneWidget);

        // Tap the "Undo" action in the snackbar.
        final undoFinder = find.text('Undo');
        await tester.ensureVisible(undoFinder);
        await tester.tap(undoFinder);
        await tester.pump();

        // unarchive should have been called by the undo action.
        expect(ctrls.itemController.unarchiveCalled, isTrue);
      },
    );

    // ── Delete undo action ──────────────────────────────────────────────────

    testWidgets(
      'tapping Undo in delete snackbar relinks item and cancels delete timer',
      (tester) async {
        final ctrls = await _pumpWithControllers(tester);
        await tester.pump();

        // Swipe left to delete.
        await tester.drag(find.byType(Dismissible), const Offset(-300, 0));
        await tester.pumpAndSettle();

        expect(ctrls.checklistTracker.unlinkedItemId, 'item-1');
        expect(find.text('Item deleted'), findsOneWidget);

        // Tap the "Undo" action in the snackbar.
        final undoFinder = find.text('Undo');
        await tester.ensureVisible(undoFinder);
        await tester.tap(undoFinder);
        await tester.pump();

        // relinkItem should have been called by the undo action.
        expect(ctrls.checklistTracker.relinkedItemId, 'item-1');
      },
    );

    // ── Suggestion animation stops when suggestion removed ──────────────────

    testWidgets(
      'suggestion animation stops when suggestion is removed',
      (tester) async {
        const suggestion = ChecklistCompletionSuggestion(
          checklistItemId: 'item-1',
          confidence: ChecklistCompletionConfidence.medium,
          reason: 'Looks done',
        );

        final completionSvc = FakeChecklistCompletionService([suggestion]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              checklistItemControllerProvider((
                id: 'item-1',
                taskId: 'task-1',
              )).overrideWith(() => FakeChecklistItemController(_makeItem())),
              checklistControllerProvider.overrideWith(
                FakeChecklistController.new,
              ),
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
        // Two pumps: resolve async providers, then rebuild with suggestion.
        await tester.pump();
        await tester.pump();

        // Verify the suggestion bar is visible (animation is running).
        final barFinder = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              w.constraints?.maxWidth == 8,
        );
        expect(barFinder, findsOneWidget);

        // Remove the suggestion — this triggers lines 250-252 where the
        // animation controller is stopped and reset.
        completionSvc.setSuggestions([]);
        await tester.pump();
        await tester.pump();

        // The suggestion bar should no longer be visible.
        expect(barFinder, findsNothing);
      },
    );

    // ── Sync first-frame hide for hideIfUnchecked ───────────────────────────

    testWidgets(
      'synchronous first-frame hides unchecked item when hideIfUnchecked=true',
      (tester) async {
        // Exercises line 225: _showRow = false when hideIfUnchecked && !isCompleted
        // on the synchronous first-frame path in build().
        final itemCtrl = FakeChecklistItemController(_makeItem());

        // Pre-resolve the provider so the synchronous build() path is taken.
        final container = ProviderContainer(
          overrides: [
            checklistItemControllerProvider((
              id: 'item-1',
              taskId: 'task-1',
            )).overrideWith(() => itemCtrl),
            checklistControllerProvider.overrideWith(
              FakeChecklistController.new,
            ),
            checklistCompletionServiceProvider.overrideWith(
              FakeChecklistCompletionService.new,
            ),
          ],
        );
        await container.read(
          checklistItemControllerProvider((
            id: 'item-1',
            taskId: 'task-1',
          )).future,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: makeTestableWidgetWithScaffold(
              const ChecklistItemRow(
                itemId: 'item-1',
                checklistId: 'checklist-1',
                taskId: 'task-1',
                index: 0,
                hideIfUnchecked: true,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // The unchecked item should be hidden (showSecond = SizedBox.shrink).
        final crossFade = tester.widget<AnimatedCrossFade>(
          find.byType(AnimatedCrossFade),
        );
        expect(crossFade.crossFadeState, CrossFadeState.showSecond);

        container.dispose();
      },
    );

    // ── super_drag_and_drop wiring ──────────────────────────────────────────
    //
    // The DropRegion / DragItemWidget callbacks only fire on a real native
    // drag/drop, which the test environment can't dispatch. We extract those
    // public widgets from the tree and invoke their closures directly,
    // asserting on the values they forward (operation, drag item contents,
    // and the target index/itemId passed through to the controller).
    group('drag-and-drop wiring', () {
      testWidgets(
        'onDropOver returns DropOperation.move',
        (tester) async {
          await _pumpWithControllers(tester);
          await tester.pump();

          final dropRegion = tester.widget<DropRegion>(
            find.byType(DropRegion),
          );
          final operation = await dropRegion.onDropOver(
            DropOverEvent(
              session: FakeDndDropSession(itemList: const []),
              position: DropPosition(local: Offset.zero, global: Offset.zero),
            ),
          );

          expect(operation, DropOperation.move);
        },
      );

      testWidgets(
        'onPerformDrop forwards target index/itemId to dropChecklistItem',
        (tester) async {
          final ctrls = await _pumpWithControllers(tester);
          await tester.pump();

          // Local data that routes through to dropChecklistItem (non-empty
          // map without a checklistItemTitle key).
          final localData = <String, String>{
            'checklistItemId': 'dragged-item',
            'checklistId': 'other-checklist',
          };
          final session = FakeDndDropSession(
            itemList: [FakeDndDropItem(testLocalData: localData)],
          );

          final dropRegion = tester.widget<DropRegion>(
            find.byType(DropRegion),
          );
          await dropRegion.onPerformDrop(
            PerformDropEvent(
              session: session,
              position: DropPosition(local: Offset.zero, global: Offset.zero),
              acceptedOperation: DropOperation.move,
            ),
          );

          // The closure passes widget.index (0) and widget.itemId ('item-1')
          // straight through to handleChecklistItemDrop -> dropChecklistItem.
          expect(ctrls.checklistTracker.droppedLocalData, localData);
          expect(ctrls.checklistTracker.droppedTargetIndex, 0);
          expect(ctrls.checklistTracker.droppedTargetItemId, 'item-1');
        },
      );

      testWidgets(
        'dragItemProvider builds a DragItem carrying the item id and '
        'checklist id as local data',
        (tester) async {
          await _pumpWithControllers(
            tester,
            item: _makeItem(title: 'Drag me'),
          );
          await tester.pump();

          final dragItemWidget = tester.widget<DragItemWidget>(
            find.byType(DragItemWidget),
          );
          final dragItem = await dragItemWidget.dragItemProvider(
            DragItemRequest(
              location: Offset.zero,
              session: FakeDndDragSession(),
            ),
          );

          final data = dragItem!.localData! as Map<String, String>;
          expect(data['checklistItemId'], 'item-1');
          expect(data['checklistId'], 'checklist-1');
        },
      );

      testWidgets(
        'allowedOperations returns [DropOperation.move]',
        (tester) async {
          await _pumpWithControllers(tester);
          await tester.pump();

          final dragItemWidget = tester.widget<DragItemWidget>(
            find.byType(DragItemWidget),
          );

          expect(dragItemWidget.allowedOperations(), [DropOperation.move]);
        },
      );
    });
  });
}
