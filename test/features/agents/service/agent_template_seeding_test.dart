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
    eventTemplateId,
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
      syncService: mockSync,
      crud: crud,
    );
  });

  group('seedDefaults', () {
    test(
      'creates all seven defaults when none exist, then backfills',
      () async {
        // No default template exists yet.
        when(() => mockRepo.getEntity(any())).thenAnswer((_) async => null);
        // No templates exist, so directive backfill is a no-op.
        when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => []);

        await seeding.seedDefaults();

        // Each created default writes a template + version + head (3 entities).
        final captured = verify(
          () => mockSync.upsertEntity(captureAny()),
        ).captured.cast<AgentDomainEntity>();
        final createdTemplates = captured.whereType<AgentTemplateEntity>();
        expect(createdTemplates.map((t) => t.id).toSet(), seededTemplateIds);

        // The event default is the one that powers the category event-template
        // picker, so it must be seeded as an event-agent kind (regression: it
        // was previously omitted, leaving the picker empty).
        final eventTemplate = createdTemplates.firstWhere(
          (t) => t.id == eventTemplateId,
        );
        expect(eventTemplate.kind, AgentTemplateKind.eventAgent);
        expect(eventTemplate.displayName, 'Scribe');
      },
    );

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
    const directivesByKind = {
      AgentTemplateKind.taskAgent: (
        taskAgentGeneralDirective,
        taskAgentReportDirective,
      ),
      AgentTemplateKind.dayAgent: (
        dayAgentGeneralDirective,
        dayAgentReportDirective,
      ),
      AgentTemplateKind.templateImprover: (
        templateImproverGeneralDirective,
        templateImproverReportDirective,
      ),
      AgentTemplateKind.projectAgent: (
        projectAgentGeneralDirective,
        projectAgentReportDirective,
      ),
      AgentTemplateKind.eventAgent: (
        eventAgentGeneralDirective,
        eventAgentReportDirective,
      ),
    };
    for (final MapEntry(key: kind, value: (general, report))
        in directivesByKind.entries) {
      test(
        'backfills missing general/report directives for a ${kind.name}',
        () async {
          final template = makeTestTemplate(
            id: 'tpl-${kind.name}',
            agentId: 'tpl-${kind.name}',
            kind: kind,
          );
          when(
            () => mockRepo.getAllTemplates(),
          ).thenAnswer((_) async => [template]);
          // Active version has empty directive fields -> should be backfilled.
          when(
            () => mockRepo.getActiveTemplateVersion(template.id),
          ).thenAnswer(
            (_) async => makeTestTemplateVersion(
              id: 'v-${kind.name}',
              agentId: template.id,
            ),
          );

          await seeding.seedDirectiveFields();

          final captured = verify(
            () => mockSync.upsertEntity(captureAny()),
          ).captured.cast<AgentDomainEntity>();
          expect(captured, hasLength(1));
          final updated = captured.single as AgentTemplateVersionEntity;
          expect(updated.generalDirective, general);
          expect(updated.reportDirective, report);
        },
      );
    }

    test('fills only the empty field and keeps an authored one', () async {
      final template = makeTestTemplate(id: 'tpl-half', agentId: 'tpl-half');
      when(
        () => mockRepo.getAllTemplates(),
      ).thenAnswer((_) async => [template]);
      when(() => mockRepo.getActiveTemplateVersion('tpl-half')).thenAnswer(
        (_) async => makeTestTemplateVersion(
          id: 'v-half',
          agentId: 'tpl-half',
          reportDirective: 'Report the penguin roll call first.',
        ),
      );

      await seeding.seedDirectiveFields();

      final updated =
          verify(
                () => mockSync.upsertEntity(captureAny()),
              ).captured.single
              as AgentTemplateVersionEntity;
      expect(updated.generalDirective, taskAgentGeneralDirective);
      expect(updated.reportDirective, 'Report the penguin roll call first.');
    });

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
  group('seedDayAgentCaptureReconcileDirective', () {
    test(
      'creates a new active version with the current directives for a stale '
      'Shepherd, carrying its directives blob',
      () async {
        final sync = _TransactionalSyncService();
        when(() => sync.upsertEntity(any())).thenAnswer((_) async {});
        final reconciling = AgentTemplateSeeding(
          syncService: sync,
          crud: AgentTemplateCrud(repository: mockRepo, syncService: sync),
        );
        final stale = makeTestTemplateVersion(
          id: 'v-old',
          agentId: dayAgentTemplateId,
          directives: 'Keep the colony calendar.',
          generalDirective: 'An older phase-1 directive.',
          reportDirective: dayAgentReportDirective,
        );
        when(() => mockRepo.getEntity(dayAgentTemplateId)).thenAnswer(
          (_) async => makeTestTemplate(
            id: dayAgentTemplateId,
            agentId: dayAgentTemplateId,
            kind: AgentTemplateKind.dayAgent,
          ),
        );
        when(
          () => mockRepo.getActiveTemplateVersion(dayAgentTemplateId),
        ).thenAnswer((_) async => stale);
        when(
          () => mockRepo.getTemplateHead(dayAgentTemplateId),
        ).thenAnswer((_) async => null);
        when(
          () => mockRepo.getEntitiesByAgentId(
            dayAgentTemplateId,
            type: any(named: 'type'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [stale]);
        when(
          () => mockRepo.getNextTemplateVersionNumber(dayAgentTemplateId),
        ).thenAnswer((_) async => 2);

        await reconciling.seedDayAgentCaptureReconcileDirective();

        final written = verify(
          () => sync.upsertEntity(captureAny()),
        ).captured.whereType<AgentTemplateVersionEntity>().toList();
        final created = written.singleWhere((v) => v.id != 'v-old');
        expect(created.version, 2);
        expect(created.generalDirective, dayAgentGeneralDirective);
        expect(created.reportDirective, dayAgentReportDirective);
        expect(created.directives, 'Keep the colony calendar.');
        expect(created.authoredBy, 'system');
        expect(
          written.singleWhere((v) => v.id == 'v-old').status,
          AgentTemplateVersionStatus.archived,
        );
      },
    );
  });
}

/// Runs the transaction body inline so `createVersion` can be exercised
/// against the mocked repository.
class _TransactionalSyncService extends MockAgentSyncService {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();
}
