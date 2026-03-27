// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_agent_filter.dart';

import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

JournalPageState _baseState({
  AgentAssignmentFilter agentAssignmentFilter = AgentAssignmentFilter.all,
}) {
  return JournalPageState(
    match: '',
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
    selectedPriorities: const <String>{},
    agentAssignmentFilter: agentAssignmentFilter,
  );
}

void main() {
  late FakeJournalPageController fakeController;

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

  testWidgets('renders all three filter chips', (tester) async {
    await tester.pumpWidget(
      wrap(const TaskAgentFilter(), _baseState()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Has Agent'), findsOneWidget);
    expect(find.text('No Agent'), findsOneWidget);
  });

  testWidgets('tapping "Has Agent" sets hasAgent filter', (tester) async {
    await tester.pumpWidget(
      wrap(const TaskAgentFilter(), _baseState()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Has Agent'));

    expect(fakeController.agentAssignmentFilterCalls, [
      AgentAssignmentFilter.hasAgent,
    ]);
  });

  testWidgets('tapping "No Agent" sets noAgent filter', (tester) async {
    await tester.pumpWidget(
      wrap(const TaskAgentFilter(), _baseState()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('No Agent'));

    expect(fakeController.agentAssignmentFilterCalls, [
      AgentAssignmentFilter.noAgent,
    ]);
  });

  testWidgets('tapping "All" sets all filter', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TaskAgentFilter(),
        _baseState(agentAssignmentFilter: AgentAssignmentFilter.hasAgent),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));

    expect(fakeController.agentAssignmentFilterCalls, [
      AgentAssignmentFilter.all,
    ]);
  });
}
