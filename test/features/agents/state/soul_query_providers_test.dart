import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';

class MockAgentTemplateService extends Mock implements AgentTemplateService {}

class MockSoulDocumentService extends Mock implements SoulDocumentService {}

void main() {
  late MockSoulDocumentService mockService;

  setUp(() {
    mockService = MockSoulDocumentService();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        soulDocumentServiceProvider.overrideWithValue(mockService),
      ],
    );
  }

  group('allSoulDocumentsProvider', () {
    test('returns all souls from service', () async {
      final soul1 = makeTestSoulDocument(id: 'soul-1', displayName: 'Laura');
      final soul2 = makeTestSoulDocument(id: 'soul-2', displayName: 'Tom');
      when(
        () => mockService.getAllSouls(),
      ).thenAnswer((_) async => [soul1, soul2]);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(allSoulDocumentsProvider.future);

      expect(result, hasLength(2));
      expect(result[0], isA<SoulDocumentEntity>());
      expect(result[1], isA<SoulDocumentEntity>());
    });

    test('returns empty list when no souls', () async {
      when(() => mockService.getAllSouls()).thenAnswer((_) async => []);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(allSoulDocumentsProvider.future);

      expect(result, isEmpty);
    });
  });

  group('soulDocumentProvider', () {
    test('returns soul by ID', () async {
      final soul = makeTestSoulDocument(id: 'soul-1', displayName: 'Laura');
      when(() => mockService.getSoul('soul-1')).thenAnswer((_) async => soul);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        soulDocumentProvider('soul-1').future,
      );

      expect(result, isA<SoulDocumentEntity>());
      expect(
        (result! as SoulDocumentEntity).displayName,
        'Laura',
      );
    });

    test('returns null for unknown ID', () async {
      when(() => mockService.getSoul('unknown')).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        soulDocumentProvider('unknown').future,
      );

      expect(result, isNull);
    });
  });

  group('activeSoulVersionProvider', () {
    test('returns active version for soul', () async {
      final version = makeTestSoulDocumentVersion(
        agentId: 'soul-1',
        version: 3,
      );
      when(
        () => mockService.getActiveSoulVersion('soul-1'),
      ).thenAnswer((_) async => version);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        activeSoulVersionProvider('soul-1').future,
      );

      expect(result, isA<SoulDocumentVersionEntity>());
      expect(
        (result! as SoulDocumentVersionEntity).version,
        3,
      );
    });

    test('returns null when no active version', () async {
      when(
        () => mockService.getActiveSoulVersion('soul-1'),
      ).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        activeSoulVersionProvider('soul-1').future,
      );

      expect(result, isNull);
    });
  });

  group('soulVersionHistoryProvider', () {
    test('returns version history for soul', () async {
      final v1 = makeTestSoulDocumentVersion(
        id: 'v1',
        agentId: 'soul-1',
        // ignore: avoid_redundant_argument_values
        version: 1,
      );
      final v2 = makeTestSoulDocumentVersion(
        id: 'v2',
        agentId: 'soul-1',
        version: 2,
      );
      when(
        () => mockService.getVersionHistory('soul-1', limit: -1),
      ).thenAnswer((_) async => [v2, v1]);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        soulVersionHistoryProvider('soul-1').future,
      );

      expect(result, hasLength(2));
      expect(result[0], isA<SoulDocumentVersionEntity>());
    });
  });

  group('soulForTemplateProvider', () {
    test('returns soul version assigned to template', () async {
      final version = makeTestSoulDocumentVersion(
        agentId: 'soul-1',
        version: 2,
      );
      when(
        () => mockService.resolveActiveSoulForTemplate('tpl-1'),
      ).thenAnswer((_) async => version);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        soulForTemplateProvider('tpl-1').future,
      );

      expect(result, isA<SoulDocumentVersionEntity>());
    });

    test('returns null when no soul assigned', () async {
      when(
        () => mockService.resolveActiveSoulForTemplate('tpl-1'),
      ).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        soulForTemplateProvider('tpl-1').future,
      );

      expect(result, isNull);
    });
  });

  group('templatesUsingSoulProvider', () {
    test('returns template IDs using a soul', () async {
      when(
        () => mockService.getTemplatesUsingSoul('soul-1'),
      ).thenAnswer((_) async => ['tpl-1', 'tpl-2']);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templatesUsingSoulProvider('soul-1').future,
      );

      expect(result, ['tpl-1', 'tpl-2']);
    });

    test('returns empty list when no templates use soul', () async {
      when(
        () => mockService.getTemplatesUsingSoul('soul-1'),
      ).thenAnswer((_) async => []);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templatesUsingSoulProvider('soul-1').future,
      );

      expect(result, isEmpty);
    });
  });

  group('soulEvolutionSessionsProvider', () {
    late MockAgentTemplateService mockTemplateService;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
    });

    ProviderContainer createContainerWithTemplate() {
      return ProviderContainer(
        overrides: [
          soulDocumentServiceProvider.overrideWithValue(mockService),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        ],
      );
    }

    test('returns evolution sessions for soul', () async {
      final session = makeTestEvolutionSession(
        agentId: kTestSoulId,
        templateId: kTestSoulId,
      );
      when(
        () => mockTemplateService.getEvolutionSessions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [session]);

      final container = createContainerWithTemplate();
      addTearDown(container.dispose);

      final result = await container.read(
        soulEvolutionSessionsProvider(kTestSoulId).future,
      );

      expect(result, hasLength(1));
      expect(result[0], isA<EvolutionSessionEntity>());
    });

    test('returns empty list when no sessions', () async {
      when(
        () => mockTemplateService.getEvolutionSessions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);

      final container = createContainerWithTemplate();
      addTearDown(container.dispose);

      final result = await container.read(
        soulEvolutionSessionsProvider(kTestSoulId).future,
      );

      expect(result, isEmpty);
    });
  });

  group('pendingSoulEvolutionProvider', () {
    late MockAgentTemplateService mockTemplateService;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
    });

    ProviderContainer createContainerWithTemplate() {
      return ProviderContainer(
        overrides: [
          soulDocumentServiceProvider.overrideWithValue(mockService),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        ],
      );
    }

    test('returns active session when newest is active', () async {
      final activeSession = makeTestEvolutionSession(
        id: 'session-1',
        agentId: kTestSoulId,
        templateId: kTestSoulId,
        // ignore: avoid_redundant_argument_values
        status: EvolutionSessionStatus.active,
      );
      when(
        () => mockTemplateService.getEvolutionSessions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [activeSession]);

      final container = createContainerWithTemplate();
      addTearDown(container.dispose);

      final result = await container.read(
        pendingSoulEvolutionProvider(kTestSoulId).future,
      );

      expect(result, isA<EvolutionSessionEntity>());
      expect(
        (result! as EvolutionSessionEntity).id,
        'session-1',
      );
    });

    test('returns null when newest is completed', () async {
      final completedSession = makeTestEvolutionSession(
        agentId: kTestSoulId,
        templateId: kTestSoulId,
        status: EvolutionSessionStatus.completed,
      );
      when(
        () => mockTemplateService.getEvolutionSessions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [completedSession]);

      final container = createContainerWithTemplate();
      addTearDown(container.dispose);

      final result = await container.read(
        pendingSoulEvolutionProvider(kTestSoulId).future,
      );

      expect(result, isNull);
    });

    test('returns null when no sessions', () async {
      when(
        () => mockTemplateService.getEvolutionSessions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);

      final container = createContainerWithTemplate();
      addTearDown(container.dispose);

      final result = await container.read(
        pendingSoulEvolutionProvider(kTestSoulId).future,
      );

      expect(result, isNull);
    });
  });

  group('soulEvolutionSessionHistoryProvider', () {
    late MockAgentTemplateService mockTemplateService;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
    });

    ProviderContainer createContainerWithTemplate() {
      return ProviderContainer(
        overrides: [
          soulDocumentServiceProvider.overrideWithValue(mockService),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        ],
      );
    }

    test('returns completed sessions with recaps', () async {
      final session = makeTestEvolutionSession(
        id: 'session-1',
        agentId: kTestSoulId,
        templateId: kTestSoulId,
        status: EvolutionSessionStatus.completed,
      );
      final recap = makeTestEvolutionSessionRecap(
        agentId: kTestSoulId,
        sessionId: 'session-1',
        tldr: 'Adjusted warmth',
      );
      when(
        () => mockTemplateService.getEvolutionSessions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [session]);
      when(
        () => mockTemplateService.getEvolutionSessionRecaps(kTestSoulId),
      ).thenAnswer((_) async => [recap]);

      final container = createContainerWithTemplate();
      addTearDown(container.dispose);

      final result = await container.read(
        soulEvolutionSessionHistoryProvider(kTestSoulId).future,
      );

      expect(result, hasLength(1));
      expect(result[0].session.id, 'session-1');
      expect(result[0].recap?.tldr, 'Adjusted warmth');
    });

    test('excludes active sessions from history', () async {
      final active = makeTestEvolutionSession(
        id: 'session-active',
        agentId: kTestSoulId,
        templateId: kTestSoulId,
        // ignore: avoid_redundant_argument_values
        status: EvolutionSessionStatus.active,
      );
      final completed = makeTestEvolutionSession(
        id: 'session-done',
        agentId: kTestSoulId,
        templateId: kTestSoulId,
        status: EvolutionSessionStatus.completed,
      );
      when(
        () => mockTemplateService.getEvolutionSessions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [active, completed]);
      when(
        () => mockTemplateService.getEvolutionSessionRecaps(kTestSoulId),
      ).thenAnswer((_) async => []);

      final container = createContainerWithTemplate();
      addTearDown(container.dispose);

      final result = await container.read(
        soulEvolutionSessionHistoryProvider(kTestSoulId).future,
      );

      expect(result, hasLength(1));
      expect(result[0].session.id, 'session-done');
    });

    test('returns empty when no completed sessions', () async {
      when(
        () => mockTemplateService.getEvolutionSessions(
          kTestSoulId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockTemplateService.getEvolutionSessionRecaps(kTestSoulId),
      ).thenAnswer((_) async => []);

      final container = createContainerWithTemplate();
      addTearDown(container.dispose);

      final result = await container.read(
        soulEvolutionSessionHistoryProvider(kTestSoulId).future,
      );

      expect(result, isEmpty);
    });
  });
}
