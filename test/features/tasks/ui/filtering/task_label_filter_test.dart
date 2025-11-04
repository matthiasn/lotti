// ignore_for_file: avoid_redundant_argument_values

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/tasks/ui/filtering/task_label_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_label_quick_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class _MockJournalPageCubit extends MockCubit<JournalPageState>
    implements JournalPageCubit {}

class _MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

JournalPageState _baseState({
  Set<String> selectedLabelIds = const <String>{},
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
    selectedLabelIds: selectedLabelIds,
  );
}

LabelDefinition buildTestLabel(int index) {
  final timestamp = DateTime(2024, 1, 1);
  return LabelDefinition(
    id: 'label-$index',
    name: 'Label $index',
    color: '#FF00${(index % 10).toString().padLeft(2, '0')}',
    createdAt: timestamp,
    updatedAt: timestamp,
    vectorClock: null,
    description: 'Label description $index',
    private: false,
  );
}

void main() {
  late _MockJournalPageCubit cubit;
  late _MockEntitiesCacheService cacheService;
  late List<LabelDefinition> labels;

  setUp(() async {
    cubit = _MockJournalPageCubit();
    cacheService = _MockEntitiesCacheService();
    labels = List.generate(10, buildTestLabel);

    await getIt.reset();
    getIt.registerSingleton<EntitiesCacheService>(cacheService);

    when(() => cacheService.sortedLabels).thenReturn(labels);
    for (final label in labels) {
      when(() => cacheService.getLabelById(label.id)).thenReturn(label);
    }
    when(() => cacheService.showPrivateEntries).thenReturn(true);
    // Stub async cubit APIs used by the widgets
    when(() => cubit.toggleSelectedLabelId(any())).thenAnswer((_) async {});
    when(() => cubit.clearSelectedLabelIds()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget wrapFilter(Widget child, JournalPageState state) {
    expect(
      getIt.isRegistered<EntitiesCacheService>(),
      isTrue,
      reason: 'EntitiesCacheService must be registered before building widgets',
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(
      cubit,
      Stream<JournalPageState>.fromIterable([state]),
    );

    return ProviderScope(
      child: BlocProvider<JournalPageCubit>.value(
        value: cubit,
        child: makeTestableWidgetWithScaffold(child),
      ),
    );
  }

  testWidgets('tapping label chip toggles selection', (tester) async {
    final widget = wrapFilter(const TaskLabelFilter(), _baseState());

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Label 0'));

    verify(() => cubit.toggleSelectedLabelId('label-0')).called(1);
  });

  testWidgets('shows more labels after tapping ellipsis chip', (tester) async {
    final widget = wrapFilter(const TaskLabelFilter(), _baseState());

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Label 9'), findsNothing);

    await tester.tap(find.text('...'));
    await tester.pump();

    expect(find.text('Label 9'), findsOneWidget);
  });

  testWidgets('Clear and Unlabeled chips trigger cubit actions',
      (tester) async {
    final state = _baseState(selectedLabelIds: {'label-1'});
    final widget = wrapFilter(const TaskLabelFilter(), state);

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    verify(() => cubit.clearSelectedLabelIds()).called(1);

    await tester.tap(find.text('Unlabeled'));
    verify(() => cubit.toggleSelectedLabelId('')).called(1);
  });

  testWidgets('quick filter lists active labels and clears selections',
      (tester) async {
    when(() => cubit.state)
        .thenReturn(_baseState(selectedLabelIds: {'label-0', ''}));
    whenListen(
      cubit,
      Stream<JournalPageState>.fromIterable(
        [
          _baseState(selectedLabelIds: {'label-0', ''})
        ],
      ),
    );

    final widget = ProviderScope(
      child: BlocProvider<JournalPageCubit>.value(
        value: cubit,
        child: makeTestableWidgetWithScaffold(
          const TaskLabelQuickFilter(),
        ),
      ),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.textContaining('Active label filters'), findsOneWidget);
    expect(find.text('Label 0'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    verify(() => cubit.toggleSelectedLabelId('label-0')).called(1);

    await tester.tap(find.text('Clear'));
    verify(() => cubit.clearSelectedLabelIds()).called(1);
  });
}
