// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_label_filter.dart';
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
  late FakeJournalPageController fakeController;
  late _MockEntitiesCacheService cacheService;
  late List<LabelDefinition> labels;

  setUp(() async {
    cacheService = _MockEntitiesCacheService();
    labels = List.generate(10, buildTestLabel);

    await getIt.reset();
    getIt.registerSingleton<EntitiesCacheService>(cacheService);

    when(() => cacheService.sortedLabels).thenReturn(labels);
    for (final label in labels) {
      when(() => cacheService.getLabelById(label.id)).thenReturn(label);
    }
    when(() => cacheService.showPrivateEntries).thenReturn(true);
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
    fakeController = FakeJournalPageController(state);

    return ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(true).overrideWith(() => fakeController),
      ],
      child: makeTestableWidgetWithScaffold(child),
    );
  }

  testWidgets('tapping label chip toggles selection', (tester) async {
    final widget = wrapFilter(const TaskLabelFilter(), _baseState());

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Label 0'));

    expect(fakeController.toggledLabelIds, contains('label-0'));
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

  testWidgets('Clear and Unlabeled chips trigger controller actions',
      (tester) async {
    final state = _baseState(selectedLabelIds: {'label-1'});
    final widget = wrapFilter(const TaskLabelFilter(), state);

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    expect(fakeController.clearSelectedLabelIdsCalled, 1);

    await tester.tap(find.text('Unlabeled'));
    expect(fakeController.toggledLabelIds, contains(''));
  });

  testWidgets('quick filter lists active labels and clears selections',
      (tester) async {
    final state = _baseState(selectedLabelIds: {'label-0', ''});
    fakeController = FakeJournalPageController(state);

    final widget = ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(true).overrideWith(() => fakeController),
      ],
      child: makeTestableWidgetWithScaffold(
        const TaskLabelQuickFilter(),
      ),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.textContaining('Active label filters'), findsOneWidget);
    expect(find.text('Label 0'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    expect(fakeController.toggledLabelIds, contains('label-0'));

    await tester.tap(find.text('Clear'));
    expect(fakeController.clearSelectedLabelIdsCalled, 1);
  });
}
