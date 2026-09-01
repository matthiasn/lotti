import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_tutorial_content.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';

void main() {
  group('DemoTutorialContent.build', () {
    test('builds the open, medium-priority first mission with five unchecked '
        'starter steps', () {
      final content = DemoTutorialContent.build();

      expect(content.task.meta.id, demoTutorialTaskId);
      expect(content.task.data.title, 'Your first mission');
      expect(content.task.data.status, isA<TaskOpen>());
      expect(content.task.data.priority, TaskPriority.p2Medium);
      expect(content.task.meta.categoryId, manualDemoCategoryId);
      expect(content.task.data.coverArtId, content.image.meta.id);

      expect(content.checklist.meta.id, demoTutorialChecklistId);
      expect(content.checklist.data.title, 'Learn the ropes');
      expect(content.checklistItems, hasLength(5));
      expect(
        content.checklistItems.map((item) => item.data.title),
        const [
          'Check this item off',
          'Start the timer on this task',
          'Add your own checklist item',
          'Create a brand-new task',
          'Record a voice note',
        ],
      );
      for (final item in content.checklistItems) {
        expect(item.data.isChecked, isFalse);
        expect(item.data.checkedAt, isNull);
      }
    });

    test('task, checklist, and items are fully cross-wired', () {
      final content = DemoTutorialContent.build();

      expect(
        content.task.data.checklistIds,
        [demoTutorialChecklistId],
      );
      expect(
        content.checklist.data.linkedTasks,
        [demoTutorialTaskId],
      );
      expect(
        content.checklist.data.linkedChecklistItems,
        [for (final item in content.checklistItems) item.meta.id],
      );
      for (final item in content.checklistItems) {
        expect(item.data.linkedChecklists, [demoTutorialChecklistId]);
      }
      expect(content.images, hasLength(3));
      for (final image in content.images) {
        final asset = demoMediaAssets.singleWhere(
          (asset) => asset.id == image.meta.id,
        );
        expect(image.data.thumbHash, asset.thumbHash, reason: asset.fileName);
        expect(image.data.thumbHash, isNotNull, reason: asset.fileName);
      }
      expect(content.links, hasLength(content.images.length));
      expect(
        content.links.map((link) => link.fromId),
        everyElement(demoTutorialTaskId),
      );
      expect(
        content.links.map((link) => link.toId).toSet(),
        content.images.map((image) => image.meta.id).toSet(),
      );
      // Seed-write order: image and items first, then checklist and task.
      expect(
        content.journalEntities.map((entity) => entity.meta.id).toList(),
        [
          for (final image in content.images) image.meta.id,
          for (final item in content.checklistItems) item.meta.id,
          demoTutorialChecklistId,
          demoTutorialTaskId,
        ],
      );
    });

    test(
      'translates through DemoSeedText and rebases onto the given clock',
      () {
        final now = DateTime(2026, 9, 9, 8);
        final content = DemoTutorialContent.build(
          translate: demoSeedTextForLocale(const Locale('de')),
          now: now,
        );

        expect(content.task.data.title, 'Deine erste Mission');
        expect(content.checklist.data.title, 'Lerne die Grundlagen');
        expect(
          content.checklistItems.first.data.title,
          'Hake diesen Punkt ab',
        );
        expect(content.task.meta.createdAt, now);
        expect(content.task.meta.dateFrom, now);
        expect(content.task.data.status.createdAt, now);
      },
    );

    test('is not part of the penguin logistics fixture', () {
      final world = ManualDemoWorld.penguinLogistics();
      expect(world.entityById(demoTutorialTaskId), isNull);
      expect(world.entityById(demoTutorialChecklistId), isNull);
    });
  });
}
