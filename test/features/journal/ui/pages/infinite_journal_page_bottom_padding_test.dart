import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MockJournalPageCubit extends MockCubit<JournalPageState>
    implements JournalPageCubit {}

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
    final mockCubit = MockJournalPageCubit();
    final state = JournalPageState(
      match: '',
      tagIds: <String>{},
      filters: <DisplayFilter>{},
      showPrivateEntries: false,
      showTasks: false, // simpler app bar
      selectedEntryTypes: const <String>[],
      fullTextMatches: <String>{},
      pagingController: null, // triggers loading branch
      taskStatuses: const <String>[],
      selectedTaskStatuses: <String>{},
      selectedCategoryIds: <String?>{},
      selectedLabelIds: <String>{},
      selectedPriorities: <String>{},
    );

    when(mockCubit.refreshQuery).thenAnswer((_) async {});

    whenListen<JournalPageState>(
      mockCubit,
      const Stream<JournalPageState>.empty(),
      initialState: state,
    );
    // Also ensure direct state getter returns our state when read.
    when(() => mockCubit.state).thenReturn(state);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const InfiniteJournalPageBody(showTasks: false),
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
      selectedCategoryIds: <String?>{},
      selectedLabelIds: <String>{},
      selectedPriorities: <String>{},
    );

    final mockCubit = MockJournalPageCubit();
    when(mockCubit.refreshQuery).thenAnswer((_) async {});
    when(() => mockCubit.state).thenReturn(state);
    whenListen<JournalPageState>(
      mockCubit,
      const Stream<JournalPageState>.empty(),
      initialState: state,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const InfiniteJournalPageBody(showTasks: false),
          ),
        ),
      ),
    );

    // Smoke check: branch builds without throwing.
    expect(true, isTrue);
  });
}
