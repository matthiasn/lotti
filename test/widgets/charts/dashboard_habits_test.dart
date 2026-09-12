import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;

  group('DashboardHabitsChart Widget Tests - ', () {
    setUp(() async {
      final mocks = await setUpTestGetIt();
      mockJournalDb = mocks.journalDb;
      when(
        mockJournalDb.getAllHabitDefinitions,
      ).thenAnswer((_) async => [habitFlossing]);
      when(
        () => mockJournalDb.getHabitById(habitFlossing.id),
      ).thenAnswer((_) async => habitFlossing);
      final mockEntitiesCacheService = MockEntitiesCacheService();
      final mockUpdateNotifications = mocks.updateNotifications;

      getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

      when(
        () => mockJournalDb.getHabitCompletionsByHabitId(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          habitId: habitFlossing.id,
        ),
      ).thenAnswer((_) async => []);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(
        () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
      ).thenAnswer((_) => habitFlossing);
    });
    tearDown(tearDownTestGetIt);

    testWidgets('renders habit chart with title and completion card', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardHabitsChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            habitId: habitFlossing.id,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(habitFlossing.name), findsOneWidget);
      expect(find.byType(HabitCompletionCard), findsOneWidget);
    });
  });
}
