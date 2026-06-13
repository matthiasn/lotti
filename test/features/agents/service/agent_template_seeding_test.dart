// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';
import 'package:lotti/features/agents/service/agent_template_crud.dart';
import 'package:lotti/features/agents/service/agent_template_seeding.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/template_factories.dart';

/// Mirror test for the [AgentTemplateSeeding] collaborator. Verifies the
/// idempotent default-template seeding and the directive-field backfill, both
/// of which route their template reads/writes through [AgentTemplateCrud].
void main() {
  late MockAgentRepository mockRepo;
  late MockAgentSyncService mockSync;
  late AgentTemplateSeeding seeding;

  const seededTemplateIds = {
    lauraTemplateId,
    tomTemplateId,
    dayAgentTemplateId,
    projectTemplateId,
    improverTemplateId,
    metaImproverTemplateId,
  };

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepo = MockAgentRepository();
    mockSync = MockAgentSyncService();

    when(() => mockSync.upsertEntity(any())).thenAnswer((_) async {});

    final crud = AgentTemplateCrud(
      repository: mockRepo,
      syncService: mockSync,
    );
    seeding = AgentTemplateSeeding(
      repository: mockRepo,
      syncService: mockSync,
      crud: crud,
    );
  });

  group('seedDefaults', () {
    test('creates all six defaults when none exist, then backfills', () async {
      // No default template exists yet.
      when(() => mockRepo.getEntity(any())).thenAnswer((_) async => null);
      // No templates exist, so directive backfill is a no-op.
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => []);

      await seeding.seedDefaults();

      // Each created default writes a template + version + head (3 entities).
      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      final createdTemplateIds = captured
          .whereType<AgentTemplateEntity>()
          .map((t) => t.id)
          .toSet();
      expect(createdTemplateIds, seededTemplateIds);
    });

    test('skips creation when all defaults already exist', () async {
      for (final id in seededTemplateIds) {
        when(() => mockRepo.getEntity(id)).thenAnswer(
          (_) async => makeTestTemplate(id: id, agentId: id),
        );
      }
      // listTemplates for the directive backfill: return the existing ones with
      // already-populated directives so nothing is written.
      when(() => mockRepo.getAllTemplates()).thenAnswer(
        (_) async => [
          for (final id in seededTemplateIds) makeTestTemplate(id: id),
        ],
      );
      when(() => mockRepo.getActiveTemplateVersion(any())).thenAnswer(
        (_) async => makeTestTemplateVersion(
          generalDirective: 'general',
          reportDirective: 'report',
        ),
      );
      // The day-agent reconcile pass compares against the canonical day-agent
      // directives; returning them here keeps it a no-op (no extra version).
      when(
        () => mockRepo.getActiveTemplateVersion(dayAgentTemplateId),
      ).thenAnswer(
        (_) async => makeTestTemplateVersion(
          agentId: dayAgentTemplateId,
          generalDirective: dayAgentGeneralDirective,
          reportDirective: dayAgentReportDirective,
        ),
      );

      await seeding.seedDefaults();

      // Every default already exists with populated directives, so nothing is
      // created or backfilled — no entity writes at all.
      verifyNever(() => mockSync.upsertEntity(any()));
    });
  });

  group('seedDirectiveFields', () {
    test(
      'backfills missing general/report directives by template kind',
      () async {
        final taskTemplate = makeTestTemplate(
          id: 'tpl-task',
          agentId: 'tpl-task',
          kind: AgentTemplateKind.taskAgent,
        );
        when(
          () => mockRepo.getAllTemplates(),
        ).thenAnswer((_) async => [taskTemplate]);
        // Active version has empty directive fields -> should be backfilled.
        when(
          () => mockRepo.getActiveTemplateVersion('tpl-task'),
        ).thenAnswer(
          (_) async => makeTestTemplateVersion(
            id: 'v-task',
            agentId: 'tpl-task',
          ),
        );

        await seeding.seedDirectiveFields();

        final captured = verify(
          () => mockSync.upsertEntity(captureAny()),
        ).captured.cast<AgentDomainEntity>();
        expect(captured, hasLength(1));
        final updated = captured.single as AgentTemplateVersionEntity;
        expect(updated.generalDirective, taskAgentGeneralDirective);
        expect(updated.reportDirective, taskAgentReportDirective);
      },
    );

    test(
      'leaves versions whose directive fields are already populated',
      () async {
        when(() => mockRepo.getAllTemplates()).thenAnswer(
          (_) async => [makeTestTemplate(id: 'tpl-done', agentId: 'tpl-done')],
        );
        when(
          () => mockRepo.getActiveTemplateVersion('tpl-done'),
        ).thenAnswer(
          (_) async => makeTestTemplateVersion(
            id: 'v-done',
            agentId: 'tpl-done',
            generalDirective: 'already',
            reportDirective: 'present',
          ),
        );

        await seeding.seedDirectiveFields();

        verifyNever(() => mockSync.upsertEntity(any()));
      },
    );
  });
}
