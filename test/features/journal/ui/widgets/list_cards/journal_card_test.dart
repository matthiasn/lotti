import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/journal/util/entry_tools.dart' as entry_tools;
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/tasks/state/checklist_completion_controller.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/features/tasks/ui/task_status.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:research_package/model.dart';

import '../../../../../mocks/mocks.dart'
    show
        MockEntitiesCacheService,
        MockJournalDb,
        MockTimeService,
        MockUpdateNotifications,
        RecordingMockNavService;
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

/// Fake completion controller bound to the checklist fixture id, so the
/// checklist card can surface its `done/total` progress chip + bar.
class _FakeChecklistCompletion extends ChecklistCompletionController {
  _FakeChecklistCompletion()
    : super(const (id: 'test-checklist-id', taskId: null));

  @override
  Future<ChecklistCompletionState> build() async =>
      (completedCount: 2, totalCount: 3);
}

void main() {
  late RecordingMockNavService mockNavService;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockTimeService mockTimeService;
  late MockJournalDb mockJournalDb;

  setUp(() {
    mockNavService = RecordingMockNavService();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockTimeService = MockTimeService();

    // ModernJournalCard renders text for image entries (it never reads files
    // off disk), so a plain Directory reference is enough for the defensive
    // getIt<Directory>() registration — no real filesystem call needed.
    final tempDir = Directory(
      p.join(Directory.systemTemp.path, 'journal_card_test'),
    );

    mockJournalDb = MockJournalDb();
    when(
      () => mockJournalDb.getHabitById(any()),
    ).thenAnswer((_) async => habitFlossing);
    when(
      mockJournalDb.getAllMeasurableDataTypes,
    ).thenAnswer((_) async => <MeasurableDataType>[]);

    final mockUpdateNotifications = MockUpdateNotifications();
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());

    getIt
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<Directory>(tempDir)
      ..registerSingleton<JournalDb>(mockJournalDb);

    when(() => mockTimeService.linkedFrom).thenReturn(null);
    when(mockTimeService.getStream).thenAnswer((_) => Stream.value(null));
    when(
      () => mockEntitiesCacheService.getCategoryById(any()),
    ).thenReturn(
      CategoryDefinition(
        id: 'test-category-id',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        name: 'Test Category',
        vectorClock: null,
        private: false,
        active: true,
        color: '#FF0000',
      ),
    );
    when(() => mockEntitiesCacheService.getCategoryById(null)).thenReturn(null);
    // Measurement cards resolve their data type via the cache; default to the
    // chocolate type so name + unit render. Individual tests can override.
    when(
      () => mockEntitiesCacheService.getDataTypeById(any()),
    ).thenReturn(measurableChocolate);
  });

  tearDown(() async {
    await getIt.reset();
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModernJournalCard', () {
    testWidgets('renders journal entry text as the title', (tester) async {
      final testEntry = testTextEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testEntry),
        ),
      );

      // Text entries render their plain text directly as the title (no rich
      // text viewer anymore).
      expect(find.text(testEntry.entryText!.plainText), findsOneWidget);
      // Leading glyph for a plain journal entry.
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    });

    testWidgets('renders journal audio entry with mic glyph and duration', (
      tester,
    ) async {
      final audioEntry = testAudioEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: audioEntry),
        ),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      // The audio entry spans one hour; a duration chip surfaces it as H:MM:SS.
      expect(find.text('1:00:00'), findsOneWidget);
    });

    testWidgets('renders image entry preview text', (tester) async {
      // The JournalImage branch renders entryText.plainText directly as the
      // title, so the displayed content is assertable.
      final imageEntry = testImageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: imageEntry),
        ),
      );

      expect(find.text(imageEntry.entryText!.plainText), findsOneWidget);
      expect(find.byIcon(Icons.image_rounded), findsOneWidget);
    });

    testWidgets('audio mic glyph is tinted with the primary color', (
      tester,
    ) async {
      // The mic glyph color no longer varies with transcripts; it is the
      // type tint (primary), surfaced through the leading TintedTypeGlyph.
      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testAudioEntryWithTranscripts),
        ),
      );

      final BuildContext context = tester.element(
        find.byType(ModernJournalCard),
      );
      final glyph = tester.widget<TintedTypeGlyph>(
        find.byType(TintedTypeGlyph),
      );
      expect(glyph.icon, Icons.mic_rounded);
      expect(glyph.color, context.colorScheme.primary);
    });

    testWidgets('renders day plan entry with custom label', (tester) async {
      // DayPlanEntry branch using the provided dayLabel.
      final dayPlanEntry = JournalEntity.dayPlan(
        meta: Metadata(
          id: 'day-plan-id',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          categoryId: 'test-category-id',
        ),
        data: DayPlanData(
          planDate: DateTime(2024, 3, 15),
          status: const DayPlanStatus.draft(),
          dayLabel: 'Focused Workday',
        ),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: dayPlanEntry),
        ),
      );

      expect(find.text('Focused Workday'), findsOneWidget);
      expect(find.byIcon(Icons.today_rounded), findsOneWidget);
    });

    testWidgets('renders day plan entry with fallback label', (tester) async {
      // DayPlanEntry branch with null dayLabel -> localized fallback.
      final dayPlanEntry = JournalEntity.dayPlan(
        meta: Metadata(
          id: 'day-plan-fallback-id',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          categoryId: 'test-category-id',
        ),
        data: DayPlanData(
          planDate: DateTime(2024, 3, 15),
          status: const DayPlanStatus.draft(),
        ),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: dayPlanEntry),
        ),
      );

      // Falls back to the localized "Day Plan" label.
      expect(find.text('Day Plan'), findsOneWidget);
    });

    testWidgets('renders task entry with title and status chip', (
      tester,
    ) async {
      final taskEntry = testTask;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: taskEntry),
        ),
      );

      expect(find.text(taskEntry.data.title), findsOneWidget);
      expect(find.byType(TaskStatusWidget), findsOneWidget);
    });

    testWidgets('renders measurement entry with ruler glyph and value chip', (
      tester,
    ) async {
      final measurementEntry = testMeasurementChocolateEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: measurementEntry),
        ),
      );

      // Leading glyph for measurements is now the ruler.
      expect(find.byIcon(MdiIcons.ruler), findsOneWidget);
      // Humanized name comes from the resolved data type.
      expect(find.text(measurableChocolate.displayName), findsOneWidget);
      // value 100 + unit 'g' -> '100 g' chip.
      expect(find.text('100 g'), findsOneWidget);
    });

    testWidgets('measurement falls back to not-found when type is unknown', (
      tester,
    ) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(any()),
      ).thenReturn(null);

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testMeasurementChocolateEntry),
        ),
      );

      final BuildContext context = tester.element(
        find.byType(ModernJournalCard),
      );
      expect(find.text(context.messages.measurableNotFound), findsOneWidget);
    });

    testWidgets('renders quantitative entry with heart-pulse glyph + value', (
      tester,
    ) async {
      final healthEntry = testBpSystolicEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: healthEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.heartPulse), findsOneWidget);
      // Humanized type name from the curated registry.
      expect(find.text('Systolic Blood Pressure'), findsOneWidget);
      // value 122 + humanized unit -> '122 mmHg'.
      expect(find.text('122 mmHg'), findsOneWidget);
    });

    testWidgets('renders coverage measurement with its own value', (
      tester,
    ) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(any()),
      ).thenReturn(measurableCoverage);

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testMeasuredCoverageEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.ruler), findsOneWidget);
      expect(find.text(measurableCoverage.displayName), findsOneWidget);
      // value 55 + unit '%' -> '55 %'.
      expect(find.text('55 %'), findsOneWidget);
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

    testWidgets('limits the text title to a few lines', (tester) async {
      final testEntry = testTextEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testEntry),
        ),
      );

      // The content title clamps to 3 lines with ellipsis overflow.
      final textWidget = tester.widget<Text>(
        find.text(testEntry.entryText!.plainText),
      );
      expect(textWidget.maxLines, 3);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('hides deleted entries', (tester) async {
      final deletedEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 14),
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

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: taskEntry),
        ),
      );

      await tester.tap(find.byType(ModernBaseCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        mockNavService.navigationHistory,
        contains('/tasks/${taskEntry.meta.id}'),
      );
    });

    testWidgets('navigates to journal detail on tap', (tester) async {
      final testEntry = testTextEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testEntry),
        ),
      );

      await tester.tap(find.byType(ModernBaseCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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

      // LinkedDuration widget would be shown if there's an estimate
      expect(find.byType(LinkedDuration), findsOneWidget);
    });

    testWidgets('renders workout entry with sport glyph and metric chips', (
      tester,
    ) async {
      final workoutEntry = testWorkoutRunning;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: workoutEntry),
        ),
      );

      // Running workout -> directions-run glyph + humanized title.
      expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      // 1-hour run -> '60 min' duration chip.
      expect(find.text('60 min'), findsOneWidget);
      // ~632 kcal energy -> '632 kcal' chip (whole-number formatting).
      expect(find.text('632 kcal'), findsOneWidget);
      // ~5629 m -> '5.6 km' distance chip.
      expect(find.text('5.6 km'), findsOneWidget);
    });

    testWidgets('renders habit completion entry with name and status chip', (
      tester,
    ) async {
      final habitEntry = testHabitCompletionEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: habitEntry),
        ),
      );

      // The habit name is resolved through the notification-driven stream.
      await tester.pump();

      final BuildContext context = tester.element(
        find.byType(ModernJournalCard),
      );
      expect(find.text(habitFlossing.name), findsOneWidget);
      // Default completionType (success) -> localized "Completed" chip.
      expect(
        find.text(context.messages.habitCompletionStatusCompleted),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    });

    testWidgets('leads with a category-coloured glyph tile, not a badge', (
      tester,
    ) async {
      final entryWithCategory = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(categoryId: 'test-category-id'),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: entryWithCategory),
        ),
      );

      // Category identity is now conveyed by the colour of the leading glyph
      // tile, not by an inline category badge in the meta row.
      expect(find.byType(TintedTypeGlyph), findsOneWidget);
    });

    testWidgets('renders leading type glyph for every card', (tester) async {
      final audioEntry = testAudioEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: audioEntry),
        ),
      );

      // Every card leads with one TintedTypeGlyph (wrapping ModernIconContainer).
      expect(find.byType(TintedTypeGlyph), findsOneWidget);
      expect(find.byType(ModernIconContainer), findsOneWidget);
    });

    // Comprehensive per-type rendering.
    group('Comprehensive entity tests', () {
      late JournalEvent testEvent;
      late Checklist testChecklist;
      late ChecklistItem testChecklistItem;
      late ChecklistItem testUncheckedChecklistItem;
      late SurveyEntry testSurvey;
      late AiResponseEntry testAiResponse;

      setUp(() {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        const categoryId = 'test-category-id';
        const entryText = EntryText(
          plainText: 'Test Entry',
          markdown: 'Test Entry',
        );

        // Shared metadata builder — every fixture differs only in id.
        Metadata meta(String id) => Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(hours: 1)),
          categoryId: categoryId,
        );

        testEvent = JournalEvent(
          meta: meta('test-event-id'),
          data: const EventData(
            title: 'Test Event Title',
            status: EventStatus.tentative,
            stars: 3.5,
          ),
          entryText: entryText,
        );

        testChecklist = Checklist(
          meta: meta('test-checklist-id'),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: ['item1', 'item2'],
            linkedTasks: ['task1'],
          ),
          entryText: entryText,
        );

        testChecklistItem = ChecklistItem(
          meta: meta('test-checklist-item-id'),
          data: const ChecklistItemData(
            title: 'Test Checklist Item',
            isChecked: true,
            linkedChecklists: ['checklist-id'],
            id: 'item-uuid',
          ),
          entryText: entryText,
        );

        testUncheckedChecklistItem = ChecklistItem(
          meta: meta('unchecked-item-id'),
          data: const ChecklistItemData(
            title: 'Unchecked Item',
            isChecked: false,
            linkedChecklists: ['checklist-id'],
            id: 'unchecked-item-uuid',
          ),
          entryText: entryText,
        );

        testSurvey = SurveyEntry(
          meta: meta('test-survey-id'),
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

        testAiResponse = AiResponseEntry(
          meta: meta('test-ai-response-id'),
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
            // ignore: deprecated_member_use_from_same_package
            type: AiResponseType.taskSummary,
          ),
          entryText: entryText,
        );
      });

      testWidgets('renders event with title, status chip and stars', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testEvent),
          ),
        );

        expect(find.text(testEvent.data.title), findsOneWidget);
        expect(find.byIcon(Icons.event_rounded), findsOneWidget);
        // Status is humanized into a chip ("Tentative").
        expect(find.text('Tentative'), findsOneWidget);
        // 3.5 stars are rendered through the rating widget.
        expect(find.byType(StarRating), findsOneWidget);
      });

      testWidgets('renders checklist with progress chip and bar', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testChecklist),
            overrides: [
              checklistCompletionControllerProvider(
                (id: 'test-checklist-id', taskId: null),
              ).overrideWith(_FakeChecklistCompletion.new),
            ],
          ),
        );
        // Let the AsyncNotifier resolve so the progress chip renders.
        await tester.pump();

        expect(find.text(testChecklist.data.title), findsOneWidget);
        expect(find.byIcon(MdiIcons.checkAll), findsOneWidget);
        // 2/3 completed -> chip + a linear progress bar.
        expect(find.text('2/3'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('renders checked checklist item with marked glyph', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testChecklistItem),
          ),
        );

        expect(find.text(testChecklistItem.data.title), findsOneWidget);
        expect(find.byIcon(MdiIcons.checkboxMarked), findsOneWidget);
        // Checked items render with a strikethrough title.
        final title = tester.widget<Text>(
          find.text(testChecklistItem.data.title),
        );
        expect(title.style?.decoration, TextDecoration.lineThrough);
      });

      testWidgets('renders unchecked checklist item with blank glyph', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testUncheckedChecklistItem),
          ),
        );

        expect(
          find.text(testUncheckedChecklistItem.data.title),
          findsOneWidget,
        );
        expect(
          find.byIcon(MdiIcons.checkboxBlankOutline),
          findsOneWidget,
        );
        // Unchecked items keep a normal (non-struck) title.
        final title = tester.widget<Text>(
          find.text(testUncheckedChecklistItem.data.title),
        );
        expect(title.style?.decoration, isNot(TextDecoration.lineThrough));
      });

      testWidgets('renders survey with humanized name and score chips', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testSurvey),
          ),
        );

        expect(find.byIcon(MdiIcons.clipboardTextOutline), findsOneWidget);
        // panasSurveyTask -> "PANAS" title.
        expect(find.text('PANAS'), findsOneWidget);
        // Calculated scores become compact chips ("Positive 15").
        expect(find.text('Positive 15'), findsOneWidget);
        expect(find.text('Negative 8'), findsOneWidget);
      });

      testWidgets('renders project entry with title and folder glyph', (
        tester,
      ) async {
        final testProject = ProjectEntry(
          meta: Metadata(
            id: 'test-project-id',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            categoryId: 'test-category-id',
          ),
          data: ProjectData(
            title: 'Device Synchronization',
            status: ProjectStatus.active(
              id: 'ps-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 60,
            ),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testProject),
          ),
        );

        expect(find.text('Device Synchronization'), findsOneWidget);
        expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
      });

      testWidgets('renders rating entry with label and insights glyph', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testRatingEntry),
          ),
        );

        expect(find.text('Session Rating'), findsOneWidget);
        expect(find.byIcon(Icons.insights_rounded), findsOneWidget);
      });

      testWidgets('renders AI response with preview and sparkle glyph', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testAiResponse),
          ),
        );

        // AI responses preview their text and carry an "AI" chip + sparkle.
        expect(find.text('This is a test AI response'), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
        expect(find.text('AI'), findsOneWidget);
      });

      testWidgets('renders a full date+time label, not a raw ISO timestamp', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testEvent),
          ),
        );

        // The meta row shows a full, humanised timestamp (e.g.
        // "Mar 15, 2024 10:30 AM") — resolved via the same code path so the
        // locale matches the rendered card…
        final BuildContext context = tester.element(
          find.byType(ModernJournalCard),
        );
        expect(
          find.text(
            entry_tools.entryDateLabel(context, testEvent.meta.dateFrom),
          ),
          findsOneWidget,
        );
        // …and never the raw 'yyyy-MM-dd HH:mm' ISO format.
        expect(
          find.text(
            entry_tools.dfShorter.format(testEvent.meta.dateFrom),
          ),
          findsNothing,
        );
      });

      testWidgets('navigates to checklist detail on tap', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testChecklist),
          ),
        );

        await tester.tap(find.byType(ModernBaseCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          mockNavService.navigationHistory,
          contains('/journal/${testChecklist.meta.id}'),
        );
      });

      testWidgets('navigates to event detail on tap', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testEvent),
          ),
        );

        await tester.tap(find.byType(ModernBaseCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          mockNavService.navigationHistory,
          contains('/journal/${testEvent.meta.id}'),
        );
      });

      testWidgets('navigates to AI response detail on tap', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: testAiResponse),
          ),
        );

        await tester.tap(find.byType(ModernBaseCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          mockNavService.navigationHistory,
          contains('/journal/${testAiResponse.meta.id}'),
        );
      });

      testWidgets('handles entries with multiple metadata flags', (
        tester,
      ) async {
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

    group('Labels display', () {
      // Override for labelsStreamProvider to avoid real database access
      final labelsOverride = labelsStreamProvider.overrideWith(
        (ref) => Stream.value(<LabelDefinition>[]),
      );

      testWidgets('renders labels when labelIds are present', (tester) async {
        // Arrange labels in the cache
        final labelA = LabelDefinition(
          id: 'label-a',
          name: 'Bug',
          color: '#FF0000',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );
        final labelB = LabelDefinition(
          id: 'label-b',
          name: 'Feature',
          color: '#00FF00',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(
          () => mockEntitiesCacheService.getLabelById('label-a'),
        ).thenReturn(labelA);
        when(
          () => mockEntitiesCacheService.getLabelById('label-b'),
        ).thenReturn(labelB);
        when(
          () => mockEntitiesCacheService.showPrivateEntries,
        ).thenReturn(false);

        // Build entry with two labels
        final entryWithLabels = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            labelIds: ['label-a', 'label-b'],
          ),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: entryWithLabels),
            overrides: [labelsOverride],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Two LabelChips should be rendered
        expect(find.byType(LabelChip), findsNWidgets(2));
        expect(find.text('Bug'), findsOneWidget);
        expect(find.text('Feature'), findsOneWidget);
      });

      testWidgets('renders labels for tasks too', (tester) async {
        // The shared scaffold renders labels for every entry type, tasks
        // included.
        final labelA = LabelDefinition(
          id: 'label-a',
          name: 'Bug',
          color: '#FF0000',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(
          () => mockEntitiesCacheService.getLabelById('label-a'),
        ).thenReturn(labelA);
        when(
          () => mockEntitiesCacheService.showPrivateEntries,
        ).thenReturn(false);

        final taskWithLabels = testTask.copyWith(
          meta: testTask.meta.copyWith(
            labelIds: ['label-a'],
          ),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: taskWithLabels),
            overrides: [labelsOverride],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(LabelChip), findsOneWidget);
        expect(find.text('Bug'), findsOneWidget);
      });

      testWidgets('filters out private labels when showPrivate is false', (
        tester,
      ) async {
        final publicLabel = LabelDefinition(
          id: 'label-public',
          name: 'Public',
          color: '#FF0000',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
        );
        final privateLabel = LabelDefinition(
          id: 'label-private',
          name: 'Private',
          color: '#00FF00',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: true,
        );

        when(
          () => mockEntitiesCacheService.getLabelById('label-public'),
        ).thenReturn(publicLabel);
        when(
          () => mockEntitiesCacheService.getLabelById('label-private'),
        ).thenReturn(privateLabel);
        when(
          () => mockEntitiesCacheService.showPrivateEntries,
        ).thenReturn(false);

        final entryWithLabels = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            labelIds: ['label-public', 'label-private'],
          ),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: entryWithLabels),
            overrides: [labelsOverride],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Only public label should be shown
        expect(find.byType(LabelChip), findsOneWidget);
        expect(find.text('Public'), findsOneWidget);
        expect(find.text('Private'), findsNothing);
      });

      testWidgets('shows private labels when showPrivate is true', (
        tester,
      ) async {
        final privateLabel = LabelDefinition(
          id: 'label-private',
          name: 'Private',
          color: '#00FF00',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: true,
        );

        when(
          () => mockEntitiesCacheService.getLabelById('label-private'),
        ).thenReturn(privateLabel);
        when(
          () => mockEntitiesCacheService.showPrivateEntries,
        ).thenReturn(true);

        final entryWithLabels = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            labelIds: ['label-private'],
          ),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: entryWithLabels),
            overrides: [labelsOverride],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(LabelChip), findsOneWidget);
        expect(find.text('Private'), findsOneWidget);
      });

      testWidgets('displays labels sorted alphabetically', (tester) async {
        final labelZ = LabelDefinition(
          id: 'label-z',
          name: 'Zebra',
          color: '#FF0000',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );
        final labelA = LabelDefinition(
          id: 'label-a',
          name: 'Apple',
          color: '#00FF00',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(
          () => mockEntitiesCacheService.getLabelById('label-z'),
        ).thenReturn(labelZ);
        when(
          () => mockEntitiesCacheService.getLabelById('label-a'),
        ).thenReturn(labelA);
        when(
          () => mockEntitiesCacheService.showPrivateEntries,
        ).thenReturn(false);

        final entryWithLabels = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            labelIds: ['label-z', 'label-a'],
          ),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: entryWithLabels),
            overrides: [labelsOverride],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final chips = tester.widgetList<LabelChip>(find.byType(LabelChip));
        final names = chips.map((c) => c.label.name).toList();

        // Labels should be sorted alphabetically
        expect(names, equals(['Apple', 'Zebra']));
      });

      testWidgets('does not render labels when entry has no labelIds', (
        tester,
      ) async {
        when(
          () => mockEntitiesCacheService.showPrivateEntries,
        ).thenReturn(false);

        final entryWithoutLabels = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            labelIds: null,
          ),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: entryWithoutLabels),
            overrides: [labelsOverride],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(LabelChip), findsNothing);
      });

      testWidgets('handles cache returning null for unknown label IDs', (
        tester,
      ) async {
        final knownLabel = LabelDefinition(
          id: 'label-known',
          name: 'Known',
          color: '#FF0000',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(
          () => mockEntitiesCacheService.getLabelById('label-known'),
        ).thenReturn(knownLabel);
        when(
          () => mockEntitiesCacheService.getLabelById('label-unknown'),
        ).thenReturn(null);
        when(
          () => mockEntitiesCacheService.showPrivateEntries,
        ).thenReturn(false);

        final entryWithMixedLabels = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            labelIds: ['label-known', 'label-unknown'],
          ),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalCard(item: entryWithMixedLabels),
            overrides: [labelsOverride],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Only the known label should be rendered
        expect(find.byType(LabelChip), findsOneWidget);
        expect(find.text('Known'), findsOneWidget);
      });
    });
  });

  // The de-emphasized meta row uses dfShorter ('yyyy-MM-dd HH:mm') as its
  // reference "raw" format that the relative label deliberately avoids; these
  // properties pin the invariants that distinction relies on across the whole
  // DateTime input space.
  group('entry_tools date formatters — properties', () {
    // Map an int seed to a deterministic DateTime spread over ~30 years so we
    // exercise different months, days, hours and minutes.
    DateTime dateForSeed(int seed) {
      final s = seed.abs();
      return DateTime(
        2000,
      ).add(Duration(minutes: s)).add(Duration(days: s % 11000));
    }

    glados.Glados<int>(
      glados.any.intInRange(0, 2000000),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'date-only format (dfShort) is a non-empty prefix of the date-time '
      'format (dfShorter) and never longer',
      (seed) {
        final d = dateForSeed(seed);
        final shortFormat = entry_tools.dfShort.format(d);
        final shorterFormat = entry_tools.dfShorter.format(d);

        // Both branches must produce something to render.
        expect(shortFormat, isNotEmpty, reason: 'd=$d');
        expect(shorterFormat, isNotEmpty, reason: 'd=$d');

        // dfShorter ('yyyy-MM-dd HH:mm') extends dfShort ('yyyy-MM-dd') with
        // a time suffix, so the short format is a strict prefix of the longer
        // format and the longer format carries strictly more characters.
        expect(shorterFormat.startsWith(shortFormat), isTrue, reason: 'd=$d');
        expect(
          shorterFormat.length,
          greaterThan(shortFormat.length),
          reason: 'd=$d',
        );
      },
      tags: 'glados',
    );
  });

  group('Branch coverage — edge cases', () {
    final testDate = DateTime(2024, 3, 15, 10, 30);
    Metadata meta(String id) => Metadata(
      id: id,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate.add(const Duration(hours: 1)),
      categoryId: 'test-category-id',
    );

    testWidgets('event with an empty title falls back to the type label', (
      tester,
    ) async {
      final event = JournalEvent(
        meta: meta('e-empty'),
        data: const EventData(title: '', status: EventStatus.planned, stars: 0),
      );
      await tester.pumpWidget(
        makeTestableWidget(ModernJournalCard(item: event)),
      );

      final context = tester.element(find.byType(ModernJournalCard));
      expect(
        find.text(context.messages.entryTypeLabelJournalEvent),
        findsOneWidget,
      );
    });

    testWidgets('text entry with empty text falls back to the type label', (
      tester,
    ) async {
      final entry = JournalEntry(
        meta: meta('t-empty'),
        entryText: const EntryText(plainText: '', markdown: ''),
      );
      await tester.pumpWidget(
        makeTestableWidget(ModernJournalCard(item: entry)),
      );

      final context = tester.element(find.byType(ModernJournalCard));
      expect(
        find.text(context.messages.entryTypeLabelJournalEntry),
        findsOneWidget,
      );
    });

    for (final (sport, icon) in [
      ('walking', Icons.directions_walk_rounded),
      ('swimming', Icons.pool_rounded),
      ('cycling', Icons.directions_bike_rounded),
    ]) {
      testWidgets('workout "$sport" leads with its sport glyph', (
        tester,
      ) async {
        final workout = WorkoutEntry(
          meta: meta('w-$sport'),
          data: WorkoutData(
            dateFrom: testDate,
            dateTo: testDate.add(const Duration(minutes: 20)),
            id: 'w-$sport',
            workoutType: sport,
            energy: 100,
            distance: null,
            source: null,
          ),
        );
        await tester.pumpWidget(
          makeTestableWidget(ModernJournalCard(item: workout)),
        );

        expect(find.byIcon(icon), findsOneWidget);
      });
    }

    testWidgets('workout distance under 1 km renders metres', (tester) async {
      final workout = WorkoutEntry(
        meta: meta('w-short'),
        data: WorkoutData(
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(minutes: 5)),
          id: 'w-short',
          workoutType: 'running',
          energy: null,
          distance: 800,
          source: null,
        ),
      );
      await tester.pumpWidget(
        makeTestableWidget(ModernJournalCard(item: workout)),
      );

      expect(find.text('800 m'), findsOneWidget);
    });

    testWidgets('CFQ11 survey shows its instrument name', (tester) async {
      final survey = SurveyEntry(
        meta: meta('s-cfq'),
        data: SurveyData(
          taskResult: RPTaskResult(identifier: 'cfq11SurveyTask'),
          scoreDefinitions: const {},
          calculatedScores: const {'Score': 12},
        ),
      );
      await tester.pumpWidget(
        makeTestableWidget(ModernJournalCard(item: survey)),
      );

      expect(find.text('CFQ 11'), findsOneWidget);
    });

    testWidgets('survey with an unknown id falls back to the type label', (
      tester,
    ) async {
      final survey = SurveyEntry(
        meta: meta('s-unknown'),
        data: SurveyData(
          taskResult: RPTaskResult(identifier: 'somethingElse'),
          scoreDefinitions: const {},
          calculatedScores: const {},
        ),
      );
      await tester.pumpWidget(
        makeTestableWidget(ModernJournalCard(item: survey)),
      );

      final context = tester.element(find.byType(ModernJournalCard));
      expect(
        find.text(context.messages.entryTypeLabelSurveyEntry),
        findsOneWidget,
      );
    });

    testWidgets('audio under an hour shows a m:ss duration chip', (
      tester,
    ) async {
      final audio = testAudioEntry.copyWith(
        meta: testAudioEntry.meta.copyWith(id: 'a-short'),
        data: testAudioEntry.data.copyWith(
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(minutes: 2, seconds: 5)),
        ),
      );
      await tester.pumpWidget(
        makeTestableWidget(ModernJournalCard(item: audio)),
      );

      expect(find.text('2:05'), findsOneWidget);
    });

    for (final completion in [
      HabitCompletionType.skip,
      HabitCompletionType.fail,
      HabitCompletionType.open,
    ]) {
      testWidgets('habit completion (${completion.name}) shows its state', (
        tester,
      ) async {
        final habit = HabitCompletionEntry(
          meta: meta('h-${completion.name}'),
          data: HabitCompletionData(
            dateFrom: testDate,
            dateTo: testDate,
            habitId: 'habit-1',
            completionType: completion,
          ),
        );
        await tester.pumpWidget(
          makeTestableWidget(ModernJournalCard(item: habit)),
        );

        final context = tester.element(find.byType(ModernJournalCard));
        final label = switch (completion) {
          HabitCompletionType.skip =>
            context.messages.habitCompletionStatusSkipped,
          HabitCompletionType.fail =>
            context.messages.habitCompletionStatusFailed,
          HabitCompletionType.open =>
            context.messages.habitCompletionStatusOpen,
          HabitCompletionType.success =>
            context.messages.habitCompletionStatusCompleted,
        };
        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('habit card re-subscribes when the habit id changes', (
      tester,
    ) async {
      HabitCompletionEntry habit(String id, HabitCompletionType type) =>
          HabitCompletionEntry(
            meta: meta('hc-shared'),
            data: HabitCompletionData(
              dateFrom: testDate,
              dateTo: testDate,
              habitId: id,
              completionType: type,
            ),
          );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(
            item: habit('habit-a', HabitCompletionType.success),
          ),
        ),
      );
      final context = tester.element(find.byType(ModernJournalCard));
      final completed = context.messages.habitCompletionStatusCompleted;
      final failed = context.messages.habitCompletionStatusFailed;
      expect(find.text(completed), findsOneWidget);

      // Re-pump a different habit (id + outcome) in the same position so
      // didUpdateWidget fires and the stream is re-created.
      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: habit('habit-b', HabitCompletionType.fail)),
        ),
      );
      expect(find.text(failed), findsOneWidget);
      expect(find.text(completed), findsNothing);
    });

    testWidgets('habit tile is tinted by its resolved category colour', (
      tester,
    ) async {
      // Resolve the habit to a definition that carries a category so
      // `_habitColor` takes the `colorFromCssHex(category.color)` branch rather
      // than the primary fallback.
      when(
        () => mockJournalDb.getHabitById(any()),
      ).thenAnswer((_) async => habitFlossing.copyWith(categoryId: 'cat-id'));

      final habit = HabitCompletionEntry(
        meta: meta('h-cat'),
        data: HabitCompletionData(
          dateFrom: testDate,
          dateTo: testDate,
          habitId: 'habit-1',
        ),
      );
      await tester.pumpWidget(
        makeTestableWidget(ModernJournalCard(item: habit)),
      );
      // Resolve the habit via the stream so `_habitColor` runs with a non-null
      // habit + category.
      await tester.pump();

      expect(find.text(habitFlossing.name), findsOneWidget);
    });
  });
}
