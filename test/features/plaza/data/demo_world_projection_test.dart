import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/plaza/data/demo_world_projection.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';

void main() {
  // The demo world is deterministic under a fixed clock, so project once.
  final tasks = plazaTasksFromDemoWorld(now: DateTime(2026, 7, 17, 10, 30));

  group('plazaTasksFromDemoWorld', () {
    test('projects every penguin task with a unique id and a title', () {
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.id).toSet(), hasLength(tasks.length));
      for (final task in tasks) {
        expect(task.title.trim(), isNotEmpty);
      }
    });

    test('maps a realistic mix of states', () {
      final states = tasks.map((t) => t.state).toSet();
      expect(states, contains(PlazaTaskState.done));
      expect(states, contains(PlazaTaskState.inProgress));
      expect(states.length, greaterThanOrEqualTo(3));
    });

    test('checklist progress matches the open-item projection', () {
      var withItems = 0;
      for (final task in tasks) {
        expect(task.progress, inInclusiveRange(0, 1));
        if (task.checklistItems == 0) {
          expect(task.openChecklistItems, isEmpty);
          continue;
        }
        withItems++;
        expect(task.openChecklistItems.length, lessThanOrEqualTo(8));
        if (task.checklistItems <= 8) {
          // Below the display cap, open items and progress must agree.
          final open =
              task.checklistItems -
              (task.progress * task.checklistItems).round();
          expect(task.openChecklistItems, hasLength(open));
        }
        for (final item in task.openChecklistItems) {
          expect(item.trim(), isNotEmpty);
        }
      }
      expect(withItems, greaterThan(0));
    });

    test('links reference only other projected tasks, sorted', () {
      final ids = tasks.map((t) => t.id).toSet();
      var linked = 0;
      for (final task in tasks) {
        if (task.linkedTaskIds.isEmpty) continue;
        linked++;
        expect(
          task.linkedTaskIds,
          containsAllInOrder(
            [...task.linkedTaskIds]..sort(),
          ),
        );
        for (final target in task.linkedTaskIds) {
          expect(ids, contains(target));
        }
      }
      expect(linked, greaterThan(0));
    });

    test('carries priority and last activity for the attention score', () {
      expect(tasks.map((t) => t.priority).toSet().length, greaterThan(1));
      for (final task in tasks) {
        expect(task.priority, inInclusiveRange(0, 3));
        expect(task.lastActivityAt, isNotNull);
      }
    });

    test('category labels are keyed by the colour the tasks carry', () {
      final labels = demoCategoryLabels(now: DateTime(2026, 7, 17, 10, 30));
      expect(labels, isNotEmpty);
      for (final task in tasks) {
        expect(labels[task.categoryColor.toRadixString(16)], isNotNull);
      }
    });

    test('cover art resolves to the public immutable R2 catalog', () {
      final covered = tasks.where((t) => t.coverImageUrl != null).toList();
      expect(covered, isNotEmpty);
      for (final task in covered) {
        expect(task.coverImageUrl, startsWith(demoMediaPublicBaseUrl));
      }
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

    test('projection is reproducible under the fixed clock', () {
      final again = plazaTasksFromDemoWorld(now: DateTime(2026, 7, 17, 10, 30));
      expect(again.length, tasks.length);
      for (var i = 0; i < tasks.length; i++) {
        expect(again[i].id, tasks[i].id);
        expect(again[i].createdAt, tasks[i].createdAt);
        expect(again[i].state, tasks[i].state);
        expect(again[i].progress, tasks[i].progress);
      }
    });
  });
}
