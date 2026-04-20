import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_full_list_modal.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';

import '../../../../widget_test_utils.dart';
import 'checklist_card_fakes.dart';

const String _testChecklistId = 'cl-1';
const String _testTaskId = 'task-1';

Future<void> _pumpModal(
  WidgetTester tester, {
  required int itemCount,
  ChecklistFilter initialFilter = ChecklistFilter.all,
  String title = 'Todos',
  int completedCount = 0,
  int totalCount = 0,
  double completionRate = 0.0,
  ValueChanged<ChecklistFilter>? onFilterChanged,
  Future<String?> Function(String?)? onCreateItem,
  Future<void> Function(List<String>)? onReorder,
  List<Override> extraOverrides = const [],
}) async {
  final items = [
    for (var i = 0; i < itemCount; i++)
      buildTestChecklistItem(id: 'i$i', title: 'Item $i'),
  ];

  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      ChecklistFullListModal(
        checklistId: _testChecklistId,
        taskId: _testTaskId,
        title: title,
        completedCount: completedCount,
        totalCount: totalCount == 0 ? itemCount : totalCount,
        completionRate: completionRate,
        initialFilter: initialFilter,
        onCreateItem: onCreateItem ?? (_) async => null,
        onReorder: onReorder ?? (_) async {},
        onFilterChanged: onFilterChanged ?? (_) {},
      ),
      overrides: [
        ...checklistItemOverridesFor(
          items: items,
          taskId: _testTaskId,
          checklistId: _testChecklistId,
        ),
        ...extraOverrides,
      ],
    ),
  );
  // Two pumps: one for the controller's build() future, one for the rebuild
  // after AsyncData lands.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('ChecklistFullListModal', () {
    testWidgets('renders the checklist title and progress counter', (
      tester,
    ) async {
      await _pumpModal(
        tester,
        itemCount: 3,
        title: 'My Todos',
        completedCount: 1,
        totalCount: 3,
        completionRate: 1 / 3,
      );

      expect(find.text('My Todos'), findsOneWidget);
      // The "1/3" counter uses the same localized template as the card.
      expect(find.textContaining('1/3'), findsOneWidget);
    });

    testWidgets('renders Open, Done, and All filter tabs', (tester) async {
      await _pumpModal(tester, itemCount: 3);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets(
      'renders the search field hint and every item row when the query is '
      'empty',
      (tester) async {
        // Five fits comfortably in the test viewport so we can assert an
        // exact count without fighting ReorderableListView's lazy build.
        await _pumpModal(tester, itemCount: 5);
        expect(find.text('Search todo item'), findsOneWidget);
        expect(find.byType(ChecklistItemRow), findsNWidgets(5));
      },
    );

    testWidgets(
      'typing into the search field narrows the visible rows by title',
      (tester) async {
        await _pumpModal(tester, itemCount: 12);

        // Every item has title "Item N". Typing "Item 3" should match
        // exactly 1 item ("Item 3"), since "Item 13" doesn't exist in a
        // 12-item set (items are 0..11).
        await tester.enterText(
          find.byKey(checklistFullListModalSearchFieldKey),
          'Item 3',
        );
        await tester.pumpAndSettle();

        expect(find.byType(ChecklistItemRow), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a filter tab forwards the change via onFilterChanged',
      (tester) async {
        final captured = <ChecklistFilter>[];
        await _pumpModal(
          tester,
          itemCount: 3,
          onFilterChanged: captured.add,
        );

        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.tap(find.text('Open'));
        await tester.pump();

        expect(
          captured,
          equals([ChecklistFilter.doneOnly, ChecklistFilter.openOnly]),
        );
      },
    );

    testWidgets(
      'submitting the add-item field invokes onCreateItem with the trimmed '
      'value',
      (tester) async {
        final submitted = <String?>[];
        await _pumpModal(
          tester,
          itemCount: 2,
          onCreateItem: (value) async {
            submitted.add(value);
            return 'new-id';
          },
        );

        await tester.enterText(
          find.byKey(checklistFullListModalAddFieldKey),
          '   New thing  ',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(submitted, ['New thing']);
      },
    );

    testWidgets(
      'clearing the search query restores the full list',
      (tester) async {
        await _pumpModal(tester, itemCount: 5);

        final search = find.byKey(checklistFullListModalSearchFieldKey);
        await tester.enterText(search, 'Item 0');
        await tester.pumpAndSettle();
        expect(find.byType(ChecklistItemRow), findsOneWidget);

        await tester.enterText(search, '');
        await tester.pumpAndSettle();

        // Back to rendering every row.
        expect(find.byType(ChecklistItemRow), findsNWidgets(5));
      },
    );

    testWidgets(
      'switches to a non-reorderable list when search is active',
      (tester) async {
        await _pumpModal(tester, itemCount: 6);

        // Empty query → reorderable.
        expect(find.byType(ReorderableListView), findsOneWidget);

        await tester.enterText(
          find.byKey(checklistFullListModalSearchFieldKey),
          'Item',
        );
        await tester.pumpAndSettle();

        // With search active we degrade to a plain ListView and drop the
        // ReorderableListView so absolute/visible index mismatches can't
        // crash the drag listener.
        expect(find.byType(ReorderableListView), findsNothing);
        expect(find.byType(ListView), findsOneWidget);
      },
    );

    testWidgets(
      'ReorderableListView.onReorder mutates the id list in place and '
      'forwards it to widget.onReorder',
      (tester) async {
        final persisted = <List<String>>[];
        await _pumpModal(
          tester,
          itemCount: 4,
          onReorder: (ids) async => persisted.add(List<String>.of(ids)),
        );

        final reorderable = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView),
        );
        // Move item at index 0 to index 3 (end of list).
        reorderable.onReorder(0, 3);
        await tester.pump();

        expect(persisted, hasLength(1));
        expect(persisted.single, equals(['i1', 'i2', 'i0', 'i3']));
      },
    );

    testWidgets(
      'ReorderableListView.proxyDecorator wraps the dragged row in a '
      'Material sheet using the design-system tokens',
      (tester) async {
        await _pumpModal(tester, itemCount: 3);

        final reorderable = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView),
        );
        const Key placeholderKey = ValueKey('proxy-child');
        final decorated = reorderable.proxyDecorator!(
          const SizedBox(key: placeholderKey),
          0,
          kAlwaysCompleteAnimation,
        );

        // Pump a plain MaterialApp — re-pumping through
        // `makeTestableWidgetWithScaffold` would resize the outer
        // ProviderScope's overrides list, which Riverpod refuses.
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: decorated)),
        );

        expect(find.byKey(placeholderKey), findsOneWidget);
        expect(find.byType(Material), findsWidgets);
      },
    );
  });
}
