import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_item_card.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
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
        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);

        // Check the icon
        expect(find.byIcon(Icons.insights), findsOneWidget);

        // Check the title includes the measurement name and aggregation type
        expect(find.text('Test Measurement [dailySum]'), findsOneWidget);

        // Test tap functionality
        await tester.tap(find.byType(ListTile));
        await tester.pump();

        expect(updateCalled, isTrue);
        expect(updatedItem, equals(measurementItem));
        expect(updatedIndex, equals(0));
      });

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

        // Should render with empty title
        expect(find.text(''), findsOneWidget);
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

        expect(find.byType(Card), findsOneWidget);
        expect(find.byIcon(MdiIcons.stethoscope), findsOneWidget);
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

        expect(find.byType(Card), findsOneWidget);
        expect(find.byIcon(Icons.sports_gymnastics), findsOneWidget);
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

        expect(find.byType(Card), findsOneWidget);
        expect(find.byIcon(MdiIcons.clipboardOutline), findsOneWidget);
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

        expect(find.byType(Card), findsOneWidget);
        expect(find.byIcon(MdiIcons.lightningBolt), findsOneWidget);
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

        expect(find.byType(Card), findsOneWidget);
        expect(find.byIcon(MdiIcons.lightningBolt), findsOneWidget);
        expect(find.text('non-existent-habit'), findsOneWidget);
      });
    });
  });

  group('ItemCard', () {
    testWidgets('should render item card with title and icon', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: ItemCard(
            title: 'Test Title',
            leadingIcon: Icons.star,
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('should handle tap correctly', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: ItemCard(
            title: 'Test Title',
            leadingIcon: Icons.star,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });

    testWidgets('should render without onTap callback', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: ItemCard(
            title: 'Test Title',
            leadingIcon: Icons.star,
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      // Should not crash when tapped without onTap
      await tester.tap(find.byType(ListTile));
    });
  });
}
