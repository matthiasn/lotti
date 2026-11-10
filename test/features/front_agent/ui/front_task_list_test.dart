import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/ui/front_task_list.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 11, 7, 9);
  final colony = CategoryDefinition(
    id: 'colony',
    name: 'Colony',
    color: '#4CAF93',
    createdAt: at,
    updatedAt: at,
    vectorClock: null,
    private: false,
    active: true,
  );

  Task task(
    String id,
    String title,
    TaskStatus status, {
    DateTime? due,
    String? categoryId = 'colony',
    TaskPriority priority = TaskPriority.p2Medium,
  }) => testTask.copyWith(
    data: testTask.data.copyWith(
      title: title,
      status: status,
      due: due,
      priority: priority,
    ),
    meta: testTask.meta.copyWith(id: id, categoryId: categoryId),
  );

  final counting = task(
    't1',
    'Count the hatchlings',
    TaskStatus.inProgress(id: 's1', createdAt: at, utcOffset: 60),
    due: at,
    priority: TaskPriority.p1High,
  );
  late List<String> opened;

  group('FrontClosedTaskList', () {
    final closedCards = [
      FrontClosedTaskCard(
        id: 'c1',
        title: 'Count the hatchlings',
        closedAt: DateTime(2026, 11, 7, 10),
        categoryId: 'colony',
      ),
      FrontClosedTaskCard(
        id: 'c2',
        title: 'Move the feeding station',
        closedAt: DateTime(2026, 11, 8, 11),
        rejected: true,
      ),
      FrontClosedTaskCard(
        id: 'c3',
        title: 'Check the nest cameras',
        closedAt: DateTime(2026, 11, 8, 12),
        reopened: true,
        categoryId: 'colony',
      ),
    ];

    Future<void> pumpClosed(WidgetTester tester) async {
      opened = [];
      final cache = MockEntitiesCacheService();
      when(() => cache.getCategoryById(any())).thenReturn(null);
      when(() => cache.getCategoryById('colony')).thenReturn(colony);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: SingleChildScrollView(
              child: FrontClosedTaskList(
                tasks: closedCards,
                onOpen: opened.add,
              ),
            ),
          ),
          overrides: [
            entitiesCacheServiceProvider.overrideWithValue(cache),
            // Reopened and in progress again.
            taskPreviewProvider.overrideWith(
              (ref, id) async =>
                  id == 'c3' ? TaskPreview(task: counting) : null,
            ),
          ],
        ),
      );
      await tester.pump();
    }

    Finder inClosed(String id, Finder finder) => find.descendant(
      of: find.byKey(FrontTaskListKeys.closedRow(id)),
      matching: finder,
    );

    String subtitleOf(WidgetTester tester, String id) => tester
        .widget<DesignSystemListItem>(
          inClosed(id, find.byType(DesignSystemListItem)),
        )
        .subtitleSpans!
        .whereType<TextSpan>()
        .map((span) => span.text)
        .join();

    testWidgets('one card, a row per task, each saying how it closed and '
        'when, with its category in its colour', (tester) async {
      await pumpClosed(tester);

      expect(find.byKey(FrontTaskListKeys.closedCard), findsOneWidget);
      expect(
        tester
            .widgetList<FrontClosedTaskRow>(find.byType(FrontClosedTaskRow))
            .map((row) => row.task.id),
        ['c1', 'c2', 'c3'],
      );
      // Completed and rejected read apart: glyph and words.
      expect(
        tester
            .widget<StatusGlyph>(inClosed('c1', find.byType(StatusGlyph)))
            .status,
        isA<TaskDone>(),
      );
      expect(
        tester
            .widget<StatusGlyph>(inClosed('c2', find.byType(StatusGlyph)))
            .status,
        isA<TaskRejected>(),
      );
      expect(subtitleOf(tester, 'c1'), 'Done · Sat, Nov 7    Colony');
      expect(subtitleOf(tester, 'c2'), 'Rejected · Sun, Nov 8');
      final swatch = tester.widget<ColorIcon>(
        inClosed('c1', find.byType(ColorIcon)),
      );
      expect(swatch.color, const Color(0xFF4CAF93));
      expect(inClosed('c2', find.byType(ColorIcon)), findsNothing);
    });

    testWidgets('a task reopened since shows what it is now after its close', (
      tester,
    ) async {
      await pumpClosed(tester);

      expect(
        subtitleOf(tester, 'c3'),
        'Done → In Progress · Sun, Nov 8    Colony',
      );
      expect(
        tester
            .widget<StatusGlyph>(inClosed('c3', find.byType(StatusGlyph)))
            .status,
        isA<TaskDone>(),
      );
    });

    testWidgets('a tap on a card opens its task', (tester) async {
      await pumpClosed(tester);

      await tester.tap(find.byKey(FrontTaskListKeys.closedRow('c2')));
      await tester.tap(find.byKey(FrontTaskListKeys.closedRow('c1')));

      expect(opened, ['c2', 'c1']);
    });
  });
}
