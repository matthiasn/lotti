import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';

final testEpochDateTime = DateTime.fromMillisecondsSinceEpoch(0);

final measurableWater = MeasurableDataType(
  id: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
  displayName: 'Water',
  description: 'H₂O, with or without bubbles',
  unitName: 'ml',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  version: 1,
  aggregationType: AggregationType.dailySum,
);

final measurableChocolate = MeasurableDataType(
  id: 'f8f55c10-e30b-4bf5-990d-d569ce4867fb',
  displayName: 'Chocolate',
  description: 'Delicious cocoa based sweets, any origin',
  unitName: 'g',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  version: 1,
  aggregationType: AggregationType.dailySum,
);

final measurableCoverage = MeasurableDataType(
  id: '55cd4c41-efcf-4819-8619-f79281b1de17',
  displayName: 'Coverage',
  description: 'Lotti test coverage',
  unitName: '%',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  version: 1,
  aggregationType: AggregationType.none,
);

const testDashboardName = 'Some test dashboard';
const testDashboardDescription = 'Some test dashboard description';

final testDashboardConfig = DashboardDefinition(
  items: [
    DashboardHealthItem(
      color: '#0000FF',
      healthType: 'HealthDataType.RESTING_HEART_RATE',
    ),
    DashboardWorkoutItem(
      workoutType: 'running',
      displayName: 'Running calories',
      color: '#0000FF',
      valueType: WorkoutValueType.energy,
    ),
    DashboardMeasurementItem(
      id: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
      aggregationType: AggregationType.dailySum,
    ),
    DashboardMeasurementItem(
      id: 'f8f55c10-e30b-4bf5-990d-d569ce4867fb',
    ),
    DashboardSurveyItem(
      colorsByScoreKey: {
        'Positive Affect Score': '#00FF00',
        'Negative Affect Score': '#FF0000',
      },
      surveyType: 'panasSurveyTask',
      surveyName: 'PANAS',
    ),
    DashboardStoryTimeItem(
      storyTagId: testStoryTagReading.id,
      color: '#00FF00',
    ),
  ],
  name: testDashboardName,
  description: testDashboardDescription,
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  private: false,
  version: '',
  lastReviewed: testEpochDateTime,
  active: true,
  id: '',
);

final testStoryTagReading = StoryTag(
  id: '27bbabc6-f323-11ec-b939-0242ac120002',
  tag: 'Reading',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  private: false,
  vectorClock: null,
);

final testTextEntry = JournalEntry(
  meta: Metadata(
    id: '32ea936e-dfc6-43bd-8722-d816c35eb489',
    createdAt: DateTime(2022, 7, 7, 13),
    dateFrom: DateTime(2022, 7, 7, 13),
    dateTo: DateTime(2022, 7, 7, 14),
    updatedAt: DateTime(2022, 7, 7, 13),
    starred: true,
  ),
  entryText: EntryText(plainText: 'test entry text'),
);

final testTask = Task(
  data: TaskData(
    status: TaskStatus.open(
      id: 'status_id',
      createdAt: DateTime(2022, 7, 7, 11),
      utcOffset: 60,
    ),
    title: 'Add tests for journal page',
    statusHistory: [],
    dateTo: DateTime(2022, 7, 7, 11),
    dateFrom: DateTime(2022, 7, 7, 9),
    estimate: const Duration(hours: 3),
  ),
  meta: Metadata(
    id: '79ef5021-12df-4651-ac6e-c9a5b58a859c',
    createdAt: DateTime(2022, 7, 7, 9),
    dateFrom: DateTime(2022, 7, 7, 9),
    dateTo: DateTime(2022, 7, 7, 11),
    updatedAt: DateTime(2022, 7, 7, 11),
    starred: true,
  ),
  entryText: EntryText(plainText: '- test task text'),
);

final testWeightEntry = QuantitativeEntry(
  meta: Metadata(
    id: 'c4824b56-2d4e-4ac0-92b7-08e69dae0d5a',
    createdAt: DateTime(2022, 7, 7, 15),
    dateFrom: DateTime(2022, 7, 7, 15),
    dateTo: DateTime(2022, 7, 7, 15),
    updatedAt: DateTime(2022, 7, 7, 15),
    starred: false,
  ),
  data: QuantitativeData.discreteQuantityData(
    dateFrom: DateTime(2022, 7, 7, 15),
    dateTo: DateTime(2022, 7, 7, 15),
    value: 94.49400329589844,
    dataType: 'HealthDataType.WEIGHT',
    unit: 'HealthDataUnit.KILOGRAMS',
  ),
);

final testMeasurementEntry = MeasurementEntry(
  meta: Metadata(
    id: 'c4824b56-2d4e-4ac0-92b7-08e69dae0d5a',
    createdAt: DateTime(2022, 7, 7, 17),
    dateFrom: DateTime(2022, 7, 7, 17),
    dateTo: DateTime(2022, 7, 7, 17),
    updatedAt: DateTime(2022, 7, 7, 17),
    starred: false,
    private: true,
  ),
  data: MeasurementData(
    value: 100,
    dataTypeId: measurableChocolate.id,
    dateTo: DateTime(2022, 7, 7, 17),
    dateFrom: DateTime(2022, 7, 7, 17),
  ),
);

final testMeasuredCoverageEntry = MeasurementEntry(
  meta: Metadata(
    id: '2c6ffac2-a4b7-4b00-9ff3-ae696971fede',
    createdAt: DateTime(2022, 7, 7, 17),
    dateFrom: DateTime(2022, 7, 7, 17),
    dateTo: DateTime(2022, 7, 7, 17),
    updatedAt: DateTime(2022, 7, 7, 17),
    starred: false,
    private: false,
  ),
  data: MeasurementData(
    value: 42,
    dataTypeId: measurableCoverage.id,
    dateTo: DateTime(2022, 7, 7, 17),
    dateFrom: DateTime(2022, 7, 7, 17),
  ),
);
