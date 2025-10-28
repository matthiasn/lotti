import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_priority_filter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class _MockJournalPageCubit extends MockCubit<JournalPageState>
    implements JournalPageCubit {}

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
  late _MockJournalPageCubit cubit;

  setUp(() async {
    cubit = _MockJournalPageCubit();
    // Stub async cubit APIs used by the widget
    when(() => cubit.toggleSelectedPriority(any())).thenAnswer((_) async {});
    when(() => cubit.clearSelectedPriorities()).thenAnswer((_) async {});
  });

  Widget wrap(Widget child, JournalPageState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(
      cubit,
      Stream<JournalPageState>.fromIterable([state]),
    );

    return BlocProvider<JournalPageCubit>.value(
      value: cubit,
      child: makeTestableWidgetWithScaffold(child),
    );
  }

  testWidgets('tapping priority chips toggles selection', (tester) async {
    final widget = wrap(const TaskPriorityFilter(), _baseState());

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('P0'));
    verify(() => cubit.toggleSelectedPriority('P0')).called(1);

    await tester.tap(find.text('P2'));
    verify(() => cubit.toggleSelectedPriority('P2')).called(1);
  });

  testWidgets('All chip clears selected priorities', (tester) async {
    final widget = wrap(
      const TaskPriorityFilter(),
      _baseState(selectedPriorities: {'P1'}),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    verify(() => cubit.clearSelectedPriorities()).called(1);
  });
}
