import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/soul_version_ops.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/constants.dart';
import '../test_data/soul_factories.dart';

/// Mirror test for the [SoulVersionOps] collaborator. Covers the soul-document
/// create path and the version-creation chain (archive + new active + head),
/// which together with getActiveSoulVersion are the methods SoulTemplateOps
/// and the facade depend on.
void main() {
  late MockAgentRepository mockRepo;
  late MockAgentSyncService mockSync;
  late SoulVersionOps versionOps;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepo = MockAgentRepository();
    mockSync = MockAgentSyncService();

    when(() => mockSync.upsertEntity(any())).thenAnswer((_) async {});

    versionOps = SoulVersionOps(
      repository: mockRepo,
      syncService: mockSync,
    );
  });

  group('createSoul', () {
    test('writes soul, active version, and head', () async {
      when(() => mockRepo.getSoulDocument(any())).thenAnswer((_) async => null);

      final soul = await versionOps.createSoul(
        soulId: 'soul-x',
        displayName: 'Aria',
        voiceDirective: 'Be warm.',
        authoredBy: 'user',
        toneBounds: 'No sarcasm.',
      );

      expect(soul.id, 'soul-x');
      expect(soul.displayName, 'Aria');

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      expect(captured, hasLength(3));
      expect(captured[0], isA<SoulDocumentEntity>());
      final version = captured[1] as SoulDocumentVersionEntity;
      expect(version.version, 1);
      expect(version.status, SoulDocumentVersionStatus.active);
      expect(version.voiceDirective, 'Be warm.');
      expect(version.toneBounds, 'No sarcasm.');
      expect(captured[2], isA<SoulDocumentHeadEntity>());
    });

    test('throws when the soul already exists', () async {
      when(
        () => mockRepo.getSoulDocument('dup'),
      ).thenAnswer((_) async => makeTestSoulDocument(id: 'dup'));

      await expectLater(
        () => versionOps.createSoul(
          soulId: 'dup',
          displayName: 'Dup',
          voiceDirective: 'Voice.',
          authoredBy: 'user',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a blank required field before any write', () async {
      await expectLater(
        () => versionOps.createSoul(
          displayName: '   ',
          voiceDirective: 'Voice.',
          authoredBy: 'user',
        ),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(() => mockSync.upsertEntity(any()));
    });
  });

  group('createVersion', () {
    test('archives the active version, creates a new one, and reuses the '
        'head id and clock, so the head moves even past a clock running '
        'ahead — ADR 0068 addendum', () async {
      final soul = makeTestSoulDocument();
      final activeVersion = makeTestSoulDocumentVersion(id: 'v-active');
      final head = makeTestSoulDocumentHead(
        versionId: 'v-active',
        updatedAt: DateTime(2099),
        vectorClock: const VectorClock({'peer': 4}),
      );

      when(
        () => mockRepo.getSoulDocument(kTestSoulId),
      ).thenAnswer((_) async => soul);
      when(
        () => mockRepo.getSoulDocumentHead(kTestSoulId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getSoulDocumentVersions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [activeVersion]);
      when(
        () => mockRepo.getNextSoulDocumentVersionNumber(kTestSoulId),
      ).thenAnswer((_) async => 2);

      final newVersion = await versionOps.createVersion(
        soulId: kTestSoulId,
        voiceDirective: 'New voice.',
        authoredBy: 'evolution_agent',
      );

      expect(newVersion.version, 2);
      expect(newVersion.status, SoulDocumentVersionStatus.active);
      expect(newVersion.voiceDirective, 'New voice.');
      expect(newVersion.diffFromVersionId, head.versionId);

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      // archive old + new version + updated head = 3 writes.
      expect(captured, hasLength(3));
      expect(
        (captured[0] as SoulDocumentVersionEntity).status,
        SoulDocumentVersionStatus.archived,
      );
      expect((captured[2] as SoulDocumentHeadEntity).id, head.id);
      // What AgentSyncService persists for this move over the stored head.
      final resolved =
          resolveLocalAgentWrite(persisted: head, write: captured[2])
              as SoulDocumentHeadEntity;
      expect(resolved.versionId, newVersion.id);
    });

    test('updateSoulAndCreateVersion moves the head carrying its clock, so '
        'the move survives a head stamped by a clock running ahead — ADR 0068 '
        'addendum', () async {
      final soul = makeTestSoulDocument();
      final head = makeTestSoulDocumentHead(
        versionId: 'v-active',
        updatedAt: DateTime(2099),
        vectorClock: const VectorClock({'peer': 4}),
      );
      when(
        () => mockRepo.getSoulDocument(kTestSoulId),
      ).thenAnswer((_) async => soul);
      when(
        () => mockRepo.getSoulDocumentHead(kTestSoulId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getSoulDocumentVersions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [makeTestSoulDocumentVersion(id: 'v-active')],
      );
      when(
        () => mockRepo.getNextSoulDocumentVersionNumber(kTestSoulId),
      ).thenAnswer((_) async => 2);

      final newVersion = await versionOps.updateSoulAndCreateVersion(
        soulId: kTestSoulId,
        displayName: soul.displayName,
        voiceDirective: 'New voice.',
        authoredBy: 'user',
      );

      final moved = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.whereType<SoulDocumentHeadEntity>().single;
      // What AgentSyncService persists for this move over the stored head.
      final resolved =
          resolveLocalAgentWrite(persisted: head, write: moved)
              as SoulDocumentHeadEntity;
      expect(resolved.versionId, newVersion.id);
    });

    test('throws when the soul is missing', () async {
      when(
        () => mockRepo.getSoulDocument('missing'),
      ).thenAnswer((_) async => null);

      await expectLater(
        () => versionOps.createVersion(
          soulId: 'missing',
          voiceDirective: 'Voice.',
          authoredBy: 'user',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('getActiveSoulVersion', () {
    test('delegates to the repository', () async {
      final version = makeTestSoulDocumentVersion(voiceDirective: 'Active.');
      when(
        () => mockRepo.getActiveSoulDocumentVersion(kTestSoulId),
      ).thenAnswer((_) async => version);

      final result = await versionOps.getActiveSoulVersion(kTestSoulId);
      expect(result?.voiceDirective, 'Active.');
    });
  });
}
