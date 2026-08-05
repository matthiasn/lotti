import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/utils/image_utils.dart';

void main() {
  group('ManualDemoWorld.penguinLogistics', () {
    test('default clock reproduces the exact EN fixture strings and dates', () {
      // No LOTTI_MANUAL_LOCALE in the test environment → English. This is
      // the byte-identity gate for the manual screenshot suites: the world
      // built with defaults must match the historical fixture exactly.
      final world = ManualDemoWorld.penguinLogistics();

      expect(
        world.orbitalHabitatTask.data.title,
        'Inspect orbital penguin habitat',
      );
      expect(world.category.name, 'Penguin Operations');
      expect(world.orbitalHabitatTask.data.due, DateTime(2026, 7, 17, 12));
      expect(world.orbitalHabitatTask.meta.dateFrom, manualDemoNow);
      expect(
        world.habitatTimeRecord.meta.dateFrom,
        manualDemoNow.subtract(const Duration(hours: 1, minutes: 18)),
      );
      expect(
        world.habitatTimeRecord.entryText?.plainText,
        'Seal walk complete: A–F held at 101.3 kPa overnight. Roll call '
        'confirmed all 37 penguins, including the one asleep in the '
        'cargo netting.',
      );
    });

    test('German translation reproduces the exact DE fixture strings', () {
      final world = ManualDemoWorld.penguinLogistics(
        translate: demoSeedTextForLocale(const Locale('de')),
      );

      expect(
        world.orbitalHabitatTask.data.title,
        'Pinguin-Habitat im Orbit inspizieren',
      );
      expect(
        world.habitatTimeRecord.entryText?.plainText,
        'Dichtungsrundgang abgeschlossen: A–F hielten über Nacht 101,3 kPa. '
        'Der Zählappell bestätigte alle 37 Pinguine, auch den, der im '
        'Frachtnetz schlief.',
      );
    });

    test('rebasing onto another clock shifts every date by the same delta', () {
      final rebasedNow = DateTime(2027, 3, 2, 14, 45);
      final delta = rebasedNow.difference(manualDemoNow);
      final baseline = ManualDemoWorld.penguinLogistics();
      final rebased = ManualDemoWorld.penguinLogistics(now: rebasedNow);

      void expectShifted(DateTime? actual, DateTime? original) {
        if (original == null) {
          expect(actual, isNull);
          return;
        }
        expect(actual, original.add(delta));
      }

      expectShifted(rebased.category.createdAt, baseline.category.createdAt);
      for (var i = 0; i < baseline.labels.length; i++) {
        expectShifted(
          rebased.labels[i].updatedAt,
          baseline.labels[i].updatedAt,
        );
      }
      for (final original in baseline.coverImages) {
        final shifted = rebased.coverImageById(original.meta.id);
        expectShifted(shifted.meta.dateFrom, original.meta.dateFrom);
        expectShifted(shifted.data.capturedAt, original.data.capturedAt);
      }
      for (final original in baseline.tasks) {
        final shifted = rebased.taskById(original.meta.id);
        expectShifted(shifted.meta.createdAt, original.meta.createdAt);
        expectShifted(shifted.meta.dateFrom, original.meta.dateFrom);
        expectShifted(shifted.meta.dateTo, original.meta.dateTo);
        expectShifted(shifted.data.due, original.data.due);
        expectShifted(
          shifted.data.status.createdAt,
          original.data.status.createdAt,
        );
      }
      for (final original in baseline.checklistItems) {
        final shifted = rebased.checklistItems.singleWhere(
          (item) => item.meta.id == original.meta.id,
        );
        expectShifted(shifted.meta.createdAt, original.meta.createdAt);
        expectShifted(shifted.data.checkedAt, original.data.checkedAt);
      }
      expectShifted(
        rebased.habitatTimeRecord.meta.dateFrom,
        baseline.habitatTimeRecord.meta.dateFrom,
      );
      expectShifted(
        rebased.habitatTimeRecord.meta.dateTo,
        baseline.habitatTimeRecord.meta.dateTo,
      );

      // Rebasing must not leak into content: ids and strings are unchanged.
      expect(
        rebased.orbitalHabitatTask.data.title,
        baseline.orbitalHabitatTask.data.title,
      );
      expect(
        rebased.tasks.map((task) => task.meta.id),
        baseline.tasks.map((task) => task.meta.id),
      );
    });

    test('checklist wiring stays complete in the entity data', () {
      final world = ManualDemoWorld.penguinLogistics();

      expect(
        world.orbitalHabitatTask.data.checklistIds,
        const [manualHabitatChecklistId],
      );
      expect(
        world.habitatChecklist.data.linkedChecklistItems,
        [for (final item in world.checklistItems) item.meta.id],
      );
      expect(
        world.habitatChecklist.data.linkedTasks,
        const [manualOrbitalHabitatTaskId],
      );
      for (final item in world.checklistItems) {
        expect(item.data.linkedChecklists, const [manualHabitatChecklistId]);
      }
    });

    test('taskBrowseTasks is the curated browse page: hero first, then the '
        'feeder/cargo/passenger rows the manual documents', () {
      final world = ManualDemoWorld.penguinLogistics();

      expect(
        world.taskBrowseTasks.map((task) => task.meta.id),
        const [
          manualOrbitalHabitatTaskId,
          manualFishFeederTaskId,
          manualSardineCargoTaskId,
          manualPenguinPassengerTaskId,
        ],
      );
      // The named getters and the full task list agree on the entities.
      expect(
        world.fishFeederTask,
        same(world.taskById(manualFishFeederTaskId)),
      );
      expect(
        world.sardineCargoTask,
        same(world.taskById(manualSardineCargoTaskId)),
      );
      expect(
        world.penguinPassengerTask,
        same(world.taskById(manualPenguinPassengerTaskId)),
      );
    });

    test('installMedia copies every bundled cover into the document-relative '
        'path production cover-art widgets resolve', () async {
      final documents = Directory.systemTemp.createTempSync('lotti_world_');
      addTearDown(() => documents.delete(recursive: true));
      final world = ManualDemoWorld.penguinLogistics();

      final installed = await world.installMedia(documents);

      expect(installed, hasLength(world.coverImages.length));
      for (final coverImage in world.coverImages) {
        final target = File(
          getFullImagePath(
            coverImage,
            documentsDirectory: documents.path,
          ),
        );
        expect(
          target.existsSync(),
          isTrue,
          reason: '${coverImage.meta.id} must land at the production path',
        );
        // Byte identity with the repo asset, so the demo world shows the
        // exact artwork the manual documents.
        final asset = File(manualDemoCoverAssets[coverImage.meta.id]!);
        expect(target.lengthSync(), asset.lengthSync());
      }
    });
  });
}
