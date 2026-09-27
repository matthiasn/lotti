import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';
import 'package:lotti/features/agents/service/agent_template_seeding.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_template_ops.dart';
import 'package:lotti/features/agents/service/soul_version_ops.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../agent_test_device.dart';
import '../test_data/constants.dart';
import '../test_data/soul_factories.dart';
import 'default_seeding_device.dart';

/// Mirror test for the SoulTemplateOps collaborator. Exercises assignment
/// link management, the soul-deletion guard, and the cross-collaborator path
/// where resolveActiveSoulForTemplate reaches into SoulVersionOps.
void main() {
  late MockAgentRepository mockRepo;
  late MockAgentSyncService mockSync;
  late SoulTemplateOps templateOps;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepo = MockAgentRepository();
    mockSync = MockAgentSyncService();

    when(() => mockSync.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSync.upsertLink(any())).thenAnswer((_) async {});

    // A real version-ops over the same mocks, mirroring the production wiring,
    // so the cross-collaborator call in resolveActiveSoulForTemplate is real.
    final versionOps = SoulVersionOps(
      repository: mockRepo,
      syncService: mockSync,
    );
    templateOps = SoulTemplateOps(
      repository: mockRepo,
      syncService: mockSync,
      versionOps: versionOps,
    );
  });

  group('assignSoulToTemplate', () {
    test('soft-deletes stale links then writes a fresh assignment', () async {
      final stale = makeTestSoulAssignmentLink(id: 'stale', toId: 'old-soul');
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => [stale]);

      await templateOps.assignSoulToTemplate(kTestTemplateId, kTestSoulId);

      final captured = verify(
        () => mockSync.upsertLink(captureAny()),
      ).captured.cast<AgentLink>();
      expect(captured, hasLength(2));
      expect(captured[0].deletedAt, isNotNull); // stale link removed
      final fresh = captured[1] as SoulAssignmentLink;
      expect(fresh.deletedAt, isNull);
      expect(fresh.toId, kTestSoulId);
    });

    test('is a no-op when the sole link already points at the soul', () async {
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => [makeTestSoulAssignmentLink()]);

      await templateOps.assignSoulToTemplate(kTestTemplateId, kTestSoulId);

      verifyNever(() => mockSync.upsertLink(any()));
    });
  });

  group('resolveActiveSoulForTemplate', () {
    test(
      'follows link → active version via the version-ops collaborator',
      () async {
        when(
          () => mockRepo.getLinksFrom(
            kTestTemplateId,
            type: AgentLinkTypes.soulAssignment,
          ),
        ).thenAnswer((_) async => [makeTestSoulAssignmentLink()]);
        when(
          () => mockRepo.getActiveSoulDocumentVersion(kTestSoulId),
        ).thenAnswer(
          (_) async => makeTestSoulDocumentVersion(voiceDirective: 'Resolved.'),
        );

        final result = await templateOps.resolveActiveSoulForTemplate(
          kTestTemplateId,
        );
        expect(result?.voiceDirective, 'Resolved.');
      },
    );

    test('returns null when no soul is assigned', () async {
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer((_) async => []);

      expect(
        await templateOps.resolveActiveSoulForTemplate(kTestTemplateId),
        isNull,
      );
    });
  });

  group('deleteSoul', () {
    test('throws when templates still reference the soul', () async {
      when(
        () => mockRepo.getLinksTo(
          kTestSoulId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer(
        (_) async => [makeTestSoulAssignmentLink(fromId: 'tpl-using')],
      );

      await expectLater(
        () => templateOps.deleteSoul(kTestSoulId),
        throwsA(isA<StateError>()),
      );
      verifyNever(() => mockSync.upsertEntity(any()));
    });

    test(
      'soft-deletes versions, head, and the soul when unreferenced',
      () async {
        when(
          () => mockRepo.getLinksTo(
            kTestSoulId,
            type: AgentLinkTypes.soulAssignment,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepo.getSoulDocument(kTestSoulId),
        ).thenAnswer((_) async => makeTestSoulDocument());
        when(
          () => mockRepo.getSoulDocumentVersions(
            kTestSoulId,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [makeTestSoulDocumentVersion()]);
        when(
          () => mockRepo.getSoulDocumentHead(kTestSoulId),
        ).thenAnswer((_) async => makeTestSoulDocumentHead());

        await templateOps.deleteSoul(kTestSoulId);

        final captured = verify(
          () => mockSync.upsertEntity(captureAny()),
        ).captured;
        // version + head + soul, each soft-deleted.
        expect(captured, hasLength(3));
        expect(
          (captured[0] as SoulDocumentVersionEntity).deletedAt,
          isNotNull,
        );
        expect((captured[1] as SoulDocumentHeadEntity).deletedAt, isNotNull);
        expect((captured[2] as SoulDocumentEntity).deletedAt, isNotNull);
      },
    );
  });

  group('seedDefaults (ADR 0100)', () {
    final start = DateTime(2026, 9, 27, 9);
    late DefaultSeedingDevice a;
    late DefaultSeedingDevice b;

    setUp(() {
      a = DefaultSeedingDevice(AgentTestDevice('host-a', background: false));
      b = DefaultSeedingDevice(AgentTestDevice('host-b', background: false));
      addTearDown(a.device.close);
      addTearDown(b.device.close);
    });

    Future<void> at(int minutes, Future<void> Function() action) =>
        withClock(Clock.fixed(start.add(Duration(minutes: minutes))), action);

    /// The user removes the Laura soul: it is assigned to two defaults, so
    /// both are unassigned first, as `deleteSoul` requires.
    Future<void> deleteLauraSoul(DefaultSeedingDevice device) async {
      await device.soulAssignments.unassignSoul(lauraTemplateId);
      await device.soulAssignments.unassignSoul(projectTemplateId);
      await device.soulAssignments.deleteSoul(lauraSoulId);
    }

    Future<List<String>> assignedSouls(
      DefaultSeedingDevice device,
      String templateId,
    ) async => [
      for (final link in await device.device.repository.getLinksFrom(
        templateId,
        type: AgentLinkTypes.soulAssignment,
      ))
        link.toId,
    ];

    test(
      'stamps the default souls and assignments at the seed instant, the '
      'assignment under its deterministic id',
      () async {
        await at(0, a.start);

        final soul = (await a.stored(lauraSoulId))! as SoulDocumentEntity;
        expect(soul.createdAt, agentSeedInstant);
        expect(soul.updatedAt, agentSeedInstant);
        final version = (await a.souls.getActiveSoulVersion(lauraSoulId))!;
        expect(version.createdAt, start, reason: 'the history shows it');

        final link = (await a.storedLink(
          seededSoulAssignmentLinkId(lauraTemplateId),
        ))!;
        expect(link.toId, lauraSoulId);
        expect(link.updatedAt, agentSeedInstant);
        expect(link.deletedAt, isNull);
        expect(await assignedSouls(a, tomTemplateId), [tomSoulId]);
        expect(await assignedSouls(a, projectTemplateId), [lauraSoulId]);
      },
    );

    test(
      'does not seed a default soul the user deleted again, nor assign it',
      () async {
        await at(0, a.start);
        await at(1, () => deleteLauraSoul(a));
        final entitiesBefore = a.device.sentEntities.length;
        final linksBefore = a.device.sentLinks.length;

        await at(2, a.start);

        expect((await a.stored(lauraSoulId))!.deletedAt, isNotNull);
        expect(await assignedSouls(a, lauraTemplateId), isEmpty);
        expect(await assignedSouls(a, projectTemplateId), isEmpty);
        expect(
          a.device.sentEntities
              .skip(entitiesBefore)
              .where((e) => e.agentId == lauraSoulId),
          isEmpty,
          reason: 'nothing of the soul is written',
        );
        expect(a.device.sentLinks.skip(linksBefore), isEmpty);
      },
    );

    test('keeps a soul the user unassigned or replaced', () async {
      await at(0, a.start);
      await at(1, () => a.soulAssignments.unassignSoul(tomTemplateId));
      await at(
        2,
        () =>
            a.soulAssignments.assignSoulToTemplate(lauraTemplateId, maxSoulId),
      );

      await at(3, a.start);

      expect(await assignedSouls(a, tomTemplateId), isEmpty);
      expect(await assignedSouls(a, lauraTemplateId), [maxSoulId]);
    });

    test(
      'does not assign a soul to a default template the user deleted',
      () async {
        // Templates seeded by a build that had no souls yet, so Tom's
        // template has never had an assignment; the user deletes it.
        await at(
          0,
          () => AgentTemplateSeeding(
            syncService: a.device.sync,
            crud: a.templates,
          ).seedDefaults(),
        );
        await at(1, () => a.templates.deleteTemplate(tomTemplateId));

        await at(2, a.start);

        expect(await a.souls.getSoul(tomSoulId), isNotNull);
        expect(await assignedSouls(a, tomTemplateId), isEmpty);
        expect(
          await a.device.repository.hasAnyLinkFrom(
            tomTemplateId,
            type: AgentLinkTypes.soulAssignment,
          ),
          isFalse,
        );
        expect(await assignedSouls(a, lauraTemplateId), [lauraSoulId]);
      },
    );

    test(
      "a peer's deletion of a default soul wins over a later seed of it on a "
      'device that had not received the deletion',
      () async {
        await at(0, a.start);
        await at(1, () => deleteLauraSoul(a));
        // B starts later, before anything of A's reaches it.
        await at(5, b.start);

        await at(6, () => b.receiveAllFrom(a));
        await at(6, () => a.receiveAllFrom(b));

        for (final device in [a, b]) {
          expect(
            (await device.stored(lauraSoulId))!.deletedAt,
            isNotNull,
            reason: device.device.host,
          );
          expect(await assignedSouls(device, lauraTemplateId), isEmpty);
          expect(await assignedSouls(device, projectTemplateId), isEmpty);
        }

        // Neither device brings it back at its next start.
        await at(7, a.start);
        await at(7, b.start);
        for (final device in [a, b]) {
          expect(await device.souls.getSoul(lauraSoulId), isNull);
        }
      },
    );

    test(
      "a peer's unassignment of a default soul wins over a later seed of the "
      'assignment',
      () async {
        await at(0, a.start);
        await at(1, () => a.soulAssignments.unassignSoul(tomTemplateId));
        await at(5, b.start);

        await at(6, () => b.receiveAllFrom(a));
        await at(6, () => a.receiveAllFrom(b));

        for (final device in [a, b]) {
          expect(
            await assignedSouls(device, tomTemplateId),
            isEmpty,
            reason: device.device.host,
          );
        }
      },
    );
  });

  group('getTemplatesUsingSoul', () {
    test('returns the from-ids of reverse assignment links', () async {
      when(
        () => mockRepo.getLinksTo(
          kTestSoulId,
          type: AgentLinkTypes.soulAssignment,
        ),
      ).thenAnswer(
        (_) async => [
          makeTestSoulAssignmentLink(id: 'l1', fromId: 'tpl-a'),
          makeTestSoulAssignmentLink(id: 'l2', fromId: 'tpl-b'),
        ],
      );

      expect(
        await templateOps.getTemplatesUsingSoul(kTestSoulId),
        ['tpl-a', 'tpl-b'],
      );
    });
  });
}
