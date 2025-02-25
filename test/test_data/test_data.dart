import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/vector_clock.dart';

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

final categoryMindfulness = CategoryDefinition(
  id: '3a163404-c80b-11ed-afa1-0242ac120002',
  name: 'Mindfulness',
  color: '#0000FFFF',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  active: true,
  private: false,
);

final habitFlossing = HabitDefinition(
  id: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
  name: 'Flossing',
  description: 'Maintain healthy teeth and gums',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  active: true,
  private: false,
);

final habitFlossingDueLater = HabitDefinition(
  id: '4325b06e-a24c-4d90-b42b-5006f5f82f48',
  name: 'Flossing later today',
  description: 'Maintain healthy teeth and gums',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  active: true,
  private: false,
  activeFrom: DateTime.now().add(const Duration(minutes: 10)),
);

final measurablePullUps = MeasurableDataType(
  id: '22922182-15bf-4f2b-864f-1f546f95cac2',
  displayName: 'Pull-Ups',
  description: 'maximum repetitions in one recording',
  unitName: 'reps',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  version: 1,
  aggregationType: AggregationType.dailyMax,
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
    const DashboardHealthItem(
      color: '#0000FF',
      healthType: 'HealthDataType.RESTING_HEART_RATE',
    ),
    const DashboardWorkoutItem(
      workoutType: 'running',
      displayName: 'Running calories',
      color: '#0000FF',
      valueType: WorkoutValueType.energy,
    ),
    const DashboardMeasurementItem(
      id: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
      aggregationType: AggregationType.dailySum,
    ),
    const DashboardMeasurementItem(
      id: 'f8f55c10-e30b-4bf5-990d-d569ce4867fb',
    ),
    const DashboardSurveyItem(
      colorsByScoreKey: {
        'Positive Affect Score': '#00FF00',
        'Negative Affect Score': '#FF0000',
      },
      surveyType: 'panasSurveyTask',
      surveyName: 'PANAS',
    ),
    DashboardStoryTimeItem(
      storyTagId: testStoryTag1.id,
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
  categoryId: categoryMindfulness.id,
);

final emptyTestDashboardConfig = DashboardDefinition(
  items: [],
  name: 'Test Dashboard #2 - empty',
  description: 'testDashboardDescription #2',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  private: false,
  version: '',
  lastReviewed: testEpochDateTime,
  active: true,
  id: '',
);

final testStoryTag1 = StoryTag(
  id: '27bbabc6-f323-11ec-b939-0242ac120002',
  tag: 'Reading',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  private: false,
  vectorClock: null,
);

final testPersonTag1 = PersonTag(
  id: '6de83f4d-74db-43e5-9971-c977fc5a10f7',
  tag: 'Jane Doe',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  private: false,
  vectorClock: null,
);

final testTag1 = GenericTag(
  id: '614b9c7f-f180-45b5-81e0-8f879bdd5f9f',
  tag: 'SomeGenericTag',
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
    vectorClock: const VectorClock({'a': 11}),
  ),
  entryText: const EntryText(plainText: 'test entry text'),
  geolocation: Geolocation(
    geohashString: '',
    longitude: 13.43,
    latitude: 52.51,
    createdAt: DateTime(2022, 7, 7, 13),
  ),
);

final testTextEntryNoGeo = JournalEntry(
  meta: Metadata(
    id: '32ea936e-dfc6-43bd-8722-d816c35eb322',
    createdAt: DateTime(2022, 7, 7, 13),
    dateFrom: DateTime(2022, 7, 7, 13),
    dateTo: DateTime(2022, 7, 7, 14),
    updatedAt: DateTime(2022, 7, 7, 13),
    starred: true,
    vectorClock: const VectorClock({'a': 11}),
  ),
  entryText: const EntryText(plainText: 'test entry text'),
);

final testTextEntryWithTags = testTextEntry.copyWith(
  meta: testTextEntry.meta.copyWith(
    tagIds: [
      testStoryTag1.id,
      testPersonTag1.id,
    ],
  ),
);

final testImageEntry = JournalImage(
  meta: Metadata(
    id: '32ea936e-dfc6-43bd-8722-d816c35eb489',
    createdAt: DateTime(2022, 7, 7, 13),
    dateFrom: DateTime(2022, 7, 7, 13),
    dateTo: DateTime(2022, 7, 7, 14),
    updatedAt: DateTime(2022, 7, 7, 13),
    starred: true,
  ),
  entryText: const EntryText(plainText: 'test image entry text'),
  data: ImageData(
    imageId: '',
    imageFile: '',
    imageDirectory: '',
    capturedAt: DateTime.now(),
  ),
);

final testAudioEntry = JournalAudio(
  meta: Metadata(
    id: '32ea936e-dfc6-43bd-8722-d816c35eb489',
    createdAt: DateTime(2022, 7, 7, 13),
    dateFrom: DateTime(2022, 7, 7, 13),
    dateTo: DateTime(2022, 7, 7, 14),
    updatedAt: DateTime(2022, 7, 7, 13),
    starred: true,
  ),
  entryText: const EntryText(plainText: 'test image entry text'),
  data: AudioData(
    dateFrom: DateTime(2022, 7, 7, 13),
    dateTo: DateTime(2022, 7, 7, 14),
    duration: const Duration(hours: 1),
    audioFile: '',
    audioDirectory: '',
  ),
);

final testAudioEntryWithTranscripts = JournalAudio(
  meta: Metadata(
    id: '32ea936e-dfc6-43bd-8722-d816c35e4b89',
    createdAt: DateTime(2022, 7, 7, 13),
    dateFrom: DateTime(2022, 7, 7, 13),
    dateTo: DateTime(2022, 7, 7, 14),
    updatedAt: DateTime(2022, 7, 7, 13),
    starred: true,
  ),
  entryText: const EntryText(plainText: 'test image entry text'),
  data: AudioData(
    dateFrom: DateTime(2022, 7, 7, 13),
    dateTo: DateTime(2022, 7, 7, 14),
    duration: const Duration(hours: 1),
    audioFile: '',
    audioDirectory: '',
    transcripts: [
      AudioTranscript(
        created: DateTime(2022, 7, 7, 13),
        library: 'whisper-v1.4.0',
        model: 'ggml-small.bin',
        detectedLanguage: 'en',
        transcript: 'transcript',
      ),
    ],
  ),
);

final testHabitCompletionEntry = HabitCompletionEntry(
  meta: Metadata(
    id: '32ea936e-dfc6-43bd-8722-d816c35eb489',
    createdAt: DateTime.now(),
    dateFrom: DateTime.now(),
    dateTo: DateTime.now(),
    updatedAt: DateTime.now(),
    starred: true,
  ),
  entryText: const EntryText(plainText: 'test image entry text'),
  data: HabitCompletionData(
    dateFrom: DateTime.now(),
    dateTo: DateTime.now(),
    habitId: habitFlossing.id,
  ),
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
    dateTo: DateTime(2022, 7, 7, 9),
    dateFrom: DateTime(2022, 7, 7, 9),
    estimate: const Duration(hours: 4),
  ),
  meta: Metadata(
    id: '79ef5021-12df-4651-ac6e-c9a5b58a859c',
    createdAt: DateTime(2022, 7, 7, 9),
    dateFrom: DateTime(2022, 7, 7, 9),
    dateTo: DateTime(2022, 7, 7, 11),
    updatedAt: DateTime(2022, 7, 7, 11),
    starred: true,
  ),
  entryText: const EntryText(plainText: '- test task text'),
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

final testWeightEntry2 = QuantitativeEntry(
  meta: Metadata(
    id: '3db0fc34-07d0-4a6e-b9cd-b1a64f56c977',
    createdAt: DateTime(2022, 6, 7, 15),
    dateFrom: DateTime(2022, 6, 7, 15),
    dateTo: DateTime(2022, 6, 7, 15),
    updatedAt: DateTime(2022, 6, 7, 15),
    starred: false,
  ),
  data: QuantitativeData.discreteQuantityData(
    dateFrom: DateTime(2022, 6, 7, 15),
    dateTo: DateTime(2022, 6, 7, 15),
    value: 99.2,
    dataType: 'HealthDataType.WEIGHT',
    unit: 'HealthDataUnit.KILOGRAMS',
  ),
);

final testHeightEntry = QuantitativeEntry(
  meta: Metadata(
    id: '21621a9f-a2b9-5ad1-a530-2d73f9e4bb92',
    createdAt: DateTime(2022, 1, 1, 15),
    dateFrom: DateTime(2022, 1, 1, 15),
    dateTo: DateTime(2022, 1, 1, 15),
    updatedAt: DateTime(2022, 1, 1, 15),
    starred: false,
  ),
  data: QuantitativeData.discreteQuantityData(
    dateFrom: DateTime(2022, 1, 1, 15),
    dateTo: DateTime(2022, 1, 1, 15),
    value: 1.86,
    dataType: 'HealthDataType.HEIGHT',
    unit: 'HealthDataUnit.METERS',
  ),
);

final testBpSystolicEntry = QuantitativeEntry(
  meta: Metadata(
    id: '4dd10110-9c38-5f65-a260-1f371cecf038',
    createdAt: DateTime(2022, 7, 7, 8),
    dateFrom: DateTime(2022, 7, 7, 8),
    dateTo: DateTime(2022, 7, 7, 8),
    updatedAt: DateTime(2022, 7, 7, 8),
    starred: false,
  ),
  data: QuantitativeData.discreteQuantityData(
    dateFrom: DateTime(2022, 7, 7, 8),
    dateTo: DateTime(2022, 7, 7, 8),
    value: 122,
    dataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
    unit: 'HealthDataUnit.MILLIMETER_OF_MERCURY',
  ),
);

final testBpDiastolicEntry = QuantitativeEntry(
  meta: Metadata(
    id: '4dd10110-9c38-5f65-a260-1f371cecf038',
    createdAt: DateTime(2022, 7, 7, 8),
    dateFrom: DateTime(2022, 7, 7, 8),
    dateTo: DateTime(2022, 7, 7, 8),
    updatedAt: DateTime(2022, 7, 7, 8),
    starred: false,
  ),
  data: QuantitativeData.discreteQuantityData(
    dateFrom: DateTime(2022, 7, 7, 8),
    dateTo: DateTime(2022, 7, 7, 8),
    value: 122,
    dataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
    unit: 'HealthDataUnit.MILLIMETER_OF_MERCURY',
  ),
);

final testMeasurementChocolateEntry = MeasurementEntry(
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
    value: 55,
    dataTypeId: measurableCoverage.id,
    dateTo: DateTime(2022, 7, 7, 17),
    dateFrom: DateTime(2022, 7, 7, 17),
  ),
  entryText: const EntryText(plainText: 'test measurement comment'),
);

final testMeasuredPullUpsEntry = MeasurementEntry(
  meta: Metadata(
    id: '2f952c8f-5a27-4125-a745-623ec3917c4f',
    createdAt: DateTime(2022, 7, 7, 20),
    dateFrom: DateTime(2022, 7, 7, 20),
    dateTo: DateTime(2022, 7, 7, 20),
    updatedAt: DateTime(2022, 7, 7, 20),
    starred: false,
    private: false,
  ),
  data: MeasurementData(
    value: 10,
    dataTypeId: measurablePullUps.id,
    dateTo: DateTime(2022, 7, 7, 20),
    dateFrom: DateTime(2022, 7, 7, 20),
  ),
);

final testWorkoutRunning = WorkoutEntry(
  meta: Metadata(
    id: '20CDE5C9-5B56-4C93-A217-FB08908EF5BA',
    createdAt: DateTime(2022, 7, 1, 20),
    dateFrom: DateTime(2022, 7, 1, 20),
    dateTo: DateTime(2022, 7, 1, 21),
    updatedAt: DateTime(2022, 7, 1, 21),
    starred: false,
    private: false,
  ),
  data: WorkoutData(
    distance: 5629.194772059913,
    dateFrom: DateTime(2022, 7, 1, 20),
    dateTo: DateTime(2022, 7, 1, 21),
    workoutType: 'running',
    energy: 632.0180571495033,
    id: '20CDE5C9-5B56-4C93-A217-FB08908EF5BA',
    source: '',
  ),
);

final testDurationEntry1 = JournalEntry(
  meta: Metadata(
    id: 'id',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    dateFrom: DateTime(2022, 7, 3, 13),
    dateTo: DateTime(2022, 7, 3, 14),
  ),
);

final testDurationEntry2 = JournalEntry(
  meta: Metadata(
    id: 'id',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    dateFrom: DateTime(2022, 7, 4, 13),
    dateTo: DateTime(2022, 7, 4, 14),
  ),
);

final testDurationEntry3 = JournalEntry(
  meta: Metadata(
    id: 'id',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    dateFrom: DateTime(2022, 7, 4, 15),
    dateTo: DateTime(2022, 7, 4, 18, 11, 33),
  ),
);

final testDurationEntry4 = JournalEntry(
  meta: Metadata(
    id: 'id',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    dateFrom: DateTime(2022, 7, 1, 23),
    dateTo: DateTime(2022, 7, 2, 2),
  ),
);

final testDurationEntry5 = JournalEntry(
  meta: Metadata(
    id: 'id',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    dateFrom: DateTime(2022, 7, 2, 22),
    dateTo: DateTime(2022, 7, 5, 1),
  ),
);

final testDurationEntry6 = JournalEntry(
  meta: Metadata(
    id: 'id',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    dateFrom: DateTime(2022, 6, 1, 22),
    dateTo: DateTime(2022, 6, 12, 1),
  ),
);

final resolvedConflict = Conflict(
  id: 'id',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  serialized: jsonEncode(testTextEntry.toJson()),
  schemaVersion: 1,
  status: ConflictStatus.resolved.index,
);

final unresolvedConflict = Conflict(
  id: 'id',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  serialized: jsonEncode(testTextEntry.toJson()),
  schemaVersion: 1,
  status: ConflictStatus.unresolved.index,
);
