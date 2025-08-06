import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/habit_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/survey_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/workout_summary.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_view_widget.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget_non_scrollable.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/features/tasks/ui/task_status.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';
import 'package:lotti/widgets/events/event_status.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:research_package/model.dart';

import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTagsService extends Mock implements TagsService {
  @override
  Map<String, TagEntity> get tagsById => {};

  @override
  Stream<List<TagEntity>> watchTags() {
    return Stream.value(<TagEntity>[]);
  }

  @override
  TagEntity? getTagById(String id) {
    return null;
  }
}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {
  @override
  CategoryDefinition? getCategoryById(String? categoryId) {
    return categoryId != null
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

class MockJournalDb extends Mock implements JournalDb {
  @override
  Stream<HabitDefinition?> watchHabitById(String habitId) {
    return Stream.value(habitFlossing);
  }

  @override
  Stream<List<MeasurableDataType>> watchMeasurableDataTypes() {
    return Stream.value([]);
  }
}

void main() {
  late MockNavService mockNavService;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockTagsService mockTagsService;
  late MockTimeService mockTimeService;

  setUp(() {
    mockNavService = MockNavService();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockTagsService = MockTagsService();
    mockTimeService = MockTimeService();

    getIt.allowReassignment = true;

    // Create temp directory for tests
    final tempDir = Directory.systemTemp.createTempSync('journal_card_test');

    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TagsService>(mockTagsService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<Directory>(tempDir)
      ..registerSingleton<JournalDb>(MockJournalDb());
  });

  tearDown(() async {
    await getIt.reset();
  });

  tearDownAll(() {
    // Clean up temp directories
    try {
      Directory.systemTemp
          .listSync()
          .where((entity) => entity.path.contains('journal_card_test'))
          .forEach((entity) => entity.deleteSync(recursive: true));
    } catch (_) {}
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModernJournalCard', () {
    testWidgets('renders journal entry with text', (tester) async {
      final testEntry = testTextEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byType(ModernBaseCard), findsOneWidget);

      // TextViewerWidgetNonScrollable uses QuillEditor which doesn't create a simple Text widget
      // Instead, we should verify that the TextViewerWidgetNonScrollable is present
      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);

      // For compact mode, we can find the text directly
      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testEntry, isCompact: true),
        ),
      );
      // In compact mode, we render plain text instead of TextViewerWidget
      expect(find.text(testEntry.entryText!.plainText), findsOneWidget);
    });

    testWidgets('renders journal audio entry', (tester) async {
      final audioEntry = testAudioEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: audioEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('renders task entry with title', (tester) async {
      final taskEntry = testTask;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: taskEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.text(taskEntry.data.title), findsOneWidget);
    });

    testWidgets('renders measurement entry with numeric icon', (tester) async {
      final measurementEntry = testMeasurementChocolateEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: measurementEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byIcon(MdiIcons.numeric), findsWidgets);
    });

    testWidgets('renders quantitative entry with heart icon', (tester) async {
      final healthEntry = testBpSystolicEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: healthEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byIcon(MdiIcons.heart), findsOneWidget);
    });

    testWidgets('renders another measurement entry', (tester) async {
      final measurementEntry = testMeasuredCoverageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: measurementEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byIcon(MdiIcons.numeric), findsOneWidget);
    });

    testWidgets('shows starred icon when entry is starred', (tester) async {
      final starredEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(starred: true),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: starredEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.star), findsOneWidget);
    });

    testWidgets('shows private icon when entry is private', (tester) async {
      final privateEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(private: true),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: privateEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });

    testWidgets('shows flag icon for imported entries', (tester) async {
      final importedEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(flag: EntryFlag.import),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: importedEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.flag), findsOneWidget);
    });

    testWidgets('renders in compact mode', (tester) async {
      final testEntry = testTextEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(
            item: testEntry,
            isCompact: true,
          ),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);

      // In compact mode, text should be limited to 2 lines
      final textWidget = tester.widget<Text>(
        find.text(testEntry.entryText!.plainText),
      );
      expect(textWidget.maxLines, 2);
    });

    testWidgets('hides deleted entries', (tester) async {
      final deletedEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(
          deletedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: deletedEntry),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(ModernBaseCard), findsNothing);
    });

    testWidgets('navigates to task detail on tap', (tester) async {
      final taskEntry = testTask;
      getIt.registerSingleton<NavService>(mockNavService);

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: taskEntry),
        ),
      );

      await tester.tap(find.byType(ModernBaseCard));
      await tester.pumpAndSettle();

      expect(
        mockNavService.navigationHistory,
        contains('/tasks/${taskEntry.meta.id}'),
      );
    });

    testWidgets('navigates to journal detail on tap', (tester) async {
      final testEntry = testTextEntry;
      getIt.registerSingleton<NavService>(mockNavService);

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testEntry),
        ),
      );

      await tester.tap(find.byType(ModernBaseCard));
      await tester.pumpAndSettle();

      expect(
        mockNavService.navigationHistory,
        contains('/journal/${testEntry.meta.id}'),
      );
    });

    testWidgets('shows linked duration when enabled', (tester) async {
      final taskEntry = testTask;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernJournalCard(
            item: taskEntry,
            showLinkedDuration: true,
          ),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      // LinkedDuration widget would be shown if there's an estimate
      expect(find.byType(LinkedDuration), findsOneWidget);
    });

    testWidgets('renders workout entry', (tester) async {
      final workoutEntry = testWorkoutRunning;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: workoutEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byType(WorkoutSummary), findsOneWidget);
    });

    testWidgets('renders habit completion entry', (tester) async {
      final habitEntry = testHabitCompletionEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: habitEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byType(HabitSummary), findsOneWidget);
    });

    testWidgets('displays category icon correctly', (tester) async {
      final entryWithCategory = testTextEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: entryWithCategory),
        ),
      );

      expect(find.byType(CategoryIconCompact), findsOneWidget);
    });

    testWidgets('displays tags widget', (tester) async {
      final taggedEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(
          tags: ['test-tag'],
          tagIds: ['test-tag-id'],
        ),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: taggedEntry),
        ),
      );

      expect(find.byType(TagsViewWidget), findsOneWidget);
    });

    testWidgets('displays text viewer widget', (tester) async {
      final textEntry = testTextEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: textEntry),
        ),
      );

      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
    });

    testWidgets('displays task status widget for tasks', (tester) async {
      final taskEntry = testTask;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: taskEntry),
        ),
      );

      expect(find.byType(TaskStatusWidget), findsOneWidget);
    });

    testWidgets('renders modern card components', (tester) async {
      final entry = testTextEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: entry),
        ),
      );

      expect(find.byType(ModernBaseCard), findsOneWidget);
      expect(find.byType(TagsViewWidget), findsOneWidget);
    });

    testWidgets('shows icon container for entries with leading icons',
        (tester) async {
      final audioEntry = testAudioEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: audioEntry),
        ),
      );

      expect(find.byType(ModernIconContainer), findsOneWidget);
    });

    // Additional comprehensive tests to match journal_card_test.dart coverage
    group('Comprehensive entity tests', () {
      late JournalEvent testEvent;
      late Checklist testChecklist;
      late ChecklistItem testChecklistItem;
      late ChecklistItem testUncheckedChecklistItem;
      late SurveyEntry testSurvey;
      late AiResponseEntry testAiResponse;
      final dfShort = DateFormat('yyyy-MM-dd');

      setUp(() {
        final now = DateTime.now();
        const categoryId = 'test-category-id';
        const entryText = EntryText(
          plainText: 'Test Entry',
          markdown: 'Test Entry',
        );

        // Create test event
        testEvent = JournalEvent(
          meta: Metadata(
            id: 'test-event-id',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now.add(const Duration(hours: 1)),
            categoryId: categoryId,
          ),
          data: const EventData(
            title: 'Test Event Title',
            status: EventStatus.tentative,
            stars: 3.5,
          ),
          entryText: entryText,
        );

        // Create test checklist
        testChecklist = Checklist(
          meta: Metadata(
            id: 'test-checklist-id',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now.add(const Duration(hours: 1)),
            categoryId: categoryId,
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: ['item1', 'item2'],
            linkedTasks: ['task1'],
          ),
          entryText: entryText,
        );

        // Create test checklist item
        testChecklistItem = ChecklistItem(
          meta: Metadata(
            id: 'test-checklist-item-id',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now.add(const Duration(hours: 1)),
            categoryId: categoryId,
          ),
          data: const ChecklistItemData(
            title: 'Test Checklist Item',
            isChecked: true,
            linkedChecklists: ['checklist-id'],
            id: 'item-uuid',
          ),
          entryText: entryText,
        );

        // Create unchecked checklist item
        testUncheckedChecklistItem = ChecklistItem(
          meta: Metadata(
            id: 'unchecked-item-id',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now.add(const Duration(hours: 1)),
            categoryId: categoryId,
          ),
          data: const ChecklistItemData(
            title: 'Unchecked Item',
            isChecked: false,
            linkedChecklists: ['checklist-id'],
            id: 'unchecked-item-uuid',
          ),
          entryText: entryText,
        );

        // Create test survey
        testSurvey = SurveyEntry(
          meta: Metadata(
            id: 'test-survey-id',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now.add(const Duration(hours: 1)),
            categoryId: categoryId,
          ),
          data: SurveyData(
            taskResult: RPTaskResult(identifier: 'panasSurveyTask'),
            scoreDefinitions: {
              'Positive Affect Score': {'q1', 'q3', 'q5'},
              'Negative Affect Score': {'q2', 'q4', 'q6'},
            },
            calculatedScores: {
              'Positive Affect Score': 15,
              'Negative Affect Score': 8,
            },
          ),
          entryText: entryText,
        );

        // Create test AI response
        testAiResponse = AiResponseEntry(
          meta: Metadata(
            id: 'test-ai-response-id',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now.add(const Duration(hours: 1)),
            categoryId: categoryId,
          ),
          data: const AiResponseData(
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
            type: AiResponseType.taskSummary,
          ),
          entryText: entryText,
        );
      });

      testWidgets('renders event with stars and status', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testEvent),
          ),
        );

        expect(find.byType(ModernJournalCard), findsOneWidget);
        expect(find.text(testEvent.data.title), findsOneWidget);
        expect(find.byType(EventStatusWidget), findsOneWidget);
        expect(find.byType(StarRating), findsOneWidget);
      });

      testWidgets('renders checklist entry', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testChecklist),
          ),
        );

        expect(find.byType(ModernJournalCard), findsOneWidget);
        expect(find.text(testChecklist.data.title), findsOneWidget);
        expect(find.byIcon(MdiIcons.checkAll), findsOneWidget);
      });

      testWidgets('renders checked checklist item', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testChecklistItem),
          ),
        );

        expect(find.byType(ModernJournalCard), findsOneWidget);
        expect(find.text(testChecklistItem.data.title), findsOneWidget);
        expect(find.byIcon(MdiIcons.checkboxMarked), findsOneWidget);
      });

      testWidgets('renders unchecked checklist item', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testUncheckedChecklistItem),
          ),
        );

        expect(find.byType(ModernJournalCard), findsOneWidget);
        expect(
            find.text(testUncheckedChecklistItem.data.title), findsOneWidget);
        // Verify the unchecked icon is present somewhere in the card
        expect(find.byIcon(MdiIcons.checkboxBlankOutline),
            findsAtLeastNWidgets(1));
      });

      testWidgets('renders survey entry', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testSurvey),
          ),
        );

        expect(find.byType(ModernJournalCard), findsOneWidget);
        expect(find.byType(SurveySummary), findsOneWidget);
      });

      testWidgets('renders AI response entry', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testAiResponse),
          ),
        );

        expect(find.byType(ModernJournalCard), findsOneWidget);
        expect(find.byType(GptMarkdown), findsOneWidget);
        expect(find.byIcon(Icons.assistant), findsOneWidget);
      });

      testWidgets('shows time formatting correctly for event', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testEvent),
          ),
        );

        // Verify date format is displayed (look for date text)
        expect(
            find.text(dfShort.format(testEvent.meta.dateFrom)), findsOneWidget);
      });

      testWidgets('navigates to checklist detail on tap', (tester) async {
        getIt.registerSingleton<NavService>(mockNavService);

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testChecklist),
          ),
        );

        await tester.tap(find.byType(ModernBaseCard));
        await tester.pumpAndSettle();

        expect(
          mockNavService.navigationHistory,
          contains('/journal/${testChecklist.meta.id}'),
        );
      });

      testWidgets('navigates to event detail on tap', (tester) async {
        getIt.registerSingleton<NavService>(mockNavService);

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testEvent),
          ),
        );

        await tester.tap(find.byType(ModernBaseCard));
        await tester.pumpAndSettle();

        expect(
          mockNavService.navigationHistory,
          contains('/journal/${testEvent.meta.id}'),
        );
      });

      testWidgets('navigates to AI response detail on tap', (tester) async {
        getIt.registerSingleton<NavService>(mockNavService);

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testAiResponse),
          ),
        );

        await tester.tap(find.byType(ModernBaseCard));
        await tester.pumpAndSettle();

        expect(
          mockNavService.navigationHistory,
          contains('/journal/${testAiResponse.meta.id}'),
        );
      });

      testWidgets('displays proper icon types for different entities',
          (tester) async {
        // Test checklist icon is present
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testChecklist),
          ),
        );
        expect(find.byIcon(MdiIcons.checkAll), findsAtLeastNWidgets(1));

        // Test checked checklist item icon is present
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testChecklistItem),
          ),
        );
        expect(find.byIcon(MdiIcons.checkboxMarked), findsAtLeastNWidgets(1));

        // Test unchecked checklist item icon is present
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testUncheckedChecklistItem),
          ),
        );
        expect(find.byIcon(MdiIcons.checkboxBlankOutline),
            findsAtLeastNWidgets(1));

        // Test AI response icon is present
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testAiResponse),
          ),
        );
        expect(find.byIcon(Icons.assistant), findsAtLeastNWidgets(1));
      });

      testWidgets('handles entries with various metadata flags',
          (tester) async {
        final flaggedEntry = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            flag: EntryFlag.import,
            private: true,
            starred: true,
          ),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: flaggedEntry),
          ),
        );

        expect(find.byIcon(MdiIcons.flag), findsOneWidget);
        expect(find.byIcon(MdiIcons.security), findsOneWidget);
        expect(find.byIcon(MdiIcons.star), findsOneWidget);
      });
    });
  });
}
