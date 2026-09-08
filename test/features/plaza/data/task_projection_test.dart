import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/data/task_projection.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';

void main() {
  final world = ManualDemoWorld.penguinLogistics(now: manualDemoNow);
  final task = world.tasks.first;
  final item = world.checklistItems.first;

  PlazaTask project({
    Task? source,
    List<ChecklistItem> items = const [],
    List<String> links = const [],
    String? cover,
  }) => projectPlazaTask(
    task: source ?? task,
    checklistItems: items,
    linkedTaskIds: links,
    categoryColor: 0xFF123456,
    coverImageUrl: cover,
  );

  test('preserves persisted identity, dates, priority, colour and cover', () {
    final source = task.copyWith(
      meta: task.meta.copyWith(deletedAt: manualDemoNow),
      data: task.data.copyWith(priority: TaskPriority.p0Urgent),
    );
    final result = project(source: source, cover: 'file:///cover.png');
    expect(result.id, source.meta.id);
    expect(result.createdAt, source.meta.createdAt);
    expect(result.lastActivityAt, source.meta.updatedAt);
    expect(result.title, source.data.title);
    expect(result.due, source.data.due);
    expect(result.deleted, isTrue);
    expect(result.priority, 0);
    expect(result.categoryColor, 0xFF123456);
    expect(result.coverImageUrl, 'file:///cover.png');
  });

  test('empty checklist has zero progress and no writable item IDs', () {
    final result = project();
    expect(result.progress, 0);
    expect(result.checklistItems, 0);
    expect(result.openChecklistItems, isEmpty);
    expect(result.openChecklistItemIds, isEmpty);
    expect(result.coverImageUrl, isNull);
  });

  test('filters deleted and archived items and deduplicates IDs', () {
    final open = item.copyWith(data: item.data.copyWith(isChecked: false));
    final checked = item.copyWith(
      meta: item.meta.copyWith(id: 'checked'),
      data: item.data.copyWith(isChecked: true),
    );
    final archived = item.copyWith(
      meta: item.meta.copyWith(id: 'archived'),
      data: item.data.copyWith(isArchived: true),
    );
    final deleted = item.copyWith(
      meta: item.meta.copyWith(id: 'deleted', deletedAt: manualDemoNow),
    );
    final result = project(items: [open, checked, archived, deleted, open]);
    expect(result.checklistItems, 2);
    expect(result.progress, 0.5);
    expect(result.openChecklistItems, [open.data.title]);
    expect(result.openChecklistItemIds, [open.meta.id]);
  });

  test('caps previews without inflating progress or losing item identity', () {
    final items = [
      for (var i = 0; i < 12; i++)
        item.copyWith(
          meta: item.meta.copyWith(id: 'item-$i'),
          data: item.data.copyWith(title: 'Step $i', isChecked: i >= 10),
        ),
    ];
    final result = project(items: items);
    expect(result.checklistItems, 12);
    expect(result.progress, 2 / 12);
    expect(result.openChecklistItems, [for (var i = 0; i < 8; i++) 'Step $i']);
    expect(result.openChecklistItemIds, [
      for (var i = 0; i < 8; i++) 'item-$i',
    ]);
  });

  test('all checked items produce full progress and no open preview', () {
    final result = project(
      items: [
        item.copyWith(data: item.data.copyWith(isChecked: true)),
      ],
    );
    expect(result.progress, 1);
    expect(result.checklistItems, 1);
    expect(result.openChecklistItems, isEmpty);
    expect(result.openChecklistItemIds, isEmpty);
  });

  test('sorts and deduplicates links without mutating the source', () {
    final links = ['z', task.meta.id, 'a', 'z'];
    expect(project(links: links).linkedTaskIds, ['a', 'z']);
    expect(links, ['z', task.meta.id, 'a', 'z']);
  });

  test('every task status arm maps to a plaza state', () {
    final now = DateTime.utc(2026, 7, 17);
    expect(
      mapTaskStatusToPlazaState(
        TaskStatus.open(id: 'a', createdAt: now, utcOffset: 0),
      ),
      PlazaTaskState.open,
    );
    expect(
      mapTaskStatusToPlazaState(
        TaskStatus.groomed(id: 'b', createdAt: now, utcOffset: 0),
      ),
      PlazaTaskState.open,
    );
    expect(
      mapTaskStatusToPlazaState(
        TaskStatus.inProgress(id: 'c', createdAt: now, utcOffset: 0),
      ),
      PlazaTaskState.inProgress,
    );
    expect(
      mapTaskStatusToPlazaState(
        TaskStatus.blocked(
          id: 'd',
          createdAt: now,
          utcOffset: 0,
          reason: 'ice',
        ),
      ),
      PlazaTaskState.blocked,
    );
    expect(
      mapTaskStatusToPlazaState(
        TaskStatus.onHold(
          id: 'e',
          createdAt: now,
          utcOffset: 0,
          reason: 'ice',
        ),
      ),
      PlazaTaskState.blocked,
    );
    expect(
      mapTaskStatusToPlazaState(
        TaskStatus.done(id: 'f', createdAt: now, utcOffset: 0),
      ),
      PlazaTaskState.done,
    );
    expect(
      mapTaskStatusToPlazaState(
        TaskStatus.rejected(id: 'g', createdAt: now, utcOffset: 0),
      ),
      PlazaTaskState.cancelled,
    );
  });
}
