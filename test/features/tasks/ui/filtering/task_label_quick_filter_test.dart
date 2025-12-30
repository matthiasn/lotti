// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_label_quick_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class FakeJournalPageController extends JournalPageController {
  FakeJournalPageController(this._testState);

  final JournalPageState _testState;
  final List<String> toggledLabelIds = [];
  int clearSelectedLabelIdsCalled = 0;

  @override
  JournalPageState build(bool showTasks) => _testState;

  @override
  JournalPageState get state => _testState;

  @override
  Future<void> toggleSelectedLabelId(String id) async {
    toggledLabelIds.add(id);
  }

  @override
  Future<void> clearSelectedLabelIds() async {
    clearSelectedLabelIdsCalled++;
  }
}

class _MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

JournalPageState _baseState({
  Set<String> selectedLabelIds = const <String>{},
  bool showTasks = true,
}) {
  return JournalPageState(
    match: '',
    tagIds: const <String>{},
    filters: const <DisplayFilter>{},
    showPrivateEntries: false,
    showTasks: showTasks,
    selectedEntryTypes: const ['Task'],
    fullTextMatches: const <String>{},
    pagingController: null,
    taskStatuses: const ['OPEN', 'IN PROGRESS', 'DONE'],
    selectedTaskStatuses: const <String>{},
    selectedCategoryIds: const <String>{},
    selectedLabelIds: selectedLabelIds,
  );
}

LabelDefinition _buildLabel(String id, String name) {
  final timestamp = DateTime(2024, 1, 1);
  return LabelDefinition(
    id: id,
    name: name,
    color: '#ABCDEF',
    createdAt: timestamp,
    updatedAt: timestamp,
    vectorClock: null,
  );
}

void main() {
  late FakeJournalPageController fakeController;
  late _MockEntitiesCacheService mockCache;

  setUp(() async {
    await getIt.reset();
    mockCache = _MockEntitiesCacheService();
    getIt.registerSingleton<EntitiesCacheService>(mockCache);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget pumpFilter(JournalPageState state) {
    fakeController = FakeJournalPageController(state);

    return ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(true).overrideWith(() => fakeController),
      ],
      child: makeTestableWidgetWithScaffold(const TaskLabelQuickFilter()),
    );
  }

  testWidgets('renders chips for each selected label', (tester) async {
    final work = _buildLabel('label-work', 'Work');
    final focus = _buildLabel('label-focus', 'Focus');

    when(() => mockCache.getLabelById(work.id)).thenReturn(work);
    when(() => mockCache.getLabelById(focus.id)).thenReturn(focus);

    final widget = pumpFilter(
      _baseState(selectedLabelIds: {work.id, focus.id}),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.textContaining('Active label filters'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
  });

  testWidgets('delete icon removes individual labels', (tester) async {
    final focus = _buildLabel('label-focus', 'Focus');
    when(() => mockCache.getLabelById(focus.id)).thenReturn(focus);

    final widget = pumpFilter(
      _baseState(selectedLabelIds: {focus.id}),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    expect(fakeController.toggledLabelIds, contains(focus.id));
  });

  testWidgets('clear button clears all label selections', (tester) async {
    final focus = _buildLabel('label-focus', 'Focus');
    when(() => mockCache.getLabelById(focus.id)).thenReturn(focus);

    final widget = pumpFilter(
      _baseState(selectedLabelIds: {focus.id, ''}),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    expect(fakeController.clearSelectedLabelIdsCalled, 1);
  });

  testWidgets('renders unassigned chip when empty id present', (tester) async {
    final widget = pumpFilter(
      _baseState(selectedLabelIds: {''}),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Unassigned'), findsOneWidget);
  });

  testWidgets('stays hidden when no labels selected or tasks hidden',
      (tester) async {
    final hidden = pumpFilter(_baseState(selectedLabelIds: {}));
    await tester.pumpWidget(hidden);
    await tester.pumpAndSettle();
    expect(find.textContaining('Active label filters'), findsNothing);

    final state = _baseState(selectedLabelIds: {'label-a'}, showTasks: false);
    when(() => mockCache.getLabelById(any())).thenReturn(_buildLabel(
      'label-a',
      'Alpha',
    ));
    final widget = pumpFilter(state);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    expect(find.textContaining('Active label filters'), findsNothing);
  });
}
