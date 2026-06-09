import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

void main() {
  late AgentDatabase db;
  late AgentRepository repo;

  final testDate = DateTime(2026, 4, 5);
  const soulId = 'soul-001';
  const soulId2 = 'soul-002';

  SoulDocumentEntity makeSoul({
    String id = soulId,
    String displayName = 'Laura',
  }) =>
      AgentDomainEntity.soulDocument(
            id: id,
            agentId: id,
            displayName: displayName,
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          )
          as SoulDocumentEntity;

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

  SoulDocumentHeadEntity makeHead({
    String id = 'sh-001',
    String agentId = soulId,
    String versionId = 'sv-001',
  }) =>
      AgentDomainEntity.soulDocumentHead(
            id: id,
            agentId: agentId,
            versionId: versionId,
            updatedAt: testDate,
            vectorClock: null,
          )
          as SoulDocumentHeadEntity;

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    repo = AgentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getSoulDocument', () {
    test('returns soul when it exists', () async {
      await repo.upsertEntity(makeSoul());

      final result = await repo.getSoulDocument(soulId);
      expect(result, isNotNull);
      expect(result!.displayName, 'Laura');
    });

    test('returns null when not found', () async {
      final result = await repo.getSoulDocument('nonexistent');
      expect(result, isNull);
    });
  });

  group('getAllSoulDocuments', () {
    test('returns all soul documents', () async {
      await repo.upsertEntity(makeSoul());
      await repo.upsertEntity(makeSoul(id: soulId2, displayName: 'Max'));

      final result = await repo.getAllSoulDocuments();
      expect(result, hasLength(2));
      expect(result.map((s) => s.displayName), containsAll(['Laura', 'Max']));
    });

    test('excludes soft-deleted souls', () async {
      await repo.upsertEntity(makeSoul());
      await repo.upsertEntity(
        makeSoul(id: soulId2, displayName: 'Deleted').copyWith(
          deletedAt: testDate,
        ),
      );

      final result = await repo.getAllSoulDocuments();
      expect(result, hasLength(1));
      expect(result.first.displayName, 'Laura');
    });
  });

  group('getSoulDocumentHead', () {
    test('returns head when it exists', () async {
      await repo.upsertEntity(makeHead());

      final result = await repo.getSoulDocumentHead(soulId);
      expect(result, isNotNull);
      expect(result!.versionId, 'sv-001');
    });

    test('returns null when not found', () async {
      final result = await repo.getSoulDocumentHead('nonexistent');
      expect(result, isNull);
    });
  });

  group('getActiveSoulDocumentVersion', () {
    test('resolves head → version chain', () async {
      await repo.upsertEntity(makeVersion());
      await repo.upsertEntity(makeHead());

      final result = await repo.getActiveSoulDocumentVersion(soulId);
      expect(result, isNotNull);
      expect(result!.voiceDirective, 'Be warm.');
    });

    test('returns null when head missing', () async {
      await repo.upsertEntity(makeVersion());
      // No head inserted.

      final result = await repo.getActiveSoulDocumentVersion(soulId);
      expect(result, isNull);
    });
  });

  group('getActiveSoulDocumentVersionsBySoulIds', () {
    test('resolves each requested soul through its active head', () async {
      await repo.upsertEntity(makeVersion());
      await repo.upsertEntity(makeHead());
      await repo.upsertEntity(
        makeVersion(
          id: 'sv-002',
          agentId: soulId2,
          voiceDirective: 'Be direct.',
        ),
      );
      await repo.upsertEntity(
        makeHead(
          id: 'head-002',
          agentId: soulId2,
          versionId: 'sv-002',
        ),
      );

      final result = await repo.getActiveSoulDocumentVersionsBySoulIds([
        soulId,
        soulId2,
        'missing-soul',
      ]);

      expect(result.keys, unorderedEquals([soulId, soulId2]));
      expect(result[soulId]?.voiceDirective, 'Be warm.');
      expect(result[soulId2]?.voiceDirective, 'Be direct.');
      expect(result['missing-soul'], isNull);
    });

    test(
      'chunks large soul-id lists and ignores newer deleted heads',
      () async {
        const total = 1005;
        final requestedIds = [
          for (var i = 0; i < total; i++) 'chunk-soul-$i',
        ];

        await repo.upsertEntity(
          makeVersion(
            id: 'chunk-version-0',
            agentId: requestedIds[0],
            voiceDirective: 'First chunk.',
          ),
        );
        await repo.upsertEntity(
          makeHead(
            id: 'chunk-head-0',
            agentId: requestedIds[0],
            versionId: 'chunk-version-0',
          ),
        );

        await repo.upsertEntity(
          makeVersion(
            id: 'chunk-version-901-live',
            agentId: requestedIds[901],
            voiceDirective: 'Live head wins.',
          ),
        );
        await repo.upsertEntity(
          makeHead(
            id: 'chunk-head-901-live',
            agentId: requestedIds[901],
            versionId: 'chunk-version-901-live',
          ),
        );
        await repo.upsertEntity(
          makeVersion(
            id: 'chunk-version-901-deleted',
            agentId: requestedIds[901],
            voiceDirective: 'Deleted head must not win.',
          ),
        );
        await repo.upsertEntity(
          makeHead(
            id: 'chunk-head-901-deleted',
            agentId: requestedIds[901],
            versionId: 'chunk-version-901-deleted',
          ).copyWith(
            updatedAt: testDate.add(const Duration(hours: 1)),
            deletedAt: testDate.add(const Duration(hours: 1)),
          ),
        );

        await repo.upsertEntity(
          makeVersion(
            id: 'chunk-version-1004',
            agentId: requestedIds[1004],
            voiceDirective: 'Second chunk.',
          ),
        );
        await repo.upsertEntity(
          makeHead(
            id: 'chunk-head-1004',
            agentId: requestedIds[1004],
            versionId: 'chunk-version-1004',
          ),
        );

        final result = await repo.getActiveSoulDocumentVersionsBySoulIds([
          ...requestedIds,
          requestedIds[901],
        ]);

        expect(
          result.keys,
          unorderedEquals([
            requestedIds[0],
            requestedIds[901],
            requestedIds[1004],
          ]),
        );
        expect(result[requestedIds[0]]?.voiceDirective, 'First chunk.');
        expect(result[requestedIds[901]]?.voiceDirective, 'Live head wins.');
        expect(result[requestedIds[1004]]?.voiceDirective, 'Second chunk.');
      },
    );
  });

  group('getSoulDocumentVersions', () {
    test('returns versions newest first', () async {
      await repo.upsertEntity(makeVersion());
      await repo.upsertEntity(
        makeVersion(
          id: 'sv-002',
          version: 2,
          voiceDirective: 'Be terse.',
        ).copyWith(
          createdAt: testDate.add(const Duration(hours: 1)),
        ),
      );

      final result = await repo.getSoulDocumentVersions(soulId);
      expect(result, hasLength(2));
      // Newest first.
      expect(result.first.version, 2);
      expect(result.last.version, 1);
    });

    test('respects limit', () async {
      await repo.upsertEntity(makeVersion());
      await repo.upsertEntity(
        makeVersion(id: 'sv-002', version: 2).copyWith(
          createdAt: testDate.add(const Duration(hours: 1)),
        ),
      );

      final result = await repo.getSoulDocumentVersions(soulId, limit: 1);
      expect(result, hasLength(1));
    });
  });
}
