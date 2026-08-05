import 'dart:io';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Media directory (relative, in `ImageData.imageDirectory` notation) that
/// copied demo media lands in under the real root.
const String demoImportMediaDirectory = '/demo_import/';

/// One media file staged for the crossing: bytes already copied out of the
/// demo world, waiting to be moved under the real root before the entity
/// that references them is inserted.
class DemoStagedMedia {
  const DemoStagedMedia({
    required this.stagedFile,
    required this.relativeTarget,
  });

  /// The staged copy in the temp staging directory.
  final File stagedFile;

  /// Target path relative to the real root, in the same leading-slash
  /// notation `getFullImagePath`/`AudioUtils` concatenate with
  /// (e.g. `/demo_import/<newId>.jpg`).
  final String relativeTarget;
}

/// An in-memory, fully remapped copy of the selected demo work — everything
/// [DemoDataCopier.apply] needs AFTER the app has switched back to the real
/// world, at which point the demo databases are closed.
class DemoCopyPlan {
  const DemoCopyPlan({
    required this.entities,
    required this.links,
    required this.definitions,
    required this.media,
  });

  /// Remapped entities in insertion order (checklist items → checklists →
  /// other entries → tasks).
  final List<JournalEntity> entities;

  /// Closure-internal links, both ends already remapped.
  final List<({String fromId, String toId})> links;

  /// Category/label definitions referenced by [entities], carried with their
  /// ORIGINAL ids (upserted idempotently into the real world).
  final List<EntityDefinition> definitions;

  final List<DemoStagedMedia> media;

  bool get isEmpty => entities.isEmpty;
}

/// Copies demo-created work into the real world across the profile switch.
///
/// [prepare] runs while the DEMO generation is active (its databases open)
/// and produces a self-contained [DemoCopyPlan]; [apply] runs after the
/// switch, in the REAL generation, and writes through [PersistenceLogic] so
/// every copy gets a fresh real-world vector clock and is enqueued for sync
/// via the production code path. Copies keep their original
/// dateFrom/dateTo/createdAt; `updatedAt` and the vector clock are stamped
/// at apply time by `PersistenceLogic.updateMetadata`.
class DemoDataCopier {
  DemoDataCopier({String Function()? newId})
    : _newId = newId ?? const Uuid().v4;

  final String Function() _newId;

  /// Builds the copy plan from the demo world.
  ///
  /// Closure: BFS from [selectedIds] over outbound entry links plus the
  /// checklist wiring (`TaskData.checklistIds`,
  /// `ChecklistData.linkedChecklistItems`), restricted to demo-CREATED ids —
  /// anything listed in the seed manifest is cut off (a selected task's own
  /// checklist tree is demo-created by construction, so it always travels).
  /// Deleted entities are skipped.
  Future<DemoCopyPlan> prepare({
    required Set<String> selectedIds,
    required JournalDb sourceDb,
    required Directory sourceRoot,
    Directory? stagingDir,
  }) async {
    DemoSeedManifest? manifest;
    try {
      manifest = await DemoSeedManifest.read(sourceRoot);
    } catch (_) {
      manifest = null;
    }
    final seeded = {...?manifest?.seededJournalIds};

    // --- Closure -----------------------------------------------------------
    final closure = <String, JournalEntity>{};
    var frontier = selectedIds.difference(seeded);
    while (frontier.isNotEmpty) {
      final fetched = await sourceDb.journalEntityMapForIdsIncludingDeleted(
        frontier,
      );
      final added = <String>{};
      final next = <String>{};
      for (final entity in fetched.values) {
        final id = entity.meta.id;
        if (closure.containsKey(id) ||
            seeded.contains(id) ||
            entity.meta.deletedAt != null) {
          continue;
        }
        closure[id] = entity;
        added.add(id);
        next.addAll(_childIds(entity));
      }
      if (added.isNotEmpty) {
        // Follow outbound links (task → attachment, entry → sub-entry).
        final links = await sourceDb.linksForEntryIdsBidirectional(added);
        for (final link in links) {
          if (link.deletedAt != null) continue;
          if (closure.containsKey(link.fromId)) {
            next.add(link.toId);
          }
        }
      }
      frontier = next.difference(seeded)..removeWhere(closure.containsKey);
    }

    // Closure-internal links, collected in one final pass so links whose
    // fromId joined the closure later than their toId are still caught.
    final allLinks = await sourceDb.linksForEntryIdsBidirectional(
      closure.keys.toSet(),
    );
    final internalLinks = {
      for (final link in allLinks)
        if (link.deletedAt == null &&
            closure.containsKey(link.fromId) &&
            closure.containsKey(link.toId))
          link.id: link,
    };

    // --- Remap + stage -----------------------------------------------------
    final idMap = {for (final id in closure.keys) id: _newId()};
    final staging =
        stagingDir ?? Directory.systemTemp.createTempSync('lotti_demo_copy_');
    final media = <DemoStagedMedia>[];

    Future<JournalEntity> remap(JournalEntity entity) async {
      final newMeta = entity.meta.copyWith(
        id: idMap[entity.meta.id]!,
        vectorClock: null,
      );
      List<String> mapKept(List<String>? ids) => [
        for (final id in ids ?? const <String>[])
          if (idMap.containsKey(id)) idMap[id]!,
      ];
      return entity.maybeMap<Future<JournalEntity>>(
        task: (task) async => task.copyWith(
          meta: newMeta,
          data: task.data.copyWith(
            checklistIds: mapKept(task.data.checklistIds),
          ),
        ),
        checklist: (checklist) async => checklist.copyWith(
          meta: newMeta,
          data: checklist.data.copyWith(
            linkedChecklistItems: mapKept(checklist.data.linkedChecklistItems),
            linkedTasks: mapKept(checklist.data.linkedTasks),
          ),
        ),
        checklistItem: (item) async => item.copyWith(
          meta: newMeta,
          data: item.data.copyWith(
            linkedChecklists: mapKept(item.data.linkedChecklists),
            // The inner data id (when set) mirrors the entity id.
            id: item.data.id == null ? null : newMeta.id,
          ),
        ),
        journalImage: (image) async {
          final fileName = await _stageMedia(
            sourcePath: getFullImagePath(
              image,
              documentsDirectory: sourceRoot.path,
            ),
            originalFileName: image.data.imageFile,
            newId: newMeta.id,
            staging: staging,
            media: media,
          );
          return image.copyWith(
            meta: newMeta,
            data: image.data.copyWith(
              imageDirectory: demoImportMediaDirectory,
              imageFile: fileName,
            ),
          );
        },
        journalAudio: (audio) async {
          final fileName = await _stageMedia(
            sourcePath: AudioUtils.getAudioPath(audio, sourceRoot),
            originalFileName: audio.data.audioFile,
            newId: newMeta.id,
            staging: staging,
            media: media,
          );
          return audio.copyWith(
            meta: newMeta,
            data: audio.data.copyWith(
              audioDirectory: demoImportMediaDirectory,
              audioFile: fileName,
            ),
          );
        },
        orElse: () async => entity.copyWith(meta: newMeta),
      );
    }

    // Insertion order: checklist items → checklists → other entries → tasks.
    int tier(JournalEntity entity) => entity.maybeMap(
      checklistItem: (_) => 0,
      checklist: (_) => 1,
      task: (_) => 3,
      orElse: () => 2,
    );
    final ordered = closure.values.toList()
      ..sort((a, b) {
        final byTier = tier(a).compareTo(tier(b));
        if (byTier != 0) return byTier;
        return a.meta.id.compareTo(b.meta.id);
      });
    final entities = <JournalEntity>[
      for (final entity in ordered) await remap(entity),
    ];

    // --- Referenced definitions (same ids, upserted idempotently) ----------
    final categoryIds = <String>{
      for (final entity in closure.values) ?entity.meta.categoryId,
    };
    final labelIds = <String>{
      for (final entity in closure.values) ...?entity.meta.labelIds,
    };
    final definitions = <EntityDefinition>[
      for (final id in categoryIds) ?await sourceDb.getCategoryById(id),
      for (final id in labelIds) ?await sourceDb.getLabelDefinitionById(id),
    ];

    return DemoCopyPlan(
      entities: entities,
      links: [
        for (final link in internalLinks.values)
          (fromId: idMap[link.fromId]!, toId: idMap[link.toId]!),
      ],
      definitions: definitions,
      media: media,
    );
  }

  /// Applies [plan] in the REAL generation.
  ///
  /// Order matters: media files move into place first (so an image/audio
  /// entity never exists without its bytes), then definitions (so category
  /// and label references resolve), then entities through
  /// `PersistenceLogic.updateMetadata` + `createDbEntity` (fresh vector
  /// clock, preserved dates, sync enqueued), then the closure-internal links
  /// through `createLink`. Definitions keep their demo ids and are only
  /// written when absent, so re-copying never clobbers real-world edits.
  ///
  /// Returns the number of entities written.
  Future<int> apply(
    DemoCopyPlan plan, {
    required PersistenceLogic persistence,
    required JournalDb targetJournalDb,
    required Directory targetRoot,
  }) async {
    for (final staged in plan.media) {
      final target = File('${targetRoot.path}${staged.relativeTarget}');
      await target.parent.create(recursive: true);
      await staged.stagedFile.copy(target.path);
      try {
        await staged.stagedFile.delete();
      } catch (_) {
        // Staging lives in the OS temp dir; a leftover file is harmless.
      }
    }

    for (final definition in plan.definitions) {
      final exists = switch (definition) {
        CategoryDefinition() =>
          await targetJournalDb.getCategoryById(definition.id) != null,
        LabelDefinition() =>
          await targetJournalDb.getLabelDefinitionById(definition.id) != null,
        _ => true,
      };
      if (!exists) {
        await persistence.upsertEntityDefinition(definition);
      }
    }

    var copied = 0;
    for (final entity in plan.entities) {
      // Stamps a fresh real-world vector clock (and updatedAt) while
      // preserving id, createdAt, dateFrom and dateTo — createDbEntity
      // itself never touches the metadata it is handed.
      final stamped = await persistence.updateMetadata(entity.meta);
      final applied = await persistence.createDbEntity(
        entity.copyWith(meta: stamped),
        shouldAddGeolocation: false,
      );
      if (applied ?? false) copied++;
    }

    for (final link in plan.links) {
      await persistence.createLink(fromId: link.fromId, toId: link.toId);
    }
    return copied;
  }

  /// Copies one media file into [staging] under a fresh name derived from
  /// the new entity id (original extension kept), recording the move for
  /// [apply]. Returns the new file name; a missing source file (already
  /// cleaned up externally) keeps the original name and stages nothing.
  Future<String> _stageMedia({
    required String sourcePath,
    required String originalFileName,
    required String newId,
    required Directory staging,
    required List<DemoStagedMedia> media,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) return originalFileName;
    final fileName = '$newId${p.extension(originalFileName)}';
    final staged = await source.copy(p.join(staging.path, fileName));
    media.add(
      DemoStagedMedia(
        stagedFile: staged,
        relativeTarget: '$demoImportMediaDirectory$fileName',
      ),
    );
    return fileName;
  }

  Iterable<String> _childIds(JournalEntity entity) => entity.maybeMap(
    task: (task) => task.data.checklistIds ?? const <String>[],
    checklist: (checklist) => checklist.data.linkedChecklistItems,
    orElse: () => const <String>[],
  );
}
