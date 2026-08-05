import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';

/// Batch size for paging through the demo journal. Small worlds only — the
/// demo journal holds the seed fixture plus whatever the user created.
const int _candidatePageSize = 200;

/// The journal entity types offered for copy-over. Checklists and checklist
/// items deliberately never appear as roots: they travel with the task that
/// owns them (via the copier's closure), never on their own.
const List<String> _candidateRootTypes = [
  'Task',
  'JournalEntry',
  'JournalAudio',
  'JournalImage',
];

/// What the exit sheet offers to copy: demo-CREATED root entities, grouped
/// the way the sheet renders them.
///
/// A root is a non-deleted entity whose id is NOT in the seed manifest and
/// that is either a task or an entry with no inbound link (an entry linked
/// under a task travels with that task instead of being offered twice).
/// Consequence, documented as v1 scope: an entry the user attached to a
/// SEEDED task has an inbound link and is not offered — edits and additions
/// to seeded entities do not copy.
class DemoCopyCandidates {
  const DemoCopyCandidates({
    required this.tasks,
    required this.entries,
    required this.aiProviders,
  });

  static const DemoCopyCandidates empty = DemoCopyCandidates(
    tasks: [],
    entries: [],
    aiProviders: [],
  );

  /// Demo-created tasks, newest first (query order).
  final List<JournalEntity> tasks;

  /// Demo-created standalone entries (text/audio/image), newest first.
  final List<JournalEntity> entries;

  /// USER-connected inference providers (id not in the seed manifest) — the
  /// selectable units of the "AI setup" group. Selecting one carries its
  /// dependent models/profiles/skills via the copier; the fictional seeded
  /// fixtures never appear here.
  final List<AiConfigInferenceProvider> aiProviders;

  bool get isEmpty => tasks.isEmpty && entries.isEmpty && aiProviders.isEmpty;
  bool get isNotEmpty => !isEmpty;
  int get length => tasks.length + entries.length + aiProviders.length;
}

/// Loads the copy-over candidates from the ACTIVE demo world.
///
/// [journalDb], [aiConfigRepository] and [demoRoot] are the demo
/// generation's active handles (`getIt<JournalDb>()` /
/// `getIt<AiConfigRepository>()` / `getIt<Directory>()` in production); the
/// manifest at [demoRoot] supplies the seeded-id exclusion sets. A missing
/// or malformed manifest excludes nothing — better to over-offer than to
/// lose user work behind a corrupt manifest.
Future<DemoCopyCandidates> loadDemoCopyCandidates({
  required JournalDb journalDb,
  required AiConfigRepository aiConfigRepository,
  required Directory demoRoot,
}) async {
  DemoSeedManifest? manifest;
  try {
    manifest = await DemoSeedManifest.read(demoRoot);
  } catch (_) {
    manifest = null;
  }
  final seeded = {...?manifest?.seededJournalIds};

  final created = <JournalEntity>[];
  var offset = 0;
  while (true) {
    final batch = await journalDb.getJournalEntities(
      types: _candidateRootTypes,
      starredStatuses: const [true, false],
      privateStatuses: const [true, false],
      flaggedStatuses: const [0, 1],
      ids: null,
      limit: _candidatePageSize,
      offset: offset,
    );
    created.addAll(
      batch.where((entity) => !seeded.contains(entity.meta.id)),
    );
    if (batch.length < _candidatePageSize) break;
    offset += _candidatePageSize;
  }

  final tasks = created.whereType<Task>().toList();
  final nonTasks = created.where((entity) => entity is! Task).toList();

  // Entries with an inbound link (from a task or another entry) are not
  // roots — they ride along when their parent is copied.
  final inboundLinks = await journalDb.linksForEntryIds({
    for (final entity in nonTasks) entity.meta.id,
  });
  final linkedToIds = {
    for (final link in inboundLinks)
      if (link.deletedAt == null) link.toId,
  };

  // USER-connected providers: everything of the inference-provider type not
  // listed in the manifest. The seeded fictional fixtures are excluded by
  // id; models/profiles/skills are never offered on their own — they travel
  // with the provider they belong to (copier closure).
  final seededAi = {...?manifest?.seededAiConfigIds};
  final providerConfigs = await aiConfigRepository.getConfigsByType(
    AiConfigType.inferenceProvider,
  );
  final aiProviders = [
    for (final config in providerConfigs.whereType<AiConfigInferenceProvider>())
      if (!seededAi.contains(config.id)) config,
  ];

  return DemoCopyCandidates(
    tasks: tasks,
    entries: [
      for (final entity in nonTasks)
        if (!linkedToIds.contains(entity.meta.id)) entity,
    ],
    aiProviders: aiProviders,
  );
}
