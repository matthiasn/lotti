import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;

import '../test_utils.dart';

void main() {
  late AgentDatabase db;
  late AgentRepository repo;

  final testDate = DateTime(2026, 2, 20);
  const templateId = 'tpl-001';
  const agentIdA = 'agent-A';
  const agentIdB = 'agent-B';

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    repo = AgentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Evolution entity roundtrips ────────────────────────────────────────────

  group('Evolution entity CRUD', () {
    test('evolutionSession variant persists and restores correctly', () async {
      final session = makeTestEvolutionSession(
        userRating: 0.75,
        feedbackSummary: '{"enjoyed":"reports"}',
      );
      await repo.upsertEntity(session);

      final result = await repo.getEntity(session.id);

      expect(result, isNotNull);
      final restored = result! as EvolutionSessionEntity;
      expect(restored.id, session.id);
      expect(restored.templateId, kTestTemplateId);
      expect(restored.sessionNumber, 1);
      expect(restored.status, EvolutionSessionStatus.active);
      expect(restored.userRating, 0.75);
      expect(restored.feedbackSummary, '{"enjoyed":"reports"}');
      expect(restored.completedAt, isNull);
    });

    test('evolutionSession with completedAt roundtrips correctly', () async {
      final completedAt = DateTime(2026, 2, 25, 14, 30);
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
        completedAt: completedAt,
        userRating: 0.9,
      );
      await repo.upsertEntity(session);

      final result = await repo.getEntity(session.id);

      final restored = result! as EvolutionSessionEntity;
      expect(restored.status, EvolutionSessionStatus.completed);
      expect(restored.completedAt, completedAt);
      expect(restored.userRating, 0.9);
    });

    test('evolutionNote variant persists and restores correctly', () async {
      final note = makeTestEvolutionNote(
        kind: EvolutionNoteKind.hypothesis,
        content: 'Maybe shorter reports work better.',
      );
      await repo.upsertEntity(note);

      final result = await repo.getEntity(note.id);

      expect(result, isNotNull);
      final restored = result! as EvolutionNoteEntity;
      expect(restored.id, note.id);
      expect(restored.sessionId, 'evo-session-001');
      expect(restored.kind, EvolutionNoteKind.hypothesis);
      expect(restored.content, 'Maybe shorter reports work better.');
    });

    test('all EvolutionSessionStatus values roundtrip', () async {
      for (final status in EvolutionSessionStatus.values) {
        final session = makeTestEvolutionSession(
          id: 'session-${status.name}',
          status: status,
        );
        await repo.upsertEntity(session);

        final result = await repo.getEntity(session.id);
        final restored = result! as EvolutionSessionEntity;
        expect(restored.status, status);
      }
    });

    test('all EvolutionNoteKind values roundtrip', () async {
      for (final kind in EvolutionNoteKind.values) {
        final note = makeTestEvolutionNote(
          id: 'note-${kind.name}',
          kind: kind,
          content: 'Content for ${kind.name}',
        );
        await repo.upsertEntity(note);

        final result = await repo.getEntity(note.id);
        final restored = result! as EvolutionNoteEntity;
        expect(restored.kind, kind);
        expect(restored.content, 'Content for ${kind.name}');
      }
    });

    test('evolutionSession subtype stores status name', () async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );
      await repo.upsertEntity(session);

      final rows = await db
          .getAgentEntitiesByTypeAndSubtype(
            kTestTemplateId,
            'evolutionSession',
            'completed',
            1,
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.subtype, 'completed');
    });

    test('evolutionNote subtype stores kind name', () async {
      final note = makeTestEvolutionNote(kind: EvolutionNoteKind.pattern);
      await repo.upsertEntity(note);

      final rows = await db
          .getAgentEntitiesByTypeAndSubtype(
            kTestTemplateId,
            'evolutionNote',
            'pattern',
            1,
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.subtype, 'pattern');
    });

    test('evolution session status transition via upsert', () async {
      final session = makeTestEvolutionSession();
      await repo.upsertEntity(session);

      // Transition to completed via upsert with same ID
      final completed = AgentDomainEntity.evolutionSession(
        id: session.id,
        agentId: session.agentId,
        templateId: session.templateId,
        sessionNumber: session.sessionNumber,
        status: EvolutionSessionStatus.completed,
        createdAt: session.createdAt,
        updatedAt: DateTime(2026, 2, 25),
        vectorClock: session.vectorClock,
        completedAt: DateTime(2026, 2, 25),
        userRating: 0.85,
        feedbackSummary: '{"overall":"great"}',
      );
      await repo.upsertEntity(completed);

      final result = await repo.getEntity(session.id);
      final restored = result! as EvolutionSessionEntity;
      expect(restored.status, EvolutionSessionStatus.completed);
      expect(restored.completedAt, DateTime(2026, 2, 25));
      expect(restored.userRating, 0.85);
    });
  });

  // ── Cross-instance queries ─────────────────────────────────────────────────

  group('Cross-instance template queries', () {
    Future<void> seedTemplateWithInstances() async {
      // Create template
      await repo.upsertEntity(makeTestTemplate(id: templateId));

      // Create two agent instances assigned to the template
      await repo.upsertEntity(
        makeTestIdentity(id: agentIdA, agentId: agentIdA),
      );
      await repo.upsertEntity(
        makeTestIdentity(id: agentIdB, agentId: agentIdB),
      );

      // Create template_assignment links
      await repo.upsertLink(model.AgentLink.templateAssignment(
        id: 'link-ta-A',
        fromId: templateId,
        toId: agentIdA,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      ));
      await repo.upsertLink(model.AgentLink.templateAssignment(
        id: 'link-ta-B',
        fromId: templateId,
        toId: agentIdB,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      ));
    }

    group('getRecentReportsByTemplate', () {
      test('returns reports from all instances of a template', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(makeTestReport(
          id: 'report-A',
          agentId: agentIdA,
          createdAt: DateTime(2026, 2, 19),
        ));
        await repo.upsertEntity(makeTestReport(
          id: 'report-B',
          agentId: agentIdB,
          createdAt: DateTime(2026, 2, 20),
        ));

        final reports = await repo.getRecentReportsByTemplate(templateId);

        expect(reports.length, 2);
        // Newest first
        expect(reports[0].id, 'report-B');
        expect(reports[1].id, 'report-A');
      });

      test('respects limit parameter', () async {
        await seedTemplateWithInstances();

        for (var i = 0; i < 5; i++) {
          await repo.upsertEntity(makeTestReport(
            id: 'report-$i',
            agentId: agentIdA,
            createdAt: DateTime(2026, 2, 15 + i),
          ));
        }

        final reports = await repo.getRecentReportsByTemplate(
          templateId,
          limit: 3,
        );
        expect(reports.length, 3);
      });

      test('returns empty when no instances exist', () async {
        final reports =
            await repo.getRecentReportsByTemplate('nonexistent-template');
        expect(reports, isEmpty);
      });

      test('excludes reports from unrelated agents', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(makeTestReport(
          id: 'report-assigned',
          agentId: agentIdA,
        ));
        await repo.upsertEntity(makeTestReport(
          id: 'report-unrelated',
          agentId: 'agent-unrelated',
        ));

        final reports = await repo.getRecentReportsByTemplate(templateId);

        expect(reports.length, 1);
        expect(reports.first.id, 'report-assigned');
      });

      test('excludes reports with non-current scope', () async {
        await seedTemplateWithInstances();

        // 'current' scope report (default from makeTestReport)
        await repo.upsertEntity(makeTestReport(
          id: 'report-current',
          agentId: agentIdA,
        ));

        // 'daily' scope report — should be excluded by the query
        await repo.upsertEntity(makeTestReport(
          id: 'report-daily',
          agentId: agentIdA,
          scope: 'daily',
        ));

        final reports = await repo.getRecentReportsByTemplate(templateId);

        expect(reports.length, 1);
        expect(reports.first.id, 'report-current');
      });

      test('excludes soft-deleted reports', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(makeTestReport(
          id: 'report-alive',
          agentId: agentIdA,
        ));
        await repo.upsertEntity(makeTestReport(
          id: 'report-deleted',
          agentId: agentIdA,
        ));

        // Soft-delete one report
        await (db.update(db.agentEntities)
              ..where((t) => t.id.equals('report-deleted')))
            .write(
          AgentEntitiesCompanion(
            deletedAt: Value(DateTime(2026, 2, 21)),
          ),
        );

        final reports = await repo.getRecentReportsByTemplate(templateId);

        expect(reports.length, 1);
        expect(reports.first.id, 'report-alive');
      });

      test('excludes reports via soft-deleted assignment link', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(makeTestReport(
          id: 'report-A',
          agentId: agentIdA,
        ));
        await repo.upsertEntity(makeTestReport(
          id: 'report-B',
          agentId: agentIdB,
        ));

        // Soft-delete the link to agent A
        await (db.update(db.agentLinks)..where((t) => t.id.equals('link-ta-A')))
            .write(
          AgentLinksCompanion(
            deletedAt: Value(DateTime(2026, 2, 21)),
          ),
        );

        final reports = await repo.getRecentReportsByTemplate(templateId);

        expect(reports.length, 1);
        expect(reports.first.id, 'report-B');
      });
    });

    group('getRecentObservationsByTemplate', () {
      test('returns observations from all instances of a template', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(makeTestMessage(
          id: 'obs-A',
          agentId: agentIdA,
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2026, 2, 19),
        ));
        await repo.upsertEntity(makeTestMessage(
          id: 'obs-B',
          agentId: agentIdB,
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2026, 2, 20),
        ));

        final observations =
            await repo.getRecentObservationsByTemplate(templateId);

        expect(observations.length, 2);
        expect(observations[0].id, 'obs-B');
        expect(observations[1].id, 'obs-A');
      });

      test('excludes non-observation messages', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(makeTestMessage(
          id: 'obs-1',
          agentId: agentIdA,
          kind: AgentMessageKind.observation,
        ));
        await repo.upsertEntity(makeTestMessage(
          id: 'thought-1',
          agentId: agentIdA,
        ));

        final observations =
            await repo.getRecentObservationsByTemplate(templateId);

        expect(observations.length, 1);
        expect(observations.first.id, 'obs-1');
      });

      test('respects limit parameter', () async {
        await seedTemplateWithInstances();

        for (var i = 0; i < 5; i++) {
          await repo.upsertEntity(makeTestMessage(
            id: 'obs-$i',
            agentId: agentIdA,
            kind: AgentMessageKind.observation,
            createdAt: DateTime(2026, 2, 15 + i),
          ));
        }

        final observations = await repo.getRecentObservationsByTemplate(
          templateId,
          limit: 3,
        );
        expect(observations.length, 3);
      });
    });

    group('getEvolutionSessions', () {
      test('returns sessions for a template newest-first', () async {
        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-1',
          createdAt: DateTime(2026, 2, 18),
          updatedAt: DateTime(2026, 2, 18),
        ));
        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-2',
          sessionNumber: 2,
          createdAt: DateTime(2026, 2, 20),
          updatedAt: DateTime(2026, 2, 20),
        ));

        final sessions = await repo.getEvolutionSessions(kTestTemplateId);

        expect(sessions.length, 2);
        expect(sessions[0].id, 'session-2');
        expect(sessions[1].id, 'session-1');
      });

      test('respects limit parameter', () async {
        for (var i = 0; i < 5; i++) {
          await repo.upsertEntity(makeTestEvolutionSession(
            id: 'session-$i',
            sessionNumber: i + 1,
            createdAt: DateTime(2026, 2, 15 + i),
            updatedAt: DateTime(2026, 2, 15 + i),
          ));
        }

        final sessions = await repo.getEvolutionSessions(
          kTestTemplateId,
          limit: 3,
        );
        expect(sessions.length, 3);
      });

      test('returns empty when no sessions exist', () async {
        final sessions =
            await repo.getEvolutionSessions('nonexistent-template');
        expect(sessions, isEmpty);
      });

      test('excludes soft-deleted sessions', () async {
        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-alive',
        ));
        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-deleted',
          sessionNumber: 2,
        ));

        // Soft-delete one session
        await (db.update(db.agentEntities)
              ..where((t) => t.id.equals('session-deleted')))
            .write(
          AgentEntitiesCompanion(
            deletedAt: Value(DateTime(2026, 2, 21)),
          ),
        );

        final sessions = await repo.getEvolutionSessions(kTestTemplateId);

        expect(sessions.length, 1);
        expect(sessions.first.id, 'session-alive');
      });

      test('excludes non-session entity types', () async {
        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-1',
        ));
        await repo.upsertEntity(makeTestEvolutionNote(id: 'note-1'));
        await repo.upsertEntity(makeTestTemplate());

        final sessions = await repo.getEvolutionSessions(kTestTemplateId);

        expect(sessions.length, 1);
        expect(sessions.first.id, 'session-1');
      });
    });

    group('getAllEvolutionSessions', () {
      test('returns sessions from multiple templates', () async {
        // Create two templates
        await repo.upsertEntity(
          makeTestTemplate(id: 'tpl-A', agentId: 'tpl-A'),
        );
        await repo.upsertEntity(
          makeTestTemplate(id: 'tpl-B', agentId: 'tpl-B'),
        );

        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-A1',
          agentId: 'tpl-A',
          templateId: 'tpl-A',
          createdAt: DateTime(2026, 2, 18),
          updatedAt: DateTime(2026, 2, 18),
        ));
        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-B1',
          agentId: 'tpl-B',
          templateId: 'tpl-B',
          sessionNumber: 2,
          createdAt: DateTime(2026, 2, 20),
          updatedAt: DateTime(2026, 2, 20),
        ));

        final sessions = await repo.getAllEvolutionSessions();

        expect(sessions, hasLength(2));
        // Newest updated_at first
        expect(sessions[0].id, 'session-B1');
        expect(sessions[1].id, 'session-A1');
      });

      test('excludes sessions whose parent template is soft-deleted', () async {
        // Create two templates
        await repo.upsertEntity(
          makeTestTemplate(id: 'tpl-alive', agentId: 'tpl-alive'),
        );
        await repo.upsertEntity(
          makeTestTemplate(id: 'tpl-dead', agentId: 'tpl-dead'),
        );

        // Create sessions for both
        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-alive',
          agentId: 'tpl-alive',
          templateId: 'tpl-alive',
        ));
        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-orphan',
          agentId: 'tpl-dead',
          templateId: 'tpl-dead',
          sessionNumber: 2,
        ));

        // Soft-delete the second template
        await (db.update(db.agentEntities)
              ..where((t) => t.id.equals('tpl-dead')))
            .write(
          AgentEntitiesCompanion(
            deletedAt: Value(DateTime(2026, 2, 21)),
          ),
        );

        final sessions = await repo.getAllEvolutionSessions();

        expect(sessions, hasLength(1));
        expect(sessions.first.id, 'session-alive');
      });

      test('excludes soft-deleted sessions even when template is alive',
          () async {
        await repo.upsertEntity(
          makeTestTemplate(id: 'tpl-1', agentId: 'tpl-1'),
        );

        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-ok',
          agentId: 'tpl-1',
          templateId: 'tpl-1',
        ));
        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'session-gone',
          agentId: 'tpl-1',
          templateId: 'tpl-1',
          sessionNumber: 2,
        ));

        // Soft-delete one session
        await (db.update(db.agentEntities)
              ..where((t) => t.id.equals('session-gone')))
            .write(
          AgentEntitiesCompanion(
            deletedAt: Value(DateTime(2026, 2, 21)),
          ),
        );

        final sessions = await repo.getAllEvolutionSessions();

        expect(sessions, hasLength(1));
        expect(sessions.first.id, 'session-ok');
      });

      test('returns empty when no templates exist', () async {
        // Insert a session with no matching template
        await repo.upsertEntity(makeTestEvolutionSession(
          id: 'orphan-session',
          agentId: 'nonexistent-template',
          templateId: 'nonexistent-template',
        ));

        final sessions = await repo.getAllEvolutionSessions();

        expect(sessions, isEmpty);
      });
    });

    group('getEvolutionNotes', () {
      test('returns notes for a template newest-first', () async {
        await repo.upsertEntity(makeTestEvolutionNote(
          id: 'note-1',
          kind: EvolutionNoteKind.pattern,
          createdAt: DateTime(2026, 2, 18),
        ));
        await repo.upsertEntity(makeTestEvolutionNote(
          id: 'note-2',
          kind: EvolutionNoteKind.hypothesis,
          createdAt: DateTime(2026, 2, 20),
        ));

        final notes = await repo.getEvolutionNotes(kTestTemplateId);

        expect(notes.length, 2);
        expect(notes[0].id, 'note-2');
        expect(notes[1].id, 'note-1');
      });

      test('respects limit parameter', () async {
        for (var i = 0; i < 5; i++) {
          await repo.upsertEntity(makeTestEvolutionNote(
            id: 'note-$i',
            createdAt: DateTime(2026, 2, 15 + i),
          ));
        }

        final notes = await repo.getEvolutionNotes(
          kTestTemplateId,
          limit: 3,
        );
        expect(notes.length, 3);
      });

      test('returns empty when no notes exist', () async {
        final notes = await repo.getEvolutionNotes('nonexistent-template');
        expect(notes, isEmpty);
      });

      test('excludes soft-deleted notes', () async {
        await repo.upsertEntity(makeTestEvolutionNote(id: 'note-alive'));
        await repo.upsertEntity(makeTestEvolutionNote(
          id: 'note-deleted',
          kind: EvolutionNoteKind.decision,
        ));

        await (db.update(db.agentEntities)
              ..where((t) => t.id.equals('note-deleted')))
            .write(
          AgentEntitiesCompanion(
            deletedAt: Value(DateTime(2026, 2, 21)),
          ),
        );

        final notes = await repo.getEvolutionNotes(kTestTemplateId);

        expect(notes.length, 1);
        expect(notes.first.id, 'note-alive');
      });
    });

    group('countChangedSinceForTemplate', () {
      test('returns 0 when since is null', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(makeTestReport(
          id: 'report-recent',
          agentId: agentIdA,
        ));

        final count = await repo.countChangedSinceForTemplate(templateId, null);
        expect(count, 0);
      });

      test('counts entities updated after since timestamp', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(makeTestReport(
          id: 'report-old',
          agentId: agentIdA,
          createdAt: DateTime(2026, 2, 10),
        ));
        await repo.upsertEntity(makeTestReport(
          id: 'report-new',
          agentId: agentIdA,
          createdAt: DateTime(2026, 2, 20),
        ));

        final count = await repo.countChangedSinceForTemplate(
          templateId,
          DateTime(2026, 2, 15),
        );
        expect(count, 1);
      });

      test('returns 0 when no entities changed after since', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(makeTestReport(
          id: 'report-old',
          agentId: agentIdA,
          createdAt: DateTime(2026, 2, 10),
        ));

        final count = await repo.countChangedSinceForTemplate(
          templateId,
          DateTime(2026, 2, 15),
        );
        expect(count, 0);
      });
    });
  });

  // ── Wake run rating ────────────────────────────────────────────────────────

  group('Wake run rating', () {
    test('updateWakeRunRating sets rating and ratedAt', () async {
      await repo.insertWakeRun(
        entry: makeTestWakeRun(runKey: 'run-rated'),
      );
      final ratedAt = DateTime(2026, 2, 20, 15, 30);

      await repo.updateWakeRunRating(
        'run-rated',
        rating: 0.85,
        ratedAt: ratedAt,
      );

      final run = await repo.getWakeRun('run-rated');
      expect(run, isNotNull);
      expect(run!.userRating, 0.85);
      expect(run.ratedAt, ratedAt);
    });

    test('updateWakeRunRating throws StateError for unknown runKey', () async {
      expect(
        () => repo.updateWakeRunRating(
          'nonexistent-run',
          rating: 0.5,
          ratedAt: DateTime(2026, 2, 20),
        ),
        throwsStateError,
      );
    });

    test('wake run without rating has null fields', () async {
      await repo.insertWakeRun(
        entry: makeTestWakeRun(runKey: 'run-unrated'),
      );

      final run = await repo.getWakeRun('run-unrated');
      expect(run!.userRating, isNull);
      expect(run.ratedAt, isNull);
    });
  });
}
