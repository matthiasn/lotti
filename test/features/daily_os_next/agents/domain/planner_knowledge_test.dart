import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/planner_knowledge.dart';

void main() {
  PlannerKnowledgeEntity entry({
    required String id,
    required String key,
    String hook = 'hook',
    String statementText = 'statement',
    KnowledgeStatus status = KnowledgeStatus.confirmed,
    String scope = knowledgeGlobalScope,
    DateTime? updatedAt,
    DateTime? reviewAfter,
    DateTime? deletedAt,
  }) {
    final at = updatedAt ?? DateTime(2026, 5, 25, 8);
    return AgentDomainEntity.plannerKnowledge(
          id: id,
          agentId: 'daily_os_planner',
          key: key,
          hook: hook,
          statementText: statementText,
          source: KnowledgeSource.userStated,
          status: status,
          createdAt: at,
          updatedAt: at,
          vectorClock: null,
          scope: scope,
          reviewAfter: reviewAfter,
          deletedAt: deletedAt,
        )
        as PlannerKnowledgeEntity;
  }

  group('activePlannerKnowledge', () {
    test('keeps the most recent confirmed entry per key (recency wins)', () {
      final result = activePlannerKnowledge([
        entry(
          id: 'a1',
          key: 'deep-work',
          statementText: 'old',
          updatedAt: DateTime(2026, 5, 20),
        ),
        entry(
          id: 'a2',
          key: 'deep-work',
          statementText: 'new',
          updatedAt: DateTime(2026, 5, 24),
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.single.statementText, 'new');
    });

    test('excludes retracted, proposed, and deleted entries', () {
      final result = activePlannerKnowledge([
        entry(id: 'r', key: 'k1', status: KnowledgeStatus.retracted),
        entry(id: 'p', key: 'k2', status: KnowledgeStatus.proposed),
        entry(id: 'd', key: 'k3', deletedAt: DateTime(2026, 5, 25)),
        entry(id: 'c', key: 'k4'),
      ]);

      expect(result.map((e) => e.key), ['k4']);
    });

    test('breaks updatedAt ties by id deterministically', () {
      final at = DateTime(2026, 5, 25, 8);
      final result = activePlannerKnowledge([
        entry(id: 'b', key: 'k', statementText: 'B', updatedAt: at),
        entry(id: 'a', key: 'k', statementText: 'A', updatedAt: at),
      ]);
      // Higher id wins on a tie.
      expect(result.single.statementText, 'B');
    });

    test('returns entries sorted by key', () {
      final result = activePlannerKnowledge([
        entry(id: '1', key: 'zeta'),
        entry(id: '2', key: 'alpha'),
      ]);
      expect(result.map((e) => e.key), ['alpha', 'zeta']);
    });

    test('retracting the head resurfaces the prior confirmed entry', () {
      // recency-wins supersession (ADR 0022 Decision 10): the older confirmed
      // entry becomes active again once the newer head is retracted.
      final result = activePlannerKnowledge([
        entry(
          id: 'old',
          key: 'deep-work',
          statementText: 'before 9',
          updatedAt: DateTime(2026, 5, 20),
        ),
        entry(
          id: 'new',
          key: 'deep-work',
          statementText: 'before 10',
          status: KnowledgeStatus.retracted,
          updatedAt: DateTime(2026, 5, 24),
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.single.statementText, 'before 9');
    });
  });

  group('activePlannerKnowledge — properties', () {
    // A random knowledge set: a few keys, every status, optional deletion, and
    // a small spread of updatedAt — exactly the shape that exercises Head
    // selection, supersession, and tiebreaks.
    final knowledgeSets = glados.ListAnys(glados.any)
        .listWithLengthInRange(
          0,
          8,
          glados.CombinableAny(glados.any).combine4(
            glados.IntAnys(glados.any).intInRange(0, 3), // key
            glados.IntAnys(glados.any).intInRange(0, 3), // status
            glados.IntAnys(glados.any).intInRange(0, 2), // deleted?
            glados.IntAnys(glados.any).intInRange(0, 12), // day offset
            (k, s, d, day) => [k, s, d, day],
          ),
        )
        .map((rows) {
          const statuses = [
            KnowledgeStatus.confirmed,
            KnowledgeStatus.proposed,
            KnowledgeStatus.retracted,
          ];
          return [
            for (var i = 0; i < rows.length; i++)
              entry(
                id: 'e$i',
                key: 'k${rows[i][0]}',
                status: statuses[rows[i][1]],
                deletedAt: rows[i][2] == 1 ? DateTime(2026, 5, 25) : null,
                updatedAt: DateTime(2026, 5).add(Duration(days: rows[i][3])),
              ),
          ];
        });

    glados.Glados(knowledgeSets, glados.ExploreConfig(numRuns: 120)).test(
      'Head is order-independent — devices converge regardless of input order',
      (entries) {
        final forward = activePlannerKnowledge(entries).map((e) => e.id);
        final reversed = activePlannerKnowledge(
          entries.reversed.toList(),
        ).map((e) => e.id);
        expect(forward.toList(), reversed.toList());
      },
      tags: 'glados',
    );

    glados.Glados(knowledgeSets, glados.ExploreConfig(numRuns: 120)).test(
      'Head = the maximal confirmed, non-deleted entry per key, sorted+unique',
      (entries) {
        final head = activePlannerKnowledge(entries);

        // Only confirmed, live entries survive.
        expect(
          head.every(
            (e) => e.status == KnowledgeStatus.confirmed && e.deletedAt == null,
          ),
          isTrue,
        );

        // Sorted by key, exactly one entry per key.
        final keys = head.map((e) => e.key).toList();
        expect(keys, [...keys]..sort());
        expect(keys.toSet().length, keys.length);

        // Every key with an eligible entry is represented.
        final eligible = entries
            .where(
              (e) =>
                  e.status == KnowledgeStatus.confirmed && e.deletedAt == null,
            )
            .toList();
        expect(
          head.map((e) => e.key).toSet(),
          eligible.map((e) => e.key).toSet(),
        );

        // The selected entry dominates every eligible sibling of its key —
        // an independent statement of "most recent, id-tiebroken".
        bool dominates(PlannerKnowledgeEntity a, PlannerKnowledgeEntity b) =>
            a.updatedAt.isAfter(b.updatedAt) ||
            (a.updatedAt == b.updatedAt && a.id.compareTo(b.id) > 0);
        for (final h in head) {
          for (final sib in eligible.where(
            (e) => e.key == h.key && e.id != h.id,
          )) {
            expect(
              dominates(sib, h),
              isFalse,
              reason: '${sib.id} > head ${h.id}',
            );
          }
        }
      },
      tags: 'glados',
    );
  });

  group('knowledgeInScope', () {
    test('global is always in scope', () {
      expect(knowledgeInScope(knowledgeGlobalScope, const {}), isTrue);
    });

    test('category/project scopes require an exact touch', () {
      final touched = {knowledgeCategoryScope('cat-1')};
      expect(
        knowledgeInScope(knowledgeCategoryScope('cat-1'), touched),
        isTrue,
      );
      expect(
        knowledgeInScope(knowledgeCategoryScope('cat-2'), touched),
        isFalse,
      );
      expect(
        knowledgeInScope(knowledgeProjectScope('proj-1'), touched),
        isFalse,
      );
    });
  });

  group('renderKnowledgeHookIndex', () {
    test('renders one bounded line per active key, always present', () {
      final block = renderKnowledgeHookIndex([
        entry(id: '1', key: 'deep-work', hook: 'no deep work before 10'),
        entry(
          id: '2',
          key: 'gym',
          hook: '3x per week',
          scope: 'category:fitness',
        ),
      ]);
      expect(
        block,
        '- [deep-work] no deep work before 10 (scope: global)\n'
        '- [gym] 3x per week (scope: category:fitness)',
      );
    });

    test('is empty when there is no active knowledge', () {
      expect(renderKnowledgeHookIndex(const []), isEmpty);
    });
  });

  group('renderKnowledgeStatements', () {
    final now = DateTime(2026, 5, 25, 8);

    test('pulls only in-scope full statements on demand', () {
      final active = [
        entry(
          id: '1',
          key: 'deep-work',
          statementText: 'Never schedule deep work before 10:00.',
        ),
        entry(
          id: '2',
          key: 'gym',
          statementText: 'Protect gym 3x/week.',
          scope: knowledgeCategoryScope('fitness'),
        ),
      ];

      // A wake touching only fitness gets global + fitness, not other scopes.
      final block = renderKnowledgeStatements(
        active,
        {knowledgeCategoryScope('fitness')},
        now: now,
      );
      expect(block, contains('Never schedule deep work before 10:00.'));
      expect(block, contains('Protect gym 3x/week.'));

      // A wake touching nothing extra gets only the global statement.
      final globalOnly = renderKnowledgeStatements(active, const {}, now: now);
      expect(globalOnly, contains('Never schedule deep work before 10:00.'));
      expect(globalOnly, isNot(contains('Protect gym 3x/week.')));
    });

    test('flags entries past reviewAfter for re-confirmation', () {
      final active = [
        entry(
          id: '1',
          key: 'stale',
          statementText: 'old preference',
          reviewAfter: DateTime(2026, 5, 2),
        ),
        entry(
          id: '2',
          key: 'fresh',
          statementText: 'current preference',
          reviewAfter: DateTime(2026, 6, 2),
        ),
      ];

      final block = renderKnowledgeStatements(active, const {}, now: now);
      expect(
        block,
        contains('old preference (please re-confirm — this may be stale)'),
      );
      expect(
        block,
        contains('- [fresh] current preference'),
      );
      expect(
        block,
        isNot(contains('current preference (please re-confirm')),
      );
    });

    test('is empty when nothing is in scope', () {
      final active = [
        entry(id: '1', key: 'gym', scope: knowledgeCategoryScope('fitness')),
      ];
      expect(renderKnowledgeStatements(active, const {}, now: now), isEmpty);
    });
  });
}
