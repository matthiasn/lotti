import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_row.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filters_section.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

const _filterA = TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'});
const _filterB = TasksFilter(
  agentAssignmentFilter: AgentAssignmentFilter.noAgent,
);

/// GestureDetector defers single-tap by `kDoubleTapTimeout` (300 ms) when
/// `onDoubleTap` is also wired.
const _afterDoubleTapTimeout = Duration(milliseconds: 350);

Future<void> _pumpSection(
  WidgetTester tester, {
  required ValueChanged<SavedTaskFilter> onActivate,
  String? activeId,
  Map<String, int>? counts,
  VoidCallback? onDeleted,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SavedTaskFiltersSection(
        activeId: activeId,
        counts: counts,
        onActivate: onActivate,
        onDeleted: onDeleted,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  void stubPersisted(List<SavedTaskFilter> items) {
    when(
      () => mocks.settingsDb.itemByKey(
        SavedTaskFiltersPersistence.storageKey,
      ),
    ).thenAnswer(
      (_) async => jsonEncode(
        items.map((e) => e.toJson()).toList(growable: false),
      ),
    );
  }

  testWidgets(
    'renders nothing when no saved filters exist (header is hidden too)',
    (tester) async {
      await _pumpSection(tester, onActivate: (_) {});

      // Section root is still in the tree as a SizedBox.shrink — no header,
      // no list, no empty-state pill. New filters are saved through the
      // modal's Save button, so an empty placeholder adds noise.
      expect(find.byKey(SavedTaskFiltersSectionKeys.root), findsOneWidget);
      expect(find.byKey(SavedTaskFiltersSectionKeys.list), findsNothing);
    },
  );

  testWidgets('renders rows for each persisted saved filter', (tester) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
      SavedTaskFilter(id: 'sv-2', name: 'B', filter: _filterB),
    ]);

    await _pumpSection(tester, onActivate: (_) {});

    expect(find.byKey(SavedTaskFiltersSectionKeys.list), findsOneWidget);
    expect(find.byKey(SavedTaskFilterRowKeys.root('sv-1')), findsOneWidget);
    expect(find.byKey(SavedTaskFilterRowKeys.root('sv-2')), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('forwards onActivate with the tapped saved filter', (
    tester,
  ) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
    ]);

    SavedTaskFilter? activated;
    await _pumpSection(tester, onActivate: (f) => activated = f);

    await tester.tap(find.byKey(SavedTaskFilterRowKeys.root('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);

    expect(activated?.id, 'sv-1');
  });

  testWidgets('passes counts through to rows', (tester) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
    ]);

    await _pumpSection(
      tester,
      onActivate: (_) {},
      counts: const {'sv-1': 12},
    );

    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('onRename writes the renamed filter to settings', (
    tester,
  ) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
    ]);

    await _pumpSection(tester, onActivate: (_) {});

    // Double-tap the row to enter rename mode.
    final rowFinder = find.byKey(SavedTaskFilterRowKeys.root('sv-1'));
    await tester.tap(rowFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(rowFinder);
    await tester.pump(_afterDoubleTapTimeout);

    await tester.enterText(
      find.byKey(SavedTaskFilterRowKeys.renameField('sv-1')),
      'Beta',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // Allow the controller's async save to settle.
    await tester.pumpAndSettle();

    // Verify the controller persisted the renamed filter.
    final captured = verify(
      () => mocks.settingsDb.saveSettingsItem(
        SavedTaskFiltersPersistence.storageKey,
        captureAny(),
      ),
    ).captured;
    expect(captured, isNotEmpty);
    final stored = captured.last as String;
    expect(stored, contains('"name":"Beta"'));
  });

  testWidgets('onDelete removes the filter via the controller', (
    tester,
  ) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
      SavedTaskFilter(id: 'sv-2', name: 'Bravo', filter: _filterB),
    ]);

    await _pumpSection(tester, onActivate: (_) {});

    // Reveal the delete button via hover, then two-tap to commit.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(
      tester.getCenter(find.byKey(SavedTaskFilterRowKeys.root('sv-1'))),
    );
    await tester.pump();

    await tester.tap(find.byKey(SavedTaskFilterRowKeys.deleteButton('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);
    await tester.tap(find.byKey(SavedTaskFilterRowKeys.deleteButton('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);
    await tester.pumpAndSettle();

    final captured = verify(
      () => mocks.settingsDb.saveSettingsItem(
        SavedTaskFiltersPersistence.storageKey,
        captureAny(),
      ),
    ).captured;
    expect(captured, isNotEmpty);
    final stored = captured.last as String;
    // sv-1 is deleted, sv-2 remains.
    expect(stored, isNot(contains('"id":"sv-1"')));
    expect(stored, contains('"id":"sv-2"'));
  });

  testWidgets('marks the active filter row when activeId matches', (
    tester,
  ) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
      SavedTaskFilter(id: 'sv-2', name: 'Bravo', filter: _filterB),
    ]);

    await _pumpSection(
      tester,
      onActivate: (_) {},
      activeId: 'sv-2',
    );

    final activeRow = tester.widget<SavedTaskFilterRow>(
      find.ancestor(
        of: find.byKey(SavedTaskFilterRowKeys.root('sv-2')),
        matching: find.byType(SavedTaskFilterRow),
      ),
    );
    final inactiveRow = tester.widget<SavedTaskFilterRow>(
      find.ancestor(
        of: find.byKey(SavedTaskFilterRowKeys.root('sv-1')),
        matching: find.byType(SavedTaskFilterRow),
      ),
    );
    expect(activeRow.active, isTrue);
    expect(inactiveRow.active, isFalse);
  });

  testWidgets('fires onDeleted callback after a filter is deleted', (
    tester,
  ) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
      SavedTaskFilter(id: 'sv-2', name: 'Bravo', filter: _filterB),
    ]);

    var deletedCount = 0;
    await _pumpSection(
      tester,
      onActivate: (_) {},
      onDeleted: () => deletedCount++,
    );

    // Hover to reveal the delete button, then two-tap to confirm deletion.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(
      tester.getCenter(find.byKey(SavedTaskFilterRowKeys.root('sv-1'))),
    );
    await tester.pump();

    await tester.tap(find.byKey(SavedTaskFilterRowKeys.deleteButton('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);
    await tester.tap(find.byKey(SavedTaskFilterRowKeys.deleteButton('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);
    await tester.pumpAndSettle();

    // onDeleted must have been called exactly once after the confirmed delete.
    expect(deletedCount, 1);
  });

  testWidgets(
    'onReorderItem newIndex > oldIndex branch fires but guard returns early — '
    'no persistence write when adjusted equals oldIndex',
    (tester) async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
        SavedTaskFilter(id: 'sv-2', name: 'Bravo', filter: _filterB),
        SavedTaskFilter(id: 'sv-3', name: 'Charlie', filter: _filterA),
      ]);

      await _pumpSection(tester, onActivate: (_) {});

      // "Move down" on the first row triggers onReorderItem(0, 1) from
      // Flutter's semantic layer.  Inside our widget's handler:
      //   adjusted = 1; if (1 > 0) adjusted = 1-1 = 0; adjusted == oldIndex →
      //   return early.
      // This exercises the newIndex > oldIndex branch (line 133) and the
      // early-return guard (line 134) without persisting anything.
      final firstItemNode = tester.getSemantics(find.text('Alpha'));
      final moveDownId = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Move down'),
      );
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        firstItemNode.id,
        SemanticsAction.customAction,
        moveDownId,
      );
      await tester.pumpAndSettle();

      // No persistence write must occur because the reorder is a no-op.
      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(
          SavedTaskFiltersPersistence.storageKey,
          any(),
        ),
      );
    },
  );

  testWidgets(
    'onReorder moves item up via semantics — persists reordered list '
    'and covers onReorderItem newIndex <= oldIndex branch',
    (tester) async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
        SavedTaskFilter(id: 'sv-2', name: 'Bravo', filter: _filterB),
        SavedTaskFilter(id: 'sv-3', name: 'Charlie', filter: _filterA),
      ]);

      await _pumpSection(tester, onActivate: (_) {});

      // Use "Move up" on the second row → onReorderItem(1, 0).
      // newIndex(0) <= oldIndex(1) → no adjustment; adjusted == 0 ≠ 1
      // so onReorder('sv-2', 'sv-1') fires and the controller persists
      // sv-2 at position 0.
      final secondItemNode = tester.getSemantics(find.text('Bravo'));
      final moveUpId = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Move up'),
      );
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        secondItemNode.id,
        SemanticsAction.customAction,
        moveUpId,
      );
      await tester.pumpAndSettle();

      final captured = verify(
        () => mocks.settingsDb.saveSettingsItem(
          SavedTaskFiltersPersistence.storageKey,
          captureAny(),
        ),
      ).captured;
      expect(captured, isNotEmpty);
      final stored = captured.last as String;
      final decoded = jsonDecode(stored) as List<dynamic>;
      final ids = decoded
          .map((e) => (e as Map<String, dynamic>)['id'] as String)
          .toList();
      // sv-2 moved up; it is now before sv-1.
      expect(ids.indexOf('sv-2'), lessThan(ids.indexOf('sv-1')));
    },
  );

  testWidgets(
    'onReorderItem is a no-op when adjusted index equals oldIndex — '
    'controller is not called',
    (tester) async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
        SavedTaskFilter(id: 'sv-2', name: 'Bravo', filter: _filterB),
      ]);

      await _pumpSection(tester, onActivate: (_) {});

      // "Move down" on the LAST item: the ReorderableListView fires
      // onReorderItem(1, 3) — but there are only 2 items so Flutter
      // clamps to onReorderItem(1, 2). Because newIndex(2) > oldIndex(1)
      // the widget computes adjusted = 2 - 1 = 1 == oldIndex(1), so it
      // returns early without calling onReorder — the controller must NOT
      // write to settings.
      final lastItemNode = tester.getSemantics(find.text('Bravo'));
      final moveDownId = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Move down'),
      );
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        lastItemNode.id,
        SemanticsAction.customAction,
        moveDownId,
      );
      await tester.pumpAndSettle();

      // No persistence write must occur because the reorder was a no-op.
      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(
          SavedTaskFiltersPersistence.storageKey,
          any(),
        ),
      );
    },
  );
}
