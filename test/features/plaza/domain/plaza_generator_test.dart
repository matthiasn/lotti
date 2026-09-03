import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/plaza_generator.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';

void main() {
  group('generatePlazaTasks', () {
    test('presets produce their advertised task counts', () {
      expect(generatePlazaTasks(preset: PlazaPreset.small), hasLength(20));
      expect(generatePlazaTasks(preset: PlazaPreset.medium), hasLength(80));
      expect(generatePlazaTasks(preset: PlazaPreset.large), hasLength(300));
    });

    test('same seed reproduces the identical dataset', () {
      final a = generatePlazaTasks(preset: PlazaPreset.medium, seed: 7);
      final b = generatePlazaTasks(preset: PlazaPreset.medium, seed: 7);
      for (var i = 0; i < a.length; i++) {
        expect(b[i].id, a[i].id);
        expect(b[i].title, a[i].title);
        expect(b[i].state, a[i].state);
        expect(b[i].createdAt, a[i].createdAt);
        expect(b[i].progress, a[i].progress);
        expect(b[i].linkedTaskIds, a[i].linkedTaskIds);
        expect(b[i].openChecklistItems, a[i].openChecklistItems);
      }
    });

    test('different seeds produce different datasets', () {
      final a = generatePlazaTasks(preset: PlazaPreset.small, seed: 1);
      final b = generatePlazaTasks(preset: PlazaPreset.small, seed: 2);
      expect(
        a.map((t) => t.title).join(),
        isNot(b.map((t) => t.title).join()),
      );
    });

    test('creation times are strictly increasing (placement input)', () {
      final tasks = generatePlazaTasks(preset: PlazaPreset.large);
      for (var i = 1; i < tasks.length; i++) {
        expect(tasks[i].createdAt.isAfter(tasks[i - 1].createdAt), isTrue);
      }
    });

    test('the large preset exercises every state and some deletions', () {
      final tasks = generatePlazaTasks(preset: PlazaPreset.large);
      final states = tasks.map((t) => t.state).toSet();
      expect(states, containsAll(PlazaTaskState.values));
      expect(tasks.any((t) => t.deleted), isTrue);
      expect(tasks.any((t) => t.linkedTaskIds.isNotEmpty), isTrue);
    });

    test('checklist bookkeeping is internally consistent', () {
      for (final task in generatePlazaTasks(preset: PlazaPreset.large)) {
        expect(task.progress, inInclusiveRange(0, 1));
        if (task.checklistItems == 0) {
          expect(task.progress, 0);
          expect(task.openChecklistItems, isEmpty);
        } else {
          if (task.state == PlazaTaskState.done) {
            expect(task.progress, 1);
          }
          final open =
              task.checklistItems -
              (task.progress * task.checklistItems).round();
          expect(task.openChecklistItems, hasLength(open));
        }
      }
    });

    test('links point at tasks that exist in the same dataset', () {
      final tasks = generatePlazaTasks(preset: PlazaPreset.large);
      final ids = tasks.map((t) => t.id).toSet();
      for (final task in tasks) {
        for (final target in task.linkedTaskIds) {
          expect(ids, contains(target));
          expect(target, isNot(task.id));
        }
      }
    });
  });
}
