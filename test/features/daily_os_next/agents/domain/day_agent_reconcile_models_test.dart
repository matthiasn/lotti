import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';

class _GeneratedPendingItemSpec {
  const _GeneratedPendingItemSpec({
    required this.taskSeed,
    required this.titleSeed,
    required this.kind,
    required this.dueOffset,
    required this.hasDue,
  });

  final int taskSeed;
  final int titleSeed;
  final DayAgentPendingKind kind;
  final int dueOffset;
  final bool hasDue;

  DayAgentPendingItem toItem() {
    final base = DateTime(2026, 5, 25, 9);
    return DayAgentPendingItem(
      taskId: 'task-${taskSeed.abs() % 8}',
      title: 'Task ${titleSeed.abs() % 20}',
      kind: kind,
      status: 'OPEN',
      categoryId: 'cat-${taskSeed.abs() % 3}',
      due: hasDue ? base.add(Duration(hours: dueOffset)) : null,
    );
  }

  @override
  String toString() {
    return '_GeneratedPendingItemSpec('
        'taskSeed: $taskSeed, titleSeed: $titleSeed, kind: $kind, '
        'dueOffset: $dueOffset, hasDue: $hasDue)';
  }
}

extension _AnyDayAgentReconcile on glados.Any {
  glados.Generator<double> get confidenceScore =>
      glados.IntAnys(this).intInRange(0, 1000).map((value) => value / 1000);

  glados.Generator<DayAgentPendingKind> get pendingKind =>
      glados.AnyUtils(this).choose(DayAgentPendingKind.values);

  glados.Generator<_GeneratedPendingItemSpec> get pendingItemSpec =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(-10000, 10000),
        glados.IntAnys(this).intInRange(-10000, 10000),
        pendingKind,
        glados.IntAnys(this).intInRange(-48, 48),
        glados.AnyUtils(this).choose([false, true]),
        (
          int taskSeed,
          int titleSeed,
          DayAgentPendingKind kind,
          int dueOffset,
          bool hasDue,
        ) => _GeneratedPendingItemSpec(
          taskSeed: taskSeed,
          titleSeed: titleSeed,
          kind: kind,
          dueOffset: dueOffset,
          hasDue: hasDue,
        ),
      );
}

void main() {
  group('classifyParsedItemMatch', () {
    test('uses the documented threshold boundaries', () {
      expect(
        classifyParsedItemMatch(0.49).confidence,
        ParsedItemConfidence.low,
      );
      expect(
        classifyParsedItemMatch(0.5).confidence,
        ParsedItemConfidence.medium,
      );
      expect(
        classifyParsedItemMatch(0.75).confidence,
        ParsedItemConfidence.high,
      );
    });

    glados.Glados(
      glados.any.confidenceScore,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'classification obeys phase-2 threshold invariants',
      (score) {
        final classification = classifyParsedItemMatch(score);

        if (score >= dayAgentHighConfidenceThreshold) {
          expect(classification.confidence, ParsedItemConfidence.high);
          expect(classification.lowConfidence, isFalse);
          expect(classification.shouldAutoLink, isTrue);
        } else if (score >= dayAgentMediumConfidenceThreshold) {
          expect(classification.confidence, ParsedItemConfidence.medium);
          expect(classification.lowConfidence, isTrue);
          expect(classification.shouldAutoLink, isTrue);
        } else {
          expect(classification.confidence, ParsedItemConfidence.low);
          expect(classification.lowConfidence, isFalse);
          expect(classification.shouldAutoLink, isFalse);
        }
      },
      tags: 'glados',
    );
  });

  group('dedupeAndSortPendingItems', () {
    test('keeps the highest-priority reason per task', () {
      final items = dedupeAndSortPendingItems([
        const DayAgentPendingItem(
          taskId: 'task-1',
          title: 'Due today',
          kind: DayAgentPendingKind.dueToday,
          status: 'OPEN',
          categoryId: 'cat',
        ),
        const DayAgentPendingItem(
          taskId: 'task-1',
          title: 'Overdue',
          kind: DayAgentPendingKind.overdue,
          status: 'OPEN',
          categoryId: 'cat',
        ),
      ]);

      expect(items, hasLength(1));
      expect(items.single.kind, DayAgentPendingKind.overdue);
    });

    glados.Glados(
      glados.ListAnys(
        glados.any,
      ).listWithLengthInRange(0, 32, glados.any.pendingItemSpec),
    ).test(
      'dedupes by task and sorts by nondecreasing pending priority',
      (specs) {
        final result = dedupeAndSortPendingItems(
          specs.map((spec) => spec.toItem()),
        );

        expect(
          result.map((item) => item.taskId).toSet(),
          hasLength(result.length),
        );

        for (var i = 1; i < result.length; i++) {
          expect(
            _rank(result[i - 1].kind) <= _rank(result[i].kind),
            isTrue,
            reason: '$specs',
          );
        }
      },
      tags: 'glados',
    );
  });
}

int _rank(DayAgentPendingKind kind) {
  return switch (kind) {
    DayAgentPendingKind.overdue => 0,
    DayAgentPendingKind.inProgress => 1,
    DayAgentPendingKind.missedRecurring => 2,
    DayAgentPendingKind.dueToday => 3,
  };
}
