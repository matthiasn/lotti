import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/soul_template_ops.dart';
import 'package:lotti/features/agents/service/soul_version_ops.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/constants.dart';
import '../test_data/soul_factories.dart';

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
