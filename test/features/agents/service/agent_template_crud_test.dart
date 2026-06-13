// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_crud.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/constants.dart';
import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';
import '../test_data/template_factories.dart';

/// Mirror test for the [AgentTemplateCrud] collaborator extracted from
/// [AgentTemplateService]. Exercises the collaborator directly (constructed
/// with central mocks) to prove it is independently testable.
void main() {
  late MockAgentRepository mockRepo;
  late MockAgentSyncService mockSync;
  late AgentTemplateCrud crud;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepo = MockAgentRepository();
    mockSync = MockAgentSyncService();

    when(() => mockSync.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSync.upsertLink(any())).thenAnswer((_) async {});

    crud = AgentTemplateCrud(
      repository: mockRepo,
      syncService: mockSync,
    );
  });

  group('createTemplate', () {
    test('writes template, version, and head with initial values', () async {
      final result = await crud.createTemplate(
        displayName: 'Laura',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Be helpful.',
        authoredBy: 'user',
        templateId: 'tpl-fixed',
      );

      expect(result.id, 'tpl-fixed');
      expect(result.displayName, 'Laura');
      expect(result.kind, AgentTemplateKind.taskAgent);

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      expect(captured, hasLength(3));
      expect(captured[0], isA<AgentTemplateEntity>());

      final version = captured[1] as AgentTemplateVersionEntity;
      expect(version.version, 1);
      expect(version.status, AgentTemplateVersionStatus.active);
      expect(version.directives, 'Be helpful.');
      expect(captured[2], isA<AgentTemplateHeadEntity>());
    });
  });

  group('getTemplate', () {
    test('returns the template when the entity is a template', () async {
      final template = makeTestTemplate(displayName: 'Mapped');
      when(
        () => mockRepo.getEntity(kTestTemplateId),
      ).thenAnswer((_) async => template);

      final result = await crud.getTemplate(kTestTemplateId);
      expect(result?.displayName, 'Mapped');
    });

    test('returns null when the entity is a non-template type', () async {
      when(
        () => mockRepo.getEntity(kTestTemplateId),
      ).thenAnswer((_) async => makeTestTemplateVersion());

      expect(await crud.getTemplate(kTestTemplateId), isNull);
    });
  });

  group('createVersion', () {
    test('archives non-archived versions and advances the head', () async {
      final template = makeTestTemplate();
      final activeVersion = makeTestTemplateVersion(id: 'v-active');
      final head = makeTestTemplateHead(versionId: 'v-active');

      when(
        () => mockRepo.getEntity(kTestTemplateId),
      ).thenAnswer((_) async => template);
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <AgentDomainEntity>[activeVersion]);
      when(
        () => mockRepo.getNextTemplateVersionNumber(kTestTemplateId),
      ).thenAnswer((_) async => 2);

      final newVersion = await crud.createVersion(
        templateId: kTestTemplateId,
        directives: 'New directives.',
        authoredBy: 'system',
      );

      expect(newVersion.version, 2);
      expect(newVersion.status, AgentTemplateVersionStatus.active);
      expect(newVersion.directives, 'New directives.');

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      // archive old active + new version + updated head = 3 writes.
      expect(captured, hasLength(3));
      final archived = captured[0] as AgentTemplateVersionEntity;
      expect(archived.status, AgentTemplateVersionStatus.archived);
      final updatedHead = captured[2] as AgentTemplateHeadEntity;
      expect(updatedHead.id, head.id); // reused head id
      expect(updatedHead.versionId, newVersion.id);
    });

    test('throws when the template does not exist', () async {
      when(
        () => mockRepo.getEntity('missing'),
      ).thenAnswer((_) async => null);

      await expectLater(
        () => crud.createVersion(
          templateId: 'missing',
          directives: 'x',
          authoredBy: 'system',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('deleteTemplate', () {
    test('throws TemplateInUseException when active agents exist', () async {
      final agent = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: any(named: 'type'),
        ),
      ).thenAnswer(
        (_) async => [
          makeTestTemplateAssignmentLink(
            fromId: kTestTemplateId,
            toId: agent.id,
          ),
        ],
      );
      when(
        () => mockRepo.getEntity(agent.id),
      ).thenAnswer((_) async => agent);

      await expectLater(
        () => crud.deleteTemplate(kTestTemplateId),
        throwsA(isA<TemplateInUseException>()),
      );
      verifyNever(() => mockSync.upsertEntity(any()));
    });

    test('soft-deletes template, head, and versions when no active '
        'agents block it', () async {
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => []);
      final template = makeTestTemplate();
      when(
        () => mockRepo.getEntity(kTestTemplateId),
      ).thenAnswer((_) async => template);
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => makeTestTemplateHead());
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
        ),
      ).thenAnswer((_) async => <AgentDomainEntity>[makeTestTemplateVersion()]);

      await crud.deleteTemplate(kTestTemplateId);

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      // template + head + version, each carrying a deletedAt.
      expect(captured, hasLength(3));
      expect((captured[0] as AgentTemplateEntity).deletedAt, isNotNull);
      expect((captured[1] as AgentTemplateHeadEntity).deletedAt, isNotNull);
      expect((captured[2] as AgentTemplateVersionEntity).deletedAt, isNotNull);
    });
  });

  group('getVersionHistory', () {
    test('returns versions sorted newest-first', () async {
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => <AgentDomainEntity>[
          makeTestTemplateVersion(id: 'v1', version: 1),
          makeTestTemplateVersion(id: 'v3', version: 3),
          makeTestTemplateVersion(id: 'v2', version: 2),
        ],
      );

      final history = await crud.getVersionHistory(kTestTemplateId);
      expect(history.map((v) => v.version), [3, 2, 1]);
    });
  });
}
