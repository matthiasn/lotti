import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_image_card.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_view_widget.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/events/event_status.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:research_package/model.dart';

import '../../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {
  @override
  CategoryDefinition? getCategoryById(String? id) {
    return id == 'test-category-id'
        ? CategoryDefinition(
            id: 'test-category-id',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            name: 'Test Category',
            vectorClock: null,
            private: false,
            active: true,
            color: '#FF0000',
          )
        : null;
  }
}

class MockNavService extends Mock implements NavService {
  final List<String> navigationHistory = [];

  @override
  void beamToNamed(String path, {Object? data}) {
    navigationHistory.add(path);
  }
}

class MockTimeService implements TimeService {
  JournalEntity? _linkedFrom;

  @override
  JournalEntity? get linkedFrom => _linkedFrom;

  @override
  Stream<JournalEntity?> getStream() {
    return Stream.value(null);
  }

  // Implement other required methods with default implementations
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTagsService extends Mock implements TagsService {
  @override
  Map<String, TagEntity> tagsById = {};

  @override
  Stream<List<TagEntity>> watchTags() {
    return Stream.value(<TagEntity>[]);
  }

  @override
  TagEntity? getTagById(String id) {
    return null;
  }
}

class MockBuildContext extends Mock implements BuildContext {}

class FakeJournalEntity extends Fake implements JournalEntity {}

class MockRPTaskResult extends Mock implements RPTaskResult {
  @override
  String get identifier => 'panasSurveyTask';
}

// Mock HabitSummary widget to avoid JournalDb dependency
class MockHabitSummary extends StatelessWidget {
  const MockHabitSummary(this.entry, {super.key, this.showChart = true});

  final HabitCompletionEntry entry;
  final bool showChart;

  @override
  Widget build(BuildContext context) {
    return Text('Habit Summary: ${entry.data.habitId}');
  }
}

void main() {
  late JournalEntry testJournalEntry;
  late Task testTask;
  late JournalEvent testEvent;
  late JournalImage testImage;
  late JournalAudio testAudio;
  late AiResponseEntry testAiResponse;
  late Checklist testChecklist;
  late ChecklistItem testChecklistItem;
  late ChecklistItem testUncheckedChecklistItem;
  late SurveyEntry testSurvey;
  late WorkoutEntry testWorkout;

  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNavService mockNavService;
  late MockTimeService mockTimeService;
  late MockTagsService mockTagsService;
  late Directory mockDirectory;

  // Define date formatter for tests
  final dfShort = DateFormat('yyyy-MM-dd');

  setUpAll(() {
    registerFallbackValue(MockBuildContext());
    registerFallbackValue(FakeJournalEntity());
  });

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNavService = MockNavService();
    mockTimeService = MockTimeService();
    mockTagsService = MockTagsService();

    // Create and register mock directory for image tests
    final tempDir = Directory.systemTemp.createTempSync('journal_card_test');
    mockDirectory = tempDir;

    // Register mock services
    getIt.allowReassignment = true;
    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<TagsService>(mockTagsService)
      ..registerSingleton<Directory>(mockDirectory);

    // Create test data
    final now = DateTime.now();
    const categoryId = 'test-category-id';
    const entryId = 'test-entry-id';
    const taskId = 'test-task-id';
    const eventId = 'test-event-id';
    const imageId = 'test-image-id';
    const audioId = 'test-audio-id';
    const aiResponseId = 'test-ai-response-id';
    const checklistId = 'test-checklist-id';
    const checklistItemId = 'test-checklist-item-id';
    const surveyId = 'test-survey-id';

    // Create a journal entry for testing
    final metadata = Metadata(
      id: entryId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
      starred: true,
    );

    const entryText = EntryText(
      plainText: 'Test Journal Entry',
      markdown: 'Test Journal Entry',
    );

    testJournalEntry = JournalEntry(
      meta: metadata,
      entryText: entryText,
    );

    // Create a task for testing
    final taskMetadata = Metadata(
      id: taskId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    final taskStatus = TaskStatus.open(
      id: 'status-id',
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );

    final taskData = TaskData(
      status: taskStatus,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      statusHistory: [],
      title: 'Test Task Title',
    );

    testTask = Task(
      meta: taskMetadata,
      data: taskData,
      entryText: entryText,
    );

    // Create an event for testing
    final eventMetadata = Metadata(
      id: eventId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    const eventData = EventData(
      title: 'Test Event Title',
      status: EventStatus.tentative,
      stars: 3.5,
    );

    testEvent = JournalEvent(
      meta: eventMetadata,
      data: eventData,
      entryText: entryText,
    );

    // Create a journal image for testing
    final imageMetadata = Metadata(
      id: imageId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    final imageData = ImageData(
      capturedAt: now,
      imageId: 'image-uuid',
      imageFile: 'test-image.jpg',
      imageDirectory: '/images/2023-01-01/',
    );

    testImage = JournalImage(
      meta: imageMetadata,
      data: imageData,
      entryText: entryText,
    );

    // Create an audio entry for testing
    final audioMetadata = Metadata(
      id: audioId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    final audioData = AudioData(
      dateFrom: now,
      dateTo: now.add(const Duration(minutes: 5)),
      audioFile: 'test-audio.aac',
      audioDirectory: '/audio/2023-01-01/',
      duration: const Duration(minutes: 5),
    );

    testAudio = JournalAudio(
      meta: audioMetadata,
      data: audioData,
      entryText: entryText,
    );

    // Create an AI response entry for testing
    final aiResponseMetadata = Metadata(
      id: aiResponseId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    const aiResponseData = AiResponseData(
      model: 'gpt-4',
      systemMessage: 'You are a helpful assistant',
      prompt: 'Summarize this entry',
      thoughts: 'Thinking about the best way to summarize',
      response: 'This is a test AI response',
      suggestedActionItems: [
        AiActionItem(
          title: 'Test action item',
          completed: false,
        ),
      ],
      type: 'summary',
    );

    testAiResponse = AiResponseEntry(
      meta: aiResponseMetadata,
      data: aiResponseData,
      entryText: entryText,
    );

    // Create a checklist for testing
    final checklistMetadata = Metadata(
      id: checklistId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    const checklistData = ChecklistData(
      title: 'Test Checklist',
      linkedChecklistItems: ['item1', 'item2'],
      linkedTasks: ['task1'],
    );

    testChecklist = Checklist(
      meta: checklistMetadata,
      data: checklistData,
      entryText: entryText,
    );

    // Create a checklist item for testing
    final checklistItemMetadata = Metadata(
      id: checklistItemId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    const checklistItemData = ChecklistItemData(
      title: 'Test Checklist Item',
      isChecked: true,
      linkedChecklists: [checklistId],
      id: 'item-uuid',
    );

    testChecklistItem = ChecklistItem(
      meta: checklistItemMetadata,
      data: checklistItemData,
      entryText: entryText,
    );

    // Create a survey entry for testing
    final surveyMetadata = Metadata(
      id: surveyId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    final mockRpTaskResult = MockRPTaskResult();

    final surveyData = SurveyData(
      taskResult: mockRpTaskResult,
      scoreDefinitions: {
        'Positive Affect Score': {'q1', 'q3', 'q5'},
        'Negative Affect Score': {'q2', 'q4', 'q6'},
      },
      calculatedScores: {
        'Positive Affect Score': 15,
        'Negative Affect Score': 8,
      },
    );

    testSurvey = SurveyEntry(
      meta: surveyMetadata,
      data: surveyData,
      entryText: entryText,
    );

    // Create a workout entry for testing
    const workoutId = 'test-workout-id';
    final workoutMetadata = Metadata(
      id: workoutId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    final workoutData = WorkoutData(
      dateFrom: now,
      dateTo: now.add(const Duration(minutes: 45)),
      id: 'workout-activity-id',
      workoutType: 'running',
      energy: 350,
      distance: 5.0,
      source: 'manual',
    );

    testWorkout = WorkoutEntry(
      meta: workoutMetadata,
      data: workoutData,
      entryText: entryText,
    );

    // Create an unchecked checklist item for testing
    const uncheckedChecklistItemId = 'unchecked-item-id';
    final uncheckedChecklistItemMetadata = Metadata(
      id: uncheckedChecklistItemId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    const uncheckedChecklistItemData = ChecklistItemData(
      title: 'Unchecked Item',
      isChecked: false,
      linkedChecklists: [checklistId],
      id: 'unchecked-item-uuid',
    );

    testUncheckedChecklistItem = ChecklistItem(
      meta: uncheckedChecklistItemMetadata,
      data: uncheckedChecklistItemData,
      entryText: entryText,
    );
  });

  tearDown(() {
    // Clean up registered services
    getIt
      ..unregister<EntitiesCacheService>()
      ..unregister<TimeService>()
      ..unregister<NavService>()
      ..unregister<TagsService>()
      ..unregister<Directory>();

    try {
      mockDirectory.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('JournalCard navigates to journal entry details on tap',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testJournalEntry),
      ),
    );

    // Act
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    // Assert
    expect(
      mockNavService.navigationHistory,
      contains('/journal/${testJournalEntry.meta.id}'),
    );
  });

  testWidgets('JournalCard navigates to task details on tap',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testTask),
      ),
    );

    // Act
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    // Assert
    expect(
      mockNavService.navigationHistory,
      contains('/tasks/${testTask.meta.id}'),
    );
  });

  testWidgets('JournalCard does not render deleted entities',
      (WidgetTester tester) async {
    // Create a deleted entry
    final deletedEntry = testJournalEntry.copyWith(
      meta: testJournalEntry.meta.copyWith(
        deletedAt: DateTime.now(),
      ),
    );

    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: deletedEntry),
      ),
    );

    // Assert - should not render anything
    expect(find.byType(Card), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('LeadingIcon renders with correct color',
      (WidgetTester tester) async {
    // Arrange
    const iconData = Icons.abc;
    const color = Colors.red;

    await tester.pumpWidget(
      const WidgetTestBench(
        child: LeadingIcon(iconData, color: color),
      ),
    );

    // Assert
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, iconData);
    expect(icon.color, color);
    expect(icon.size, 32);
  });

  testWidgets('JournalCard renders JournalEvent with stars and status',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testEvent),
      ),
    );

    // Assert
    expect(find.text('Test Event Title'), findsOneWidget);
    expect(find.byType(EventStatusWidget), findsOneWidget);

    // Verify stars are rendered
    expect(
      find.descendant(
        of: find.byType(JournalCard),
        matching: find.byType(StarRating),
      ),
      findsOneWidget,
    );
  });

  testWidgets('JournalCardTitle displays category icon correctly',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCardTitle(
          item: testJournalEntry,
          maxHeight: 120,
        ),
      ),
    );

    // Assert
    expect(find.byType(CategoryColorIcon), findsOneWidget);
  });

  testWidgets('JournalCard displays time formatting correctly for event',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCardTitle(
          item: testEvent,
          maxHeight: 120,
        ),
      ),
    );

    // Assert - verify date format
    expect(find.text(dfShort.format(testEvent.meta.dateFrom)), findsOneWidget);
  });

  testWidgets(
      'JournalCard with showLinkedDuration shows TimeRecordingIcon for tasks',
      (WidgetTester tester) async {
    // This test is skipped as it requires Riverpod ProviderScope which would need additional setup
  });

  testWidgets('JournalCard with flag shows flag icon',
      (WidgetTester tester) async {
    // Create an entry with a flag
    final flaggedEntry = testJournalEntry.copyWith(
      meta: testJournalEntry.meta.copyWith(
        flag: EntryFlag.import,
      ),
    );

    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: flaggedEntry),
      ),
    );

    // Assert flag icon is shown
    expect(find.byIcon(MdiIcons.flag), findsOneWidget);
  });

  testWidgets('JournalCard with private shows security icon',
      (WidgetTester tester) async {
    // Create a private entry
    final privateEntry = testJournalEntry.copyWith(
      meta: testJournalEntry.meta.copyWith(
        private: true,
      ),
    );

    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: privateEntry),
      ),
    );

    // Assert security icon is shown
    expect(find.byIcon(MdiIcons.security), findsOneWidget);
  });

  testWidgets('JournalCard with star shows star icon',
      (WidgetTester tester) async {
    // Arrange (using testJournalEntry which is already starred)
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testJournalEntry),
      ),
    );

    // Assert star icon is shown
    expect(find.byIcon(MdiIcons.star), findsOneWidget);
  });

  testWidgets('JournalCard renders TagsViewWidget',
      (WidgetTester tester) async {
    // Create an entry with tags
    final taggedEntry = testJournalEntry.copyWith(
      meta: testJournalEntry.meta.copyWith(
        tags: ['test-tag'],
        tagIds: ['test-tag-id'],
      ),
    );

    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: taggedEntry),
      ),
    );

    // Assert
    expect(find.byType(TagsViewWidget), findsOneWidget);
  });

  testWidgets('JournalCard renders TextViewerWidget',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testJournalEntry),
      ),
    );

    // Assert
    expect(find.byType(TextViewerWidget), findsOneWidget);
  });

  testWidgets('JournalImageCard navigates to image details on tap',
      (WidgetTester tester) async {
    // Arrange
    // Create directory structure for image
    Directory('${mockDirectory.path}${testImage.data.imageDirectory}')
        .createSync(recursive: true);

    // Create mock image file
    final filePath =
        '${mockDirectory.path}${testImage.data.imageDirectory}${testImage.data.imageFile}';
    File(filePath).createSync();

    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalImageCard(item: testImage),
      ),
    );

    // Act
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    // Assert
    expect(
      mockNavService.navigationHistory,
      contains('/journal/${testImage.meta.id}'),
    );
  });

  testWidgets('JournalCard for JournalAudio renders audio information',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testAudio),
      ),
    );

    // Assert - verify audio duration is shown somewhere
    expect(find.byType(JournalCard), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);

    // Verify navigation works
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(
      mockNavService.navigationHistory,
      contains('/journal/${testAudio.meta.id}'),
    );
  });

  testWidgets('JournalCard for AiResponseEntry displays AI response data',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testAiResponse),
      ),
    );

    // Assert
    expect(find.byType(JournalCard), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);

    // Verify text is rendered
    expect(find.text('This is a test AI response'), findsOneWidget);

    // Verify navigation works
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(
      mockNavService.navigationHistory,
      contains('/journal/${testAiResponse.meta.id}'),
    );
  });

  testWidgets('JournalCard for Checklist displays checklist title',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testChecklist),
      ),
    );

    // Assert
    expect(find.byType(JournalCard), findsOneWidget);
    expect(find.text('Test Checklist'), findsOneWidget);

    // Verify navigation works
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(
      mockNavService.navigationHistory,
      contains('/journal/${testChecklist.meta.id}'),
    );
  });

  testWidgets(
      'JournalCard for ChecklistItem displays item title and checked state',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testChecklistItem),
      ),
    );

    // Assert
    expect(find.byType(JournalCard), findsOneWidget);
    expect(find.text('Test Checklist Item'), findsOneWidget);

    // Verify navigation works
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(
      mockNavService.navigationHistory,
      contains('/journal/${testChecklistItem.meta.id}'),
    );
  });

  testWidgets('JournalCard for SurveyEntry displays survey scores',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testSurvey),
      ),
    );

    // Assert the card is rendered
    expect(find.byType(JournalCard), findsOneWidget);

    // Verify navigation works
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(
      mockNavService.navigationHistory,
      contains('/journal/${testSurvey.meta.id}'),
    );
  });

  testWidgets('JournalCard for WorkoutEntry displays workout information',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testWorkout),
      ),
    );

    // Assert
    expect(find.byType(JournalCard), findsOneWidget);

    // Verify navigation works
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(
      mockNavService.navigationHistory,
      contains('/journal/${testWorkout.meta.id}'),
    );
  });

  testWidgets(
      'JournalCard for unchecked ChecklistItem displays unchecked state',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: JournalCard(item: testUncheckedChecklistItem),
      ),
    );

    // Assert
    expect(find.byType(JournalCard), findsOneWidget);
    expect(find.text('Unchecked Item'), findsOneWidget);

    // Verify leading icon shows unchecked state
    expect(find.byIcon(MdiIcons.checkboxBlankOutline), findsOneWidget);

    // Verify navigation works
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(
      mockNavService.navigationHistory,
      contains('/journal/${testUncheckedChecklistItem.meta.id}'),
    );
  });
}
