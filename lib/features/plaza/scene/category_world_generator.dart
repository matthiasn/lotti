import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/plaza/data/plaza_repository.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/scene/project_world_generator.dart';
import 'package:lotti/features/plaza/ui/plaza_copy.dart';
import 'package:lotti/utils/color.dart';

/// One labelled avenue per project, joined by the street's walking network.
/// Closed projects occupy the outer avenues and use green, recessed buildings.
/// Portals retain real dates; explicit buckets replace the task-week grouping.
PlazaWorld generateCategoryWorld({
  required CategoryPlazaData data,
  required DateTime now,
  ProjectWorldConfig config = const ProjectWorldConfig(weeksPerRow: 1),
  PlazaCopy? copy,
}) {
  bool closed(PlazaProjectSummary summary) =>
      switch (summary.project.data.status) {
        ProjectCompleted() || ProjectArchived() => true,
        _ => false,
      };
  final projects =
      {
        for (final summary in data.projects)
          if (summary.project.meta.categoryId == data.category.id &&
              summary.project.meta.deletedAt == null)
            summary.project.meta.id: summary,
      }.values.toList()..sort((a, b) {
        // Home is at the street frontier: completed avenues go at the far end.
        final byCompletion = (closed(b) ? 1 : 0).compareTo(closed(a) ? 1 : 0);
        if (byCompletion != 0) return byCompletion;
        final byDate = a.project.meta.createdAt.compareTo(
          b.project.meta.createdAt,
        );
        return byDate != 0
            ? byDate
            : a.project.meta.id.compareTo(b.project.meta.id);
      });
  final color = colorFromCssHex(data.category.color).toARGB32();
  final portals = <PlazaTask>[];
  for (final summary in projects) {
    final project = summary.project;
    final tasks = summary.tasks.where((task) => !task.deleted).toList();
    final attention = attentionForAll(tasks, now);
    final done = tasks
        .where((task) => task.state == PlazaTaskState.done)
        .length;
    final status = switch (project.data.status) {
      ProjectOpen() => PlazaProjectState.open,
      ProjectActive() => PlazaProjectState.active,
      ProjectMonitoring() => PlazaProjectState.monitoring,
      ProjectOnHold() => PlazaProjectState.onHold,
      ProjectCompleted() => PlazaProjectState.completed,
      ProjectArchived() => PlazaProjectState.archived,
    };
    final active = tasks.where(
      (task) =>
          task.state != PlazaTaskState.done &&
          task.state != PlazaTaskState.cancelled,
    );
    var priority = 3;
    var updated = project.meta.updatedAt;
    for (final task in active) {
      if (task.priority < priority) priority = task.priority;
      if (task.activityAt.isAfter(updated)) updated = task.activityAt;
    }
    portals.add(
      PlazaTask(
        id: project.meta.id,
        createdAt: project.meta.createdAt,
        title: project.data.title,
        state: switch (status) {
          PlazaProjectState.completed ||
          PlazaProjectState.archived => PlazaTaskState.done,
          PlazaProjectState.onHold => PlazaTaskState.blocked,
          PlazaProjectState.active => PlazaTaskState.inProgress,
          _ => PlazaTaskState.open,
        },
        due: project.data.targetDate,
        lastActivityAt: updated,
        progress: tasks.isEmpty ? 0 : done / tasks.length,
        checklistItems: 0,
        linkedTaskIds: const [],
        categoryColor: color,
        priority: closed(summary) ? 3 : priority,
        project: PlazaProjectInfo(
          state: status,
          taskCount: tasks.length,
          doneCount: done,
          attentionCount: attention.where((a) => a.anomalous).length,
          overdueCount: attention.where((a) => a.overdue).length,
        ),
      ),
    );
  }
  return PlazaWorld(
    tasks: List.unmodifiable(portals),
    now: now,
    projectLabel: data.category.name,
    layout: config.layoutFor(data.category.id),
    ambientCreatures: config.ambientCreatures,
    categoryLabels: {color.toRadixString(16): data.category.name},
    avenueLabels: {for (final (i, portal) in portals.indexed) i: portal.title},
    avenueByProjectId: {
      for (final (i, portal) in portals.indexed) portal.id: i,
    },
    copy: copy,
  );
}
