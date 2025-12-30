import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habits_search.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late StreamController<List<HabitDefinition>> definitionsController;
  late StreamController<Set<String>> updateController;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    definitionsController = StreamController.broadcast();
    updateController = StreamController.broadcast();

    when(mockJournalDb.watchHabitDefinitions)
        .thenAnswer((_) => definitionsController.stream);

    when(
      () => mockJournalDb.getHabitCompletionsInRange(
        rangeStart: any(named: 'rangeStart'),
      ),
    ).thenAnswer((_) async => []);

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateController.stream);

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() async {
    await definitionsController.close();
    await updateController.close();
    await getIt.reset();
  });

  group('HabitsSearchWidget', () {
    testWidgets('renders search bar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HabitsSearchWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('updates state when text is entered', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const HabitsSearchWidget();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(SearchBar), 'test query');
      await tester.pumpAndSettle();

      // Verify state was updated (lowercase)
      final state = capturedRef.read(habitsControllerProvider);
      expect(state.searchString, 'test query');
    });

    testWidgets('shows clear button when search has text', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HabitsSearchWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no clear button visible
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Enter search text
      await tester.enterText(find.byType(SearchBar), 'test');
      await tester.pumpAndSettle();

      // Clear button should now be visible
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('clear button clears search text and state', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const HabitsSearchWidget();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(SearchBar), 'test query');
      await tester.pumpAndSettle();

      // Verify text was entered
      expect(capturedRef.read(habitsControllerProvider).searchString,
          'test query');

      // Tap clear button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Verify state was cleared
      expect(capturedRef.read(habitsControllerProvider).searchString, isEmpty);
    });

    testWidgets('search text persists across rebuilds', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HabitsSearchWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(SearchBar), 'persistent text');
      await tester.pumpAndSettle();

      // Trigger a rebuild by pumping with a new frame
      await tester.pump(const Duration(milliseconds: 100));

      // Verify text is still in the SearchBar
      final searchBar = tester.widget<SearchBar>(find.byType(SearchBar));
      expect(searchBar.controller?.text, 'persistent text');
    });

    testWidgets('syncs controller text when state changes externally',
        (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const HabitsSearchWidget();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter some text
      await tester.enterText(find.byType(SearchBar), 'initial text');
      await tester.pumpAndSettle();

      // Change state externally (e.g., via another widget)
      capturedRef.read(habitsControllerProvider.notifier).setSearchString('');
      await tester.pumpAndSettle();

      // Verify the text field was cleared
      final searchBar = tester.widget<SearchBar>(find.byType(SearchBar));
      expect(searchBar.controller?.text, isEmpty);
    });

    testWidgets('converts input to lowercase', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const HabitsSearchWidget();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter mixed case text
      await tester.enterText(find.byType(SearchBar), 'TEST Query');
      await tester.pumpAndSettle();

      // Verify state is lowercase
      expect(
        capturedRef.read(habitsControllerProvider).searchString,
        'test query',
      );
    });
  });
}
