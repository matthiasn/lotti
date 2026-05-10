import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;

import '../test_utils.dart';

enum _GeneratedEvolutionTemplateSlot { target, other, missing }

enum _GeneratedEvolutionAssignableTemplateSlot { target, other }

enum _GeneratedEvolutionAgentSlot { first, second, other }

const _generatedEvolutionTargetTemplateId =
    'generated-evolution-template-target';
const _generatedEvolutionOtherTemplateId = 'generated-evolution-template-other';
const _generatedEvolutionMissingTemplateId =
    'generated-evolution-template-missing';

final _generatedEvolutionBase = DateTime(2026, 5, 16, 12);
final _generatedEvolutionSince = DateTime(2026, 5, 16, 12);

String _generatedEvolutionTemplateId(
  _GeneratedEvolutionTemplateSlot slot,
) => switch (slot) {
  _GeneratedEvolutionTemplateSlot.target => _generatedEvolutionTargetTemplateId,
  _GeneratedEvolutionTemplateSlot.other => _generatedEvolutionOtherTemplateId,
  _GeneratedEvolutionTemplateSlot.missing =>
    _generatedEvolutionMissingTemplateId,
};

String _generatedEvolutionAssignableTemplateId(
  _GeneratedEvolutionAssignableTemplateSlot slot,
) => switch (slot) {
  _GeneratedEvolutionAssignableTemplateSlot.target =>
    _generatedEvolutionTargetTemplateId,
  _GeneratedEvolutionAssignableTemplateSlot.other =>
    _generatedEvolutionOtherTemplateId,
};

String _generatedEvolutionAgentId(_GeneratedEvolutionAgentSlot slot) =>
    'generated-evolution-agent-${slot.name}';

class _GeneratedEvolutionTemplateSpec {
  const _GeneratedEvolutionTemplateSpec({
    required this.slot,
    required this.deleted,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final _GeneratedEvolutionAssignableTemplateSlot slot;
  final bool deleted;
  final int updatedMinuteOffset;
  final int seed;

  String get id => _generatedEvolutionAssignableTemplateId(slot);

  String get displayName => 'Generated evolution template ${slot.name} $seed';

  DateTime get createdAt => _generatedEvolutionBase;

  DateTime get updatedAt =>
      _generatedEvolutionBase.add(Duration(minutes: updatedMinuteOffset));

  DateTime? get deletedAt =>
      deleted ? updatedAt.add(const Duration(minutes: 1)) : null;

  @override
  String toString() {
    return '_GeneratedEvolutionTemplateSpec('
        'slot: $slot, deleted: $deleted, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class _GeneratedEvolutionSessionSpec {
  const _GeneratedEvolutionSessionSpec({
    required this.slot,
    required this.status,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final _GeneratedEvolutionTemplateSlot slot;
  final EvolutionSessionStatus status;
  final bool deleted;
  final int createdMinuteOffset;
  final int updatedMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-evolution-session-$index-$seed';

  String get templateId => _generatedEvolutionTemplateId(slot);

  DateTime createdAt(int index) => _generatedEvolutionBase.add(
    Duration(minutes: createdMinuteOffset, seconds: index),
  );

  DateTime updatedAt(int index) => _generatedEvolutionBase.add(
    Duration(minutes: updatedMinuteOffset, seconds: index),
  );

  DateTime? deletedAt(int index) =>
      deleted ? updatedAt(index).add(const Duration(minutes: 1)) : null;

  @override
  String toString() {
    return '_GeneratedEvolutionSessionSpec('
        'slot: $slot, status: $status, deleted: $deleted, '
        'createdMinuteOffset: $createdMinuteOffset, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class _GeneratedEvolutionNoteSpec {
  const _GeneratedEvolutionNoteSpec({
    required this.slot,
    required this.kind,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final _GeneratedEvolutionTemplateSlot slot;
  final EvolutionNoteKind kind;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-evolution-note-$index-$seed';

  String sessionIdAt(int index) => 'generated-evolution-note-session-$index';

  String get templateId => _generatedEvolutionTemplateId(slot);

  String contentAt(int index) => 'Generated evolution note $index seed $seed';

  DateTime createdAt(int index) => _generatedEvolutionBase.add(
    Duration(minutes: createdMinuteOffset, seconds: index),
  );

  DateTime? deletedAt(int index) =>
      deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;

  @override
  String toString() {
    return '_GeneratedEvolutionNoteSpec('
        'slot: $slot, kind: $kind, deleted: $deleted, '
        'createdMinuteOffset: $createdMinuteOffset, seed: $seed)';
  }
}

class _GeneratedEvolutionAssignmentSpec {
  const _GeneratedEvolutionAssignmentSpec({
    required this.templateSlot,
    required this.agentSlot,
    required this.deleted,
    required this.createdMinuteOffset,
  });

  final _GeneratedEvolutionAssignableTemplateSlot templateSlot;
  final _GeneratedEvolutionAgentSlot agentSlot;
  final bool deleted;
  final int createdMinuteOffset;

  String get id =>
      'generated-evolution-assignment-${templateSlot.name}-${agentSlot.name}';

  String get fromId => _generatedEvolutionAssignableTemplateId(templateSlot);

  String get toId => _generatedEvolutionAgentId(agentSlot);

  DateTime get createdAt =>
      _generatedEvolutionBase.add(Duration(minutes: createdMinuteOffset));

  DateTime? get deletedAt =>
      deleted ? createdAt.add(const Duration(minutes: 1)) : null;

  @override
  String toString() {
    return '_GeneratedEvolutionAssignmentSpec('
        'templateSlot: $templateSlot, agentSlot: $agentSlot, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset)';
  }
}

class _GeneratedEvolutionChangedEntitySpec {
  const _GeneratedEvolutionChangedEntitySpec({
    required this.agentSlot,
    required this.deleted,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final _GeneratedEvolutionAgentSlot agentSlot;
  final bool deleted;
  final int updatedMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-evolution-changed-$index-$seed';

  String get agentId => _generatedEvolutionAgentId(agentSlot);

  DateTime updatedAt(int index) => _generatedEvolutionBase.add(
    Duration(minutes: updatedMinuteOffset, seconds: index),
  );

  DateTime? deletedAt(int index) =>
      deleted ? updatedAt(index).add(const Duration(minutes: 1)) : null;

  @override
  String toString() {
    return '_GeneratedEvolutionChangedEntitySpec('
        'agentSlot: $agentSlot, deleted: $deleted, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class _GeneratedEvolutionQueryScenario {
  const _GeneratedEvolutionQueryScenario({
    required this.templates,
    required this.sessions,
    required this.notes,
    required this.assignments,
    required this.changedEntities,
    required this.sessionLimit,
    required this.noteLimit,
  });

  final List<_GeneratedEvolutionTemplateSpec> templates;
  final List<_GeneratedEvolutionSessionSpec> sessions;
  final List<_GeneratedEvolutionNoteSpec> notes;
  final List<_GeneratedEvolutionAssignmentSpec> assignments;
  final List<_GeneratedEvolutionChangedEntitySpec> changedEntities;
  final int sessionLimit;
  final int noteLimit;

  List<String> expectedTemplateSessionIds() {
    final indexed =
        sessions.indexed
            .where(
              (entry) =>
                  entry.$2.slot == _GeneratedEvolutionTemplateSlot.target &&
                  !entry.$2.deleted,
            )
            .toList()
          ..sort(
            (a, b) => b.$2.createdAt(b.$1).compareTo(a.$2.createdAt(a.$1)),
          );
    return indexed
        .take(sessionLimit)
        .map((entry) => entry.$2.idAt(entry.$1))
        .toList();
  }

  List<String> expectedAllSessionIds() {
    final activeTemplates = _activeTemplateSlots();
    final indexed =
        sessions.indexed.where((entry) {
          final slot = _assignableSlotFor(entry.$2.slot);
          return !entry.$2.deleted &&
              slot != null &&
              activeTemplates.contains(slot);
        }).toList()..sort(
          (a, b) => b.$2.updatedAt(b.$1).compareTo(a.$2.updatedAt(a.$1)),
        );
    return indexed.map((entry) => entry.$2.idAt(entry.$1)).toList();
  }

  List<String> expectedNoteIds() {
    final indexed =
        notes.indexed
            .where(
              (entry) =>
                  entry.$2.slot == _GeneratedEvolutionTemplateSlot.target &&
                  !entry.$2.deleted,
            )
            .toList()
          ..sort(
            (a, b) => b.$2.createdAt(b.$1).compareTo(a.$2.createdAt(a.$1)),
          );
    return indexed
        .take(noteLimit)
        .map((entry) => entry.$2.idAt(entry.$1))
        .toList();
  }

  int get expectedChangedCount {
    final targetAssignedAgents = _activeTargetAssignmentAgentSlots();
    return changedEntities.indexed
        .where(
          (entry) =>
              !entry.$2.deleted &&
              targetAssignedAgents.contains(entry.$2.agentSlot) &&
              entry.$2.updatedAt(entry.$1).isAfter(_generatedEvolutionSince),
        )
        .length;
  }

  Set<_GeneratedEvolutionAssignableTemplateSlot> _activeTemplateSlots() {
    final bySlot =
        <
          _GeneratedEvolutionAssignableTemplateSlot,
          _GeneratedEvolutionTemplateSpec
        >{};
    for (final template in templates) {
      bySlot[template.slot] = template;
    }
    return bySlot.entries
        .where((entry) => !entry.value.deleted)
        .map((entry) => entry.key)
        .toSet();
  }

  Set<_GeneratedEvolutionAgentSlot> _activeTargetAssignmentAgentSlots() {
    final byNaturalKey =
        <
          (
            _GeneratedEvolutionAssignableTemplateSlot,
            _GeneratedEvolutionAgentSlot,
          ),
          _GeneratedEvolutionAssignmentSpec
        >{};
    for (final assignment in assignments) {
      byNaturalKey[(assignment.templateSlot, assignment.agentSlot)] =
          assignment;
    }
    return byNaturalKey.values
        .where(
          (assignment) =>
              assignment.templateSlot ==
                  _GeneratedEvolutionAssignableTemplateSlot.target &&
              !assignment.deleted,
        )
        .map((assignment) => assignment.agentSlot)
        .toSet();
  }

  _GeneratedEvolutionAssignableTemplateSlot? _assignableSlotFor(
    _GeneratedEvolutionTemplateSlot slot,
  ) => switch (slot) {
    _GeneratedEvolutionTemplateSlot.target =>
      _GeneratedEvolutionAssignableTemplateSlot.target,
    _GeneratedEvolutionTemplateSlot.other =>
      _GeneratedEvolutionAssignableTemplateSlot.other,
    _GeneratedEvolutionTemplateSlot.missing => null,
  };

  @override
  String toString() {
    return '_GeneratedEvolutionQueryScenario('
        'templates: $templates, sessions: $sessions, notes: $notes, '
        'assignments: $assignments, changedEntities: $changedEntities, '
        'sessionLimit: $sessionLimit, noteLimit: $noteLimit)';
  }
}

extension _AnyGeneratedEvolutionQueryScenario on glados.Any {
  glados.Generator<_GeneratedEvolutionAssignableTemplateSlot>
  get evolutionAssignableTemplateSlot => glados.AnyUtils(this).choose(
    _GeneratedEvolutionAssignableTemplateSlot.values,
  );

  glados.Generator<_GeneratedEvolutionTemplateSlot> get evolutionTemplateSlot =>
      glados.AnyUtils(this).choose(_GeneratedEvolutionTemplateSlot.values);

  glados.Generator<_GeneratedEvolutionAgentSlot> get evolutionAgentSlot =>
      glados.AnyUtils(this).choose(_GeneratedEvolutionAgentSlot.values);

  glados.Generator<EvolutionSessionStatus> get evolutionSessionStatus =>
      glados.AnyUtils(this).choose(EvolutionSessionStatus.values);

  glados.Generator<EvolutionNoteKind> get evolutionNoteKind =>
      glados.AnyUtils(this).choose(EvolutionNoteKind.values);

  glados.Generator<_GeneratedEvolutionTemplateSpec> get evolutionTemplateSpec =>
      glados.CombinableAny(this).combine4(
        evolutionAssignableTemplateSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-3, 3),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedEvolutionAssignableTemplateSlot slot,
          bool deleted,
          int updatedMinuteOffset,
          int seed,
        ) => _GeneratedEvolutionTemplateSpec(
          slot: slot,
          deleted: deleted,
          updatedMinuteOffset: updatedMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedEvolutionSessionSpec> get evolutionSessionSpec =>
      glados.CombinableAny(this).combine6(
        evolutionTemplateSlot,
        evolutionSessionStatus,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-5, 5),
        glados.IntAnys(this).intInRange(-5, 5),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedEvolutionTemplateSlot slot,
          EvolutionSessionStatus status,
          bool deleted,
          int createdMinuteOffset,
          int updatedMinuteOffset,
          int seed,
        ) => _GeneratedEvolutionSessionSpec(
          slot: slot,
          status: status,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          updatedMinuteOffset: updatedMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedEvolutionNoteSpec> get evolutionNoteSpec =>
      glados.CombinableAny(this).combine5(
        evolutionTemplateSlot,
        evolutionNoteKind,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-5, 5),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedEvolutionTemplateSlot slot,
          EvolutionNoteKind kind,
          bool deleted,
          int createdMinuteOffset,
          int seed,
        ) => _GeneratedEvolutionNoteSpec(
          slot: slot,
          kind: kind,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedEvolutionAssignmentSpec>
  get evolutionAssignmentSpec => glados.CombinableAny(this).combine4(
    evolutionAssignableTemplateSlot,
    evolutionAgentSlot,
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(-5, 5),
    (
      _GeneratedEvolutionAssignableTemplateSlot templateSlot,
      _GeneratedEvolutionAgentSlot agentSlot,
      bool deleted,
      int createdMinuteOffset,
    ) => _GeneratedEvolutionAssignmentSpec(
      templateSlot: templateSlot,
      agentSlot: agentSlot,
      deleted: deleted,
      createdMinuteOffset: createdMinuteOffset,
    ),
  );

  glados.Generator<_GeneratedEvolutionChangedEntitySpec>
  get evolutionChangedEntitySpec => glados.CombinableAny(this).combine4(
    evolutionAgentSlot,
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(-5, 5),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      _GeneratedEvolutionAgentSlot agentSlot,
      bool deleted,
      int updatedMinuteOffset,
      int seed,
    ) => _GeneratedEvolutionChangedEntitySpec(
      agentSlot: agentSlot,
      deleted: deleted,
      updatedMinuteOffset: updatedMinuteOffset,
      seed: seed,
    ),
  );

  glados.Generator<_GeneratedEvolutionQueryScenario>
  get evolutionQueryScenario => glados.CombinableAny(this).combine7(
    glados.ListAnys(this).listWithLengthInRange(
      0,
      5,
      evolutionTemplateSpec,
    ),
    glados.ListAnys(this).listWithLengthInRange(
      0,
      8,
      evolutionSessionSpec,
    ),
    glados.ListAnys(this).listWithLengthInRange(0, 8, evolutionNoteSpec),
    glados.ListAnys(this).listWithLengthInRange(
      0,
      8,
      evolutionAssignmentSpec,
    ),
    glados.ListAnys(this).listWithLengthInRange(
      0,
      8,
      evolutionChangedEntitySpec,
    ),
    glados.IntAnys(this).intInRange(1, 4),
    glados.IntAnys(this).intInRange(1, 4),
    (
      List<_GeneratedEvolutionTemplateSpec> templates,
      List<_GeneratedEvolutionSessionSpec> sessions,
      List<_GeneratedEvolutionNoteSpec> notes,
      List<_GeneratedEvolutionAssignmentSpec> assignments,
      List<_GeneratedEvolutionChangedEntitySpec> changedEntities,
      int sessionLimit,
      int noteLimit,
    ) => _GeneratedEvolutionQueryScenario(
      templates: templates,
      sessions: sessions,
      notes: notes,
      assignments: assignments,
      changedEntities: changedEntities,
      sessionLimit: sessionLimit,
      noteLimit: noteLimit,
    ),
  );
}

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
      await repo.upsertLink(
        model.AgentLink.templateAssignment(
          id: 'link-ta-A',
          fromId: templateId,
          toId: agentIdA,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );
      await repo.upsertLink(
        model.AgentLink.templateAssignment(
          id: 'link-ta-B',
          fromId: templateId,
          toId: agentIdB,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );
    }

    group('getRecentReportsByTemplate', () {
      test('returns reports from all instances of a template', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(
          makeTestReport(
            id: 'report-A',
            agentId: agentIdA,
            createdAt: DateTime(2026, 2, 19),
          ),
        );
        await repo.upsertEntity(
          makeTestReport(
            id: 'report-B',
            agentId: agentIdB,
            createdAt: DateTime(2026, 2, 20),
          ),
        );

        final reports = await repo.getRecentReportsByTemplate(templateId);

        expect(reports.length, 2);
        // Newest first
        expect(reports[0].id, 'report-B');
        expect(reports[1].id, 'report-A');
      });

      test('respects limit parameter', () async {
        await seedTemplateWithInstances();

        for (var i = 0; i < 5; i++) {
          await repo.upsertEntity(
            makeTestReport(
              id: 'report-$i',
              agentId: agentIdA,
              createdAt: DateTime(2026, 2, 15 + i),
            ),
          );
        }

        final reports = await repo.getRecentReportsByTemplate(
          templateId,
          limit: 3,
        );
        expect(reports.length, 3);
      });

      test('returns empty when no instances exist', () async {
        final reports = await repo.getRecentReportsByTemplate(
          'nonexistent-template',
        );
        expect(reports, isEmpty);
      });

      test('excludes reports from unrelated agents', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(
          makeTestReport(
            id: 'report-assigned',
            agentId: agentIdA,
          ),
        );
        await repo.upsertEntity(
          makeTestReport(
            id: 'report-unrelated',
            agentId: 'agent-unrelated',
          ),
        );

        final reports = await repo.getRecentReportsByTemplate(templateId);

        expect(reports.length, 1);
        expect(reports.first.id, 'report-assigned');
      });

      test('excludes reports with non-current scope', () async {
        await seedTemplateWithInstances();

        // 'current' scope report (default from makeTestReport)
        await repo.upsertEntity(
          makeTestReport(
            id: 'report-current',
            agentId: agentIdA,
          ),
        );

        // 'daily' scope report — should be excluded by the query
        await repo.upsertEntity(
          makeTestReport(
            id: 'report-daily',
            agentId: agentIdA,
            scope: 'daily',
          ),
        );

        final reports = await repo.getRecentReportsByTemplate(templateId);

        expect(reports.length, 1);
        expect(reports.first.id, 'report-current');
      });

      test('excludes soft-deleted reports', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(
          makeTestReport(
            id: 'report-alive',
            agentId: agentIdA,
          ),
        );
        await repo.upsertEntity(
          makeTestReport(
            id: 'report-deleted',
            agentId: agentIdA,
          ),
        );

        // Soft-delete one report
        await (db.update(
          db.agentEntities,
        )..where((t) => t.id.equals('report-deleted'))).write(
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

        await repo.upsertEntity(
          makeTestReport(
            id: 'report-A',
            agentId: agentIdA,
          ),
        );
        await repo.upsertEntity(
          makeTestReport(
            id: 'report-B',
            agentId: agentIdB,
          ),
        );

        // Soft-delete the link to agent A
        await (db.update(
          db.agentLinks,
        )..where((t) => t.id.equals('link-ta-A'))).write(
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

        await repo.upsertEntity(
          makeTestMessage(
            id: 'obs-A',
            agentId: agentIdA,
            kind: AgentMessageKind.observation,
            createdAt: DateTime(2026, 2, 19),
          ),
        );
        await repo.upsertEntity(
          makeTestMessage(
            id: 'obs-B',
            agentId: agentIdB,
            kind: AgentMessageKind.observation,
            createdAt: DateTime(2026, 2, 20),
          ),
        );

        final observations = await repo.getRecentObservationsByTemplate(
          templateId,
        );

        expect(observations.length, 2);
        expect(observations[0].id, 'obs-B');
        expect(observations[1].id, 'obs-A');
      });

      test('excludes non-observation messages', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(
          makeTestMessage(
            id: 'obs-1',
            agentId: agentIdA,
            kind: AgentMessageKind.observation,
          ),
        );
        await repo.upsertEntity(
          makeTestMessage(
            id: 'thought-1',
            agentId: agentIdA,
          ),
        );

        final observations = await repo.getRecentObservationsByTemplate(
          templateId,
        );

        expect(observations.length, 1);
        expect(observations.first.id, 'obs-1');
      });

      test('respects limit parameter', () async {
        await seedTemplateWithInstances();

        for (var i = 0; i < 5; i++) {
          await repo.upsertEntity(
            makeTestMessage(
              id: 'obs-$i',
              agentId: agentIdA,
              kind: AgentMessageKind.observation,
              createdAt: DateTime(2026, 2, 15 + i),
            ),
          );
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
        await repo.upsertEntity(
          makeTestEvolutionSession(
            id: 'session-1',
            createdAt: DateTime(2026, 2, 18),
            updatedAt: DateTime(2026, 2, 18),
          ),
        );
        await repo.upsertEntity(
          makeTestEvolutionSession(
            id: 'session-2',
            sessionNumber: 2,
            createdAt: DateTime(2026, 2, 20),
            updatedAt: DateTime(2026, 2, 20),
          ),
        );

        final sessions = await repo.getEvolutionSessions(kTestTemplateId);

        expect(sessions.length, 2);
        expect(sessions[0].id, 'session-2');
        expect(sessions[1].id, 'session-1');
      });

      test('respects limit parameter', () async {
        for (var i = 0; i < 5; i++) {
          await repo.upsertEntity(
            makeTestEvolutionSession(
              id: 'session-$i',
              sessionNumber: i + 1,
              createdAt: DateTime(2026, 2, 15 + i),
              updatedAt: DateTime(2026, 2, 15 + i),
            ),
          );
        }

        final sessions = await repo.getEvolutionSessions(
          kTestTemplateId,
          limit: 3,
        );
        expect(sessions.length, 3);
      });

      test('returns empty when no sessions exist', () async {
        final sessions = await repo.getEvolutionSessions(
          'nonexistent-template',
        );
        expect(sessions, isEmpty);
      });

      test('excludes soft-deleted sessions', () async {
        await repo.upsertEntity(
          makeTestEvolutionSession(
            id: 'session-alive',
          ),
        );
        await repo.upsertEntity(
          makeTestEvolutionSession(
            id: 'session-deleted',
            sessionNumber: 2,
          ),
        );

        // Soft-delete one session
        await (db.update(
          db.agentEntities,
        )..where((t) => t.id.equals('session-deleted'))).write(
          AgentEntitiesCompanion(
            deletedAt: Value(DateTime(2026, 2, 21)),
          ),
        );

        final sessions = await repo.getEvolutionSessions(kTestTemplateId);

        expect(sessions.length, 1);
        expect(sessions.first.id, 'session-alive');
      });

      test('excludes non-session entity types', () async {
        await repo.upsertEntity(
          makeTestEvolutionSession(
            id: 'session-1',
          ),
        );
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

        await repo.upsertEntity(
          makeTestEvolutionSession(
            id: 'session-A1',
            agentId: 'tpl-A',
            templateId: 'tpl-A',
            createdAt: DateTime(2026, 2, 18),
            updatedAt: DateTime(2026, 2, 18),
          ),
        );
        await repo.upsertEntity(
          makeTestEvolutionSession(
            id: 'session-B1',
            agentId: 'tpl-B',
            templateId: 'tpl-B',
            sessionNumber: 2,
            createdAt: DateTime(2026, 2, 20),
            updatedAt: DateTime(2026, 2, 20),
          ),
        );

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
        await repo.upsertEntity(
          makeTestEvolutionSession(
            id: 'session-alive',
            agentId: 'tpl-alive',
            templateId: 'tpl-alive',
          ),
        );
        await repo.upsertEntity(
          makeTestEvolutionSession(
            id: 'session-orphan',
            agentId: 'tpl-dead',
            templateId: 'tpl-dead',
            sessionNumber: 2,
          ),
        );

        // Soft-delete the second template
        await (db.update(
          db.agentEntities,
        )..where((t) => t.id.equals('tpl-dead'))).write(
          AgentEntitiesCompanion(
            deletedAt: Value(DateTime(2026, 2, 21)),
          ),
        );

        final sessions = await repo.getAllEvolutionSessions();

        expect(sessions, hasLength(1));
        expect(sessions.first.id, 'session-alive');
      });

      test(
        'excludes soft-deleted sessions even when template is alive',
        () async {
          await repo.upsertEntity(
            makeTestTemplate(id: 'tpl-1', agentId: 'tpl-1'),
          );

          await repo.upsertEntity(
            makeTestEvolutionSession(
              id: 'session-ok',
              agentId: 'tpl-1',
              templateId: 'tpl-1',
            ),
          );
          await repo.upsertEntity(
            makeTestEvolutionSession(
              id: 'session-gone',
              agentId: 'tpl-1',
              templateId: 'tpl-1',
              sessionNumber: 2,
            ),
          );

          // Soft-delete one session
          await (db.update(
            db.agentEntities,
          )..where((t) => t.id.equals('session-gone'))).write(
            AgentEntitiesCompanion(
              deletedAt: Value(DateTime(2026, 2, 21)),
            ),
          );

          final sessions = await repo.getAllEvolutionSessions();

          expect(sessions, hasLength(1));
          expect(sessions.first.id, 'session-ok');
        },
      );

      test('returns empty when no templates exist', () async {
        // Insert a session with no matching template
        await repo.upsertEntity(
          makeTestEvolutionSession(
            id: 'orphan-session',
            agentId: 'nonexistent-template',
            templateId: 'nonexistent-template',
          ),
        );

        final sessions = await repo.getAllEvolutionSessions();

        expect(sessions, isEmpty);
      });
    });

    group('getEvolutionNotes', () {
      test('returns notes for a template newest-first', () async {
        await repo.upsertEntity(
          makeTestEvolutionNote(
            id: 'note-1',
            kind: EvolutionNoteKind.pattern,
            createdAt: DateTime(2026, 2, 18),
          ),
        );
        await repo.upsertEntity(
          makeTestEvolutionNote(
            id: 'note-2',
            kind: EvolutionNoteKind.hypothesis,
            createdAt: DateTime(2026, 2, 20),
          ),
        );

        final notes = await repo.getEvolutionNotes(kTestTemplateId);

        expect(notes.length, 2);
        expect(notes[0].id, 'note-2');
        expect(notes[1].id, 'note-1');
      });

      test('respects limit parameter', () async {
        for (var i = 0; i < 5; i++) {
          await repo.upsertEntity(
            makeTestEvolutionNote(
              id: 'note-$i',
              createdAt: DateTime(2026, 2, 15 + i),
            ),
          );
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
        await repo.upsertEntity(
          makeTestEvolutionNote(
            id: 'note-deleted',
            kind: EvolutionNoteKind.decision,
          ),
        );

        await (db.update(
          db.agentEntities,
        )..where((t) => t.id.equals('note-deleted'))).write(
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

        await repo.upsertEntity(
          makeTestReport(
            id: 'report-recent',
            agentId: agentIdA,
          ),
        );

        final count = await repo.countChangedSinceForTemplate(templateId, null);
        expect(count, 0);
      });

      test('counts entities updated after since timestamp', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(
          makeTestReport(
            id: 'report-old',
            agentId: agentIdA,
            createdAt: DateTime(2026, 2, 10),
          ),
        );
        await repo.upsertEntity(
          makeTestReport(
            id: 'report-new',
            agentId: agentIdA,
            createdAt: DateTime(2026, 2, 20),
          ),
        );

        final count = await repo.countChangedSinceForTemplate(
          templateId,
          DateTime(2026, 2, 15),
        );
        expect(count, 1);
      });

      test('returns 0 when no entities changed after since', () async {
        await seedTemplateWithInstances();

        await repo.upsertEntity(
          makeTestReport(
            id: 'report-old',
            agentId: agentIdA,
            createdAt: DateTime(2026, 2, 10),
          ),
        );

        final count = await repo.countChangedSinceForTemplate(
          templateId,
          DateTime(2026, 2, 15),
        );
        expect(count, 0);
      });
    });

    glados.Glados(glados.any.evolutionQueryScenario).test(
      'matches generated evolution template query semantics',
      (scenario) async {
        final localDb = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        final localRepo = AgentRepository(localDb);

        try {
          for (final template in scenario.templates) {
            await localRepo.upsertEntity(
              makeTestTemplate(
                id: template.id,
                agentId: template.id,
                displayName: template.displayName,
                createdAt: template.createdAt,
                updatedAt: template.updatedAt,
              ).copyWith(deletedAt: template.deletedAt),
            );
          }

          for (final (index, session) in scenario.sessions.indexed) {
            await localRepo.upsertEntity(
              makeTestEvolutionSession(
                id: session.idAt(index),
                agentId: session.templateId,
                templateId: session.templateId,
                sessionNumber: index + 1,
                status: session.status,
                createdAt: session.createdAt(index),
                updatedAt: session.updatedAt(index),
              ).copyWith(deletedAt: session.deletedAt(index)),
            );
          }

          for (final (index, note) in scenario.notes.indexed) {
            await localRepo.upsertEntity(
              makeTestEvolutionNote(
                id: note.idAt(index),
                agentId: note.templateId,
                sessionId: note.sessionIdAt(index),
                kind: note.kind,
                createdAt: note.createdAt(index),
                content: note.contentAt(index),
              ).copyWith(deletedAt: note.deletedAt(index)),
            );
          }

          for (final assignment in scenario.assignments) {
            await localRepo.upsertLink(
              model.AgentLink.templateAssignment(
                id: assignment.id,
                fromId: assignment.fromId,
                toId: assignment.toId,
                createdAt: assignment.createdAt,
                updatedAt: assignment.createdAt,
                vectorClock: null,
                deletedAt: assignment.deletedAt,
              ),
            );
          }

          for (final (index, changed) in scenario.changedEntities.indexed) {
            await localRepo.upsertEntity(
              makeTestReport(
                id: changed.idAt(index),
                agentId: changed.agentId,
                createdAt: changed.updatedAt(index),
                content: 'Generated changed entity $index seed ${changed.seed}',
              ).copyWith(deletedAt: changed.deletedAt(index)),
            );
          }

          final templateSessions = await localRepo.getEvolutionSessions(
            _generatedEvolutionTargetTemplateId,
            limit: scenario.sessionLimit,
          );
          expect(
            templateSessions.map((session) => session.id).toList(),
            scenario.expectedTemplateSessionIds(),
            reason: '$scenario',
          );

          final allSessions = await localRepo.getAllEvolutionSessions();
          expect(
            allSessions.map((session) => session.id).toList(),
            scenario.expectedAllSessionIds(),
            reason: '$scenario',
          );

          final notes = await localRepo.getEvolutionNotes(
            _generatedEvolutionTargetTemplateId,
            limit: scenario.noteLimit,
          );
          expect(
            notes.map((note) => note.id).toList(),
            scenario.expectedNoteIds(),
            reason: '$scenario',
          );

          expect(
            await localRepo.countChangedSinceForTemplate(
              _generatedEvolutionTargetTemplateId,
              null,
            ),
            0,
            reason: '$scenario',
          );
          expect(
            await localRepo.countChangedSinceForTemplate(
              _generatedEvolutionTargetTemplateId,
              _generatedEvolutionSince,
            ),
            scenario.expectedChangedCount,
            reason: '$scenario',
          );
        } finally {
          await localDb.close();
        }
      },
      tags: 'glados',
    );
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
