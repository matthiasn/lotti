import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

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

  Widget createTestWidget() {
    return const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: HabitCompletionRateChart(),
        ),
      ),
    );
  }

  group('HabitCompletionRateChart', () {
    testWidgets('renders chart widget', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify LineChart is rendered
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('displays default info label when no day selected',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show the default message
      expect(find.textContaining('active habits'), findsOneWidget);
      expect(find.textContaining('Tap chart'), findsOneWidget);
    });

    testWidgets('chart tap triggers setInfoYmd on next frame', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the LineChart
      final chartFinder = find.byType(LineChart);
      expect(chartFinder, findsOneWidget);

      // Get the center of the chart
      final chartCenter = tester.getCenter(chartFinder);

      // Tap the chart
      await tester.tapAt(chartCenter);

      // Pump to allow addPostFrameCallback to execute
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The test verifies the tap doesn't cause an error
      // (the previous bug was modifying state during paint)
      // The actual setInfoYmd call is deferred via addPostFrameCallback
    });

    testWidgets('displays percentage info when day is selected',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsControllerProvider.overrideWith(_TestHabitsController.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HabitCompletionRateChart(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The test controller sets selectedInfoYmd, so we should see percentages
      expect(find.textContaining('2025-12-30'), findsOneWidget);
      expect(find.textContaining('% successful'), findsOneWidget);
      expect(find.textContaining('% skipped'), findsOneWidget);
      expect(find.textContaining('% recorded fails'), findsOneWidget);
    });
  });
}

/// Test controller that provides a state with selectedInfoYmd set
class _TestHabitsController extends HabitsController {
  @override
  HabitsState build() {
    return HabitsState.initial().copyWith(
      selectedInfoYmd: '2025-12-30',
      successPercentage: 75,
      skippedPercentage: 10,
      failedPercentage: 15,
    );
  }
}
