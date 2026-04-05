import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/constants.dart';
import '../test_data/soul_factories.dart';

void main() {
  late MockAgentRepository mockRepo;
  late MockAgentSyncService mockSync;
  late SoulDocumentService service;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepo = MockAgentRepository();
    mockSync = MockAgentSyncService();

    // Stub sync service to delegate to repo stubs.
    when(() => mockSync.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSync.upsertLink(any())).thenAnswer((_) async {});

    service = SoulDocumentService(
      repository: mockRepo,
      syncService: mockSync,
    );
  });

  group('createSoul', () {
    test('creates entity, version, and head in transaction', () async {
      when(
        () => mockRepo.getSoulDocument(any()),
      ).thenAnswer((_) async => null);

      final soul = await service.createSoul(
        displayName: 'Test Soul',
        voiceDirective: 'Be warm.',
        authoredBy: 'user',
        toneBounds: 'No sarcasm.',
        coachingStyle: 'Gentle.',
        antiSycophancyPolicy: 'Push back.',
      );

      expect(soul.displayName, 'Test Soul');

      // Three upsertEntity calls: soul + version + head.
      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured;
      expect(captured, hasLength(3));
      expect(captured[0], isA<SoulDocumentEntity>());
      expect(captured[1], isA<SoulDocumentVersionEntity>());
      expect(captured[2], isA<SoulDocumentHeadEntity>());

      final version = captured[1] as SoulDocumentVersionEntity;
      expect(version.voiceDirective, 'Be warm.');
      expect(version.toneBounds, 'No sarcasm.');
      expect(version.coachingStyle, 'Gentle.');
      expect(version.antiSycophancyPolicy, 'Push back.');
      expect(version.version, 1);
      expect(version.status, SoulDocumentVersionStatus.active);
    });

    test('throws when soul with given ID already exists', () async {
      when(
        () => mockRepo.getSoulDocument('existing-id'),
      ).thenAnswer((_) async => makeTestSoulDocument(id: 'existing-id'));

      await expectLater(
        () => service.createSoul(
          soulId: 'existing-id',
          displayName: 'Dup',
          voiceDirective: 'Voice.',
          authoredBy: 'user',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on blank displayName', () async {
      expect(
        () => service.createSoul(
          displayName: '  ',
          voiceDirective: 'Voice.',
          authoredBy: 'user',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on blank voiceDirective', () async {
      expect(
        () => service.createSoul(
          displayName: 'Name',
          voiceDirective: '',
          authoredBy: 'user',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('uses provided soulId', () async {
      when(
        () => mockRepo.getSoulDocument('custom-id'),
      ).thenAnswer((_) async => null);

      final soul = await service.createSoul(
        soulId: 'custom-id',
        displayName: 'Custom',
        voiceDirective: 'Voice.',
        authoredBy: 'user',
      );

      expect(soul.id, 'custom-id');
      expect(soul.agentId, 'custom-id');
    });
  });

  group('createVersion', () {
    test('archives old versions and creates new active version', () async {
      final existingSoul = makeTestSoulDocument();
      final existingVersion = makeTestSoulDocumentVersion();
      final existingHead = makeTestSoulDocumentHead();

      when(
        () => mockRepo.getSoulDocument(kTestSoulId),
      ).thenAnswer((_) async => existingSoul);
      when(
        () => mockRepo.getSoulDocumentHead(kTestSoulId),
      ).thenAnswer((_) async => existingHead);
      when(
        () => mockRepo.getEntity(existingHead.versionId),
      ).thenAnswer((_) async => existingVersion);
      when(
        () => mockRepo.getNextSoulDocumentVersionNumber(kTestSoulId),
      ).thenAnswer((_) async => 2);

      final newVersion = await service.createVersion(
        soulId: kTestSoulId,
        voiceDirective: 'Updated voice.',
        authoredBy: 'evolution_agent',
      );

      expect(newVersion.version, 2);
      expect(newVersion.voiceDirective, 'Updated voice.');
      expect(newVersion.status, SoulDocumentVersionStatus.active);
      expect(newVersion.diffFromVersionId, existingHead.versionId);

      // Verify: archive active + create new + update head = 3 upserts.
      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured;
      expect(captured, hasLength(3));

      // First: archived old version.
      final archived = captured[0] as SoulDocumentVersionEntity;
      expect(archived.status, SoulDocumentVersionStatus.archived);

      // Second: new version.
      expect(captured[1], isA<SoulDocumentVersionEntity>());

      // Third: updated head.
      final head = captured[2] as SoulDocumentHeadEntity;
      expect(head.id, existingHead.id); // Reused head ID.
    });

    test('throws when soul not found', () async {
      when(
        () => mockRepo.getSoulDocument('nonexistent'),
      ).thenAnswer((_) async => null);

      await expectLater(
        () => service.createVersion(
          soulId: 'nonexistent',
          voiceDirective: 'Voice.',
          authoredBy: 'user',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('assignSoulToTemplate', () {
    test('creates soul assignment link', () async {
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => []);

      await service.assignSoulToTemplate(kTestTemplateId, kTestSoulId);

      final captured = verify(() => mockSync.upsertLink(captureAny())).captured;
      expect(captured, hasLength(1));
      final link = captured.first as SoulAssignmentLink;
      expect(link.fromId, kTestTemplateId);
      expect(link.toId, kTestSoulId);
    });

    test('replaces existing assignment by soft-deleting old link', () async {
      final existingLink = makeTestSoulAssignmentLink(toId: 'old-soul');
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => [existingLink]);

      await service.assignSoulToTemplate(kTestTemplateId, kTestSoulId);

      final captured = verify(() => mockSync.upsertLink(captureAny())).captured;
      // First: soft-deleted old link. Second: new link.
      expect(captured, hasLength(2));
      final deleted = captured[0] as AgentLink;
      expect(deleted.deletedAt, isNotNull);
    });

    test('is a no-op when already assigned to the same soul', () async {
      final existingLink = makeTestSoulAssignmentLink();
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => [existingLink]);

      await service.assignSoulToTemplate(kTestTemplateId, kTestSoulId);

      verifyNever(() => mockSync.upsertLink(any()));
    });
  });

  group('resolveActiveSoulForTemplate', () {
    test('returns null when no soul assigned', () async {
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => []);

      final result = await service.resolveActiveSoulForTemplate(
        kTestTemplateId,
      );
      expect(result, isNull);
    });

    test('resolves full chain: link → head → version', () async {
      final link = makeTestSoulAssignmentLink();
      final version = makeTestSoulDocumentVersion();

      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => mockRepo.getActiveSoulDocumentVersion(kTestSoulId),
      ).thenAnswer((_) async => version);

      final result = await service.resolveActiveSoulForTemplate(
        kTestTemplateId,
      );
      expect(result, isNotNull);
      expect(result!.voiceDirective, version.voiceDirective);
    });
  });

  group('getTemplatesUsingSoul', () {
    test('returns template IDs from reverse links', () async {
      final link1 = makeTestSoulAssignmentLink(
        id: 'link-1',
        fromId: 'template-a',
      );
      final link2 = makeTestSoulAssignmentLink(
        id: 'link-2',
        fromId: 'template-b',
      );

      when(
        () => mockRepo.getLinksTo(
          kTestSoulId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => [link1, link2]);

      final result = await service.getTemplatesUsingSoul(kTestSoulId);
      expect(result, ['template-a', 'template-b']);
    });
  });

  group('rollbackToVersion', () {
    test('moves head pointer and reactivates target version', () async {
      final head = makeTestSoulDocumentHead(versionId: 'version-2');
      final v1 = makeTestSoulDocumentVersion(
        id: 'version-1',
        status: SoulDocumentVersionStatus.archived,
      );
      final v2 = makeTestSoulDocumentVersion(
        id: 'version-2',
        version: 2,
      );

      when(
        () => mockRepo.getSoulDocumentHead(kTestSoulId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getEntity('version-1'),
      ).thenAnswer((_) async => v1);
      when(
        () => mockRepo.getSoulDocumentVersions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [v2, v1]);

      await service.rollbackToVersion(
        soulId: kTestSoulId,
        versionId: 'version-1',
      );

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured;

      // Should archive v2, reactivate v1, update head.
      expect(captured, hasLength(3));

      // v2 archived.
      final archivedV2 = captured[0] as SoulDocumentVersionEntity;
      expect(archivedV2.id, 'version-2');
      expect(archivedV2.status, SoulDocumentVersionStatus.archived);

      // v1 reactivated.
      final reactivatedV1 = captured[1] as SoulDocumentVersionEntity;
      expect(reactivatedV1.id, 'version-1');
      expect(reactivatedV1.status, SoulDocumentVersionStatus.active);

      // Head updated.
      final updatedHead = captured[2] as SoulDocumentHeadEntity;
      expect(updatedHead.versionId, 'version-1');
    });
  });

  group('unassignSoul', () {
    test('soft-deletes existing soul assignment link', () async {
      final existingLink = makeTestSoulAssignmentLink();
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => [existingLink]);

      await service.unassignSoul(kTestTemplateId);

      final captured = verify(() => mockSync.upsertLink(captureAny())).captured;
      expect(captured, hasLength(1));
      final deleted = captured.first as AgentLink;
      expect(deleted.deletedAt, isNotNull);
    });

    test('does nothing when no soul is assigned', () async {
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => []);

      await service.unassignSoul(kTestTemplateId);

      verifyNever(() => mockSync.upsertLink(any()));
    });
  });

  group('getSoul', () {
    test('delegates to repository', () async {
      final soul = makeTestSoulDocument();
      when(
        () => mockRepo.getSoulDocument(kTestSoulId),
      ).thenAnswer((_) async => soul);

      final result = await service.getSoul(kTestSoulId);
      expect(result, soul);
    });

    test('returns null when not found', () async {
      when(
        () => mockRepo.getSoulDocument('missing'),
      ).thenAnswer((_) async => null);

      final result = await service.getSoul('missing');
      expect(result, isNull);
    });
  });

  group('getAllSouls', () {
    test('delegates to repository', () async {
      final souls = [
        makeTestSoulDocument(id: 'soul-a', agentId: 'soul-a'),
        makeTestSoulDocument(id: 'soul-b', agentId: 'soul-b'),
      ];
      when(
        () => mockRepo.getAllSoulDocuments(),
      ).thenAnswer((_) async => souls);

      final result = await service.getAllSouls();
      expect(result, hasLength(2));
    });
  });

  group('getVersionHistory', () {
    test('delegates to repository with limit', () async {
      final versions = [
        makeTestSoulDocumentVersion(id: 'v2', version: 2),
        makeTestSoulDocumentVersion(id: 'v1'),
      ];
      when(
        () => mockRepo.getSoulDocumentVersions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => versions);

      final result = await service.getVersionHistory(kTestSoulId, limit: 10);
      expect(result, hasLength(2));
    });
  });

  group('seedDefaults', () {
    test('creates all 6 souls when none exist', () async {
      // All getSoul calls return null (nothing seeded yet).
      when(
        () => mockRepo.getSoulDocument(any()),
      ).thenAnswer((_) async => null);

      // assignSoulToTemplate needs link lookups.
      when(
        () => mockRepo.getLinksFrom(any(), type: AgentLinkTypes.soulAssignment),
      ).thenAnswer((_) async => []);

      await service.seedDefaults();

      // 6 souls × 3 entities each (soul + version + head) = 18 upserts,
      // plus 3 assignment links.
      final entityCalls = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured;
      expect(entityCalls, hasLength(18));

      final linkCalls = verify(
        () => mockSync.upsertLink(captureAny()),
      ).captured;
      expect(linkCalls, hasLength(3));
    });

    test('skips soul creation but runs assignments when all exist', () async {
      when(
        () => mockRepo.getSoulDocument(any()),
      ).thenAnswer((_) async => makeTestSoulDocument());

      // Return a link whose toId matches the soulId being assigned, so
      // the idempotency check in assignSoulToTemplate returns early.
      when(
        () => mockRepo.getLinksFrom(any(), type: AgentLinkTypes.soulAssignment),
      ).thenAnswer((invocation) async {
        final templateId = invocation.positionalArguments.first as String;
        // Map template → expected soul for the seed assignments.
        final soulId = switch (templateId) {
          'template-laura-001' => 'soul-laura-001',
          'template-tom-001' => 'soul-tom-001',
          'template-project-001' => 'soul-laura-001',
          _ => 'unknown',
        };
        return [makeTestSoulAssignmentLink(fromId: templateId, toId: soulId)];
      });

      await service.seedDefaults();

      // No soul entities created.
      verifyNever(() => mockSync.upsertEntity(any()));
      // Assignments checked but no writes (idempotent no-op).
      verifyNever(() => mockSync.upsertLink(any()));
    });
  });
}
