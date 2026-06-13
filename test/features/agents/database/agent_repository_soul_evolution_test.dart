import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'agent_repository_soul_test_helpers.dart';

void main() {
  late AgentDatabase db;
  late AgentRepository repo;

  final testDate = DateTime(2026, 4, 5);
  const soulId = 'soul-001';

  SoulDocumentVersionEntity makeVersion({
    String id = 'sv-001',
    String agentId = soulId,
    int version = 1,
    SoulDocumentVersionStatus status = SoulDocumentVersionStatus.active,
    String voiceDirective = 'Be warm.',
  }) =>
      AgentDomainEntity.soulDocumentVersion(
            id: id,
            agentId: agentId,
            version: version,
            status: status,
            authoredBy: 'system',
            createdAt: testDate,
            vectorClock: null,
            voiceDirective: voiceDirective,
          )
          as SoulDocumentVersionEntity;

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    repo = AgentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getNextSoulDocumentVersionNumber', () {
    test('returns 1 when no versions exist', () async {
      final result = await repo.getNextSoulDocumentVersionNumber(soulId);
      expect(result, 1);
    });

    test('returns max + 1', () async {
      await repo.upsertEntity(makeVersion());
      await repo.upsertEntity(makeVersion(id: 'sv-002', version: 2));

      final result = await repo.getNextSoulDocumentVersionNumber(soulId);
      expect(result, 3);
    });
  });

  glados.Glados(
    glados.any.soulResolutionScenario,
    glados.ExploreConfig(numRuns: 80),
  ).test(
    'matches generated soul document resolution semantics',
    (scenario) async {
      final localDb = AgentDatabase(inMemoryDatabase: true, background: false);
      final localRepo = AgentRepository(localDb);

      try {
        for (final document in scenario.documents) {
          await localRepo.upsertEntity(
            AgentDomainEntity.soulDocument(
              id: document.id,
              agentId: document.id,
              displayName: document.displayName,
              createdAt: document.createdAt,
              updatedAt: document.updatedAt,
              vectorClock: null,
              deletedAt: document.deletedAt,
            ),
          );
        }

        for (var index = 0; index < scenario.versions.length; index++) {
          final version = scenario.versions[index];
          await localRepo.upsertEntity(
            AgentDomainEntity.soulDocumentVersion(
              id: version.idAt(index),
              agentId: version.soulId,
              version: version.version,
              status: version.status,
              authoredBy: 'generated',
              createdAt: version.createdAt(index),
              vectorClock: null,
              voiceDirective: 'generated voice $index',
              deletedAt: version.deletedAt(index),
            ),
          );
        }

        for (var index = 0; index < scenario.heads.length; index++) {
          final head = scenario.heads[index];
          await localRepo.upsertEntity(
            AgentDomainEntity.soulDocumentHead(
              id: head.idAt(index),
              agentId: head.soulId,
              versionId: head.versionIdFor(scenario),
              updatedAt: head.updatedAt(index),
              vectorClock: null,
              deletedAt: head.deletedAt(index),
            ),
          );
        }

        for (final assignment in scenario.assignments) {
          await localRepo.upsertLink(
            model.AgentLink.soulAssignment(
              id: assignment.id,
              fromId: assignment.templateId,
              toId: assignment.soulId,
              createdAt: assignment.createdAt,
              updatedAt: assignment.createdAt,
              vectorClock: null,
              deletedAt: assignment.deletedAt,
            ),
          );
        }

        final allSouls = await localRepo.getAllSoulDocuments();
        expect(
          allSouls.map((soul) => soul.id).toSet(),
          scenario.expectedAllSoulDocumentIds,
          reason: '$scenario',
        );

        final targetSoul = await localRepo.getSoulDocument(
          hGeneratedSoulTargetId,
        );
        expect(
          targetSoul?.displayName,
          scenario.expectedTargetSoulDisplayName,
          reason: '$scenario',
        );

        final head = await localRepo.getSoulDocumentHead(
          hGeneratedSoulTargetId,
        );
        expect(
          head?.id,
          scenario.expectedTargetHeadId,
          reason: '$scenario',
        );
        expect(
          head?.versionId,
          scenario.expectedTargetHeadVersionId,
          reason: '$scenario',
        );

        final activeVersion = await localRepo.getActiveSoulDocumentVersion(
          hGeneratedSoulTargetId,
        );
        expect(
          activeVersion?.id,
          scenario.expectedActiveVersionId,
          reason: '$scenario',
        );
        expect(
          activeVersion?.status,
          scenario.expectedActiveVersionStatus,
          reason: '$scenario',
        );

        final versions = await localRepo.getSoulDocumentVersions(
          hGeneratedSoulTargetId,
          limit: scenario.versionLimit,
        );
        expect(
          versions.map((version) => version.id).toList(),
          scenario.expectedVersionIds(limit: scenario.versionLimit),
          reason: '$scenario',
        );

        final nextVersion = await localRepo.getNextSoulDocumentVersionNumber(
          hGeneratedSoulTargetId,
        );
        expect(
          nextVersion,
          scenario.expectedNextVersionNumber,
          reason: '$scenario',
        );

        final targetTemplateLinks = await localRepo.getLinksFrom(
          hGeneratedSoulTargetTemplateId,
          type: AgentLinkTypes.soulAssignment,
        );
        final expectedTemplateAssignment =
            scenario.expectedTargetTemplateAssignment;
        expect(
          targetTemplateLinks.map((link) => link.id).toSet(),
          expectedTemplateAssignment == null
              ? isEmpty
              : {expectedTemplateAssignment.id},
          reason: '$scenario',
        );
        if (expectedTemplateAssignment != null) {
          expect(
            targetTemplateLinks.single.toId,
            expectedTemplateAssignment.soulId,
            reason: '$scenario',
          );
        }

        final targetSoulLinks = await localRepo.getLinksTo(
          hGeneratedSoulTargetId,
          type: AgentLinkTypes.soulAssignment,
        );
        expect(
          targetSoulLinks.map((link) => link.id).toSet(),
          scenario.expectedTargetSoulAssignmentIds,
          reason: '$scenario',
        );
      } finally {
        await localDb.close();
      }
    },
    tags: 'glados',
  );

  group('soul assignment link queries', () {
    test('getLinksFrom returns soul assignment links', () async {
      final link = model.AgentLink.soulAssignment(
        id: 'link-sa-001',
        fromId: 'tpl-001',
        toId: soulId,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );
      await repo.upsertLink(link);

      final result = await repo.getLinksFrom(
        'tpl-001',
        type: AgentLinkTypes.soulAssignment,
      );
      expect(result, hasLength(1));
      expect(result.first, isA<model.SoulAssignmentLink>());
      expect(result.first.toId, soulId);
    });

    test('getLinksTo returns reverse soul assignment links', () async {
      final link = model.AgentLink.soulAssignment(
        id: 'link-sa-002',
        fromId: 'tpl-001',
        toId: soulId,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );
      await repo.upsertLink(link);

      final result = await repo.getLinksTo(
        soulId,
        type: AgentLinkTypes.soulAssignment,
      );
      expect(result, hasLength(1));
      expect(result.first.fromId, 'tpl-001');
    });

    test(
      'upsertLink succeeds when an existing soul_assignment row has the '
      'exact same natural key (from_id, to_id, type) but a different id '
      '— the global UNIQUE(from_id,to_id,type) constraint applies to '
      'all rows including soft-deleted ones, so the handoff path must '
      'free the slot before the INSERT',
      () async {
        final original = model.AgentLink.soulAssignment(
          id: 'link-sa-original',
          fromId: 'tpl-001',
          toId: soulId,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );
        await repo.upsertLink(original);

        final replacement = model.AgentLink.soulAssignment(
          id: 'link-sa-replacement',
          fromId: 'tpl-001',
          toId: soulId,
          createdAt: testDate.add(const Duration(minutes: 1)),
          updatedAt: testDate.add(const Duration(minutes: 1)),
          vectorClock: null,
        );

        // Before the fix this threw SqliteException(2067) because the
        // soft-delete of the original only set deleted_at; the row still
        // occupied the global UNIQUE slot so INSERT of the replacement
        // blew up before the ON CONFLICT(id) upsert could run.
        await repo.upsertLink(replacement);

        final active = await repo.getLinksFrom(
          'tpl-001',
          type: AgentLinkTypes.soulAssignment,
        );
        expect(active, hasLength(1));
        expect(active.first.id, 'link-sa-replacement');
      },
    );

    test(
      'upsertLink succeeds when an existing improver_target row has the '
      'exact same natural key — symmetric to the soul_assignment case',
      () async {
        final original = model.AgentLink.improverTarget(
          id: 'link-it-original',
          fromId: 'tpl-001',
          toId: 'improver-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );
        await repo.upsertLink(original);

        final replacement = model.AgentLink.improverTarget(
          id: 'link-it-replacement',
          fromId: 'tpl-001',
          toId: 'improver-001',
          createdAt: testDate.add(const Duration(minutes: 1)),
          updatedAt: testDate.add(const Duration(minutes: 1)),
          vectorClock: null,
        );

        await repo.upsertLink(replacement);

        final active = await repo.getLinksTo(
          'improver-001',
          type: AgentLinkTypes.improverTarget,
        );
        expect(active, hasLength(1));
        expect(active.first.id, 'link-it-replacement');
      },
    );

    test(
      'upsertLink soft-deletes a conflicting improver_target from a '
      'DIFFERENT template (UNIQUE on to_id) instead of hard-deleting it',
      () async {
        final original = model.AgentLink.improverTarget(
          id: 'link-it-tpl-a',
          fromId: 'tpl-a',
          toId: 'improver-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );
        await repo.upsertLink(original);

        // Different from_id -> natural key differs -> the conflict goes
        // through the soft-delete (tombstone) path, not the hard delete.
        final rebind = model.AgentLink.improverTarget(
          id: 'link-it-tpl-b',
          fromId: 'tpl-b',
          toId: 'improver-001',
          createdAt: testDate.add(const Duration(minutes: 1)),
          updatedAt: testDate.add(const Duration(minutes: 1)),
          vectorClock: null,
        );
        await repo.upsertLink(rebind);

        final active = await repo.getLinksTo(
          'improver-001',
          type: AgentLinkTypes.improverTarget,
        );
        expect(active, hasLength(1));
        expect(active.first.id, 'link-it-tpl-b');

        // The original row survives as a tombstone (soft-deleted, not
        // hard-deleted), so sync still propagates the retraction.
        final raw = await db
            .customSelect(
              'SELECT deleted_at FROM agent_links WHERE id = ?',
              variables: [Variable.withString('link-it-tpl-a')],
            )
            .getSingle();
        expect(raw.data['deleted_at'], isNotNull);
      },
    );

    test(
      "upsertLink keeps the soft-deleted row's serialized JSON in step "
      'with the SQL tombstone columns (json_set side-channel)',
      () async {
        final original = model.AgentLink.soulAssignment(
          id: 'link-sa-json',
          fromId: 'tpl-json',
          toId: soulId,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );
        await repo.upsertLink(original);

        // Re-bind the template to a different soul: the original link is
        // soft-deleted via the handoff path.
        final rebind = model.AgentLink.soulAssignment(
          id: 'link-sa-json-2',
          fromId: 'tpl-json',
          toId: 'soul-other',
          createdAt: testDate.add(const Duration(minutes: 1)),
          updatedAt: testDate.add(const Duration(minutes: 1)),
          vectorClock: null,
        );
        await repo.upsertLink(rebind);

        final raw = await db
            .customSelect(
              'SELECT deleted_at, serialized FROM agent_links WHERE id = ?',
              variables: [Variable.withString('link-sa-json')],
            )
            .getSingle();
        expect(raw.data['deleted_at'], isNotNull);

        // Readers that decode from `serialized` without a deleted_at filter
        // must see the tombstone in the JSON too.
        final decoded =
            jsonDecode(raw.data['serialized'] as String)
                as Map<String, dynamic>;
        expect(decoded['deletedAt'], isNotNull);
        expect(decoded['updatedAt'], isNot(testDate.toIso8601String()));
      },
    );
  });
}
