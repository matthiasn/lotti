import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockJournalPageCubit extends Mock implements JournalPageCubit {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJournalDb mockDb;
  late MockJournalPageCubit mockCubit;

  setUp(() {
    mockDb = MockJournalDb();
    mockCubit = MockJournalPageCubit();

    // Mock the cubit state
    when(() => mockCubit.state).thenReturn(
      JournalPageState(
        selectedEntryTypes: const [],
        match: '',
        tagIds: const {},
        filters: const {},
        showPrivateEntries: true,
        showTasks: true,
        fullTextMatches: const {},
        pagingController: null,
        taskStatuses: const [],
        selectedTaskStatuses: const {},
        selectedCategoryIds: const {},
      ),
    );

    when(() => mockCubit.stream).thenAnswer(
      (_) => Stream<JournalPageState>.fromIterable([
        JournalPageState(
          selectedEntryTypes: const [],
          match: '',
          tagIds: const {},
          filters: const {},
          showPrivateEntries: true,
          showTasks: true,
          fullTextMatches: const {},
          pagingController: null,
          taskStatuses: const [],
          selectedTaskStatuses: const {},
          selectedCategoryIds: const {},
        ),
      ]),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('EntryTypeFilter Tests', () {
    testWidgets('filters out JournalEvent chip when enableEventsFlag is OFF',
        (tester) async {
      // Mock JournalDb.watchConfigFlags() to return enableEventsFlag: false
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: false,
            ),
          },
        ]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: 'Event' chip text is NOT found
      expect(find.text('Event'), findsNothing);
      // Assert: Other entry type chips ARE found (Task, Text, Audio, etc.)
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
    });

    testWidgets('shows JournalEvent chip when enableEventsFlag is ON',
        (tester) async {
      // Mock JournalDb.watchConfigFlags() to return enableEventsFlag: true
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
          },
        ]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: 'Event' chip text IS found
      expect(find.text('Event'), findsOneWidget);
      // Assert: All entry type chips are present
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
    });

    testWidgets('defaults to filtering out Event when flag stream is empty',
        (tester) async {
      // Mock stream returns empty set
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([{}]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: JournalEvent is filtered out (default false behavior)
      expect(find.text('Event'), findsNothing);
      expect(find.text('Task'), findsOneWidget);
    });

    testWidgets('updates when flag changes from OFF to ON', (tester) async {
      // Setup: StreamController to control flag changes
      final flagController = StreamController<Set<ConfigFlag>>();

      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => flagController.stream,
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
        ),
      );

      // Initial: flag OFF, verify Event chip hidden
      flagController.add({
        const ConfigFlag(
          name: enableEventsFlag,
          description: 'Enable Events?',
          status: false,
        ),
      });

      await tester.pumpAndSettle();
      expect(find.text('Event'), findsNothing);

      // Update: flag ON, verify Event chip appears
      flagController.add({
        const ConfigFlag(
          name: enableEventsFlag,
          description: 'Enable Events?',
          status: true,
        ),
      });

      await tester.pumpAndSettle();
      expect(find.text('Event'), findsOneWidget);

      await flagController.close();
    });
  });
}
