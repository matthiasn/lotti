import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  final rangeStart = DateTime(2024, 3, 8);
  final rangeEnd = DateTime(2024, 3, 15);

  late MockEntitiesCacheService mockCacheService;

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        mockCacheService = MockEntitiesCacheService();
        // The delegated HabitCompletionCard collapses to a shrink box when the
        // habit is unknown, which is all this test needs — it inspects the
        // forwarded widget configuration, not the rendered card.
        when(() => mockCacheService.getHabitById(any())).thenReturn(null);
        getIt.registerSingleton<EntitiesCacheService>(mockCacheService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets(
    'forwards its parameters to HabitCompletionCard and suppresses the linked '
    'dashboard (the card is already inside that dashboard)',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardHabitsChart(
            habitId: 'habit-1',
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
        ),
      );

      final card = tester.widget<HabitCompletionCard>(
        find.byType(HabitCompletionCard),
      );
      expect(card.habitId, 'habit-1');
      expect(card.rangeStart, rangeStart);
      expect(card.rangeEnd, rangeEnd);
      // The key behavior: tapping a row here must not re-open the dashboard the
      // user is already viewing.
      expect(card.showLinkedDashboard, isFalse);
    },
  );
}
