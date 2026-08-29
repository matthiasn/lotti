import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_item_card.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/widgets/charts/dashboard_item_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../test_helper.dart';

void main() {
  group('DashboardItemCard', () {
    late MockJournalDb mockJournalDb;

    setUp(() {
      mockJournalDb = MockJournalDb();

      final mockUpdateNotifications = MockUpdateNotifications();
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => const Stream.empty());

      // Register mocks with GetIt
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }
      if (getIt.isRegistered<UpdateNotifications>()) {
        getIt.unregister<UpdateNotifications>();
      }

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb);
    });

    tearDown(getIt.reset);

    group('Measurement Item', () {
      testWidgets('should render measurement item card correctly', (
        tester,
      ) async {
        const measurementItem = DashboardItem.measurement(
          id: 'test-measurement-id',
          aggregationType: AggregationType.dailySum,
        );

        final testDate = DateTime(2024, 3, 15);
        final measurableTypes = [
          EntityDefinition.measurableDataType(
                id: 'test-measurement-id',
                createdAt: testDate,
                updatedAt: testDate,
                displayName: 'Test Measurement',
                description: 'Test description',
                unitName: 'kg',
                version: 1,
                vectorClock: const VectorClock({'user': 0}),
              )
              as MeasurableDataType,
        ];

        when(
          () => mockJournalDb.getAllMeasurableDataTypes(),
        ).thenAnswer((_) async => measurableTypes);

        var updateCalled = false;
        DashboardItem? updatedItem;
        int? updatedIndex;

        await tester.pumpWidget(
          WidgetTestBench(
            child: DashboardItemCard(
              index: 0,
              item: measurementItem,
              updateItemFn: (item, index) {
                updateCalled = true;
                updatedItem = item;
                updatedIndex = index;
              },
            ),
          ),
        );

        await tester.pump();

        // Check that the card is rendered
        expect(find.byType(ItemCard), findsOneWidget);

        // Check the leading icon and the explicit drag handle
        expect(find.byIcon(LottiIcons.insights), findsOneWidget);
        expect(find.byIcon(LottiIcons.drag), findsOneWidget);

        // The title joins the measurement name and the localized
        // aggregation name — no raw enum identifiers, no brackets.
        expect(find.text('Test Measurement — Daily sum'), findsOneWidget);
        expect(find.textContaining('dailySum'), findsNothing);

        final itemCard = tester.widget<ItemCard>(find.byType(ItemCard));
        expect(itemCard.onTap, isNotNull);
        expect(updateCalled, isFalse);
        expect(updatedItem, isNull);
        expect(updatedIndex, isNull);
      });

      testWidgets(
        'tapping a numeric measurement card opens the aggregation editor '
        'for that chart',
        (tester) async {
          const measurementItem = DashboardItem.measurement(
            id: 'water-id',
            aggregationType: AggregationType.dailySum,
          );
          when(() => mockJournalDb.getAllMeasurableDataTypes()).thenAnswer(
            (_) async => [measurableWater.copyWith(id: 'water-id')],
          );

          await tester.pumpWidget(
            WidgetTestBench(
              child: DashboardItemCard(
                index: 0,
                item: measurementItem,
                updateItemFn: (item, index) {},
              ),
            ),
          );
          await tester.pump();

          tester.widget<ItemCard>(find.byType(ItemCard)).onTap!();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.text('Aggregation type'), findsOneWidget);
          final modal = tester.widget<DashboardItemModal>(
            find.byType(DashboardItemModal),
          );
          expect(modal.item, measurementItem);
          expect(modal.index, 0);
          expect(modal.chartTitle, 'Water — Daily sum');
        },
      );

      testWidgets(
        'a choice measurable names itself without an aggregation and opens '
        'no aggregation editor',
        (tester) async {
          const measurementItem = DashboardItem.measurement(
            id: 'hydration-id',
            aggregationType: AggregationType.dailySum,
          );
          when(() => mockJournalDb.getAllMeasurableDataTypes()).thenAnswer(
            (_) async => [measurableHydration.copyWith(id: 'hydration-id')],
          );

          await tester.pumpWidget(
            WidgetTestBench(
              child: DashboardItemCard(
                index: 0,
                item: measurementItem,
                updateItemFn: (item, index) {},
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Hydration'), findsOneWidget);
          expect(find.textContaining('Daily sum'), findsNothing);
          final itemCard = tester.widget<ItemCard>(find.byType(ItemCard));
          expect(itemCard.onTap, isNull);
          expect(itemCard.editSemanticsLabel, isNull);
        },
      );

      testWidgets('should handle measurement item without aggregation type', (
        tester,
      ) async {
        const measurementItem = DashboardItem.measurement(
          id: 'test-measurement-id',
        );

        final testDate = DateTime(2024, 3, 15);
        final measurableTypes = [
          EntityDefinition.measurableDataType(
                id: 'test-measurement-id',
                createdAt: testDate,
                updatedAt: testDate,
                displayName: 'Test Measurement',
                description: 'Test description',
                unitName: 'kg',
                version: 1,
                vectorClock: const VectorClock({'user': 0}),
              )
              as MeasurableDataType,
        ];

        when(
          () => mockJournalDb.getAllMeasurableDataTypes(),
        ).thenAnswer((_) async => measurableTypes);

        await tester.pumpWidget(
          WidgetTestBench(
            child: DashboardItemCard(
              index: 0,
              item: measurementItem,
              updateItemFn: (item, index) {},
            ),
          ),
        );

        await tester.pump();

        // Check the title without aggregation type
        expect(find.text('Test Measurement'), findsOneWidget);
      });

      testWidgets('should handle measurement item with no matching data type', (
        tester,
      ) async {
        const measurementItem = DashboardItem.measurement(
          id: 'non-existent-id',
          aggregationType: AggregationType.dailySum,
        );

        when(
          () => mockJournalDb.getAllMeasurableDataTypes(),
        ).thenAnswer((_) async => []);

        await tester.pumpWidget(
          WidgetTestBench(
            child: DashboardItemCard(
              index: 0,
              item: measurementItem,
              updateItemFn: (item, index) {},
            ),
          ),
        );

        await tester.pump();

        // Missing data type falls back to the item id (not a blank row).
        expect(find.text('non-existent-id'), findsOneWidget);
      });
    });

    group('Health Chart Item', () {
      testWidgets('should render health chart item correctly', (tester) async {
        const healthItem = DashboardItem.healthChart(
          color: '#FF0000',
          healthType: 'steps',
        );

        await tester.pumpWidget(
          WidgetTestBench(
            child: DashboardItemCard(
              index: 0,
              item: healthItem,
              updateItemFn: (item, index) {},
            ),
          ),
        );

        expect(find.byType(ItemCard), findsOneWidget);
        expect(find.byIcon(LottiIcons.stethoscope), findsOneWidget);
        expect(find.text('steps'), findsOneWidget);
      });
    });

    group('Workout Chart Item', () {
      testWidgets('should render workout chart item correctly', (tester) async {
        const workoutItem = DashboardItem.workoutChart(
          workoutType: 'running',
          displayName: 'Running Session',
          color: '#00FF00',
          valueType: WorkoutValueType.duration,
        );

        await tester.pumpWidget(
          WidgetTestBench(
            child: DashboardItemCard(
              index: 0,
              item: workoutItem,
              updateItemFn: (item, index) {},
            ),
          ),
        );

        expect(find.byType(ItemCard), findsOneWidget);
        expect(find.byIcon(LottiIcons.fitness), findsOneWidget);
        expect(find.text('Running (time)'), findsOneWidget);
      });
    });

    group('Survey Chart Item', () {
      testWidgets('should render survey chart item correctly', (tester) async {
        const surveyItem = DashboardItem.surveyChart(
          colorsByScoreKey: {'score1': '#FF0000', 'score2': '#00FF00'},
          surveyType: 'mood',
          surveyName: 'Daily Mood Survey',
        );

        await tester.pumpWidget(
          WidgetTestBench(
            child: DashboardItemCard(
              index: 0,
              item: surveyItem,
              updateItemFn: (item, index) {},
            ),
          ),
        );

        expect(find.byType(ItemCard), findsOneWidget);
        expect(find.byIcon(LottiIcons.clipboard), findsOneWidget);
        expect(find.text('Daily Mood Survey'), findsOneWidget);
      });
    });

    group('Habit Chart Item', () {
      testWidgets('should render habit chart item correctly', (tester) async {
        const habitItem = DashboardItem.habitChart(
          habitId: 'test-habit-id',
        );

        final testDate = DateTime(2024, 3, 15);
        final habitDefinition =
            EntityDefinition.habit(
                  id: 'test-habit-id',
                  createdAt: testDate,
                  updatedAt: testDate,
                  name: 'Daily Exercise',
                  description: 'Exercise for 30 minutes',
                  habitSchedule: const HabitSchedule.daily(
                    requiredCompletions: 1,
                  ),
                  vectorClock: const VectorClock({'user': 0}),
                  active: true,
                  private: false,
                )
                as HabitDefinition;

        when(
          () => mockJournalDb.getHabitById('test-habit-id'),
        ).thenAnswer((_) async => habitDefinition);

        await tester.pumpWidget(
          WidgetTestBench(
            child: DashboardItemCard(
              index: 0,
              item: habitItem,
              updateItemFn: (item, index) {},
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(ItemCard), findsOneWidget);
        expect(find.byIcon(LottiIcons.bolt), findsOneWidget);
        expect(find.text('Daily Exercise'), findsOneWidget);
      });

      testWidgets('should handle habit item with no habit definition', (
        tester,
      ) async {
        const habitItem = DashboardItem.habitChart(
          habitId: 'non-existent-habit',
        );

        when(
          () => mockJournalDb.getHabitById('non-existent-habit'),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          WidgetTestBench(
            child: DashboardItemCard(
              index: 0,
              item: habitItem,
              updateItemFn: (item, index) {},
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(ItemCard), findsOneWidget);
        expect(find.byIcon(LottiIcons.bolt), findsOneWidget);
        expect(find.text('non-existent-habit'), findsOneWidget);
      });
    });
  });

  group('ItemCard', () {
    testWidgets('should render title, leading icon, and drag handle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: ItemCard(
            title: 'Test Title',
            leadingIcon: LottiIcons.star,
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byIcon(LottiIcons.star), findsOneWidget);
      // Reorderable rows carry a visible drag handle.
      expect(find.byIcon(LottiIcons.drag), findsOneWidget);
    });

    testWidgets('should handle tap correctly', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: ItemCard(
            title: 'Test Title',
            leadingIcon: LottiIcons.star,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(ItemCard));
      expect(tapped, isTrue);
    });

    testWidgets('should render without onTap callback', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: ItemCard(
            title: 'Test Title',
            leadingIcon: LottiIcons.star,
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byIcon(LottiIcons.star), findsOneWidget);

      // Should not crash when tapped without onTap
      await tester.tap(find.byType(ItemCard));
    });

    testWidgets('should expose edit and remove controls', (tester) async {
      var edited = false;
      var removed = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: ItemCard(
            title: 'Test Title',
            leadingIcon: LottiIcons.star,
            onTap: () => edited = true,
            onRemove: () => removed = true,
            editSemanticsLabel: 'Edit aggregation',
          ),
        ),
      );

      expect(find.byTooltip('Edit aggregation'), findsOneWidget);
      expect(find.byTooltip('Remove chart'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit aggregation'));
      await tester.pump();
      expect(edited, isTrue);
      expect(removed, isFalse);

      await tester.tap(find.byTooltip('Remove chart'));
      await tester.pump();
      expect(removed, isTrue);
    });
  });
}
