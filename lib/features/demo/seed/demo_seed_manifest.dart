import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Version of the demo seed content. Bump when the seeded world changes in a
/// way that should trigger a wipe-and-reseed of existing demo profiles.
const demoSeedVersion = 3;

/// File name of the manifest written at the demo world's root.
const demoSeedManifestFileName = 'demo_seed_manifest.json';

/// Record of what one demo-seed run wrote, persisted as JSON at the demo
/// world's root.
///
/// The manifest is the durable boundary between seeded fixtures and
/// user-created data: exit copy-over offers exactly the entities whose ids
/// are NOT listed here, and lifecycle checks compare [seedVersion] against
/// [demoSeedVersion] to decide between resuming and reseeding.
class DemoSeedManifest {
  const DemoSeedManifest({
    required this.seedVersion,
    required this.seededAt,
    required this.localeTag,
    required this.seededJournalIds,
    required this.seededDefinitionIds,
    required this.seededAiConfigIds,
  });

  factory DemoSeedManifest.fromJson(Map<String, dynamic> json) {
    return DemoSeedManifest(
      seedVersion: json['seedVersion'] as int,
      seededAt: DateTime.parse(json['seededAt'] as String),
      localeTag: json['localeTag'] as String,
      seededJournalIds: _idList(json['seededJournalIds']),
      seededDefinitionIds: _idList(json['seededDefinitionIds']),
      seededAiConfigIds: _idList(json['seededAiConfigIds']),
    );
  }

  /// The [demoSeedVersion] active when this world was seeded.
  final int seedVersion;

  /// When the seed run happened (UTC).
  final DateTime seededAt;

  /// BCP-47-ish tag of the locale the world was seeded in (e.g. `en`, `de`).
  final String localeTag;

  /// Ids of every seeded journal entity (tasks, images, checklists,
  /// checklist items, time records).
  final List<String> seededJournalIds;

  /// Ids of every seeded entity definition (category, labels).
  final List<String> seededDefinitionIds;

  /// Ids of every seeded AI config (providers, models, profiles, skills).
  final List<String> seededAiConfigIds;

  /// Whether this world was seeded by the current app's seed content. A
  /// mismatch means the profile should be wiped and reseeded before reuse.
  bool get isCurrentVersion => seedVersion == demoSeedVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'seedVersion': seedVersion,
    'seededAt': seededAt.toIso8601String(),
    'localeTag': localeTag,
    'seededJournalIds': seededJournalIds,
    'seededDefinitionIds': seededDefinitionIds,
    'seededAiConfigIds': seededAiConfigIds,
  };

  /// The manifest file for a demo world rooted at [root].
  static File fileFor(Directory root) =>
      File(p.join(root.path, demoSeedManifestFileName));

  /// Reads the manifest at [root]; `null` when no manifest exists (an
  /// unseeded or pre-manifest world). A malformed manifest throws — callers
  /// treat that the same as a version mismatch.
  static Future<DemoSeedManifest?> read(Directory root) async {
    final file = fileFor(root);
    if (!file.existsSync()) return null;
    return DemoSeedManifest.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  /// Writes this manifest to [root]/[demoSeedManifestFileName].
  Future<void> write(Directory root) async {
    await fileFor(root).writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
      flush: true,
    );
  }

  static List<String> _idList(dynamic value) =>
      List<String>.unmodifiable((value as List<dynamic>).cast<String>());
}
