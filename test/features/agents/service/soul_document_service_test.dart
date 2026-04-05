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

    test('uses provided soulId', () async {
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
        // ignore: avoid_redundant_argument_values
        () => mockRepo.getSoulDocumentVersions(kTestSoulId, limit: -1),
      ).thenAnswer((_) async => [existingVersion]);
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

      // Verify: archive old + create new + update head = 3 upserts.
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
}
