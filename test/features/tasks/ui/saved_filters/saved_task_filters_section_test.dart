import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
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

Future<void> _pumpSection(
  WidgetTester tester, {
  required ValueChanged<SavedTaskFilter> onActivate,
  required VoidCallback onAddPressed,
  String? activeId,
  bool canAdd = false,
  Map<String, int>? counts,
}) async {
  await tester.pumpWidget(
    makeTestableWidget(
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

  testWidgets('renders the empty state when no saved filters exist',
      (tester) async {
    await _pumpSection(
      tester,
      onActivate: (_) {},
      onAddPressed: () {},
    );

    final emptyFinder =
        find.byKey(SavedTaskFiltersSectionKeys.emptyState);
    expect(emptyFinder, findsOneWidget);

    final messages =
        AppLocalizations.of(tester.element(emptyFinder))!;
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

  testWidgets('forwards onActivate with the tapped saved filter',
      (tester) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'Alpha', filter: _filterA),
    ]);

    SavedTaskFilter? activated;
    await _pumpSection(
      tester,
      onActivate: (f) => activated = f,
      onAddPressed: () {},
    );

    await tester.tap(find.text('Alpha'));
    await tester.pump();

    expect(activated?.id, 'sv-1');
  });

  testWidgets('add button is disabled and skips onAddPressed when canAdd=false',
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
  });

  testWidgets('add button invokes onAddPressed when canAdd=true',
      (tester) async {
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

  testWidgets('delete from a row removes the filter from the controller',
      (tester) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'Solo', filter: _filterA),
    ]);

    when(
      () => mocks.settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: resolveTestTheme(),
          home: Scaffold(
            body: SavedTaskFiltersSection(
              activeId: null,
              onActivate: (_) {},
              onAddPressed: () {},
            ),
          ),
        ),
      ),
    );
    await container.read(savedTaskFiltersControllerProvider.future);
    await tester.pumpAndSettle();

    // Hover, then tap delete twice (arm + commit).
    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text('Solo')));
    await tester.pumpAndSettle();

    final delete =
        find.byKey(SavedTaskFilterRowKeys.deleteButton('sv-1'));
    await tester.tap(delete);
    await tester.pump();
    await tester.tap(delete);
    await tester.pumpAndSettle();

    final list = container
        .read(savedTaskFiltersControllerProvider)
        .value!;
    expect(list, isEmpty);
  });
}
