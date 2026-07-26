import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';

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

  _expectMain();
}

int _rank(DayAgentPendingKind kind) {
  return switch (kind) {
    DayAgentPendingKind.overdue => 0,
    DayAgentPendingKind.inProgress => 1,
    DayAgentPendingKind.missedRecurring => 2,
    DayAgentPendingKind.dueToday => 3,
  };
}

Task _task({
  String id = 'task-1',
  String title = 'Title',
  String? categoryId = 'cat',
  DateTime? due,
}) {
  final status = TaskStatus.open(
    id: 'status-$id',
    createdAt: DateTime(2026, 5, 25, 8),
    utcOffset: 120,
  );
  return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: DateTime(2026, 5, 25, 8),
          updatedAt: DateTime(2026, 5, 25, 8),
          dateFrom: DateTime(2026, 5, 25, 8),
          dateTo: DateTime(2026, 5, 25, 9),
          categoryId: categoryId,
        ),
        data: TaskData(
          status: status,
          statusHistory: [status],
          dateFrom: DateTime(2026, 5, 25, 8),
          dateTo: DateTime(2026, 5, 25, 9),
          title: title,
          due: due,
        ),
      )
      as Task;
}

void _expectProjections() {
  group('pendingItemFromTask', () {
    test('projects task fields onto a pending item', () {
      final task = _task(
        title: 'Prep demo',
        due: DateTime(2026, 5, 25, 17),
      );
      final item = pendingItemFromTask(task, DayAgentPendingKind.overdue);

      expect(item.taskId, 'task-1');
      expect(item.title, 'Prep demo');
      expect(item.kind, DayAgentPendingKind.overdue);
      expect(item.status, 'OPEN');
      expect(item.categoryId, 'cat');
      expect(item.due, DateTime(2026, 5, 25, 17));
    });

    test('toJson serializes every field including nullable due', () {
      const item = DayAgentPendingItem(
        taskId: 'task-1',
        title: 'Prep demo',
        kind: DayAgentPendingKind.inProgress,
        status: 'IN PROGRESS',
        categoryId: 'cat',
      );

      expect(item.toJson(), <String, Object?>{
        'taskId': 'task-1',
        'title': 'Prep demo',
        'kind': 'inProgress',
        'status': 'IN PROGRESS',
        'categoryId': 'cat',
        'due': null,
      });
    });

    test('toJson encodes due as ISO-8601 when set', () {
      final item = DayAgentPendingItem(
        taskId: 'task-1',
        title: 'Prep demo',
        kind: DayAgentPendingKind.dueToday,
        status: 'OPEN',
        categoryId: null,
        due: DateTime(2026, 5, 25, 23, 59, 59, 999),
      );

      expect(
        item.toJson()['due'],
        DateTime(2026, 5, 25, 23, 59, 59, 999).toIso8601String(),
      );
      expect(item.toJson()['categoryId'], isNull);
    });
  });

  group('corpusMatchFromTask', () {
    test('projects task fields onto a corpus match', () {
      final task = _task(
        id: 'task-2',
        title: 'Review inbox',
        due: DateTime(2026, 5, 25, 12),
      );
      final match = corpusMatchFromTask(task, 0.42);

      expect(match.taskId, 'task-2');
      expect(match.title, 'Review inbox');
      expect(match.score, 0.42);
      expect(match.status, 'OPEN');
      expect(match.categoryId, 'cat');
      expect(match.due, DateTime(2026, 5, 25, 12));
    });

    test('toJson serializes every field', () {
      final match = corpusMatchFromTask(
        _task(
          id: 'task-3',
          title: 'Sweep',
          categoryId: null,
          due: DateTime(2026, 5, 26, 9),
        ),
        0.5,
      );

      expect(match.toJson(), <String, Object?>{
        'taskId': 'task-3',
        'title': 'Sweep',
        'score': 0.5,
        'status': 'OPEN',
        'categoryId': null,
        'due': DateTime(2026, 5, 26, 9).toIso8601String(),
      });
    });
  });
}

void _expectDedupeAndSortEdges() {
  group('dedupeAndSortPendingItems extras', () {
    test('sorts equal-rank items by due ascending', () {
      final items = dedupeAndSortPendingItems([
        DayAgentPendingItem(
          taskId: 'task-late',
          title: 'Later',
          kind: DayAgentPendingKind.overdue,
          status: 'OPEN',
          categoryId: 'cat',
          due: DateTime(2026, 5, 20),
        ),
        DayAgentPendingItem(
          taskId: 'task-early',
          title: 'Earlier',
          kind: DayAgentPendingKind.overdue,
          status: 'OPEN',
          categoryId: 'cat',
          due: DateTime(2026, 5, 10),
        ),
      ]);

      expect(items.map((item) => item.taskId), [
        'task-early',
        'task-late',
      ]);
    });

    test('prefers items with a due date over null-due', () {
      final items = dedupeAndSortPendingItems([
        const DayAgentPendingItem(
          taskId: 'task-no-due',
          title: 'Z',
          kind: DayAgentPendingKind.overdue,
          status: 'OPEN',
          categoryId: 'cat',
        ),
        DayAgentPendingItem(
          taskId: 'task-due',
          title: 'A',
          kind: DayAgentPendingKind.overdue,
          status: 'OPEN',
          categoryId: 'cat',
          due: DateTime(2026, 5, 20),
        ),
      ]);

      expect(items.first.taskId, 'task-due');
      expect(items.last.taskId, 'task-no-due');
    });

    test(
      'breaks ties by lowercased title then taskId when due is missing',
      () {
        final items = dedupeAndSortPendingItems([
          const DayAgentPendingItem(
            taskId: 'task-bb',
            title: 'beta',
            kind: DayAgentPendingKind.dueToday,
            status: 'OPEN',
            categoryId: 'cat',
          ),
          const DayAgentPendingItem(
            taskId: 'task-aa',
            title: 'Alpha',
            kind: DayAgentPendingKind.dueToday,
            status: 'OPEN',
            categoryId: 'cat',
          ),
          const DayAgentPendingItem(
            taskId: 'task-ab',
            title: 'alpha',
            kind: DayAgentPendingKind.dueToday,
            status: 'OPEN',
            categoryId: 'cat',
          ),
        ]);

        expect(items.map((item) => item.taskId), [
          'task-aa',
          'task-ab',
          'task-bb',
        ]);
      },
    );
  });
}

void _expectDecidedTaskRef() {
  group('DecidedTaskRef', () {
    test('toJson locks the drafting-prompt field names', () {
      const ref = DecidedTaskRef(
        id: 'task-1',
        title: 'Prep demo',
        categoryId: 'cat',
      );

      expect(ref.toJson(), <String, Object?>{
        'id': 'task-1',
        'title': 'Prep demo',
        'categoryId': 'cat',
      });
    });

    test('toJson emits a null categoryId rather than dropping the key', () {
      const ref = DecidedTaskRef(
        id: 'task-2',
        title: 'Review inbox',
        categoryId: null,
      );

      final json = ref.toJson();
      expect(json.containsKey('categoryId'), isTrue);
      expect(json['categoryId'], isNull);
    });

    test('toJson carries status and blockers in the corpus shape', () {
      const ref = DecidedTaskRef(
        id: 'task-c-leaf',
        title: 'Ship the integration',
        categoryId: 'work',
        status: 'BLOCKED',
        blockedBy: [
          ResolvedBlocker(
            taskId: 'task-b-middle',
            title: 'Get vendor credentials',
            status: 'OPEN',
          ),
        ],
      );

      // ADR 0043's rule is phrased against `"status": "BLOCKED"` and a
      // non-empty `blockedBy`, and `DayAgentCorpusService.buildTaskCorpusSnapshot` spells both this
      // way. A drafting wake that renders decided tasks instead of the corpus
      // has to speak the same dialect or the rule describes nothing.
      expect(ref.toJson(), <String, Object?>{
        'id': 'task-c-leaf',
        'title': 'Ship the integration',
        'categoryId': 'work',
        'status': 'BLOCKED',
        'blockedBy': [
          {
            'taskId': 'task-b-middle',
            'title': 'Get vendor credentials',
            'status': 'OPEN',
          },
        ],
      });
    });

    test('toJson carries the estimate the capacity rule needs', () {
      // The drafting rules ask the model to total estimates and compare them
      // against availableMinutes. Without this the instruction is
      // unfollowable on a capture-less wake: the corpus is the only other
      // carrier of estimates and it renders inside `<capture>` alone.
      const ref = DecidedTaskRef(
        id: 'task-a',
        title: 'Rewrite the ingestion pipeline',
        categoryId: 'work',
        estimateMinutes: 240,
      );

      expect(ref.toJson()['estimateMinutes'], 240);
    });

    test('toJson omits the estimate when the task has none', () {
      // Absent rather than zero: an unestimated task is not a free one, and
      // zero would let it total as nothing.
      const ref = DecidedTaskRef(
        id: 'task-a',
        title: 'Unsized work',
        categoryId: 'work',
      );

      expect(ref.toJson().containsKey('estimateMinutes'), isFalse);
    });

    test('toJson omits blockedBy when the task has no blockers', () {
      const ref = DecidedTaskRef(
        id: 'task-1',
        title: 'Prep demo',
        categoryId: 'work',
        status: 'OPEN',
      );

      // Omitted rather than sent empty: an empty list says nothing the absent
      // key does not, and every decided task would otherwise carry one.
      expect(ref.toJson().containsKey('blockedBy'), isFalse);
      expect(ref.toJson()['status'], 'OPEN');
    });
  });
}

void _expectDecidedTaskRefProperties() {
  // The drafting rules tell the model to total these and compare against
  // availableMinutes, so the projection has to be predictable across every
  // combination of the optional fields — not just the ones I thought to write
  // by hand. Absence is load-bearing here: an omitted estimate must not read
  // as zero, or unsized work totals as free.
  group('Glados DecidedTaskRef.toJson', () {
    glados.Glados<_RefShape>(
      glados.any.refShape,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'optional fields are present exactly when they carry meaning',
      (
        shape,
      ) {
        final json = shape.ref.toJson();

        // The three identity fields are unconditional; categoryId is emitted
        // even when null, so the model sees an explicit "no category".
        expect(json['id'], shape.ref.id);
        expect(json['title'], shape.ref.title);
        expect(json.containsKey('categoryId'), isTrue);

        expect(json.containsKey('status'), shape.ref.status != null);
        expect(json.containsKey('blockedBy'), shape.ref.blockedBy.isNotEmpty);
        expect(
          json.containsKey('estimateMinutes'),
          shape.ref.estimateMinutes != null,
        );
      },
      tags: 'glados',
    );

    glados.Glados<_RefShape>(
      glados.any.refShape,
      glados.ExploreConfig(numRuns: 300),
    ).test('an absent estimate never serializes as zero', (shape) {
      final json = shape.ref.toJson();

      // Zero would let unsized work total as free against availableMinutes.
      if (shape.ref.estimateMinutes == null) {
        expect(json['estimateMinutes'], isNull);
      } else {
        expect(json['estimateMinutes'], shape.ref.estimateMinutes);
      }
    }, tags: 'glados');
  });
}

void _expectMain() {
  _expectProjections();
  _expectDedupeAndSortEdges();
  _expectDecidedTaskRef();
  _expectDecidedTaskRefProperties();
}

/// One generated shape of the optional fields on a [DecidedTaskRef].
class _RefShape {
  _RefShape(this.status, this.blockerCount, this.estimateMinutes);

  final String? status;
  final int blockerCount;
  final int? estimateMinutes;

  DecidedTaskRef get ref => DecidedTaskRef(
    id: 'task-a',
    title: 'Rewrite the ingestion pipeline',
    categoryId: 'cat-work',
    status: status,
    blockedBy: [
      for (var i = 0; i < blockerCount; i++)
        ResolvedBlocker(taskId: 'blocker-$i'),
    ],
    estimateMinutes: estimateMinutes,
  );

  @override
  String toString() =>
      '_RefShape(status $status, $blockerCount blockers, '
      'estimate $estimateMinutes)';
}

extension _AnyRefShape on glados.Any {
  glados.Generator<_RefShape> get refShape =>
      glados.CombinableAny(this).combine3(
        glados.AnyUtils(this).choose(const [null, 'OPEN', 'BLOCKED']),
        glados.AnyUtils(this).choose(const [0, 1, 3]),
        glados.AnyUtils(this).choose(const [null, 0, 1, 25, 180]),
        _RefShape.new,
      );
}
