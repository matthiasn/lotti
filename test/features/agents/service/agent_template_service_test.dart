import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockAgentRepository mockRepo;
  late MockAgentSyncService mockSync;
  late AgentTemplateService service;

  setUp(() {
    mockRepo = MockAgentRepository();
    mockSync = MockAgentSyncService();

    // Stub sync service to delegate to repo stubs.
    when(() => mockSync.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSync.upsertLink(any())).thenAnswer((_) async {});

    service = AgentTemplateService(
      repository: mockRepo,
      syncService: mockSync,
    );
  });

  setUpAll(() {
    registerFallbackValue(
      AgentDomainEntity.unknown(
        id: '',
        agentId: '',
        createdAt: DateTime(2024),
      ),
    );
    registerFallbackValue(
      model.AgentLink.basic(
        id: '',
        fromId: '',
        toId: '',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      ),
    );
  });

  group('createTemplate', () {
    test('creates template, version, and head entities', () async {
      final result = await service.createTemplate(
        displayName: 'Laura',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Be helpful.',
        authoredBy: 'user',
        templateId: 'tpl-fixed',
      );

      expect(result.displayName, 'Laura');
      expect(result.kind, AgentTemplateKind.taskAgent);
      expect(result.id, 'tpl-fixed');

      // Should have upserted 3 entities (template + version + head).
      verify(() => mockSync.upsertEntity(any())).called(3);
    });

    test('uses provided templateId', () async {
      final result = await service.createTemplate(
        displayName: 'Custom',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Directives.',
        authoredBy: 'admin',
        templateId: 'custom-id',
      );

      expect(result.id, 'custom-id');
      expect(result.agentId, 'custom-id');
    });
  });

  group('createVersion', () {
    test('archives current version and creates new one', () async {
      final currentVersion = makeTestTemplateVersion(
        id: 'ver-old',
      );
      final currentHead = makeTestTemplateHead(versionId: 'ver-old');

      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => currentHead);
      when(() => mockRepo.getEntity('ver-old'))
          .thenAnswer((_) async => currentVersion);
      when(() => mockRepo.getNextTemplateVersionNumber(kTestTemplateId))
          .thenAnswer((_) async => 2);

      final result = await service.createVersion(
        templateId: kTestTemplateId,
        directives: 'Updated directives.',
        authoredBy: 'admin',
      );

      expect(result.version, 2);
      expect(result.status, AgentTemplateVersionStatus.active);
      expect(result.directives, 'Updated directives.');

      // 3 upserts: archived old version, new version, updated head.
      verify(() => mockSync.upsertEntity(any())).called(3);
    });

    test('creates first version when no head exists', () async {
      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getNextTemplateVersionNumber(kTestTemplateId))
          .thenAnswer((_) async => 1);

      final result = await service.createVersion(
        templateId: kTestTemplateId,
        directives: 'First directives.',
        authoredBy: 'user',
      );

      expect(result.version, 1);

      // 2 upserts: new version + new head (no old version to archive).
      verify(() => mockSync.upsertEntity(any())).called(2);
    });
  });

  group('getTemplate', () {
    test('returns template when found', () async {
      final template = makeTestTemplate();
      when(() => mockRepo.getEntity(kTestTemplateId))
          .thenAnswer((_) async => template);

      final result = await service.getTemplate(kTestTemplateId);

      expect(result, isNotNull);
      expect(result!.displayName, 'Test Template');
    });

    test('returns null when not found', () async {
      when(() => mockRepo.getEntity('nonexistent'))
          .thenAnswer((_) async => null);

      final result = await service.getTemplate('nonexistent');
      expect(result, isNull);
    });
  });

  group('listTemplates', () {
    test('delegates to repository', () async {
      final templates = [
        makeTestTemplate(id: 'tpl-a', agentId: 'tpl-a'),
        makeTestTemplate(id: 'tpl-b', agentId: 'tpl-b'),
      ];
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => templates);

      final result = await service.listTemplates();

      expect(result.length, 2);
      verify(() => mockRepo.getAllTemplates()).called(1);
    });
  });

  group('getActiveVersion', () {
    test('delegates to repository', () async {
      final version = makeTestTemplateVersion();
      when(() => mockRepo.getActiveTemplateVersion(kTestTemplateId))
          .thenAnswer((_) async => version);

      final result = await service.getActiveVersion(kTestTemplateId);

      expect(result, isNotNull);
      expect(result!.version, 1);
    });
  });

  group('getTemplateForAgent', () {
    test('resolves template via link', () async {
      final link = makeTestTemplateAssignmentLink();
      final template = makeTestTemplate();

      when(() => mockRepo.getLinksTo(kTestAgentId, type: 'template_assignment'))
          .thenAnswer((_) async => [link]);
      when(() => mockRepo.getEntity(kTestTemplateId))
          .thenAnswer((_) async => template);

      final result = await service.getTemplateForAgent(kTestAgentId);

      expect(result, isNotNull);
      expect(result!.id, kTestTemplateId);
    });

    test('returns null when no link exists', () async {
      when(() => mockRepo.getLinksTo(kTestAgentId, type: 'template_assignment'))
          .thenAnswer((_) async => []);

      final result = await service.getTemplateForAgent(kTestAgentId);
      expect(result, isNull);
    });
  });

  group('getAgentsForTemplate', () {
    test('returns agent IDs from links', () async {
      final links = [
        makeTestTemplateAssignmentLink(id: 'l1', toId: 'agent-a'),
        makeTestTemplateAssignmentLink(id: 'l2', toId: 'agent-b'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);

      final result = await service.getAgentsForTemplate(kTestTemplateId);

      expect(result, containsAll(['agent-a', 'agent-b']));
    });
  });

  group('listTemplatesForCategory', () {
    test('filters by categoryId', () async {
      final templates = [
        makeTestTemplate(
          id: 'tpl-a',
          agentId: 'tpl-a',
          categoryIds: {'cat-1', 'cat-2'},
        ),
        makeTestTemplate(
          id: 'tpl-b',
          agentId: 'tpl-b',
          categoryIds: {'cat-3'},
        ),
      ];
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => templates);

      final result = await service.listTemplatesForCategory('cat-1');

      expect(result.length, 1);
      expect(result.first.id, 'tpl-a');
    });
  });

  group('deleteTemplate', () {
    test('fails when active instances exist', () async {
      final links = [
        makeTestTemplateAssignmentLink(toId: 'agent-a'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);

      await expectLater(
        service.deleteTemplate(kTestTemplateId),
        throwsA(isA<StateError>()),
      );
    });

    test('succeeds when no active instances', () async {
      final template = makeTestTemplate();
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => []);
      when(() => mockRepo.getEntity(kTestTemplateId))
          .thenAnswer((_) async => template);

      await service.deleteTemplate(kTestTemplateId);

      final captured = verify(() => mockSync.upsertEntity(captureAny()))
          .captured
          .last as AgentDomainEntity;
      final deleted = captured as AgentTemplateEntity;
      expect(deleted.deletedAt, isNotNull);
    });
  });

  group('rollbackToVersion', () {
    test('updates head pointer', () async {
      final head = makeTestTemplateHead(versionId: 'ver-old');
      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => head);

      await service.rollbackToVersion(
        templateId: kTestTemplateId,
        versionId: 'ver-new',
      );

      final captured = verify(() => mockSync.upsertEntity(captureAny()))
          .captured
          .last as AgentDomainEntity;
      final updatedHead = captured as AgentTemplateHeadEntity;
      expect(updatedHead.versionId, 'ver-new');
    });

    test('throws when no head exists', () async {
      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => null);

      await expectLater(
        service.rollbackToVersion(
          templateId: kTestTemplateId,
          versionId: 'ver-new',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('seedDefaults', () {
    test('creates Laura and Tom when not seeded', () async {
      when(() => mockRepo.getEntity(lauraTemplateId))
          .thenAnswer((_) async => null);

      await service.seedDefaults();

      // 2 templates * 3 entities each = 6 upserts.
      verify(() => mockSync.upsertEntity(any())).called(6);
    });

    test('skips creation when already seeded', () async {
      final existing = makeTestTemplate(
        id: lauraTemplateId,
        agentId: lauraTemplateId,
      );
      when(() => mockRepo.getEntity(lauraTemplateId))
          .thenAnswer((_) async => existing);

      await service.seedDefaults();

      verifyNever(() => mockSync.upsertEntity(any()));
    });
  });
}
