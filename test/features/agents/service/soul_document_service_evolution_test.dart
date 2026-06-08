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

    test('throws when no head exists for the soul', () async {
      when(
        () => mockRepo.getSoulDocumentHead(kTestSoulId),
      ).thenAnswer((_) async => null);

      await expectLater(
        () => service.rollbackToVersion(
          soulId: kTestSoulId,
          versionId: 'version-1',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No head found for soul $kTestSoulId'),
          ),
        ),
      );

      // Bails before reading the target version or writing anything.
      verifyNever(() => mockRepo.getEntity(any()));
      verifyNever(() => mockSync.upsertEntity(any()));
    });

    test('throws when the target version is missing', () async {
      final head = makeTestSoulDocumentHead(versionId: 'version-2');
      when(
        () => mockRepo.getSoulDocumentHead(kTestSoulId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getEntity('missing-version'),
      ).thenAnswer((_) async => null);

      await expectLater(
        () => service.rollbackToVersion(
          soulId: kTestSoulId,
          versionId: 'missing-version',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'No version missing-version found for soul $kTestSoulId',
            ),
          ),
        ),
      );

      verifyNever(() => mockSync.upsertEntity(any()));
    });

    test(
      'throws when the target version belongs to a different soul',
      () async {
        final head = makeTestSoulDocumentHead(versionId: 'version-2');
        // A real version entity, but owned by another soul — the agentId guard
        // in mapOrNull rejects it, so validVersion resolves to null.
        final foreignVersion = makeTestSoulDocumentVersion(
          id: 'version-foreign',
          agentId: 'some-other-soul',
        );
        when(
          () => mockRepo.getSoulDocumentHead(kTestSoulId),
        ).thenAnswer((_) async => head);
        when(
          () => mockRepo.getEntity('version-foreign'),
        ).thenAnswer((_) async => foreignVersion);

        await expectLater(
          () => service.rollbackToVersion(
            soulId: kTestSoulId,
            versionId: 'version-foreign',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'No version version-foreign found for soul $kTestSoulId',
              ),
            ),
          ),
        );

        verifyNever(() => mockSync.upsertEntity(any()));
      },
    );
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

  group('updateSoul', () {
    test('updates display name', () async {
      final soul = makeTestSoulDocument(
        id: 'soul-upd',
        displayName: 'Old Name',
      );
      when(
        () => mockRepo.getSoulDocument('soul-upd'),
      ).thenAnswer((_) async => soul);

      final updated = await service.updateSoul(
        soulId: 'soul-upd',
        displayName: 'New Name',
      );

      expect(updated.displayName, 'New Name');
      verify(() => mockSync.upsertEntity(any())).called(1);
    });

    test('throws when soul not found', () async {
      when(
        () => mockRepo.getSoulDocument('ghost'),
      ).thenAnswer((_) async => null);

      expect(
        () => service.updateSoul(soulId: 'ghost', displayName: 'X'),
        throwsA(isA<StateError>()),
      );
    });

    test('preserves display name when not provided', () async {
      final soul = makeTestSoulDocument(
        id: 'soul-upd',
        displayName: 'Keep This',
      );
      when(
        () => mockRepo.getSoulDocument('soul-upd'),
      ).thenAnswer((_) async => soul);

      final updated = await service.updateSoul(soulId: 'soul-upd');

      expect(updated.displayName, 'Keep This');
    });

    test('rejects whitespace-only display name before touching repo', () async {
      await expectLater(
        () => service.updateSoul(soulId: 'soul-upd', displayName: '   '),
        throwsA(isA<ArgumentError>()),
      );

      // The blank guard runs before the transaction, so nothing is read or
      // written.
      verifyNever(() => mockRepo.getSoulDocument(any()));
      verifyNever(() => mockSync.upsertEntity(any()));
    });
  });

  group('updateSoulAndCreateVersion', () {
    test('updates name and creates version in one transaction', () async {
      final soul = makeTestSoulDocument(
        id: 'soul-atomic',
        displayName: 'Old Name',
      );
      final existingVersion = makeTestSoulDocumentVersion(
        agentId: 'soul-atomic',
      );
      final existingHead = makeTestSoulDocumentHead(
        agentId: 'soul-atomic',
      );

      when(
        () => mockRepo.getSoulDocument('soul-atomic'),
      ).thenAnswer((_) async => soul);
      when(
        () => mockRepo.getSoulDocumentHead('soul-atomic'),
      ).thenAnswer((_) async => existingHead);
      when(
        () => mockRepo.getSoulDocumentVersions(
          'soul-atomic',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [existingVersion]);
      when(
        () => mockRepo.getNextSoulDocumentVersionNumber('soul-atomic'),
      ).thenAnswer((_) async => 2);

      final result = await service.updateSoulAndCreateVersion(
        soulId: 'soul-atomic',
        displayName: 'New Name',
        voiceDirective: 'New voice.',
        authoredBy: 'user',
      );

      expect(result.version, 2);
      expect(result.voiceDirective, 'New voice.');

      // 4 upserts: updated soul + archived version + new version + head.
      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured;
      expect(captured, hasLength(4));
      expect(captured[0], isA<SoulDocumentEntity>());
      expect(
        (captured[0] as SoulDocumentEntity).displayName,
        'New Name',
      );
    });

    test('skips name update when unchanged', () async {
      final soul = makeTestSoulDocument(
        id: 'soul-same',
        displayName: 'Same Name',
      );
      final existingVersion = makeTestSoulDocumentVersion(
        agentId: 'soul-same',
      );
      final existingHead = makeTestSoulDocumentHead(agentId: 'soul-same');

      when(
        () => mockRepo.getSoulDocument('soul-same'),
      ).thenAnswer((_) async => soul);
      when(
        () => mockRepo.getSoulDocumentHead('soul-same'),
      ).thenAnswer((_) async => existingHead);
      when(
        () => mockRepo.getSoulDocumentVersions(
          'soul-same',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [existingVersion]);
      when(
        () => mockRepo.getNextSoulDocumentVersionNumber('soul-same'),
      ).thenAnswer((_) async => 2);

      await service.updateSoulAndCreateVersion(
        soulId: 'soul-same',
        displayName: 'Same Name',
        voiceDirective: 'Voice.',
        authoredBy: 'user',
      );

      // 3 upserts: archived version + new version + head (no soul update).
      verify(() => mockSync.upsertEntity(any())).called(3);
    });

    test('rejects blank display name', () async {
      await expectLater(
        () => service.updateSoulAndCreateVersion(
          soulId: 'soul-x',
          displayName: '   ',
          voiceDirective: 'Voice.',
          authoredBy: 'user',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when soul not found', () async {
      when(
        () => mockRepo.getSoulDocument('ghost'),
      ).thenAnswer((_) async => null);

      await expectLater(
        () => service.updateSoulAndCreateVersion(
          soulId: 'ghost',
          displayName: 'Name',
          voiceDirective: 'Voice.',
          authoredBy: 'user',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('deleteSoul', () {
    test('soft-deletes soul, versions, and head', () async {
      final soul = makeTestSoulDocument(id: 'soul-del');
      final version = makeTestSoulDocumentVersion(
        id: 'v1',
        agentId: 'soul-del',
      );
      final head = makeTestSoulDocumentHead(
        id: 'head-1',
        agentId: 'soul-del',
        versionId: 'v1',
      );

      when(
        () => mockRepo.getLinksTo('soul-del', type: any(named: 'type')),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepo.getSoulDocument('soul-del'),
      ).thenAnswer((_) async => soul);
      when(
        // ignore: avoid_redundant_argument_values
        () => mockRepo.getSoulDocumentVersions('soul-del', limit: -1),
      ).thenAnswer((_) async => [version]);
      when(
        () => mockRepo.getSoulDocumentHead('soul-del'),
      ).thenAnswer((_) async => head);

      await service.deleteSoul('soul-del');

      // Version soft-deleted.
      final capturedVersion = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured;
      expect(capturedVersion, hasLength(3));
      // Version, head, and soul — all should have deletedAt set.
      expect(
        (capturedVersion[0] as SoulDocumentVersionEntity).deletedAt,
        isNotNull,
      );
      expect(
        (capturedVersion[1] as SoulDocumentHeadEntity).deletedAt,
        isNotNull,
      );
      expect(
        (capturedVersion[2] as SoulDocumentEntity).deletedAt,
        isNotNull,
      );
    });

    test('throws when templates still assigned', () async {
      when(
        () => mockRepo.getLinksTo('soul-del', type: any(named: 'type')),
      ).thenAnswer(
        (_) async => [
          makeTestSoulAssignmentLink(
            fromId: 'tpl-1',
            toId: 'soul-del',
          ),
        ],
      );

      expect(
        () => service.deleteSoul('soul-del'),
        throwsA(isA<StateError>()),
      );
    });

    test('no-ops when soul does not exist', () async {
      when(
        () => mockRepo.getLinksTo('ghost', type: any(named: 'type')),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepo.getSoulDocument('ghost'),
      ).thenAnswer((_) async => null);

      await service.deleteSoul('ghost');

      verifyNever(() => mockSync.upsertEntity(any()));
    });
  });
}
