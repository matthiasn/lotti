// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_priority_filter.dart';
import '../../../../widget_test_utils.dart';

class FakeJournalPageController extends JournalPageController {
  FakeJournalPageController(this._testState);

  final JournalPageState _testState;
  final List<String> toggledPriorities = [];
  int clearSelectedPrioritiesCalled = 0;

  @override
  JournalPageState build(bool showTasks) => _testState;

  @override
  JournalPageState get state => _testState;

  @override
  Future<void> toggleSelectedPriority(String priority) async {
    toggledPriorities.add(priority);
  }

  @override
  Future<void> clearSelectedPriorities() async {
    clearSelectedPrioritiesCalled++;
  }
}

JournalPageState _baseState({
  Set<String> selectedPriorities = const <String>{},
}) {
  return JournalPageState(
    match: '',
    tagIds: <String>{},
    filters: <DisplayFilter>{},
    showPrivateEntries: false,
    showTasks: true,
    selectedEntryTypes: const ['Task'],
    fullTextMatches: <String>{},
    pagingController: null,
    taskStatuses: const ['OPEN', 'IN PROGRESS', 'DONE'],
    selectedTaskStatuses: <String>{},
    selectedCategoryIds: <String>{},
    selectedLabelIds: const <String>{},
    selectedPriorities: selectedPriorities,
  );
}

void main() {
  late FakeJournalPageController fakeController;

  setUp(() async {
    // Stub async controller APIs used by the widget
  });

  Widget wrap(Widget child, JournalPageState state) {
    fakeController = FakeJournalPageController(state);

    return ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(true).overrideWith(() => fakeController),
      ],
      child: makeTestableWidgetWithScaffold(child),
    );
  }

  testWidgets('tapping priority chips toggles selection', (tester) async {
    final widget = wrap(const TaskPriorityFilter(), _baseState());

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('P0'));
    expect(fakeController.toggledPriorities, contains('P0'));

    await tester.tap(find.text('P2'));
    expect(fakeController.toggledPriorities, contains('P2'));
  });

  testWidgets('All chip clears selected priorities', (tester) async {
    final widget = wrap(
      const TaskPriorityFilter(),
      _baseState(selectedPriorities: {'P1'}),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    expect(fakeController.clearSelectedPrioritiesCalled, 1);
  });
}
