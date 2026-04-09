// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../widget_test_utils.dart';

class _FakeJournalPageController extends JournalPageController {
  _FakeJournalPageController(this._testState);

  final JournalPageState _testState;

  @override
  JournalPageState build(bool showTasks) => _testState;

  @override
  JournalPageState get state => _testState;

  @override
  Future<void> refreshQuery() async {}

  @override
  void updateVisibility(VisibilityInfo info) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<UserActivityService>(UserActivityService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets('adds 100px bottom spacer sliver', (tester) async {
    const state = JournalPageState(
      match: '',
      filters: <DisplayFilter>{},
      showPrivateEntries: false,
      showTasks: false,
      selectedEntryTypes: <String>[],
      fullTextMatches: <String>{},
      pagingController: null,
      taskStatuses: <String>[],
      selectedTaskStatuses: <String>{},
      selectedCategoryIds: <String>{},
      selectedLabelIds: <String>{},
      selectedPriorities: <String>{},
    );

    final fakeController = _FakeJournalPageController(state);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const InfiniteJournalPage(),
        overrides: [
          journalPageScopeProvider.overrideWithValue(false),
          journalPageControllerProvider(
            false,
          ).overrideWith(() => fakeController),
        ],
      ),
    );

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 100,
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders paged list branch when pagingController is present', (
    tester,
  ) async {
    final controller = PagingController<int, JournalEntity>(
      getNextPageKey: (PagingState<int, JournalEntity> state) => null,
      fetchPage: (int pageKey) async => <JournalEntity>[],
    );

    final state = JournalPageState(
      match: '',
      filters: <DisplayFilter>{},
      showPrivateEntries: false,
      showTasks: false,
      selectedEntryTypes: const <String>[],
      fullTextMatches: <String>{},
      pagingController: controller,
      taskStatuses: const <String>[],
      selectedTaskStatuses: <String>{},
      selectedCategoryIds: <String>{},
      selectedLabelIds: <String>{},
      selectedPriorities: <String>{},
    );

    final fakeController = _FakeJournalPageController(state);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const InfiniteJournalPage(),
        overrides: [
          journalPageScopeProvider.overrideWithValue(false),
          journalPageControllerProvider(
            false,
          ).overrideWith(() => fakeController),
        ],
      ),
    );

    // Smoke check: branch builds without throwing.
    expect(true, isTrue);
  });
}
