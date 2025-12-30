// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/tasks/ui/filtering/task_label_quick_filter.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:mocktail/mocktail.dart' as mocktail;
import 'package:visibility_detector/visibility_detector.dart';

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
  Future<void> refreshQuery() async {}

  @override
  void updateVisibility(VisibilityInfo info) {}

  @override
  Future<void> toggleSelectedLabelId(String id) async {
    toggledLabelIds.add(id);
  }

  @override
  Future<void> clearSelectedLabelIds() async {
    clearSelectedLabelIdsCalled++;
  }
}

class _MockEntitiesCacheService extends mocktail.Mock
    implements EntitiesCacheService {}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeJournalPageController fakeController;
  late _MockEntitiesCacheService mockCache;

  setUpAll(() {
    // Avoid pending timers from VisibilityDetector during tests
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() async {
    await getIt.reset();
    mockCache = _MockEntitiesCacheService();
    getIt
      ..registerSingleton<EntitiesCacheService>(mockCache)
      ..registerSingleton<UserActivityService>(UserActivityService());
  });

  tearDown(() async {
    await getIt.reset();
  });

  // Helper copied from the existing infinite_journal_page_test.dart pattern
  Future<void> pumpWithDelay(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget pumpBody(JournalPageState state) {
    fakeController = FakeJournalPageController(state);

    return ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(true).overrideWith(() => fakeController),
      ],
      child: makeTestableWidgetWithScaffold(
        const InfiniteJournalPageBody(showTasks: true),
      ),
    );
  }

  testWidgets('shows quick filter sliver with padding when labels selected',
      (tester) async {
    final work = _buildLabel('label-work', 'Work');
    mocktail.when(() => mockCache.getLabelById(work.id)).thenReturn(work);

    final widget = pumpBody(_baseState(selectedLabelIds: {work.id}));
    await tester.pumpWidget(widget);
    await pumpWithDelay(tester);

    // Quick filter appears
    expect(find.byType(TaskLabelQuickFilter), findsOneWidget);

    // The quick filter is not inside the app bar anymore
    expect(
      find.descendant(
        of: find.byType(JournalSliverAppBar),
        matching: find.byType(TaskLabelQuickFilter),
      ),
      findsNothing,
    );

    // Verify content-aligned padding around the quick filter
    final paddingFinder = find.byWidgetPredicate(
      (w) =>
          w is Padding && w.padding == const EdgeInsets.fromLTRB(40, 8, 40, 8),
    );

    expect(
      find.descendant(
        of: paddingFinder,
        matching: find.byType(TaskLabelQuickFilter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('clear button clears all selected labels', (tester) async {
    final focus = _buildLabel('label-focus', 'Focus');
    mocktail.when(() => mockCache.getLabelById(focus.id)).thenReturn(focus);

    final widget = pumpBody(_baseState(selectedLabelIds: {focus.id}));
    await tester.pumpWidget(widget);
    await pumpWithDelay(tester);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(fakeController.clearSelectedLabelIdsCalled, 1);
  });

  testWidgets('quick filter section hidden when no labels selected',
      (tester) async {
    final widget = pumpBody(_baseState(selectedLabelIds: {}));
    await tester.pumpWidget(widget);
    await pumpWithDelay(tester);

    // With no selected labels, the quick filter sliver is not rendered at all.
    expect(find.byType(TaskLabelQuickFilter), findsNothing);
    expect(find.textContaining('Active label filters'), findsNothing);
    expect(find.byType(InputChip), findsNothing);
  });
}
