// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:visibility_detector/visibility_detector.dart';

class FakeJournalPageController extends JournalPageController {
  FakeJournalPageController(this._testState);

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
    await getIt.reset();
    getIt.allowReassignment = true;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    // Required by InfiniteJournalPageBody initState (adds a scroll listener)
    getIt.registerSingleton<UserActivityService>(UserActivityService());
  });

  tearDown(getIt.reset);

  testWidgets('adds 100px bottom spacer sliver', (tester) async {
    const state = JournalPageState(
      match: '',
      tagIds: <String>{},
      filters: <DisplayFilter>{},
      showPrivateEntries: false,
      showTasks: false, // simpler app bar
      selectedEntryTypes: <String>[],
      fullTextMatches: <String>{},
      pagingController: null, // triggers loading branch
      taskStatuses: <String>[],
      selectedTaskStatuses: <String>{},
      selectedCategoryIds: <String>{},
      selectedLabelIds: <String>{},
      selectedPriorities: <String>{},
    );

    final fakeController = FakeJournalPageController(state);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(false),
          journalPageControllerProvider(false)
              .overrideWith(() => fakeController),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfiniteJournalPageBody(showTasks: false),
          ),
        ),
      ),
    );

    // Allow a frame for slivers to build
    await tester.pump(const Duration(milliseconds: 16));

    // Allow VisibilityDetector's deferred update (500ms) to complete
    await tester.pump(const Duration(milliseconds: 600));

    // The page should contain a SizedBox(height: 100) as the terminal sliver
    expect(
      find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 100,
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders paged list branch when pagingController is present',
      (tester) async {
    // Set up a minimal PagingController that never fetches additional pages.
    final controller = PagingController<int, JournalEntity>(
      getNextPageKey: (PagingState<int, JournalEntity> state) => null,
      fetchPage: (int pageKey) async => <JournalEntity>[],
    );

    final state = JournalPageState(
      match: '',
      tagIds: <String>{},
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

    final fakeController = FakeJournalPageController(state);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(false),
          journalPageControllerProvider(false)
              .overrideWith(() => fakeController),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfiniteJournalPageBody(showTasks: false),
          ),
        ),
      ),
    );

    // Smoke check: branch builds without throwing.
    expect(true, isTrue);
  });
}
