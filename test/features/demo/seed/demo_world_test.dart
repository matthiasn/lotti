import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/utils/uuid.dart';
import 'package:path/path.dart' as p;

/// The nine tasks the manual quotes by name and the screenshot suites resolve
/// by id — frozen in content, order and position. Growth is appended after
/// them; nothing here may be renamed, removed or reordered.
final originalTaskIds = <String>[
  manualRollCallTaskId,
  manualOrbitalHabitatTaskId,
  manualLaunchReviewTaskId,
  manualLunchTaskId,
  manualSardineFuturesTaskId,
  manualFishFeederTaskId,
  manualSardineCargoTaskId,
  manualPenguinPassengerTaskId,
  manualHeadsetWalkTaskId,
];

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

    test(
      'the original nine keep their ids, order and position in the list',
      () {
        // Eight manual pages quote these task names as literal text and the
        // screenshot suites resolve them by id, so growth is append-only.
        final world = ManualDemoWorld.penguinLogistics();

        expect(
          world.tasks.take(9).map((task) => task.meta.id),
          originalTaskIds,
          reason: 'the original nine must stay first, and in this order',
        );
        expect(
          world.labels.take(2).map((label) => label.id),
          const [manualDemoProjectLabelId, manualDemoCriticalLabelId],
        );
        expect(world.categories.first, same(world.category));
        expect(world.coverImages, hasLength(9));
      },
    );

    test(
      'rebasing shifts the original fixture timestamps by the same delta',
      () {
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
        // Only the original nine: expansion content is authored against
        // whole-day helpers, which deliberately do NOT track a partial-day
        // delta (see the semantic-due-date test below).
        for (final id in originalTaskIds) {
          final original = baseline.taskById(id);
          final shifted = rebased.taskById(id);
          expectShifted(shifted.meta.createdAt, original.meta.createdAt);
          expectShifted(shifted.meta.dateFrom, original.meta.dateFrom);
          expectShifted(shifted.meta.dateTo, original.meta.dateTo);
          expectShifted(
            shifted.data.status.createdAt,
            original.data.status.createdAt,
          );
        }
        for (final original in baseline.checklistItems.take(4)) {
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
      },
    );

    test('checklist wiring stays complete in the entity data', () {
      final world = ManualDemoWorld.penguinLogistics();

      expect(
        world.orbitalHabitatTask.data.checklistIds,
        [manualHabitatChecklistId],
      );
      expect(
        world.habitatChecklist.data.linkedChecklistItems,
        [for (final item in world.checklistItems.take(4)) item.meta.id],
      );
      expect(
        world.habitatChecklist.data.linkedTasks,
        [manualOrbitalHabitatTaskId],
      );
      for (final item in world.checklistItems.take(4)) {
        expect(item.data.linkedChecklists, [manualHabitatChecklistId]);
      }
    });

    test('every checklist is owned by exactly one task, and both sides of '
        'that wiring agree', () {
      final world = ManualDemoWorld.penguinLogistics();
      final itemsById = {
        for (final item in world.checklistItems) item.meta.id: item,
      };

      expect(world.checklists, hasLength(28));
      expect(world.checklistItems, hasLength(112));

      for (final checklist in world.checklists) {
        final ownerId = checklist.data.linkedTasks.single;
        final owner = world.taskById(ownerId);
        expect(
          owner.data.checklistIds,
          contains(checklist.meta.id),
          reason: '${checklist.meta.id} is not listed on its owning task',
        );
        expect(
          checklist.data.linkedChecklistItems,
          hasLength(4),
          reason: 'every task runbook has four actionable steps',
        );
        for (final itemId in checklist.data.linkedChecklistItems) {
          final item = itemsById[itemId];
          expect(item, isNotNull, reason: '$itemId is referenced but missing');
          expect(item!.data.linkedChecklists, [checklist.meta.id]);
          expect(item.meta.categoryId, checklist.meta.categoryId);
        }
      }
      // Every item belongs to a checklist — no orphans in the seeded set.
      final claimed = {
        for (final checklist in world.checklists)
          ...checklist.data.linkedChecklistItems,
      };
      expect(itemsById.keys.toSet(), claimed);
      expect(
        world.tasks.every((task) => task.data.checklistIds?.length == 1),
        isTrue,
        reason: 'every seeded task must open with one interactive runbook',
      );
    });

    test('every seeded journal entity carries a real UUID, so the detail '
        'routes can open it', () {
      // Regression guard. The world used to be seeded with readable slug
      // ids ('task-air-scrubbers'), but `TasksLocation`/`JournalLocation`
      // gate their detail page on `isUuid`: on desktop the detail pane was
      // cleared, on mobile no page was pushed, so tapping a demo task or
      // note did nothing at all — no error, no visual change.
      final world = ManualDemoWorld.penguinLogistics();

      for (final entity in world.journalEntities) {
        expect(
          isUuid(entity.meta.id),
          isTrue,
          reason: '${entity.meta.id} is not a UUID, so no route can open it',
        );
      }
      // Ids stay unique once derived — a collision would silently merge two
      // entities on write.
      expect(
        world.journalEntities.map((entity) => entity.meta.id).toSet(),
        hasLength(world.journalEntities.length),
      );
      for (final link in world.links) {
        expect(isUuid(link.id), isTrue, reason: '${link.id} is not a UUID');
      }
      // The nested checklist-item id must agree with the entity id, since
      // `ChecklistItemData.id` is what the checklist UI resolves.
      for (final item in world.checklistItems) {
        expect(item.data.id, item.meta.id);
      }
    });

    test('the link graph is referentially sound: no dangling endpoints, no '
        'duplicate ids, no self-links', () {
      final world = ManualDemoWorld.penguinLogistics();
      final knownIds = {
        for (final entity in world.journalEntities) entity.meta.id,
      };

      expect(
        world.links.length,
        greaterThanOrEqualTo(110),
        reason: 'the graph explorer needs a web, not a handful of edges',
      );
      expect(
        world.links.map((link) => link.id).toSet(),
        hasLength(world.links.length),
        reason: 'duplicate link ids would collide on write',
      );
      for (final link in world.links) {
        expect(link.fromId, isNot(link.toId));
        expect(
          knownIds,
          containsAll([link.fromId, link.toId]),
          reason: '${link.id} points at an entity the world does not seed',
        );
      }
      // Undirected duplicates would draw the same edge twice in the graph.
      final undirected = {
        for (final link in world.links)
          ([link.fromId, link.toId]..sort()).join('|'),
      };
      expect(undirected, hasLength(world.links.length));
    });

    test('every task has neighbours, the four hubs have many, and the whole '
        'task web is within three hops of the hero task', () {
      final world = ManualDemoWorld.penguinLogistics();
      final taskIds = world.tasks.map((task) => task.meta.id).toSet();

      final neighbours = <String, Set<String>>{
        for (final id in taskIds) id: <String>{},
      };
      final taskNeighbours = <String, Set<String>>{
        for (final id in taskIds) id: <String>{},
      };
      for (final link in world.links) {
        for (final (from, to) in [
          (link.fromId, link.toId),
          (link.toId, link.fromId),
        ]) {
          if (!taskIds.contains(from)) continue;
          neighbours[from]!.add(to);
          if (taskIds.contains(to)) taskNeighbours[from]!.add(to);
        }
      }

      expect(world.tasks, hasLength(28));
      neighbours.forEach((id, linked) {
        expect(
          linked.length,
          greaterThanOrEqualTo(2),
          reason: '$id is a dead end in the graph',
        );
      });
      for (final hub in [
        manualOrbitalHabitatTaskId,
        manualLaunchReviewTaskId,
        manualSardineCargoTaskId,
        manualRollCallTaskId,
      ]) {
        expect(
          neighbours[hub]!.length,
          greaterThanOrEqualTo(6),
          reason: '$hub is meant to be a hub',
        );
      }

      // Breadth-first over task↔task links from the hero task: the graph
      // page walks two hops from wherever it is opened, so nothing may sit
      // in an unreachable pocket.
      var frontier = <String>{manualOrbitalHabitatTaskId};
      final seen = <String>{...frontier};
      for (var hop = 0; hop < 3; hop++) {
        frontier = {
          for (final id in frontier) ...taskNeighbours[id]!,
        }..removeWhere(seen.contains);
        seen.addAll(frontier);
      }
      expect(
        taskIds.difference(seen),
        isEmpty,
        reason: 'these tasks are more than three hops from the hero task',
      );
    });

    test('every task owns a distinct cover that is also linked as a photo', () {
      final world = ManualDemoWorld.penguinLogistics();
      final imagesById = {
        for (final image in world.images) image.meta.id: image,
      };
      final linkedPairs = {
        for (final link in world.links) (link.fromId, link.toId),
      };

      expect(world.images, hasLength(88));
      final catalogById = {
        for (final asset in demoMediaAssets) asset.id: asset,
      };
      for (final image in world.images) {
        // The stand-in travels with the entity: the widgets never see the
        // catalog.
        expect(
          image.data.thumbHash,
          catalogById[image.meta.id]!.thumbHash,
          reason: image.data.imageFile,
        );
        expect(image.data.thumbHash, isNotNull, reason: image.data.imageFile);
      }
      expect(
        world.tasks.map((task) => task.data.coverArtId).toSet(),
        hasLength(world.tasks.length),
      );
      for (final task in world.tasks) {
        final coverId = task.data.coverArtId;
        expect(coverId, isNotNull, reason: '${task.data.title} has no cover');
        expect(imagesById, contains(coverId));
        expect(
          linkedPairs,
          contains((task.meta.id, coverId)),
          reason: '${task.data.title} does not expose its cover as a photo',
        );
        final attachedImages = world.images.where(
          (image) => linkedPairs.contains((task.meta.id, image.meta.id)),
        );
        expect(
          attachedImages.length,
          greaterThanOrEqualTo(3),
          reason: '${task.data.title} needs a cover plus two attachments',
        );
      }
    });

    test('every task has non-image activity beyond its task relationships', () {
      final world = ManualDemoWorld.penguinLogistics();
      final taskIds = world.tasks.map((task) => task.meta.id).toSet();
      final imageIds = world.images.map((image) => image.meta.id).toSet();

      for (final task in world.tasks) {
        final activityIds = <String>{...?task.data.checklistIds};
        for (final link in world.links) {
          final otherId = switch ((link.fromId, link.toId)) {
            (final from, final to) when from == task.meta.id => to,
            (final from, final to) when to == task.meta.id => from,
            _ => null,
          };
          if (otherId != null &&
              !taskIds.contains(otherId) &&
              !imageIds.contains(otherId)) {
            activityIds.add(otherId);
          }
        }
        expect(
          activityIds,
          isNotEmpty,
          reason: '${task.data.title} has no note, logged work, or checklist',
        );
      }
    });

    test('due dates are semantic: they follow the injected clock, and the '
        'expansion fills the intended buckets', () {
      // A Monday at 23:40 — the "next Monday" bucket is then a full week
      // out, so it cannot be confused with the "within five days" one, and
      // the late hour is the boundary case the semantic helpers exist for.
      final now = DateTime(2026, 9, 14, 23, 40);
      final world = ManualDemoWorld.penguinLogistics(now: now);
      final today = DateTime(now.year, now.month, now.day);

      // Authored at 23:40: a due-today chip must still say today.
      expect(world.orbitalHabitatTask.data.due, DateTime(2026, 9, 14, 12));
      expect(
        world.taskById(manualSardineCargoTaskId).data.due,
        DateTime(2026, 9, 15, 9),
      );
      expect(
        world.taskById(manualPenguinPassengerTaskId).data.due,
        DateTime(2026, 9, 21, 16),
        reason: 'the legal question is due next Monday, whatever day it is',
      );

      final expansion = world.tasks.skip(9).toList();
      expect(expansion, hasLength(19));

      final dues = [for (final task in expansion) task.data.due];
      int countWhere(bool Function(DateTime due) test) =>
          dues.whereType<DateTime>().where(test).length;

      expect(
        dues.where((due) => due == null),
        hasLength(2),
        reason: 'two groomed backlog tasks carry no due date',
      );
      expect(
        countWhere((due) => due.isBefore(today)),
        2,
        reason: 'exactly two expansion tasks are overdue',
      );
      expect(
        countWhere((due) => due == today.add(const Duration(hours: 17))),
        3,
        reason: 'three land today at 17:00',
      );
      expect(
        countWhere(
          (due) => due == today.add(const Duration(days: 1, hours: 9)),
        ),
        3,
        reason: 'three land tomorrow at 09:00',
      );
      expect(
        countWhere(
          (due) =>
              due.isAfter(today.add(const Duration(days: 1, hours: 23))) &&
              due.isBefore(today.add(const Duration(days: 6))),
        ),
        6,
        reason: 'six spread over the following five days',
      );
      expect(
        countWhere(
          (due) =>
              due.isAfter(today.add(const Duration(days: 6))) &&
              due.weekday >= DateTime.monday &&
              due.weekday <= DateTime.wednesday,
        ),
        3,
        reason: 'three land next week, anchored on the following Monday',
      );
      // Overdue by whole days, never by hours: the chip must not depend on
      // what time the world happened to be seeded.
      for (final due in dues.whereType<DateTime>().where(
        (due) => due.isBefore(today),
      )) {
        expect(
          today.difference(DateTime(due.year, due.month, due.day)).inDays,
          greaterThanOrEqualTo(2),
        );
      }
    });

    test('logged work lands on past weekdays with a real span', () {
      final world = ManualDemoWorld.penguinLogistics(
        now: DateTime(2026, 9, 14, 8),
      );

      expect(world.timeRecords, hasLength(11));
      for (final record in world.timeRecords.skip(1)) {
        final from = record.meta.dateFrom;
        expect(
          from.weekday,
          lessThanOrEqualTo(DateTime.friday),
          reason: '${record.meta.id} was tracked at the weekend',
        );
        expect(from.isBefore(world.orbitalHabitatTask.meta.dateFrom), isTrue);
        expect(
          record.meta.dateTo.isAfter(from),
          isTrue,
          reason: '${record.meta.id} has no duration',
        );
        expect(record.entryText?.plainText, isNotEmpty);
      }
    });

    test('notes are short and spread across the past six weeks', () {
      final now = DateTime(2026, 9, 16, 10);
      final world = ManualDemoWorld.penguinLogistics(now: now);

      expect(world.entries, hasLength(21));
      final ages = <int>[];
      for (final entry in world.entries) {
        final text = entry.entryText!.plainText;
        expect(text, isNotEmpty);
        expect(
          text.length,
          lessThanOrEqualTo(120),
          reason: '${entry.meta.id} is too long for a graph node preview',
        );
        expect(entry.meta.dateFrom.isBefore(now), isTrue);
        ages.add(now.difference(entry.meta.dateFrom).inDays);
      }
      expect(ages.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(2));
      expect(ages.reduce((a, b) => a > b ? a : b), greaterThanOrEqualTo(35));
    });

    test('expansion tasks live in the three categories and use the new '
        'labels', () {
      final world = ManualDemoWorld.penguinLogistics();
      final categoryIds = world.categories.map((c) => c.id).toSet();

      expect(categoryIds, {
        manualDemoCategoryId,
        demoHabitatCategoryId,
        demoLogisticsCategoryId,
      });
      for (final task in world.tasks) {
        expect(
          categoryIds,
          contains(task.meta.categoryId),
          reason: '${task.meta.id} points at an unseeded category',
        );
      }
      // Each new category actually carries work — otherwise the graph's
      // area colouring is decoration.
      for (final id in [demoHabitatCategoryId, demoLogisticsCategoryId]) {
        expect(
          world.tasks.where((task) => task.meta.categoryId == id),
          hasLength(5),
        );
      }

      final labelIds = world.labels.map((label) => label.id).toSet();
      final usedLabels = {
        for (final task in world.tasks) ...?task.meta.labelIds,
      };
      expect(labelIds, containsAll(usedLabels));
      expect(
        usedLabels,
        containsAll([
          demoBlockedLabelId,
          demoWaitingLabelId,
          demoResearchLabelId,
        ]),
      );
    });

    test('taskBrowseTasks is the curated browse page: hero first, then the '
        'feeder/cargo/passenger rows the manual documents', () {
      final world = ManualDemoWorld.penguinLogistics();

      expect(
        world.taskBrowseTasks.map((task) => task.meta.id),
        [
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

    test('habits carry a lived-in completion history that stops before '
        'today, and the retired habit carries none', () {
      final now = DateTime(2026, 9, 14, 8);
      final world = ManualDemoWorld.penguinLogistics(now: now);

      expect(
        world.habits.map((habit) => habit.id),
        [
          manualRollCallHabitId,
          manualHabitatSealsHabitId,
          manualSardineForecastHabitId,
          demoColdChainTelemetryHabitId,
          demoOutboundManifestHabitId,
          demoShiftHandoffHabitId,
          demoFlipperMobilityHabitId,
        ],
      );

      final retired = world.habits.singleWhere(
        (habit) => habit.id == manualSardineForecastHabitId,
      );
      expect(
        retired.active,
        isFalse,
        reason: 'the habits page needs an inactive row to render',
      );

      final byHabit = <String, List<HabitCompletionEntry>>{};
      for (final completion in world.habitCompletions) {
        byHabit.putIfAbsent(completion.data.habitId, () => []).add(completion);
      }
      expect(
        byHabit.keys.toSet(),
        {
          manualRollCallHabitId,
          manualHabitatSealsHabitId,
          demoColdChainTelemetryHabitId,
          demoOutboundManifestHabitId,
          demoShiftHandoffHabitId,
          demoFlipperMobilityHabitId,
        },
        reason: 'a retired habit must not accrue completions',
      );

      final midnight = DateTime(now.year, now.month, now.day);
      for (final completion in world.habitCompletions) {
        expect(
          completion.data.dateFrom.isBefore(midnight),
          isTrue,
          reason:
              '${completion.meta.id} lands on or after today — the demo '
              'must open with something left to tick off',
        );
        expect(
          midnight.difference(completion.data.dateFrom).inDays,
          lessThanOrEqualTo(28),
          reason: 'history beyond the seeded window is unreachable',
        );
        expect(isUuid(completion.meta.id), isTrue);
      }

      // Every habit is active well before its own history starts, so no
      // streak begins on the day the habit appeared.
      for (final habit in world.habits.where((h) => h.activeFrom != null)) {
        final earliest = byHabit[habit.id]
            ?.map((c) => c.data.dateFrom)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        if (earliest == null) continue;
        expect(habit.activeFrom!.isBefore(earliest), isTrue);
      }

      // Not a perfect record: the page has to show a skip and a failure.
      final types = world.habitCompletions
          .map((completion) => completion.data.completionType)
          .toSet();
      expect(types, contains(HabitCompletionType.success));
      expect(types, contains(HabitCompletionType.skip));
      expect(types, contains(HabitCompletionType.fail));
    });

    test(
      'installMedia hydrates catalog bytes into the production path',
      () async {
        final documents = Directory.systemTemp.createTempSync('lotti_world_');
        addTearDown(() => documents.delete(recursive: true));
        final world = ManualDemoWorld.penguinLogistics();
        final bytes = Uint8List.fromList([12, 34, 56, 78]);
        final asset = DemoMediaAsset(
          id: 'test-image-id',
          fileName: 'manual-test.webp',
          sha256: sha256.convert(bytes).toString(),
          taskId: 'test-task-id',
          categoryId: 'test-category-id',
          capturedDaysAgo: 0,
          capturedHour: 10,
          isCover: true,
        );

        final installed = await world.installMedia(
          documents,
          catalog: [asset],
          download: (uri) async {
            expect(uri, asset.uri);
            return bytes;
          },
        );

        expect(installed, hasLength(1));
        expect(await installed.single.readAsBytes(), bytes);
        expect(
          installed.single.path,
          endsWith(asset.relativePath.replaceAll('/', Platform.pathSeparator)),
        );
      },
    );

    test('installMedia fails when a manual cover cannot be verified', () async {
      final documents = Directory.systemTemp.createTempSync('lotti_world_');
      addTearDown(() => documents.delete(recursive: true));
      final world = ManualDemoWorld.penguinLogistics();
      final asset = DemoMediaAsset(
        id: 'bad-image-id',
        fileName: 'bad-manual-test.webp',
        sha256: sha256.convert([1, 2, 3]).toString(),
        taskId: 'test-task-id',
        categoryId: 'test-category-id',
        capturedDaysAgo: 0,
        capturedHour: 10,
        isCover: true,
      );

      await expectLater(
        world.installMedia(
          documents,
          catalog: [asset],
          download: (uri) async => Uint8List.fromList([9, 9, 9]),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            // The count and the first cause are what make a device-suite
            // failure diagnosable from its log alone.
            allOf(
              contains('Unable to hydrate every manual demo cover'),
              contains('1 failed, 0 cancelled'),
              contains('bad-manual-test.webp'),
              contains('Checksum mismatch'),
            ),
          ),
        ),
      );
      expect(
        File(
          p.joinAll([
            documents.path,
            ...asset.relativePath.split('/'),
          ]),
        ).existsSync(),
        isFalse,
      );
    });
  });
}
