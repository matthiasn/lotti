import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_checklists_section.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_task_section.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

// Test controller for checklist completion
class TestChecklistCompletionController extends ChecklistCompletionController {
  TestChecklistCompletionController(this._value);

  final ({int completedCount, int totalCount})? _value;

  @override
  Future<({int completedCount, int totalCount})> build({
    required String id,
    required String? taskId,
  }) async {
    final value = _value;
    if (value != null) {
      state = AsyncValue.data(value);
      return value;
    }
    return (completedCount: 0, totalCount: 0);
  }
}

void main() {
  setUpAll(getIt.reset);

  group('CollapsibleChecklistsSection', () {
    late ScrollController scrollController;

    setUp(() {
      scrollController = ScrollController();
      getIt.reset();
    });

    tearDown(() {
      scrollController.dispose();
      getIt.reset();
    });

    Widget createTestWidget({
      required Widget child,
      required List<Override> overrides,
    }) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: child,
            ),
          ),
        ),
      );
    }

    Task createTaskWithChecklists(List<String> checklistIds) {
      final now = DateTime.now();
      return Task(
        meta: Metadata(
          id: 'test-task-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          title: 'Test Task',
          checklistIds: checklistIds,
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: now,
            utcOffset: now.timeZoneOffset.inMinutes,
          ),
          dateFrom: now,
          dateTo: now,
          statusHistory: [],
        ),
      );
    }

    testWidgets('shows nothing when no checklists exist', (tester) async {
      final task = createTaskWithChecklists([]);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [],
          child: CollapsibleChecklistsSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CollapsibleChecklistsSection), findsOneWidget);
      expect(find.byIcon(MdiIcons.checkboxMultipleOutline), findsNothing);
    });

    testWidgets('shows single checklist preview', (tester) async {
      final task = createTaskWithChecklists(['checklist-1']);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            checklistCompletionControllerProvider(
              id: 'checklist-1',
              taskId: 'test-task-id',
            ).overrideWith(
              () => TestChecklistCompletionController(
                (
                  totalCount: 10,
                  completedCount: 3,
                ),
              ),
            ),
          ],
          child: CollapsibleChecklistsSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.checkboxMultipleOutline), findsOneWidget);
      expect(find.text('Checklists'), findsOneWidget);
      expect(find.textContaining('30% complete'), findsOneWidget);
      expect(find.textContaining('(3/10 items)'), findsOneWidget);
    });

    testWidgets('shows multiple checklists preview', (tester) async {
      final task = createTaskWithChecklists(['checklist-1', 'checklist-2']);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            checklistCompletionControllerProvider(
              id: 'checklist-1',
              taskId: 'test-task-id',
            ).overrideWith(
              () => TestChecklistCompletionController(
                (
                  totalCount: 10,
                  completedCount: 5,
                ),
              ),
            ),
            checklistCompletionControllerProvider(
              id: 'checklist-2',
              taskId: 'test-task-id',
            ).overrideWith(
              () => TestChecklistCompletionController(
                (
                  totalCount: 5,
                  completedCount: 3,
                ),
              ),
            ),
          ],
          child: CollapsibleChecklistsSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.checkboxMultipleOutline), findsOneWidget);
      expect(find.text('Checklists'), findsOneWidget);
      expect(find.textContaining('2 checklists'), findsOneWidget);
      expect(find.textContaining('53% complete'), findsOneWidget);
      expect(find.textContaining('8 of 15 items completed'), findsOneWidget);
    });

    testWidgets('shows expand/collapse indicator', (tester) async {
      final task = createTaskWithChecklists(['checklist-1']);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            checklistCompletionControllerProvider(
              id: 'checklist-1',
              taskId: 'test-task-id',
            ).overrideWith(
              () => TestChecklistCompletionController(
                (
                  totalCount: 10,
                  completedCount: 3,
                ),
              ),
            ),
          ],
          child: CollapsibleChecklistsSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show the section with title
      expect(find.text('Checklists'), findsOneWidget);

      // Should show the collapsed content
      expect(find.textContaining('30% complete'), findsOneWidget);

      // The CollapsibleTaskSection should be present
      expect(find.byType(CollapsibleTaskSection), findsOneWidget);
    });

    testWidgets('handles empty checklists correctly', (tester) async {
      final task = createTaskWithChecklists(['checklist-1']);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            checklistCompletionControllerProvider(
              id: 'checklist-1',
              taskId: 'test-task-id',
            ).overrideWith(
              () => TestChecklistCompletionController(
                (
                  totalCount: 0,
                  completedCount: 0,
                ),
              ),
            ),
          ],
          child: CollapsibleChecklistsSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.checkboxMultipleOutline), findsOneWidget);
      expect(find.textContaining('0% complete'), findsOneWidget);
      expect(find.textContaining('(0/0 items)'), findsOneWidget);
    });

    testWidgets('calculates completion correctly with mixed states',
        (tester) async {
      final task = createTaskWithChecklists(
        ['checklist-1', 'checklist-2', 'checklist-3'],
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            checklistCompletionControllerProvider(
              id: 'checklist-1',
              taskId: 'test-task-id',
            ).overrideWith(
              () => TestChecklistCompletionController(
                (
                  totalCount: 4,
                  completedCount: 4, // 100% complete
                ),
              ),
            ),
            checklistCompletionControllerProvider(
              id: 'checklist-2',
              taskId: 'test-task-id',
            ).overrideWith(
              () => TestChecklistCompletionController(
                (
                  totalCount: 6,
                  completedCount: 3, // 50% complete
                ),
              ),
            ),
            checklistCompletionControllerProvider(
              id: 'checklist-3',
              taskId: 'test-task-id',
            ).overrideWith(
              () => TestChecklistCompletionController(
                (
                  totalCount: 10,
                  completedCount: 0, // 0% complete
                ),
              ),
            ),
          ],
          child: CollapsibleChecklistsSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('3 checklists'), findsOneWidget);
      expect(find.textContaining('35% complete'), findsOneWidget);
      expect(find.textContaining('7 of 20 items completed'), findsOneWidget);
    });
  });
}
