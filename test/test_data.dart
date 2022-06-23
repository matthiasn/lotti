import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';

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
