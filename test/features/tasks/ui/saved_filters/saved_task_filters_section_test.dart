import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_row.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filters_section.dart';
import 'package:lotti/l10n/app_localizations.dart';
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
  required VoidCallback onAddPressed,
  String? activeId,
  bool canAdd = false,
  Map<String, int>? counts,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SavedTaskFiltersSection(
        activeId: activeId,
        canAdd: canAdd,
        counts: counts,
        onActivate: onActivate,
        onAddPressed: onAddPressed,
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

  testWidgets('renders the empty state when no saved filters exist', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      onActivate: (_) {},
      onAddPressed: () {},
    );

    final emptyFinder = find.byKey(SavedTaskFiltersSectionKeys.emptyState);
    expect(emptyFinder, findsOneWidget);

    final messages = AppLocalizations.of(tester.element(emptyFinder))!;
    expect(find.text(messages.tasksSavedFiltersEmpty), findsOneWidget);
    expect(find.byKey(SavedTaskFiltersSectionKeys.list), findsNothing);
  });

  testWidgets('renders rows for each persisted saved filter', (tester) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
      SavedTaskFilter(id: 'sv-2', name: 'B', filter: _filterB),
    ]);

    await _pumpSection(
      tester,
      onActivate: (_) {},
      onAddPressed: () {},
    );

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
    await _pumpSection(
      tester,
      onActivate: (f) => activated = f,
      onAddPressed: () {},
    );

    await tester.tap(find.byKey(SavedTaskFilterRowKeys.root('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);

    expect(activated?.id, 'sv-1');
  });

  testWidgets(
    'add button is disabled and skips onAddPressed when canAdd=false',
    (tester) async {
      var pressed = 0;
      await _pumpSection(
        tester,
        onActivate: (_) {},
        onAddPressed: () => pressed++,
      );

      await tester.tap(find.byKey(SavedTaskFiltersSectionKeys.addButton));
      await tester.pump();

      expect(pressed, 0);
    },
  );

  testWidgets('add button invokes onAddPressed when canAdd=true', (
    tester,
  ) async {
    var pressed = 0;
    await _pumpSection(
      tester,
      onActivate: (_) {},
      onAddPressed: () => pressed++,
      canAdd: true,
    );

    await tester.tap(find.byKey(SavedTaskFiltersSectionKeys.addButton));
    await tester.pump();

    expect(pressed, 1);
  });

  testWidgets('passes counts through to rows', (tester) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
    ]);

    await _pumpSection(
      tester,
      onActivate: (_) {},
      onAddPressed: () {},
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

    await _pumpSection(
      tester,
      onActivate: (_) {},
      onAddPressed: () {},
    );

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

    await _pumpSection(
      tester,
      onActivate: (_) {},
      onAddPressed: () {},
    );

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
      onAddPressed: () {},
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
}
