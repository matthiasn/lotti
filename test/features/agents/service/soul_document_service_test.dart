import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    // Property: ANY whitespace-only value in any of the three required
    // fields trips the non-blank guard, not just '' and '  '.
    glados.Glados2(
      glados.AnyUtils(
        glados.any,
      ).choose(const ['', ' ', '   ', '\t', '\n', ' \t\n ']),
      glados.IntAnys(glados.any).intInRange(0, 3),
      glados.ExploreConfig(numRuns: 60),
    ).test('rejects whitespace-only required fields', (blank, fieldSlot) {
      expect(
        () => service.createSoul(
          displayName: fieldSlot == 0 ? blank : 'Name',
          voiceDirective: fieldSlot == 1 ? blank : 'Voice.',
          authoredBy: fieldSlot == 2 ? blank : 'user',
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'field $fieldSlot blank="$blank"',
      );
    }, tags: 'glados');

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
        () => mockRepo.getSoulDocumentVersions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
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

    test(
      'collapses multiple stale links (sync-race residue) even when one '
      'already points at the requested soul',
      () async {
        // Two links from a sync race: a stale one plus a matching one. The
        // single-link no-op guard must NOT fire — both get soft-deleted and
        // one fresh link is written.
        final staleLink = makeTestSoulAssignmentLink(
          id: 'link-stale',
          toId: 'old-soul',
        );
        final matchingLink = makeTestSoulAssignmentLink(id: 'link-match');
        when(
          () => mockRepo.getLinksFrom(
            kTestTemplateId,
            type: AgentLinkTypes.soulAssignment,
          ),
        ).thenAnswer((_) async => [staleLink, matchingLink]);

        await service.assignSoulToTemplate(kTestTemplateId, kTestSoulId);

        final captured = verify(
          () => mockSync.upsertLink(captureAny()),
        ).captured;
        // Two soft-deletes + one fresh link.
        expect(captured, hasLength(3));
        expect((captured[0] as AgentLink).deletedAt, isNotNull);
        expect((captured[1] as AgentLink).deletedAt, isNotNull);
        final fresh = captured[2] as SoulAssignmentLink;
        expect(fresh.deletedAt, isNull);
        expect(fresh.toId, kTestSoulId);
      },
    );
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

  group('resolveActiveSoulsForTemplates', () {
    test(
      'resolves active soul versions through batched link/head fetches',
      () async {
        final older = makeTestSoulAssignmentLink(
          id: 'older',
          fromId: 'tpl-a',
          toId: 'soul-old',
          // ignore: avoid_redundant_argument_values
          createdAt: DateTime(2024, 1),
        );
        final newer = makeTestSoulAssignmentLink(
          id: 'newer',
          fromId: 'tpl-a',
          toId: 'soul-new',
          createdAt: DateTime(2024, 2),
        );
        final version = makeTestSoulDocumentVersion(
          id: 'soul-new-version',
          agentId: 'soul-new',
          voiceDirective: 'New voice',
        );

        when(
          () => mockRepo.getLinksFromMultiple(
            any<List<String>>(),
            type: AgentLinkTypes.soulAssignment,
          ),
        ).thenAnswer(
          (_) async => {
            'tpl-a': [older, newer],
            'tpl-b': [
              makeTestSoulAssignmentLink(
                id: 'broken',
                fromId: 'tpl-b',
                toId: 'missing-soul',
              ),
            ],
            'tpl-c': [
              makeTestSoulAssignmentLink(
                id: 'same-soul',
                fromId: 'tpl-c',
                toId: 'soul-new',
              ),
            ],
          },
        );
        when(
          () => mockRepo.getActiveSoulDocumentVersionsBySoulIds(
            any<List<String>>(),
          ),
        ).thenAnswer((_) async => {'soul-new': version});

        final result = await service.resolveActiveSoulsForTemplates([
          'tpl-a',
          'tpl-b',
          'tpl-c',
        ]);

        expect(result.keys, unorderedEquals(['tpl-a', 'tpl-c']));
        expect(result['tpl-a']?.voiceDirective, 'New voice');
        expect(result['tpl-c']?.voiceDirective, 'New voice');
        final capturedSoulIds =
            verify(
                  () => mockRepo.getActiveSoulDocumentVersionsBySoulIds(
                    captureAny<List<String>>(),
                  ),
                ).captured.single
                as List<String>;
        expect(capturedSoulIds, unorderedEquals(['soul-new', 'missing-soul']));
      },
    );
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
}
