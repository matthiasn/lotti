import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  const templateId = kTestTemplateId;
  const agentId = 'agent-001';

  late MockAgentTemplateService templateService;
  late MockAgentRepository repository;
  late ProviderContainer container;

  setUp(() {
    templateService = MockAgentTemplateService();
    repository = MockAgentRepository();

    container = ProviderContainer(
      overrides: [
        agentTemplateServiceProvider.overrideWithValue(templateService),
        agentRepositoryProvider.overrideWithValue(repository),
        // The reactive rebuild hook; the queries only read it.
        agentUpdateStreamProvider.overrideWith(
          (ref, id) => const Stream<Set<String>>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('agentTemplateProvider delegates to getTemplate', () async {
    final template = makeTestTemplate();
    when(
      () => templateService.getTemplate(templateId),
    ).thenAnswer((_) async => template);

    final result = await container.read(
      agentTemplateProvider(templateId).future,
    );

    expect(result, same(template));
  });

  test('activeTemplateVersionProvider delegates to getActiveVersion', () async {
    final version = makeTestTemplateVersion();
    when(
      () => templateService.getActiveVersion(templateId),
    ).thenAnswer((_) async => version);

    final result = await container.read(
      activeTemplateVersionProvider(templateId).future,
    );

    expect(result, same(version));
  });

  test(
    'templateVersionHistoryProvider delegates to getVersionHistory',
    () async {
      final versions = [
        makeTestTemplateVersion(id: 'v2', version: 2),
        makeTestTemplateVersion(),
      ];
      when(
        () => templateService.getVersionHistory(templateId),
      ).thenAnswer((_) async => versions);

      final result = await container.read(
        templateVersionHistoryProvider(templateId).future,
      );

      expect(result, versions);
    },
  );

  test('templateForAgentProvider delegates to getTemplateForAgent', () async {
    final template = makeTestTemplate();
    when(
      () => templateService.getTemplateForAgent(agentId),
    ).thenAnswer((_) async => template);

    final result = await container.read(
      templateForAgentProvider(agentId).future,
    );

    expect(result, same(template));
  });

  test('evolutionNotesProvider delegates to getRecentEvolutionNotes', () async {
    when(
      () => templateService.getRecentEvolutionNotes(templateId),
    ).thenAnswer((_) async => <EvolutionNoteEntity>[]);

    final result = await container.read(
      evolutionNotesProvider(templateId).future,
    );

    expect(result, isEmpty);
    verify(
      () => templateService.getRecentEvolutionNotes(templateId),
    ).called(1);
  });

  test(
    'templatePerformanceMetricsProvider delegates to computeMetrics',
    () async {
      const metrics = TemplatePerformanceMetrics(
        templateId: templateId,
        totalWakes: 10,
        successCount: 9,
        failureCount: 1,
        successRate: 0.9,
        averageDuration: Duration(seconds: 12),
        firstWakeAt: null,
        lastWakeAt: null,
        activeInstanceCount: 2,
      );
      when(
        () => templateService.computeMetrics(templateId),
      ).thenAnswer((_) async => metrics);

      final result = await container.read(
        templatePerformanceMetricsProvider(templateId).future,
      );

      expect(result, metrics);
    },
  );

  test(
    'allEvolutionSessionsProvider reads all sessions from the repository',
    () async {
      final session = makeTestEvolutionSession();
      when(
        repository.getAllEvolutionSessions,
      ).thenAnswer((_) async => [session]);

      final result = await container.read(
        allEvolutionSessionsProvider.future,
      );

      expect(result, [session]);
    },
  );
}
