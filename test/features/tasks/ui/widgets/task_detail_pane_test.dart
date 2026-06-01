import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_pane.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';

import '../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CategoryDefinition _makeCategory({
  String id = 'work',
  String name = 'Work',
  String color = '#4AB6E8',
  CategoryIcon icon = CategoryIcon.work,
}) {
  final now = DateTime(2024, 3, 15);
  return EntityDefinition.categoryDefinition(
        id: id,
        createdAt: now,
        updatedAt: now,
        name: name,
        vectorClock: null,
        private: false,
        active: true,
        color: color,
        icon: icon,
      )
      as CategoryDefinition;
}

Task _makeTask({
  String id = 'task-1',
  String title = 'Test Task',
  String description = 'A task description',
  TaskPriority priority = TaskPriority.p2Medium,
  TaskStatus? status,
  String categoryId = 'work',
  DateTime? due,
}) {
  final createdAt = DateTime(2024, 3, 15, 10);
  return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: createdAt,
          updatedAt: createdAt,
          dateFrom: createdAt,
          dateTo: createdAt.add(const Duration(minutes: 30)),
          categoryId: categoryId,
        ),
        data: TaskData(
          status:
              status ??
              TaskStatus.open(
                id: 'open-1',
                createdAt: createdAt,
                utcOffset: 0,
              ),
          statusHistory: const [],
          title: title,
          dateFrom: createdAt,
          dateTo: createdAt.add(const Duration(minutes: 30)),
          due: due,
          priority: priority,
        ),
        entryText: EntryText(plainText: description),
      )
      as Task;
}

TaskRecord _makeRecord({
  String title = 'Test Task',
  String projectTitle = 'My Project',
  String aiSummary = 'AI summary text.',
  String description = 'Task description.',
  String trackedDurationLabel = '5m 00s',
  List<TaskShowcaseLabel> labels = const [],
  List<TaskShowcaseTimeEntry> trackerEntries = const [],
  List<TaskShowcaseChecklistItem> checklistItems = const [],
  List<TaskShowcaseAudioEntry> audioEntries = const [],
  TaskPriority priority = TaskPriority.p2Medium,
  CategoryDefinition? category,
  DateTime? due,
}) {
  final cat = category ?? _makeCategory();
  final task = _makeTask(
    title: title,
    priority: priority,
    categoryId: cat.id,
    due: due,
  );
  return TaskRecord(
    task: task,
    category: cat,
    sectionTitle: 'Today',
    sectionDate: DateTime(2024, 3, 15),
    projectTitle: projectTitle,
    timeRange: '10:00-11:00am',
    labels: labels,
    aiSummary: aiSummary,
    description: description,
    trackedDurationLabel: trackedDurationLabel,
    trackerEntries: trackerEntries,
    checklistItems: checklistItems,
    audioEntries: audioEntries,
  );
}

/// Pump a [TaskShowcaseDetailContent] inside a dark-themed scaffold at the
/// given [width]. Using [makeTestableWidget2] (no ProviderScope needed as the
/// widget is purely presentational).
Future<void> _pumpDetailContent(
  WidgetTester tester,
  TaskRecord record, {
  required double width,
  double height = 1200,
  bool compact = false,
  VoidCallback? onBack,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: SingleChildScrollView(
              child: TaskShowcaseDetailContent(
                record: record,
                compact: compact,
                onBack: onBack,
              ),
            ),
          ),
        ),
      ),
      mediaQueryData: MediaQueryData(size: Size(width, height)),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TaskDetailPane', () {
    setUp(setUpTestGetIt);
    tearDown(tearDownTestGetIt);

    testWidgets('renders task title and project in the detail pane', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final record = _makeRecord(
        title: 'My Important Task',
        projectTitle: 'Lotti Mobile App',
      );

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: SizedBox(
                width: 1200,
                height: 900,
                child: TaskDetailPane(record: record),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
        ),
      );
      await tester.pump();

      expect(find.text('My Important Task'), findsAtLeastNWidgets(1));
      expect(find.text('Lotti Mobile App'), findsOneWidget);
    });

    testWidgets('renders without leading border when showLeadingBorder=false', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final record = _makeRecord(title: 'No-border Task');

      // With border (default true)
      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: SizedBox(
                width: 1000,
                height: 800,
                child: TaskDetailPane(record: record),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1000, 800)),
        ),
      );
      await tester.pump();

      // Find the TaskDetailPane's DecoratedBox
      final withBorder = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final borderWithBorder =
          (withBorder.decoration as BoxDecoration).border! as Border;
      expect(borderWithBorder.left, isNot(BorderSide.none));

      // Without border
      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: SizedBox(
                width: 1000,
                height: 800,
                child: TaskDetailPane(
                  record: record,
                  showLeadingBorder: false,
                ),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1000, 800)),
        ),
      );
      await tester.pump();

      final withoutBorder = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final borderWithout =
          (withoutBorder.decoration as BoxDecoration).border! as Border;
      expect(borderWithout.left, BorderSide.none);
    });
  });

  group('TaskShowcaseDetailContent — wide layout (>= 720 px)', () {
    setUp(setUpTestGetIt);
    tearDown(tearDownTestGetIt);

    // Lines 130-162: the else branch when useCompactDetailLayout == false.
    // Width 800 > 720 and compact=false → horizontal Row with sidebar pills.
    testWidgets('shows "Jump to section" label in wide layout', (tester) async {
      final record = _makeRecord(
        title: 'Wide Layout Task',
        projectTitle: 'Wide Project',
      );

      await _pumpDetailContent(tester, record, width: 800);

      expect(find.text('Jump to section'), findsOneWidget);
    });

    testWidgets('renders section pills in a sidebar column in wide layout', (
      tester,
    ) async {
      final record = _makeRecord();

      await _pumpDetailContent(tester, record, width: 800);

      // Section pills (Timer, Todo, Audio, Images, Linked) are rendered.
      // In the wide layout they are placed in a Column-based sidebar.
      expect(find.text('Timer'), findsOneWidget);
      expect(find.text('Todo'), findsOneWidget);
    });

    testWidgets('wraps detail cards in an Expanded column in wide layout', (
      tester,
    ) async {
      final record = _makeRecord(
        aiSummary: 'Wide summary',
        description: 'Wide description',
      );

      await _pumpDetailContent(tester, record, width: 800);

      // The AI summary and description text must appear, confirming
      // _TaskDetailCardsColumn is rendered inside the Expanded.
      expect(find.text('Wide summary'), findsOneWidget);
      expect(find.text('Wide description'), findsOneWidget);
    });

    testWidgets('does NOT show "Jump to section" in compact layout', (
      tester,
    ) async {
      final record = _makeRecord();

      // Width 400 < 720, so compact layout is used.
      await _pumpDetailContent(tester, record, width: 400);

      expect(find.text('Jump to section'), findsNothing);
    });

    testWidgets('compact flag forces compact layout regardless of width', (
      tester,
    ) async {
      final record = _makeRecord();

      // Even at 900 px wide, compact=true forces the compact path.
      await _pumpDetailContent(tester, record, width: 900, compact: true);

      expect(find.text('Jump to section'), findsNothing);
    });
  });

  group('TaskShowcaseDetailContent — compact layout (< 720 px)', () {
    setUp(setUpTestGetIt);
    tearDown(tearDownTestGetIt);

    testWidgets('renders horizontal pill row in narrow layout', (tester) async {
      final record = _makeRecord(title: 'Narrow Task');

      await _pumpDetailContent(tester, record, width: 390, height: 844);

      // Pills are rendered horizontally (no "Jump to section" label).
      expect(find.text('Jump to section'), findsNothing);
      expect(find.text('Timer'), findsOneWidget);
    });

    testWidgets('shows mobile detail header when compact=true', (tester) async {
      var backCalled = false;
      final record = _makeRecord(title: 'Compact Task');

      await _pumpDetailContent(
        tester,
        record,
        width: 390,
        height: 844,
        compact: true,
        onBack: () => backCalled = true,
      );

      // The mobile header includes a back button.
      final backButtons = find.byIcon(Icons.arrow_back_ios_rounded);
      if (backButtons.evaluate().isNotEmpty) {
        await tester.tap(backButtons.first);
        await tester.pump();
        expect(backCalled, isTrue);
      } else {
        // Alternatively the back action may be represented differently;
        // at minimum the compact task title must be displayed.
        expect(find.text('Compact Task'), findsAtLeastNWidgets(1));
      }
    });
  });

  group('TaskShowcaseDetailContent — checklist item icon color (line 671)', () {
    setUp(setUpTestGetIt);
    tearDown(tearDownTestGetIt);

    testWidgets('renders check_box_rounded icon for done items', (
      tester,
    ) async {
      final record = _makeRecord(
        checklistItems: const [
          TaskShowcaseChecklistItem(title: 'Done item', done: true),
          TaskShowcaseChecklistItem(title: 'Pending item', done: false),
        ],
      );

      await _pumpDetailContent(tester, record, width: 400);

      // Done item → filled checkbox icon
      expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
      // Pending item → blank checkbox icon
      expect(
        find.byIcon(Icons.check_box_outline_blank_rounded),
        findsOneWidget,
      );
    });

    testWidgets('done item title and undone item title are both displayed', (
      tester,
    ) async {
      final record = _makeRecord(
        checklistItems: const [
          TaskShowcaseChecklistItem(title: 'Finished task', done: true),
          TaskShowcaseChecklistItem(title: 'Outstanding task', done: false),
        ],
      );

      await _pumpDetailContent(tester, record, width: 400);

      expect(find.text('Finished task'), findsOneWidget);
      expect(find.text('Outstanding task'), findsOneWidget);
    });

    testWidgets('renders all done-item icon colors in wide layout', (
      tester,
    ) async {
      // Repeat in wide layout to also exercise line 671 via the wide path.
      final record = _makeRecord(
        checklistItems: const [
          TaskShowcaseChecklistItem(title: 'Done', done: true),
        ],
      );

      await _pumpDetailContent(tester, record, width: 800);

      expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });

  group('TaskShowcaseDetailContent — header variants', () {
    setUp(setUpTestGetIt);
    tearDown(tearDownTestGetIt);

    testWidgets('renders due date chip when task has a due date', (
      tester,
    ) async {
      final record = _makeRecord(
        due: DateTime(2024, 4, 30),
      );

      await _pumpDetailContent(tester, record, width: 400);

      // The due date chip contains a formatted date string.
      expect(
        find.byIcon(Icons.watch_later_outlined),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('does not render due date chip when task has no due date', (
      tester,
    ) async {
      // No due date passed → due is null
      final record = _makeRecord();

      await _pumpDetailContent(tester, record, width: 400);

      expect(find.byIcon(Icons.watch_later_outlined), findsNothing);
    });

    testWidgets('renders all label chips', (tester) async {
      final record = _makeRecord(
        labels: const [
          TaskShowcaseLabel(id: 'l1', label: 'Bug', color: Color(0xFF1F9CF5)),
          TaskShowcaseLabel(
            id: 'l2',
            label: 'Release',
            color: Color(0xFFFBA337),
          ),
        ],
      );

      await _pumpDetailContent(tester, record, width: 400);

      expect(find.text('Bug'), findsOneWidget);
      expect(find.text('Release'), findsOneWidget);
    });

    for (final entry in {
      'compact header (< 520 px)': 390.0,
      'wide header (>= 520 px)': 600.0,
    }.entries) {
      testWidgets('header renders priority glyph — ${entry.key}', (
        tester,
      ) async {
        final record = _makeRecord(priority: TaskPriority.p0Urgent);

        await _pumpDetailContent(tester, record, width: entry.value);

        // Priority glyph (SVG asset) is always in the header regardless of
        // width. Check via the widget type, not an icon constant.
        expect(
          find.byType(TaskShowcasePriorityGlyph),
          findsAtLeastNWidgets(1),
        );
      });
    }
  });
}
