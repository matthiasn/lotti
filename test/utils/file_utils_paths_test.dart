import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path_provider/path_provider.dart';

import '../helpers/path_provider.dart';
import 'file_utils_test_helpers.dart';

void main() {
  group('normalizeAttachmentIndexKey', () {
    test('adds leading slash to bare path', () {
      expect(
        normalizeAttachmentIndexKey('agent_entities/a.json'),
        '/agent_entities/a.json',
      );
    });

    test('preserves single leading slash', () {
      expect(
        normalizeAttachmentIndexKey('/agent_entities/a.json'),
        '/agent_entities/a.json',
      );
    });

    test('collapses multiple leading slashes', () {
      expect(
        normalizeAttachmentIndexKey('///agent_entities/a.json'),
        '/agent_entities/a.json',
      );
    });

    test('converts backslashes to forward slashes', () {
      expect(
        normalizeAttachmentIndexKey(r'\agent_entities\a.json'),
        '/agent_entities/a.json',
      );
    });

    glados.Glados(
      glados.any.attachmentIndexKey,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'canonicalizes generated relative paths to one slash-prefixed key',
      (scenario) {
        final normalized = normalizeAttachmentIndexKey(scenario.rawPath);

        expect(normalized, scenario.expectedKey, reason: '$scenario');
        expect(normalized.startsWith('/'), isTrue, reason: '$scenario');
        expect(normalized.startsWith('//'), isFalse, reason: '$scenario');
        expect(normalized.contains(r'\'), isFalse, reason: '$scenario');
      },
      tags: 'glados',
    );
  });

  group('outbox bundle payload paths', () {
    test('builds encoded outbox bundle paths under /outbox_bundles/', () {
      expect(
        relativeOutboxBundlePath('abc-123'),
        '/outbox_bundles/abc-123.json',
      );
    });

    test('URI-encodes special characters in the bundle id', () {
      expect(
        relativeOutboxBundlePath('with/slash and space'),
        '/outbox_bundles/with%2Fslash%20and%20space.json',
      );
    });

    glados.Glados(
      glados.any.payloadId,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'URI-encodes generated outbox bundle ids under the bundle segment',
      (payloadId) {
        final path = relativeOutboxBundlePath(payloadId.text);

        expect(
          path,
          '$outboxBundlesSegment${payloadId.encoded}.json',
          reason: '$payloadId',
        );
        expect(isAgentPayloadPath(path), isFalse, reason: '$payloadId');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.payloadId,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'URI-encodes generated notification ids under the notification segment',
      (payloadId) {
        final path = relativeNotificationPath(payloadId.text);

        expect(
          path,
          '$notificationsSegment${payloadId.encoded}.json',
          reason: '$payloadId',
        );
        expect(isAgentPayloadPath(path), isFalse, reason: '$payloadId');
      },
      tags: 'glados',
    );

    test(
      'outbox bundle paths are NOT classified as agent payload paths — '
      'agent payloads share a VC-dominance re-download skip optimization '
      'that does not apply to outbox bundles (each bundle has a fresh uuid '
      'so the local file never pre-exists)',
      () {
        expect(isAgentPayloadPath('/outbox_bundles/abc.json'), isFalse);
      },
    );

    glados.Glados(
      glados.any.payloadId,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'classifies generated agent entity and link paths as agent payloads',
      (payloadId) {
        expect(
          isAgentPayloadPath(relativeAgentEntityPath(payloadId.encoded)),
          isTrue,
          reason: '$payloadId',
        );
        expect(
          isAgentPayloadPath(relativeAgentLinkPath(payloadId.encoded)),
          isTrue,
          reason: '$payloadId',
        );
      },
      tags: 'glados',
    );
  });

  // ---------------------------------------------------------------------------
  // relativeEntityPath — Glados properties
  //
  // Tests the `orElse` branch (non-image, non-audio entity types) where the
  // path is built from folderForJournalEntity / typeSuffix / createdAt / id.
  // We parameterise over generated ids and creation dates and verify the
  // structural invariants without re-implementing DateFormat.
  // ---------------------------------------------------------------------------
  group('relativeEntityPath — properties', () {
    // Shared generator that produces (year, month, day, id) tuples.
    // Day is capped at 28 to avoid dealing with month-end edge cases.

    glados.Glados(
      glados.any.generatedEntityScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'journalEntry path ends with .json and contains the entity id',
      (scenario) {
        final entity = JournalEntity.journalEntry(
          meta: scenario.meta,
        );
        final path = relativeEntityPath(entity);

        expect(
          path.endsWith('.json'),
          isTrue,
          reason: 'path=$path, scenario=$scenario',
        );
        expect(
          path.contains(scenario.meta.id),
          isTrue,
          reason: 'path=$path, scenario=$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedEntityScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'journalEntry path folder matches folderForJournalEntity',
      (scenario) {
        final entity = JournalEntity.journalEntry(
          meta: scenario.meta,
        );
        final path = relativeEntityPath(entity);
        final expected = folderForJournalEntity(entity);

        // Path format: /$folder/$date/$id.$suffix.json
        expect(
          path.startsWith('/$expected/'),
          isTrue,
          reason: 'path=$path, folder=$expected, scenario=$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedEntityScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'journalEntry path type-suffix matches typeSuffix helper',
      (scenario) {
        final entity = JournalEntity.journalEntry(
          meta: scenario.meta,
        );
        final path = relativeEntityPath(entity);
        final suffix = typeSuffix(entity);

        // The filename portion is: $id.$suffix.json
        expect(
          path.contains('.$suffix.json'),
          isTrue,
          reason: 'path=$path, suffix=$suffix, scenario=$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedEntityScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'journalEntry date subfolder matches yyyy-MM-dd of createdAt',
      (scenario) {
        final entity = JournalEntity.journalEntry(
          meta: scenario.meta,
        );
        final path = relativeEntityPath(entity);
        final createdAt = scenario.meta.createdAt;

        // Build expected date string without importing intl.
        final yyyy = createdAt.year.toString().padLeft(4, '0');
        final mm = createdAt.month.toString().padLeft(2, '0');
        final dd = createdAt.day.toString().padLeft(2, '0');
        final expectedDate = '$yyyy-$mm-$dd';

        expect(
          path.contains('/$expectedDate/'),
          isTrue,
          reason: 'path=$path, expectedDate=$expectedDate, scenario=$scenario',
        );
      },
      tags: 'glados',
    );
  });

  // ---------------------------------------------------------------------------
  // resolveJsonCandidateFile — Glados properties
  //
  // Verifies the sandbox invariant: any safe relative path resolves inside
  // the documents directory, and any path-traversal attempt throws.
  // ---------------------------------------------------------------------------
  group('resolveJsonCandidateFile — properties', () {
    late Directory propDocDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      setFakeDocumentsPath();
      propDocDir = await getApplicationDocumentsDirectory();
      await getIt.reset();
      getIt.registerSingleton<Directory>(propDocDir);
    });

    tearDownAll(getIt.reset);

    glados.Glados(
      glados.any.safeRelativePath,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'safe relative paths always resolve inside the documents directory',
      (relativePath) {
        final result = resolveJsonCandidateFile(relativePath);
        expect(
          result.path.startsWith(propDocDir.path),
          isTrue,
          reason: 'relativePath="$relativePath", resolved="${result.path}"',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.pathSegment,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'path-traversal prefix causes FileSystemException',
      (segment) {
        // Prepend enough ../ to escape any realistic nesting.
        final escapingPath = '../../../${segment.text}';
        expect(
          () => resolveJsonCandidateFile(escapingPath),
          throwsA(isA<FileSystemException>()),
          reason: 'escapingPath="$escapingPath"',
        );
      },
      tags: 'glados',
    );
  });
}
