import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:path/path.dart' as p;

void main() {
  final manifest = DemoSeedManifest(
    seedVersion: demoSeedVersion,
    seededAt: DateTime.utc(2026, 7, 17, 8, 30),
    localeTag: 'de',
    seededJournalIds: const ['task-1', 'image-1'],
    seededDefinitionIds: const ['category-1'],
    seededAiConfigIds: const ['provider-1', 'model-1'],
    seededLinkIds: const ['link-1'],
    seededJournalUpdatedAt: {
      'task-1': DateTime.utc(2026, 7, 17, 8, 30, 1),
    },
    seededDefinitionFingerprints: const {'category-1': '{"name":"Ops"}'},
  );

  group('DemoSeedManifest', () {
    test('round-trips through JSON without losing anything', () {
      final decoded = DemoSeedManifest.fromJson(
        jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.seedVersion, manifest.seedVersion);
      expect(decoded.seededAt, manifest.seededAt);
      expect(decoded.localeTag, 'de');
      expect(decoded.seededJournalIds, manifest.seededJournalIds);
      expect(decoded.seededDefinitionIds, manifest.seededDefinitionIds);
      expect(decoded.seededAiConfigIds, manifest.seededAiConfigIds);
      expect(decoded.seededLinkIds, manifest.seededLinkIds);
      expect(decoded.seededJournalUpdatedAt, manifest.seededJournalUpdatedAt);
      expect(
        decoded.seededDefinitionFingerprints,
        manifest.seededDefinitionFingerprints,
      );
      expect(decoded.isCurrentVersion, isTrue);
    });

    test('round-trips through the manifest file at a world root', () async {
      final root = Directory.systemTemp.createTempSync('lotti_manifest_');
      addTearDown(() => root.deleteSync(recursive: true));

      await manifest.write(root);
      expect(
        File(p.join(root.path, demoSeedManifestFileName)).existsSync(),
        isTrue,
      );

      final read = await DemoSeedManifest.read(root);
      expect(read, isNotNull);
      expect(read!.seededJournalIds, manifest.seededJournalIds);
      expect(read.seededLinkIds, manifest.seededLinkIds);
      expect(read.seededAt, manifest.seededAt);
    });

    test('read returns null for an unseeded world root', () async {
      final root = Directory.systemTemp.createTempSync('lotti_manifest_');
      addTearDown(() => root.deleteSync(recursive: true));

      expect(await DemoSeedManifest.read(root), isNull);
    });

    test('detects a seed-version mismatch', () {
      final stale = DemoSeedManifest.fromJson({
        ...manifest.toJson(),
        'seedVersion': demoSeedVersion + 1,
      });
      expect(stale.isCurrentVersion, isFalse);
      expect(manifest.isCurrentVersion, isTrue);
    });

    test('reads a v4 manifest without a seeded-link inventory', () {
      final legacy = DemoSeedManifest.fromJson(
        {
          ...manifest.toJson(),
        }..remove('seededLinkIds'),
      );

      expect(legacy.seededLinkIds, isNull);
    });
  });
}
