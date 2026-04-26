import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_row.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filters_section.dart';
import 'package:lotti/features/tasks/ui/saved_filters/tasks_saved_filters_tree.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

const _filterA = TasksFilter(
  selectedTaskStatuses: {'IN_PROGRESS'},
  selectedPriorities: {'P0', 'P1'},
);

const _wideMq = MediaQueryData(
  size: Size(900, 700),
  textScaler: TextScaler.noScaling,
);

Future<void> _pumpTree(
  WidgetTester tester, {
  required FakeJournalPageController fakeController,
  required List<SavedTaskFilter> seed,
}) async {
  await tester.pumpWidget(
    makeTestableWidget2(
      ProviderScope(
        overrides: [
          journalPageControllerProvider(
            true,
          ).overrideWith(() => fakeController),
        ],
        child: const Scaffold(body: TasksSavedFiltersTree()),
      ),
      mediaQueryData: _wideMq,
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
    'renders nothing when no saved filters are persisted',
    (tester) async {
      final fake = FakeJournalPageController(const JournalPageState());

      await _pumpTree(
        tester,
        fakeController: fake,
        seed: const [],
      );

      // The section collapses to a SizedBox.shrink when the list is empty —
      // there is no header, no list, no empty-state pill.
      expect(find.byKey(SavedTaskFiltersSectionKeys.root), findsOneWidget);
      expect(find.byKey(SavedTaskFiltersSectionKeys.list), findsNothing);
    },
  );

  testWidgets(
    'tapping a saved-filter row activates the filter on the page controller',
    (tester) async {
      stubPersisted(const [
        SavedTaskFilter(
          id: 'sv-1',
          name: 'P0/P1 in progress',
          filter: _filterA,
        ),
      ]);
      final fake = FakeJournalPageController(const JournalPageState());

      await _pumpTree(
        tester,
        fakeController: fake,
        seed: const [],
      );

      // Tap the row body. GestureDetector defers single-tap by 300ms when
      // onDoubleTap is also wired, so we pump past kDoubleTapTimeout.
      await tester.tap(find.byKey(SavedTaskFilterRowKeys.root('sv-1')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(fake.applyBatchFilterUpdateCalled, 1);
      expect(fake.setSelectedTaskStatusesCalls.single, {'IN_PROGRESS'});
      expect(fake.setSelectedPrioritiesCalls.single, {'P0', 'P1'});
    },
  );

  testWidgets('forwards onDeleted from the section into a toast', (
    tester,
  ) async {
    stubPersisted(const [
      SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
    ]);
    when(
      () => mocks.settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);

    final fake = FakeJournalPageController(const JournalPageState());

    await _pumpTree(
      tester,
      fakeController: fake,
      seed: const [],
    );

    // Drive the deletion-completed path the same way the row's two-tap delete
    // would: invoke the section's `onDeleted` closure that the tree wired up.
    // This exercises the tree's actual wiring (capturing the build context
    // and dispatching to the toast helper) without depending on the row's
    // brittle hover-driven gesture.
    final section = tester.widget<SavedTaskFiltersSection>(
      find.byType(SavedTaskFiltersSection),
    );
    expect(section.onDeleted, isNotNull);
    section.onDeleted!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final messages = AppLocalizations.of(
      tester.element(find.byType(TasksSavedFiltersTree)),
    )!;
    expect(find.text(messages.tasksSavedFilterToastDeleted), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
    'controller delete mutation propagates into provider state',
    (tester) async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
      ]);
      when(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);

      final fake = FakeJournalPageController(const JournalPageState());

      await _pumpTree(
        tester,
        fakeController: fake,
        seed: const [],
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TasksSavedFiltersTree)),
      );
      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .delete('sv-1');

      final list = container.read(savedTaskFiltersControllerProvider).value!;
      expect(list, isEmpty);
    },
  );

  testWidgets(
    'renders a list (no header) when at least one saved filter is persisted',
    (tester) async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
      ]);
      final fake = FakeJournalPageController(const JournalPageState());

      await _pumpTree(
        tester,
        fakeController: fake,
        seed: const [],
      );

      // No section header — the rows live directly under the Tasks
      // destination. The list and at least one row must be present.
      expect(find.byKey(SavedTaskFiltersSectionKeys.list), findsOneWidget);
      expect(find.byKey(SavedTaskFilterRowKeys.root('sv-1')), findsOneWidget);
    },
  );
}
