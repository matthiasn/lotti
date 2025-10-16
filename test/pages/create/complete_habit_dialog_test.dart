import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/ui/complete_habit_dialog.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('HabitDialog Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeHabitCompletionData());
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithHabits([
        habitFlossing,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      when(
        () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
      ).thenAnswer((_) => habitFlossing);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });
    tearDown(getIt.reset);

    Future<void> pumpHabitDialog(WidgetTester tester) async {
      final delegate = BeamerDelegate(
        locationBuilder: RoutesLocationBuilder(
          routes: {
            '/': (context, state, data) => Container(),
          },
        ).call,
      );

      await tester.pumpWidget(
        makeTestableWidget(
          BeamerProvider(
            routerDelegate: delegate,
            child: Material(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 800,
                  maxWidth: 800,
                ),
                child: HabitDialog(
                  habitId: habitFlossing.id,
                  themeData: ThemeData(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
    }

    testWidgets('Habit completion can be recorded', (tester) async {
      when(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).thenAnswer((_) async => null);

      await pumpHabitDialog(tester);

      expect(find.text(habitFlossing.name), findsOneWidget);

      final commentFieldFinder = find.byKey(const Key('habit_comment_field'));
      final saveButtonFinder = find.byKey(const Key('habit_save'));

      expect(commentFieldFinder, findsOneWidget);
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('Fail button records a failed completion', (tester) async {
      when(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).thenAnswer((_) async => null);

      await pumpHabitDialog(tester);

      await tester.tap(find.byKey(const Key('habit_fail')));
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: captureAny(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).captured;

      final completion = captured.single as HabitCompletionData;
      expect(completion.completionType, HabitCompletionType.fail);
    });

    testWidgets('Skip button records a skipped completion', (tester) async {
      when(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).thenAnswer((_) async => null);

      await pumpHabitDialog(tester);

      await tester.tap(find.byKey(const Key('habit_skip')));
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: captureAny(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).captured;

      final completion = captured.single as HabitCompletionData;
      expect(completion.completionType, HabitCompletionType.skip);
    });

    testWidgets('Shows dashboard preview when habit has dashboard id',
        (tester) async {
      final habitWithDashboard = habitFlossing.copyWith(dashboardId: 'dash-1');

      when(
        () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
      ).thenAnswer((_) => habitWithDashboard);

      when(
        () => mockEntitiesCacheService.getDashboardById(any()),
      ).thenReturn(null);

      when(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitWithDashboard,
        ),
      ).thenAnswer((_) async => null);

      await pumpHabitDialog(tester);

      expect(find.byType(SingleChildScrollView).evaluate().length, 2);
    });
  });
}
