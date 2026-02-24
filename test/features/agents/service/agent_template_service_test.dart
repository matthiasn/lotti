import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
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

  setUpAll(registerAllFallbackValues);

  /// Stub [mockRepo.getEntity] to return a default template for
  /// [kTestTemplateId]. Call this in tests that need the template to exist.
  void stubTemplateExists() {
    final template = makeTestTemplate();
    when(() => mockRepo.getEntity(kTestTemplateId))
        .thenAnswer((_) async => template);
  }

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

    test('generates UUID when no templateId provided', () async {
      final result = await service.createTemplate(
        displayName: 'Auto',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Directives.',
        authoredBy: 'admin',
      );

      expect(result.id, isNotEmpty);
      expect(result.id, isNot('custom-id'));
      expect(result.modelId, 'models/test');
      expect(result.categoryIds, isEmpty);
    });

    test('creates template with category IDs', () async {
      final result = await service.createTemplate(
        displayName: 'WithCats',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Directives.',
        authoredBy: 'admin',
        categoryIds: {'cat-1', 'cat-2'},
      );

      expect(result.categoryIds, containsAll(['cat-1', 'cat-2']));
    });

    test('upserts version with correct initial values', () async {
      await service.createTemplate(
        displayName: 'Check Version',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Test directives.',
        authoredBy: 'tester',
        templateId: 'tpl-ver-check',
      );

      final captured = verify(() => mockSync.upsertEntity(captureAny()))
          .captured
          .cast<AgentDomainEntity>();

      // Second entity should be the version.
      final version = captured[1] as AgentTemplateVersionEntity;
      expect(version.version, 1);
      expect(version.status, AgentTemplateVersionStatus.active);
      expect(version.directives, 'Test directives.');
      expect(version.authoredBy, 'tester');
      expect(version.agentId, 'tpl-ver-check');
    });
  });

  group('createVersion', () {
    test('archives current version and creates new one', () async {
      stubTemplateExists();
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
      stubTemplateExists();
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

    test('skips archiving when current version entity is not found', () async {
      stubTemplateExists();
      final currentHead = makeTestTemplateHead(versionId: 'ver-gone');

      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => currentHead);
      when(() => mockRepo.getEntity('ver-gone')).thenAnswer((_) async => null);
      when(() => mockRepo.getNextTemplateVersionNumber(kTestTemplateId))
          .thenAnswer((_) async => 2);

      final result = await service.createVersion(
        templateId: kTestTemplateId,
        directives: 'New directives.',
        authoredBy: 'user',
      );

      expect(result.version, 2);

      // 2 upserts: new version + updated head (no archive since old not found).
      verify(() => mockSync.upsertEntity(any())).called(2);
    });

    test('throws when template does not exist', () async {
      when(() => mockRepo.getEntity('nonexistent'))
          .thenAnswer((_) async => null);

      await expectLater(
        service.createVersion(
          templateId: 'nonexistent',
          directives: 'Directives.',
          authoredBy: 'user',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Template nonexistent not found'),
          ),
        ),
      );

      verifyNever(() => mockSync.upsertEntity(any()));
    });
  });

  group('getTemplate', () {
    test('returns template when found', () async {
      stubTemplateExists();

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

    test('returns null when entity is not a template type', () async {
      final version = makeTestTemplateVersion(id: 'ver-001');
      when(() => mockRepo.getEntity('ver-001'))
          .thenAnswer((_) async => version);

      final result = await service.getTemplate('ver-001');
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

    test('returns null when no active version exists', () async {
      when(() => mockRepo.getActiveTemplateVersion(kTestTemplateId))
          .thenAnswer((_) async => null);

      final result = await service.getActiveVersion(kTestTemplateId);

      expect(result, isNull);
    });
  });

  group('getTemplateForAgent', () {
    test('resolves template via link', () async {
      stubTemplateExists();
      final link = makeTestTemplateAssignmentLink();

      when(() => mockRepo.getLinksTo(kTestAgentId, type: 'template_assignment'))
          .thenAnswer((_) async => [link]);

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
    test('returns agent entities from links', () async {
      final agentA = makeTestIdentity(id: 'agent-a', agentId: 'agent-a');
      final agentB = makeTestIdentity(id: 'agent-b', agentId: 'agent-b');
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
      when(() => mockRepo.getEntity('agent-a')).thenAnswer((_) async => agentA);
      when(() => mockRepo.getEntity('agent-b')).thenAnswer((_) async => agentB);

      final result = await service.getAgentsForTemplate(kTestTemplateId);

      expect(result.length, 2);
      expect(result.map((a) => a.id), containsAll(['agent-a', 'agent-b']));
    });

    test('returns empty list when no assignments exist', () async {
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => []);

      final result = await service.getAgentsForTemplate(kTestTemplateId);

      expect(result, isEmpty);
    });

    test('skips links pointing to non-agent entities', () async {
      final links = [
        makeTestTemplateAssignmentLink(id: 'l1', toId: 'not-an-agent'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      // Return a template entity instead of an agent.
      when(() => mockRepo.getEntity('not-an-agent'))
          .thenAnswer((_) async => makeTestTemplate(id: 'not-an-agent'));

      final result = await service.getAgentsForTemplate(kTestTemplateId);

      expect(result, isEmpty);
    });

    test('skips links where entity is null', () async {
      final links = [
        makeTestTemplateAssignmentLink(id: 'l1', toId: 'gone'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      when(() => mockRepo.getEntity('gone')).thenAnswer((_) async => null);

      final result = await service.getAgentsForTemplate(kTestTemplateId);

      expect(result, isEmpty);
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

    test('returns empty list when no templates match category', () async {
      final templates = [
        makeTestTemplate(
          id: 'tpl-a',
          agentId: 'tpl-a',
          categoryIds: {'cat-1'},
        ),
      ];
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => templates);

      final result = await service.listTemplatesForCategory('nonexistent-cat');

      expect(result, isEmpty);
    });
  });

  group('deleteTemplate', () {
    test('fails when active instances exist', () async {
      final activeAgent = makeTestIdentity(id: 'agent-a', agentId: 'agent-a');
      final links = [
        makeTestTemplateAssignmentLink(toId: 'agent-a'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      when(() => mockRepo.getEntity('agent-a'))
          .thenAnswer((_) async => activeAgent);

      await expectLater(
        service.deleteTemplate(kTestTemplateId),
        throwsA(isA<StateError>()),
      );
    });

    test('succeeds when all instances are destroyed', () async {
      stubTemplateExists();
      final destroyedAgent = makeTestIdentity(
        id: 'agent-a',
        agentId: 'agent-a',
        lifecycle: AgentLifecycle.destroyed,
      );
      final links = [
        makeTestTemplateAssignmentLink(toId: 'agent-a'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      when(() => mockRepo.getEntity('agent-a'))
          .thenAnswer((_) async => destroyedAgent);
      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => null);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: 'agentTemplateVersion',
        ),
      ).thenAnswer((_) async => []);

      await service.deleteTemplate(kTestTemplateId);

      final captured = verify(() => mockSync.upsertEntity(captureAny()))
          .captured
          .cast<AgentDomainEntity>();
      final deleted = captured.first as AgentTemplateEntity;
      expect(deleted.deletedAt, isNotNull);
    });

    test('soft-deletes template, head, and versions', () async {
      stubTemplateExists();
      final head = makeTestTemplateHead();
      final version = makeTestTemplateVersion();
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => []);
      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => head);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: 'agentTemplateVersion',
        ),
      ).thenAnswer((_) async => [version]);

      await service.deleteTemplate(kTestTemplateId);

      final captured = verify(() => mockSync.upsertEntity(captureAny()))
          .captured
          .cast<AgentDomainEntity>();

      // 3 upserts: template, head, version — all soft-deleted.
      expect(captured.length, 3);

      final deletedTemplate = captured[0] as AgentTemplateEntity;
      expect(deletedTemplate.deletedAt, isNotNull);

      final deletedHead = captured[1] as AgentTemplateHeadEntity;
      expect(deletedHead.deletedAt, isNotNull);

      final deletedVersion = captured[2] as AgentTemplateVersionEntity;
      expect(deletedVersion.deletedAt, isNotNull);
    });

    test('no-op when template does not exist', () async {
      when(
        () => mockRepo.getLinksFrom(
          'missing',
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => []);
      when(() => mockRepo.getEntity('missing')).thenAnswer((_) async => null);

      await service.deleteTemplate('missing');

      verifyNever(() => mockSync.upsertEntity(any()));
    });

    test('fails with mix of active and destroyed instances', () async {
      final activeAgent = makeTestIdentity(id: 'agent-a', agentId: 'agent-a');
      final destroyedAgent = makeTestIdentity(
        id: 'agent-b',
        agentId: 'agent-b',
        lifecycle: AgentLifecycle.destroyed,
      );
      final links = [
        makeTestTemplateAssignmentLink(toId: 'agent-a'),
        makeTestTemplateAssignmentLink(id: 'l2', toId: 'agent-b'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      when(() => mockRepo.getEntity('agent-a'))
          .thenAnswer((_) async => activeAgent);
      when(() => mockRepo.getEntity('agent-b'))
          .thenAnswer((_) async => destroyedAgent);

      await expectLater(
        service.deleteTemplate(kTestTemplateId),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('1 active instance(s)'),
          ),
        ),
      );
    });
  });

  group('rollbackToVersion', () {
    test('archives current, reactivates target, updates head', () async {
      final currentVersion = makeTestTemplateVersion(
        id: 'ver-old',
        // ignore: avoid_redundant_argument_values
        status: AgentTemplateVersionStatus.active,
      );
      final head = makeTestTemplateHead(versionId: 'ver-old');
      final targetVersion = makeTestTemplateVersion(
        id: 'ver-new',
        // ignore: avoid_redundant_argument_values
        agentId: kTestTemplateId,
        status: AgentTemplateVersionStatus.archived,
      );
      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => head);
      when(() => mockRepo.getEntity('ver-new'))
          .thenAnswer((_) async => targetVersion);
      when(() => mockRepo.getEntity('ver-old'))
          .thenAnswer((_) async => currentVersion);

      await service.rollbackToVersion(
        templateId: kTestTemplateId,
        versionId: 'ver-new',
      );

      final captured = verify(() => mockSync.upsertEntity(captureAny()))
          .captured
          .cast<AgentDomainEntity>();

      // 3 upserts: archive current, reactivate target, update head.
      expect(captured.length, 3);

      final archivedCurrent = captured[0] as AgentTemplateVersionEntity;
      expect(archivedCurrent.id, 'ver-old');
      expect(archivedCurrent.status, AgentTemplateVersionStatus.archived);

      final reactivatedTarget = captured[1] as AgentTemplateVersionEntity;
      expect(reactivatedTarget.id, 'ver-new');
      expect(reactivatedTarget.status, AgentTemplateVersionStatus.active);

      final updatedHead = captured[2] as AgentTemplateHeadEntity;
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

    test('throws when version does not exist', () async {
      final head = makeTestTemplateHead(versionId: 'ver-old');
      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => head);
      when(() => mockRepo.getEntity('nonexistent'))
          .thenAnswer((_) async => null);

      await expectLater(
        service.rollbackToVersion(
          templateId: kTestTemplateId,
          versionId: 'nonexistent',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No version nonexistent found for template'),
          ),
        ),
      );
    });

    test('throws when version belongs to different template', () async {
      final head = makeTestTemplateHead(versionId: 'ver-old');
      final wrongTemplateVersion = makeTestTemplateVersion(
        id: 'ver-other',
        agentId: 'other-template-id',
      );
      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => head);
      when(() => mockRepo.getEntity('ver-other'))
          .thenAnswer((_) async => wrongTemplateVersion);

      await expectLater(
        service.rollbackToVersion(
          templateId: kTestTemplateId,
          versionId: 'ver-other',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No version ver-other found for template'),
          ),
        ),
      );
    });

    test('throws when entity is not a version type', () async {
      final head = makeTestTemplateHead(versionId: 'ver-old');
      final nonVersion = makeTestTemplate(id: 'not-a-version');
      when(() => mockRepo.getTemplateHead(kTestTemplateId))
          .thenAnswer((_) async => head);
      when(() => mockRepo.getEntity('not-a-version'))
          .thenAnswer((_) async => nonVersion);

      await expectLater(
        service.rollbackToVersion(
          templateId: kTestTemplateId,
          versionId: 'not-a-version',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('seedDefaults', () {
    test('creates Laura and Tom when neither is seeded', () async {
      when(() => mockRepo.getEntity(lauraTemplateId))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getEntity(tomTemplateId))
          .thenAnswer((_) async => null);

      await service.seedDefaults();

      // 2 templates * 3 entities each = 6 upserts.
      verify(() => mockSync.upsertEntity(any())).called(6);
    });

    test('skips creation when both already seeded', () async {
      final laura = makeTestTemplate(
        id: lauraTemplateId,
        agentId: lauraTemplateId,
      );
      final tom = makeTestTemplate(
        id: tomTemplateId,
        agentId: tomTemplateId,
      );
      when(() => mockRepo.getEntity(lauraTemplateId))
          .thenAnswer((_) async => laura);
      when(() => mockRepo.getEntity(tomTemplateId))
          .thenAnswer((_) async => tom);

      await service.seedDefaults();

      verifyNever(() => mockSync.upsertEntity(any()));
    });

    test('seeds only Tom when Laura already exists', () async {
      final laura = makeTestTemplate(
        id: lauraTemplateId,
        agentId: lauraTemplateId,
      );
      when(() => mockRepo.getEntity(lauraTemplateId))
          .thenAnswer((_) async => laura);
      when(() => mockRepo.getEntity(tomTemplateId))
          .thenAnswer((_) async => null);

      await service.seedDefaults();

      // Only Tom: 3 entities (template + version + head).
      verify(() => mockSync.upsertEntity(any())).called(3);
    });

    test('seeds only Laura when Tom already exists', () async {
      final tom = makeTestTemplate(
        id: tomTemplateId,
        agentId: tomTemplateId,
      );
      when(() => mockRepo.getEntity(lauraTemplateId))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getEntity(tomTemplateId))
          .thenAnswer((_) async => tom);

      await service.seedDefaults();

      // Only Laura: 3 entities (template + version + head).
      verify(() => mockSync.upsertEntity(any())).called(3);
    });
  });

  group('getVersionHistory', () {
    test('returns versions sorted by version number descending', () async {
      final v1 = makeTestTemplateVersion(id: 'v1');
      final v3 = makeTestTemplateVersion(id: 'v3', version: 3);
      final v2 = makeTestTemplateVersion(id: 'v2', version: 2);

      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: 'agentTemplateVersion',
          limit: 100,
        ),
      ).thenAnswer((_) async => [v1, v3, v2]);

      final result = await service.getVersionHistory(kTestTemplateId);

      expect(result, hasLength(3));
      expect(result[0].version, 3);
      expect(result[1].version, 2);
      expect(result[2].version, 1);
    });

    test('returns empty list when no versions exist', () async {
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: 'agentTemplateVersion',
          limit: 100,
        ),
      ).thenAnswer((_) async => []);

      final result = await service.getVersionHistory(kTestTemplateId);

      expect(result, isEmpty);
    });

    test('filters out non-version entity types', () async {
      final v1 = makeTestTemplateVersion(id: 'v1');
      final report = makeTestReport(id: 'r1');

      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: 'agentTemplateVersion',
          limit: 100,
        ),
      ).thenAnswer((_) async => [v1, report]);

      final result = await service.getVersionHistory(kTestTemplateId);

      expect(result, hasLength(1));
      expect(result[0].id, 'v1');
    });
  });

  group('computeMetrics', () {
    void stubAgentsForTemplate(List<AgentIdentityEntity> agents) {
      final links = agents
          .map(
            (a) => makeTestTemplateAssignmentLink(
              id: 'link-${a.id}',
              toId: a.id,
            ),
          )
          .toList();
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      for (final agent in agents) {
        when(() => mockRepo.getEntity(agent.id)).thenAnswer((_) async => agent);
      }
    }

    test('returns zeroed metrics when no runs exist', () async {
      when(() => mockRepo.getWakeRunsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => []);
      stubAgentsForTemplate([]);

      final metrics = await service.computeMetrics(kTestTemplateId);

      expect(metrics.templateId, kTestTemplateId);
      expect(metrics.totalWakes, 0);
      expect(metrics.successCount, 0);
      expect(metrics.failureCount, 0);
      expect(metrics.successRate, 0.0);
      expect(metrics.averageDuration, isNull);
      expect(metrics.firstWakeAt, isNull);
      expect(metrics.lastWakeAt, isNull);
      expect(metrics.activeInstanceCount, 0);
    });

    test('computes counts and success rate from mixed statuses', () async {
      final runs = [
        makeTestWakeRun(
          runKey: 'r1',
          status: 'completed',
          createdAt: DateTime(2024, 3, 15, 12),
        ),
        makeTestWakeRun(
          runKey: 'r2',
          status: 'failed',
          createdAt: DateTime(2024, 3, 15, 11),
        ),
        makeTestWakeRun(
          runKey: 'r3',
          status: 'completed',
          createdAt: DateTime(2024, 3, 15, 10),
        ),
        makeTestWakeRun(
          runKey: 'r4',
          createdAt: DateTime(2024, 3, 15, 9),
        ),
      ];
      when(() => mockRepo.getWakeRunsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => runs);
      stubAgentsForTemplate([]);

      final metrics = await service.computeMetrics(kTestTemplateId);

      expect(metrics.totalWakes, 4);
      expect(metrics.successCount, 2);
      expect(metrics.failureCount, 1);
      // 2 successes / 3 terminal (2 completed + 1 failed) — running excluded.
      expect(metrics.successRate, closeTo(2 / 3, 0.001));
    });

    test('computes average duration from completed runs with timestamps',
        () async {
      final runs = [
        makeTestWakeRun(
          runKey: 'r1',
          status: 'completed',
          createdAt: DateTime(2024, 3, 15, 12),
          startedAt: DateTime(2024, 3, 15, 12),
          completedAt: DateTime(2024, 3, 15, 12, 0, 10), // 10s
        ),
        makeTestWakeRun(
          runKey: 'r2',
          status: 'completed',
          createdAt: DateTime(2024, 3, 15, 11),
          startedAt: DateTime(2024, 3, 15, 11),
          completedAt: DateTime(2024, 3, 15, 11, 0, 20), // 20s
        ),
        // This run has no timestamps — should be skipped for avg.
        makeTestWakeRun(
          runKey: 'r3',
          status: 'completed',
          createdAt: DateTime(2024, 3, 15, 10),
        ),
      ];
      when(() => mockRepo.getWakeRunsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => runs);
      stubAgentsForTemplate([]);

      final metrics = await service.computeMetrics(kTestTemplateId);

      // Average of 10s and 20s = 15s.
      expect(metrics.averageDuration, const Duration(seconds: 15));
    });

    test('firstWakeAt is oldest, lastWakeAt is newest (DESC order)', () async {
      final runs = [
        makeTestWakeRun(
          runKey: 'newest',
          status: 'completed',
          createdAt: DateTime(2024, 3, 20),
        ),
        makeTestWakeRun(
          runKey: 'oldest',
          status: 'completed',
          createdAt: DateTime(2024, 3, 10),
        ),
      ];
      when(() => mockRepo.getWakeRunsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => runs);
      stubAgentsForTemplate([]);

      final metrics = await service.computeMetrics(kTestTemplateId);

      // Runs are DESC: first = newest, last = oldest.
      expect(metrics.lastWakeAt, DateTime(2024, 3, 20));
      expect(metrics.firstWakeAt, DateTime(2024, 3, 10));
    });

    test('activeInstanceCount counts only active agents', () async {
      when(() => mockRepo.getWakeRunsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => []);
      stubAgentsForTemplate([
        makeTestIdentity(id: 'a1', agentId: 'a1'),
        makeTestIdentity(
          id: 'a2',
          agentId: 'a2',
          lifecycle: AgentLifecycle.destroyed,
        ),
        makeTestIdentity(
          id: 'a3',
          agentId: 'a3',
          lifecycle: AgentLifecycle.dormant,
        ),
        makeTestIdentity(id: 'a4', agentId: 'a4'),
      ]);

      final metrics = await service.computeMetrics(kTestTemplateId);

      // Only a1 and a4 are active; a2 is destroyed, a3 is dormant.
      expect(metrics.activeInstanceCount, 2);
    });
  });
}
