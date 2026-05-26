import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
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

void _expectTokenRoundTrip() {
  group('dayAgentCaptureSubmittedToken', () {
    test('prefixes the capture id', () {
      expect(
        dayAgentCaptureSubmittedToken('capture-abc'),
        '${dayAgentCaptureSubmittedPrefix}capture-abc',
      );
    });
  });

  group('captureIdFromTriggerTokens', () {
    test('returns the capture id when a token has the prefix', () {
      final result = captureIdFromTriggerTokens({
        'day-token',
        dayAgentCaptureSubmittedToken('capture-1'),
      });
      expect(result, 'capture-1');
    });

    test('returns null when no token uses the prefix', () {
      expect(
        captureIdFromTriggerTokens({'other', 'misc'}),
        isNull,
      );
    });

    test('returns null on an empty trigger-token set', () {
      expect(captureIdFromTriggerTokens(<String>{}), isNull);
    });

    test('skips a prefix-only token without a capture id', () {
      expect(
        captureIdFromTriggerTokens({dayAgentCaptureSubmittedPrefix}),
        isNull,
      );
    });

    test('skips a whitespace-only capture id and returns null', () {
      expect(
        captureIdFromTriggerTokens({'$dayAgentCaptureSubmittedPrefix   '}),
        isNull,
      );
    });

    test('trims surrounding whitespace from the returned capture id', () {
      expect(
        captureIdFromTriggerTokens({
          '$dayAgentCaptureSubmittedPrefix  capture-1  ',
        }),
        'capture-1',
      );
    });
  });

  group('dayAgentDraftingToken', () {
    test('prefixes the day id', () {
      expect(
        dayAgentDraftingToken('dayplan-2026-05-25'),
        '${dayAgentDraftingPrefix}dayplan-2026-05-25',
      );
    });
  });

  group('draftingDayIdFromTriggerTokens', () {
    test('returns the day id when a token has the prefix', () {
      final result = draftingDayIdFromTriggerTokens({
        dayAgentCaptureSubmittedToken('capture-1'),
        dayAgentDraftingToken('dayplan-2026-05-25'),
      });
      expect(result, 'dayplan-2026-05-25');
    });

    test('returns null when no token uses the drafting prefix', () {
      expect(
        draftingDayIdFromTriggerTokens({
          dayAgentCaptureSubmittedToken('capture-1'),
          'other',
        }),
        isNull,
      );
    });

    test('returns null on an empty trigger-token set', () {
      expect(draftingDayIdFromTriggerTokens(<String>{}), isNull);
    });

    test('skips a prefix-only token without a day id', () {
      expect(
        draftingDayIdFromTriggerTokens({dayAgentDraftingPrefix}),
        isNull,
      );
    });

    test('skips a whitespace-only day id and returns null', () {
      expect(
        draftingDayIdFromTriggerTokens({'$dayAgentDraftingPrefix   '}),
        isNull,
      );
    });

    test('trims surrounding whitespace from the returned day id', () {
      expect(
        draftingDayIdFromTriggerTokens({
          '$dayAgentDraftingPrefix  dayplan-2026-05-25  ',
        }),
        'dayplan-2026-05-25',
      );
    });
  });
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

void _expectMain() {
  _expectTokenRoundTrip();
  _expectProjections();
  _expectDedupeAndSortEdges();
}
