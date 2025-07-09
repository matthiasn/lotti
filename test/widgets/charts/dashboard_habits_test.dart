import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();

  group('DashboardHabitsChart Widget Tests - ', () {
    setUp(() {
      mockJournalDb = mockJournalDbWithHabits([habitFlossing]);
      final mockEntitiesCacheService = MockEntitiesCacheService();
      final mockUpdateNotifications = MockUpdateNotifications();

      getIt
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb);

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
    tearDown(getIt.reset);

    testWidgets('workout chart for running distance is rendered',
        (tester) async {
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

      // chart displays expected title
      expect(
        find.text(habitFlossing.name),
        findsOneWidget,
      );
    });
  });
}
