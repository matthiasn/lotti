import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habits_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockUpdateNotifications mockUpdateNotifications;
  late StreamController<List<HabitDefinition>> definitionsController;
  late StreamController<Set<String>> updateController;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockEntitiesCacheService = MockEntitiesCacheService();
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

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([
      categoryMindfulness,
    ]);

    when(() => mockEntitiesCacheService.getCategoryById(any())).thenReturn(
      categoryMindfulness,
    );

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() async {
    await definitionsController.close();
    await updateController.close();
    await getIt.reset();
  });

  group('HabitsFilter', () {
    testWidgets('renders filter icon when no habits', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsControllerProvider.overrideWith(_EmptyController.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HabitsFilter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the empty filter icon
      expect(find.byIcon(Icons.filter_alt_off_outlined), findsOneWidget);
    });

    testWidgets('renders pie chart when habits have categories',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsControllerProvider.overrideWith(_WithHabitsController.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HabitsFilter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have an IconButton
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('opens modal when tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsControllerProvider.overrideWith(_WithHabitsController.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HabitsFilter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the filter button
      await tester.tap(find.byKey(const Key('habit_category_filter')));
      await tester.pumpAndSettle();

      // Modal should show category chips
      expect(find.byType(ActionChip), findsWidgets);
    });

    testWidgets('toggles category when chip is tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsControllerProvider.overrideWith(_WithHabitsController.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HabitsFilter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the filter button to open modal
      await tester.tap(find.byKey(const Key('habit_category_filter')));
      await tester.pumpAndSettle();

      // Find and tap a category chip
      final chipFinder = find.byType(ActionChip);
      expect(chipFinder, findsWidgets);

      await tester.tap(chipFinder.first);
      await tester.pumpAndSettle();
    });
  });
}

class _EmptyController extends HabitsController {
  @override
  HabitsState build() {
    return HabitsState.initial();
  }

  @override
  void toggleSelectedCategoryIds(String categoryId) {}
}

class _WithHabitsController extends HabitsController {
  @override
  HabitsState build() {
    return HabitsState.initial().copyWith(
      openNow: [habitFlossing],
      habitDefinitions: [habitFlossing],
    );
  }

  @override
  void toggleSelectedCategoryIds(String categoryId) {}
}
