import 'dart:io';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
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
    this.aiConfigs = const [],
  });

  /// Remapped entities in insertion order (checklist items → checklists →
  /// other entries → tasks).
  final List<JournalEntity> entities;

  /// Closure-internal links, both ends already remapped. The relationship
  /// semantics ([EntryLinkType]) and the `collapsed`/`hidden` flags travel
  /// with each link so a typed relationship (blocks/follows-up/…) created in
  /// the demo keeps its meaning — and its visibility — in the real world.
  final List<
    ({
      String fromId,
      String toId,
      EntryLinkType linkType,
      bool collapsed,
      bool hidden,
    })
  >
  links;

  /// Category/label definitions referenced by [entities], carried with their
  /// ORIGINAL ids (upserted idempotently into the real world).
  final List<EntityDefinition> definitions;

  final List<DemoStagedMedia> media;

  /// User-created AI configs carried with their ORIGINAL ids, in insertion
  /// order (providers → models → profiles → skills). Written only when the
  /// id does not already exist in the real world.
  final List<AiConfig> aiConfigs;

  bool get isEmpty => entities.isEmpty && aiConfigs.isEmpty;
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
  ///
  /// [selectedAiProviderIds] are the "AI setup" selections: user-connected
  /// inference providers, each carried together with its user-created
  /// dependents (models on the provider, profiles slotting those models,
  /// skills those profiles assign) read from [sourceAiConfigs]. AI configs
  /// keep their ORIGINAL ids — unlike journal entities they are per-device
  /// configuration upserted idempotently, not content that could collide
  /// with an earlier copy run. Seeded fixture ids never travel.
  Future<DemoCopyPlan> prepare({
    required Set<String> selectedIds,
    required JournalDb sourceDb,
    required Directory sourceRoot,
    Set<String> selectedAiProviderIds = const {},
    AiConfigRepository? sourceAiConfigs,
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
            // The cover image travels in the closure (see [_childIds]), so
            // its remapped id keeps the art attached; an id that did not
            // travel (seeded or deleted image) is dropped rather than left
            // dangling into the demo world.
            coverArtId: task.data.coverArtId == null
                ? null
                : idMap[task.data.coverArtId],
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
          final staged = await _stageMedia(
            sourcePath: getFullImagePath(
              image,
              documentsDirectory: sourceRoot.path,
            ),
            originalDirectory: image.data.imageDirectory,
            originalFileName: image.data.imageFile,
            newId: newMeta.id,
            staging: staging,
            media: media,
          );
          return image.copyWith(
            meta: newMeta,
            data: image.data.copyWith(
              imageDirectory: staged.directory,
              imageFile: staged.fileName,
            ),
          );
        },
        journalAudio: (audio) async {
          final staged = await _stageMedia(
            sourcePath: AudioUtils.getAudioPath(audio, sourceRoot),
            originalDirectory: audio.data.audioDirectory,
            originalFileName: audio.data.audioFile,
            newId: newMeta.id,
            staging: staging,
            media: media,
          );
          return audio.copyWith(
            meta: newMeta,
            data: audio.data.copyWith(
              audioDirectory: staged.directory,
              audioFile: staged.fileName,
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

    // --- AI setup (same ids, no remap) --------------------------------------
    final aiConfigs = selectedAiProviderIds.isEmpty || sourceAiConfigs == null
        ? const <AiConfig>[]
        : await _prepareAiConfigs(
            selectedProviderIds: selectedAiProviderIds,
            repository: sourceAiConfigs,
            seededAiIds: {...?manifest?.seededAiConfigIds},
          );

    return DemoCopyPlan(
      entities: entities,
      links: [
        for (final link in internalLinks.values)
          (
            fromId: idMap[link.fromId]!,
            toId: idMap[link.toId]!,
            linkType: entryLinkTypeOf(link),
            collapsed: link.collapsed ?? false,
            hidden: link.hidden ?? false,
          ),
      ],
      definitions: definitions,
      media: media,
      aiConfigs: aiConfigs,
    );
  }

  /// Collects the AI configs traveling with the selected providers, in
  /// insertion order: the providers themselves, then user-created models
  /// bound to them, then user-created profiles whose REQUIRED thinking slot
  /// references a carried model, then user-created skills those profiles
  /// assign.
  ///
  /// Anchoring the closure on the selected PROVIDERS keeps junk out: rows
  /// the app auto-seeded against a fictional fixture provider (backfilled
  /// models, gated bundled profiles) reference fixture ids and therefore
  /// never join. Anything listed in the manifest is excluded outright.
  ///
  /// Carried profiles are PRUNED to the traveling dependency set: an
  /// optional model slot referencing a model that does not travel (a seeded
  /// fixture, or a model of an unselected provider) is cleared, and skill
  /// assignments pointing at seeded fixtures are dropped — a copied profile
  /// must never reference a config id that will not exist in the real
  /// world, where it would look configured but silently fail.
  Future<List<AiConfig>> _prepareAiConfigs({
    required Set<String> selectedProviderIds,
    required AiConfigRepository repository,
    required Set<String> seededAiIds,
  }) async {
    final providers = [
      for (final config in (await repository.getConfigsByType(
        AiConfigType.inferenceProvider,
      )).whereType<AiConfigInferenceProvider>())
        if (selectedProviderIds.contains(config.id) &&
            !seededAiIds.contains(config.id))
          config,
    ];
    if (providers.isEmpty) return const [];
    final providerIds = {for (final provider in providers) provider.id};

    final models = [
      for (final config in (await repository.getConfigsByType(
        AiConfigType.model,
      )).whereType<AiConfigModel>())
        if (!seededAiIds.contains(config.id) &&
            providerIds.contains(config.inferenceProviderId))
          config,
    ];
    final modelIds = {for (final model in models) model.id};

    final profiles = [
      for (final config in (await repository.getConfigsByType(
        AiConfigType.inferenceProfile,
      )).whereType<AiConfigInferenceProfile>())
        // The thinking slot is the profile's required core: a profile whose
        // thinking model does not travel would arrive fundamentally broken,
        // so it stays behind entirely.
        if (!seededAiIds.contains(config.id) &&
            modelIds.contains(config.thinkingModelId))
          _pruneProfile(
            config,
            carriedModelIds: modelIds,
            seededAiIds: seededAiIds,
          ),
    ];
    final skillIds = {
      for (final profile in profiles)
        for (final assignment in profile.skillAssignments) assignment.skillId,
    };

    final skills = [
      for (final config in (await repository.getConfigsByType(
        AiConfigType.skill,
      )).whereType<AiConfigSkill>())
        if (!seededAiIds.contains(config.id) && skillIds.contains(config.id))
          config,
    ];

    return [...providers, ...models, ...profiles, ...skills];
  }

  /// Clears every optional model slot not in [carriedModelIds] and drops
  /// skill assignments that reference seeded fixture skills, so the copied
  /// profile only references configs that exist after the crossing.
  static AiConfigInferenceProfile _pruneProfile(
    AiConfigInferenceProfile profile, {
    required Set<String> carriedModelIds,
    required Set<String> seededAiIds,
  }) {
    String? keep(String? modelId) =>
        modelId != null && carriedModelIds.contains(modelId) ? modelId : null;
    return profile.copyWith(
      thinkingHighEndModelId: keep(profile.thinkingHighEndModelId),
      imageRecognitionModelId: keep(profile.imageRecognitionModelId),
      transcriptionModelId: keep(profile.transcriptionModelId),
      imageGenerationModelId: keep(profile.imageGenerationModelId),
      skillAssignments: [
        for (final assignment in profile.skillAssignments)
          if (!seededAiIds.contains(assignment.skillId)) assignment,
      ],
    );
  }

  /// Applies [plan] in the REAL generation.
  ///
  /// Order matters: media files move into place first (so an image/audio
  /// entity never exists without its bytes), then AI configs (so entity and
  /// definition profile references can be validated against what actually
  /// lands — see [_resolveAiConfigsAgainstTarget]), then definitions (so
  /// category and label references resolve), then entities through
  /// `PersistenceLogic.updateMetadata` + `createDbEntity` (fresh vector
  /// clock, preserved dates, sync enqueued), then the closure-internal links
  /// through `createLink` (relationship type, `collapsed` and `hidden` all
  /// preserved). Definitions keep their demo ids and are only written when
  /// absent, so re-copying never clobbers real-world edits.
  ///
  /// AI configs go through [targetAiConfigs] (the REAL generation's
  /// repository) with their original ids, skipped when the id already
  /// exists there — including as a tombstone: a config the user deleted in
  /// the real world must not be resurrected by a demo exit. A tombstoned
  /// dependency also takes its carried dependents down with it, so a copied
  /// model/profile can never point at a config the target has deleted.
  /// Saves use the default `fromSync: false`, so copied AI setup replicates
  /// to peers like any locally created config.
  ///
  /// A `TaskData.profileId` or `CategoryDefinition.defaultProfileId`
  /// (stamped inside the demo by the real-AI wiring) survives the crossing
  /// only when the referenced profile is usable in the target — carried and
  /// saved, or already present there. Anything else is cleared: a dangling
  /// profile reference would make AI actions resolve a missing profile
  /// instead of falling back.
  ///
  /// [targetFts] is the REAL generation's FTS5 index. `createDbEntity`
  /// deliberately never touches FTS5 (only the update path and manual
  /// rebuilds do), so without indexing here every copied title and note
  /// would be invisible to full-text search and duplicate detection until
  /// the user edits it. Indexing is best-effort per entity — an FTS hiccup
  /// must not abort the copy.
  ///
  /// Returns the number of entities plus AI configs written.
  Future<int> apply(
    DemoCopyPlan plan, {
    required PersistenceLogic persistence,
    required JournalDb targetJournalDb,
    required Directory targetRoot,
    AiConfigRepository? targetAiConfigs,
    Fts5Db? targetFts,
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

    var copied = 0;
    final activeAiIds = <String>{};
    if (plan.aiConfigs.isNotEmpty) {
      final aiRepository = targetAiConfigs;
      if (aiRepository == null) {
        throw ArgumentError(
          'plan carries AI configs but no targetAiConfigs was provided',
        );
      }
      final resolved = await _resolveAiConfigsAgainstTarget(
        plan.aiConfigs,
        repository: aiRepository,
      );
      activeAiIds.addAll(resolved.activeIds);
      for (final config in resolved.toSave) {
        await aiRepository.saveConfig(config);
        copied++;
      }
    }

    // Whether an AI config id resolves to a live config in the target after
    // this apply — either carried (and active) or already present there
    // (e.g. the bundled onboarding profile of a provider the user has also
    // connected in the real world). Without a target repository nothing can
    // be verified, so nothing may be kept.
    final aiUsableCache = <String, bool>{};
    Future<bool> aiIdUsable(String id) async {
      if (activeAiIds.contains(id)) return true;
      final cached = aiUsableCache[id];
      if (cached != null) return cached;
      final usable =
          targetAiConfigs != null &&
          await targetAiConfigs.getConfigById(id) != null;
      aiUsableCache[id] = usable;
      return usable;
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
        var toWrite = definition;
        if (toWrite is CategoryDefinition) {
          final profileId = toWrite.defaultProfileId;
          if (profileId != null && !await aiIdUsable(profileId)) {
            _log(
              'clearing defaultProfileId $profileId on copied category '
              '${toWrite.id}: the profile does not exist in the target',
            );
            toWrite = toWrite.copyWith(defaultProfileId: null);
          }
        }
        await persistence.upsertEntityDefinition(toWrite);
      }
    }

    for (final entity in plan.entities) {
      var toWrite = entity;
      if (entity is Task) {
        final profileId = entity.data.profileId;
        if (profileId != null && !await aiIdUsable(profileId)) {
          _log(
            'clearing profileId $profileId on copied task '
            '${entity.meta.id}: the profile does not exist in the target',
          );
          toWrite = entity.copyWith(
            data: entity.data.copyWith(profileId: null),
          );
        }
      }
      // Stamps a fresh real-world vector clock (and updatedAt) while
      // preserving id, createdAt, dateFrom and dateTo — createDbEntity
      // itself never touches the metadata it is handed.
      final stamped = await persistence.updateMetadata(toWrite.meta);
      final withStampedMeta = toWrite.copyWith(meta: stamped);
      final applied = await persistence.createDbEntity(
        withStampedMeta,
        shouldAddGeolocation: false,
      );
      if (applied ?? false) {
        copied++;
        if (targetFts != null) {
          try {
            await targetFts.insertText(withStampedMeta);
          } catch (_) {
            // Search indexing is recoverable via the maintenance FTS
            // rebuild; the copy itself must not fail on it.
          }
        }
      }
    }

    for (final link in plan.links) {
      await persistence.createLink(
        fromId: link.fromId,
        toId: link.toId,
        linkType: link.linkType,
        collapsed: link.collapsed,
        hidden: link.hidden,
      );
    }
    return copied;
  }

  /// Re-resolves the carried AI configs against the TARGET world's actual
  /// state, in dependency order.
  ///
  /// [_prepareAiConfigs] pruned against the demo-side carry set, but the
  /// target has its own history: an id may already exist there as a live
  /// config (skip the save, dependents may reference it) or as a tombstone
  /// (skip the save AND treat the id as unusable — the user deleted it, and
  /// a demo exit must neither resurrect it nor deliver dependents that
  /// point at it). Dependents of an unusable id are dropped transitively:
  /// models without their provider, profiles without their thinking model;
  /// optional profile slots and skill assignments are pruned instead, and
  /// carried skills only travel while a surviving profile still references
  /// them.
  ///
  /// Returns the configs to save (in providers → models → profiles → skills
  /// order) and the full set of ids usable in the target after the apply.
  Future<({List<AiConfig> toSave, Set<String> activeIds})>
  _resolveAiConfigsAgainstTarget(
    List<AiConfig> configs, {
    required AiConfigRepository repository,
  }) async {
    final presentActive = <String>{};
    final tombstoned = <String>{};
    for (final config in configs) {
      final existing = await repository.getConfigById(
        config.id,
        includeDeleted: true,
      );
      if (existing == null) continue;
      if (existing.deletedAt != null) {
        tombstoned.add(config.id);
      } else {
        presentActive.add(config.id);
      }
    }

    // Ids usable in the target once this apply is done. Grown in dependency
    // order so each tier only sees dependencies that actually made it.
    final active = <String>{...presentActive};
    bool needsSave(String id) =>
        !presentActive.contains(id) && !tombstoned.contains(id);

    final providers = <AiConfig>[
      for (final config in configs.whereType<AiConfigInferenceProvider>())
        if (needsSave(config.id)) config,
    ];
    active.addAll([for (final provider in providers) provider.id]);

    final models = <AiConfig>[];
    for (final config in configs.whereType<AiConfigModel>()) {
      if (!needsSave(config.id)) continue;
      if (!active.contains(config.inferenceProviderId)) {
        _log(
          'dropping copied model ${config.id}: its provider '
          '${config.inferenceProviderId} is deleted in the target',
        );
        continue;
      }
      models.add(config);
      active.add(config.id);
    }

    // Skills carry no dependencies of their own, so their usability is
    // known before profiles prune their assignments; whether each one is
    // actually SAVED depends on a surviving profile still referencing it.
    final carriedSkillIds = {
      for (final config in configs.whereType<AiConfigSkill>())
        if (needsSave(config.id)) config.id,
    };
    final skillUsable = {...active, ...carriedSkillIds};

    final profiles = <AiConfig>[];
    final neededSkillIds = <String>{};
    for (final config in configs.whereType<AiConfigInferenceProfile>()) {
      if (presentActive.contains(config.id)) {
        // Already live in the target: its assignments define what it needs.
        neededSkillIds.addAll([
          for (final assignment in config.skillAssignments) assignment.skillId,
        ]);
        continue;
      }
      if (tombstoned.contains(config.id)) continue;
      if (!active.contains(config.thinkingModelId)) {
        _log(
          'dropping copied profile ${config.id}: its thinking model '
          '${config.thinkingModelId} is deleted in the target',
        );
        continue;
      }
      String? keep(String? modelId) =>
          modelId != null && active.contains(modelId) ? modelId : null;
      final pruned = config.copyWith(
        thinkingHighEndModelId: keep(config.thinkingHighEndModelId),
        imageRecognitionModelId: keep(config.imageRecognitionModelId),
        transcriptionModelId: keep(config.transcriptionModelId),
        imageGenerationModelId: keep(config.imageGenerationModelId),
        skillAssignments: [
          for (final assignment in config.skillAssignments)
            if (skillUsable.contains(assignment.skillId)) assignment,
        ],
      );
      profiles.add(pruned);
      active.add(pruned.id);
      neededSkillIds.addAll([
        for (final assignment in pruned.skillAssignments) assignment.skillId,
      ]);
    }

    final skills = <AiConfig>[
      for (final config in configs.whereType<AiConfigSkill>())
        if (carriedSkillIds.contains(config.id) &&
            neededSkillIds.contains(config.id))
          config,
    ];
    active.addAll([for (final skill in skills) skill.id]);

    return (
      toSave: [...providers, ...models, ...profiles, ...skills],
      activeIds: active,
    );
  }

  /// Best-effort breadcrumb for dropped/cleared references — the copy keeps
  /// going, but the pruning decision must be reconstructable from the logs.
  void _log(String message) {
    if (!getIt.isRegistered<DomainLogger>()) return;
    getIt<DomainLogger>().log(
      LogDomain.general,
      message,
      subDomain: 'demoDataCopier',
    );
  }

  /// Copies one media file into [staging] under a fresh name derived from
  /// the new entity id (original extension kept), recording the move for
  /// [apply].
  ///
  /// Returns the `(directory, fileName)` pair to write onto the copied
  /// entity. A staged file gets [demoImportMediaDirectory] and the fresh
  /// name; a MISSING source file (already cleaned up externally) stages
  /// nothing and keeps the entity's original pair. Rewriting the directory
  /// in that case would point the copy at `demo_import/<originalName>`, a
  /// path nothing ever creates — a broken attachment dressed up as an
  /// imported one.
  Future<({String directory, String fileName})> _stageMedia({
    required String sourcePath,
    required String originalDirectory,
    required String originalFileName,
    required String newId,
    required Directory staging,
    required List<DemoStagedMedia> media,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      _log('media source missing, keeping original path: $sourcePath');
      return (directory: originalDirectory, fileName: originalFileName);
    }
    final fileName = '$newId${p.extension(originalFileName)}';
    final staged = await source.copy(p.join(staging.path, fileName));
    media.add(
      DemoStagedMedia(
        stagedFile: staged,
        relativeTarget: '$demoImportMediaDirectory$fileName',
      ),
    );
    return (directory: demoImportMediaDirectory, fileName: fileName);
  }

  Iterable<String> _childIds(JournalEntity entity) => entity.maybeMap(
    task: (task) => [
      ...task.data.checklistIds ?? const <String>[],
      // Cover art is referenced by id, not by link — without following it
      // here a demo-created task would arrive with art that only exists in
      // the demo world.
      ?task.data.coverArtId,
    ],
    checklist: (checklist) => checklist.data.linkedChecklistItems,
    orElse: () => const <String>[],
  );
}
