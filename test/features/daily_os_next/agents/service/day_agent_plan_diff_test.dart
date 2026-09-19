import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentCaptureException;
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_diff.dart';

import '../../../agents/test_data/entity_factories.dart';

void main() {
  final planDate = DateTime(2024, 3, 15);
  final plan = makeTestDayPlan(planDate: planDate);

  PlannedBlock block({
    String id = 'block-1',
    int startHour = 9,
    int endHour = 10,
  }) {
    return PlannedBlock(
      id: id,
      categoryId: 'cat-1',
      startTime: DateTime(2024, 3, 15, startHour),
      endTime: DateTime(2024, 3, 15, endHour),
      title: 'Focus',
      reason: 'placed here originally',
    );
  }

  Map<String, dynamic> rawChange({
    String action = 'moved',
    String? blockId = 'block-1',
    Map<String, dynamic>? from,
    Map<String, dynamic>? to,
  }) {
    return <String, dynamic>{
      'action': action,
      'reason': 'user asked',
      'blockId': ?blockId,
      'from': ?from,
      'to': ?to,
    };
  }

  Map<String, dynamic> snapshot({int startHour = 9, int endHour = 10}) {
    return <String, dynamic>{
      'start': DateTime(2024, 3, 15, startHour).toIso8601String(),
      'end': DateTime(2024, 3, 15, endHour).toIso8601String(),
      'title': 'Focus',
      'categoryId': 'cat-1',
    };
  }

  group('parsePlanDiffChange', () {
    test('a proposed remainder survives into the change args', () {
      // The snapshot parser never read the field, so the schema advertised
      // it, the apply path handled it, and nothing in between carried it.
      final change = parsePlanDiffChange(
        raw: rawChange(
          action: 'added',
          blockId: null,
          to: snapshot()
            ..['taskId'] = 'task-ops'
            ..['remainingMinutes'] = 45,
        ),
        plan: plan,
        blockById: {'block-1': block()},
      );

      expect(change.to?.remainingMinutes, 45);
      expect(change.toArgs()['remainingMinutes'], 45);
    });

    test('a negative proposed remainder is refused', () {
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(
            action: 'added',
            blockId: null,
            to: snapshot()..['remainingMinutes'] = -5,
          ),
          plan: plan,
          blockById: {'block-1': block()},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('parses a moved change with from/to snapshots', () {
      final change = parsePlanDiffChange(
        raw: rawChange(
          from: snapshot(),
          to: snapshot(startHour: 11, endHour: 12),
        ),
        plan: plan,
        blockById: {'block-1': block()},
      );

      expect(change.action, PlanDiffAction.moved);
      expect(change.blockId, 'block-1');
      expect(change.toolName, 'move_block');
      expect(change.to?.start, DateTime(2024, 3, 15, 11));
      expect(change.reason, 'user asked');
    });

    test('rejects unknown actions and missing requirements', () {
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(action: 'teleported'),
          plan: plan,
          blockById: const {},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
      // moved without `to`
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(from: snapshot()),
          plan: plan,
          blockById: {'block-1': block()},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
      // moved referencing an unknown block
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(from: snapshot(), to: snapshot(startHour: 11)),
          plan: plan,
          blockById: const {},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
      // added without title/categoryId
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(
            action: 'added',
            blockId: null,
            to: <String, dynamic>{
              'start': DateTime(2024, 3, 15, 9).toIso8601String(),
              'end': DateTime(2024, 3, 15, 10).toIso8601String(),
            },
          ),
          plan: plan,
          blockById: const {},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('rejects snapshots outside the plan day', () {
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(
            action: 'added',
            blockId: null,
            to: <String, dynamic>{
              'start': DateTime(2024, 3, 16, 9).toIso8601String(),
              'end': DateTime(2024, 3, 16, 10).toIso8601String(),
              'title': 'Focus',
              'categoryId': 'cat-1',
            },
          ),
          plan: plan,
          blockById: const {},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });
  });

  group('applyPlanDiffItem', () {
    ChangeItem item(String toolName, Map<String, dynamic> args) =>
        ChangeItem(toolName: toolName, args: args, humanSummary: 's');

    test('add_block files the block under its task category', () {
      // The accepted-diff door of the same rule the draft path enforces.
      // Fixing only one of them is how the original mismatch arose.
      final result = applyPlanDiffItem(
        item('add_block', {
          'categoryId': 'cat-1',
          'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
          'title': 'Ops work',
          'taskId': 'task-ops',
          'blockReason': 'why',
        }),
        const [],
        addedBlockState: PlannedBlockState.drafted,
        taskCategoryIds: const {'task-ops': 'cat-ops'},
      );

      expect(result.single.categoryId, 'cat-ops');
    });

    test('add_block carries a declared remainder onto the new block', () {
      final result = applyPlanDiffItem(
        item('add_block', {
          'categoryId': 'cat-1',
          'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
          'title': 'Ops work',
          'taskId': 'task-ops',
          'blockReason': 'why',
          'remainingMinutes': 45,
        }),
        const [],
        addedBlockState: PlannedBlockState.drafted,
        taskCategoryIds: const {'task-ops': 'cat-ops'},
      );

      expect(result.single.remainingMinutes, 45);
    });

    test(
      'move_block updates the remainder it is given, keeps it otherwise',
      () {
        // Resizing a partial block changes the arithmetic, so a refine that
        // shortens one must be able to restate what is left — and a move that
        // says nothing about it must not silently drop it.
        final partial = block().copyWith(
          taskId: 'task-ops',
          remainingMinutes: 60,
        );
        final resized = applyPlanDiffItem(
          item('move_block', {
            'blockId': 'block-1',
            'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
            'remainingMinutes': 30,
          }),
          [partial],
          addedBlockState: PlannedBlockState.drafted,
        );
        final untouched = applyPlanDiffItem(
          item('move_block', {
            'blockId': 'block-1',
            'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          }),
          [partial],
          addedBlockState: PlannedBlockState.drafted,
        );

        expect(resized.single.remainingMinutes, 30);
        expect(untouched.single.remainingMinutes, 60);
      },
    );

    test('move_block re-derives the category even when only times move', () {
      // Applied at acceptance, not only at proposal: a change set written
      // before this rule — or by a peer on an older build — is filed
      // correctly when the user accepts it, rather than persisting the old
      // mismatch.
      final result = applyPlanDiffItem(
        item('move_block', {
          'blockId': 'block-1',
          'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
        }),
        [block().copyWith(taskId: 'task-ops')],
        addedBlockState: PlannedBlockState.drafted,
        taskCategoryIds: const {'task-ops': 'cat-ops'},
      );

      expect(result.single.categoryId, 'cat-ops');
    });

    test('move_block ignores a category that disagrees with the task', () {
      final result = applyPlanDiffItem(
        item('move_block', {
          'blockId': 'block-1',
          'categoryId': 'cat-1',
          'taskId': 'task-ops',
        }),
        [block()],
        addedBlockState: PlannedBlockState.drafted,
        taskCategoryIds: const {'task-ops': 'cat-ops'},
      );

      expect(result.single.categoryId, 'cat-ops');
    });

    test('a block with no task keeps the category the change supplied', () {
      final result = applyPlanDiffItem(
        item('add_block', {
          'categoryId': 'cat-1',
          'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
          'title': 'Buffer',
          'blockReason': 'why',
        }),
        const [],
        addedBlockState: PlannedBlockState.drafted,
      );

      expect(result.single.categoryId, 'cat-1');
    });

    test('move_block updates times and keeps the block reason', () {
      final result = applyPlanDiffItem(
        item('move_block', {
          'blockId': 'block-1',
          'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
        }),
        [block()],
        addedBlockState: PlannedBlockState.drafted,
      );

      expect(result.single.startTime, DateTime(2024, 3, 15, 14));
      expect(result.single.endTime, DateTime(2024, 3, 15, 15));
      // The change-level reason must not clobber the block's own reason.
      expect(result.single.reason, 'placed here originally');
    });

    test('add_block appends a new block in the requested state', () {
      final result = applyPlanDiffItem(
        item('add_block', {
          'categoryId': 'cat-2',
          'toStart': DateTime(2024, 3, 15, 16).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 17).toIso8601String(),
          'title': 'New block',
          'blockReason': 'fills the gap',
        }),
        [block()],
        addedBlockState: PlannedBlockState.committed,
      );

      expect(result, hasLength(2));
      final added = result.last;
      expect(added.categoryId, 'cat-2');
      expect(added.title, 'New block');
      expect(added.state, PlannedBlockState.committed);
      expect(added.reason, 'fills the gap');
      expect(added.id, startsWith('block_'));
    });

    test('drop_block removes the block and rejects unknown ids', () {
      final result = applyPlanDiffItem(
        item('drop_block', {'blockId': 'block-1'}),
        [block()],
        addedBlockState: PlannedBlockState.drafted,
      );
      expect(result, isEmpty);

      expect(
        () => applyPlanDiffItem(
          item('drop_block', {'blockId': 'nope'}),
          [block()],
          addedBlockState: PlannedBlockState.drafted,
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });
  });

  group('stateForAcceptedAddedBlock', () {
    test('commits blocks only for agreed or committed plans', () {
      expect(
        stateForAcceptedAddedBlock(
          DayPlanStatus.agreed(agreedAt: DateTime(2024, 3, 15)),
        ),
        PlannedBlockState.committed,
      );
      expect(
        stateForAcceptedAddedBlock(
          DayPlanStatus.committed(committedAt: DateTime(2024, 3, 15)),
        ),
        PlannedBlockState.committed,
      );
      expect(
        stateForAcceptedAddedBlock(const DayPlanStatus.draft()),
        PlannedBlockState.drafted,
      );
    });
  });

  group('plan-diff properties', () {
    final dayStart = DateTime(2024, 3, 15);
    final dayEnd = DateTime(2024, 3, 16);

    // Two moves on one block are checked against the block as the first move
    // left it, not as it stood before the batch: 09–10 is moved to 11–12,
    // then only its end to 10:30. Checked against the original start (09:00)
    // the second move looked fine; applied, it made a block ending before it
    // starts.
    test('a second move on the same block is checked against the first', () {
      final original = makeTestDayPlan(
        planDate: planDate,
        data: DayPlanData(
          planDate: planDate,
          status: const DayPlanStatus.draft(),
          plannedBlocks: [block()],
        ),
      );
      final batch = [
        _move('block-1', start: 44, end: 48),
        _move('block-1', end: 42),
      ].asMap().entries;

      expect(
        () => validateApplicablePlanDiffBatch(batch, original, const {}),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    glados.Glados(
      glados.any.planDiffCase,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'an accepted batch applies cleanly into well-formed in-day blocks',
      (planCase) {
        final original = planCase.plan(planDate);
        final entries = planCase.items.asMap().entries;
        try {
          validateApplicablePlanDiffBatch(entries, original, const {});
        } on DayAgentCaptureException {
          return;
        }

        var blocks = List<PlannedBlock>.of(original.data.plannedBlocks);
        for (final item in planCase.items) {
          blocks = applyPlanDiffItem(
            item,
            blocks,
            addedBlockState: PlannedBlockState.drafted,
          );
        }

        final adds = planCase.items.where((i) => i.toolName == 'add_block');
        final drops = planCase.items.where((i) => i.toolName == 'drop_block');
        expect(
          blocks,
          hasLength(
            original.data.plannedBlocks.length + adds.length - drops.length,
          ),
        );
        for (final b in blocks) {
          expect(b.endTime.isAfter(b.startTime), isTrue, reason: '$b');
          expect(b.startTime.isBefore(dayStart), isFalse, reason: '$b');
          expect(b.endTime.isAfter(dayEnd), isFalse, reason: '$b');
          expect(b.type, isNot(PlannedBlockType.cal), reason: '$b');
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.rawPlanChange,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'a parsed change re-parses from its own args unchanged',
      (raw) {
        final blockById = {'block-1': block()};
        final PlanDiffChange change;
        try {
          change = parsePlanDiffChange(
            raw: raw,
            plan: plan,
            blockById: blockById,
          );
        } on DayAgentCaptureException {
          return;
        }
        final args = change.toArgs();
        final reparsed = parsePlanDiffChange(
          raw: _rawFromArgs(args),
          plan: plan,
          blockById: blockById,
        );

        expect(reparsed.toArgs(), args);
        expect(reparsed.toolName, change.toolName);
        expect(args['action'], change.action.name);
        expect(args['toStart'], change.to?.start?.toIso8601String());
        expect(args['toEnd'], change.to?.end?.toIso8601String());
      },
      tags: 'glados',
    );
  });
}

/// Fifteen-minute slot [slot] of 2024-03-15; slot 96 is the next midnight.
DateTime _slot(int slot) =>
    DateTime(2024, 3, 15).add(Duration(minutes: 15 * slot));

ChangeItem _move(String blockId, {int? start, int? end}) => ChangeItem(
  toolName: 'move_block',
  args: {
    'blockId': blockId,
    if (start != null) 'toStart': _slot(start).toIso8601String(),
    if (end != null) 'toEnd': _slot(end).toIso8601String(),
  },
  humanSummary: 'move',
);

/// Reshapes the flat arg map [PlanDiffChange.toArgs] persists back into the
/// nested shape the model emits.
Map<String, dynamic> _rawFromArgs(Map<String, dynamic> args) {
  final from = <String, dynamic>{
    'start': ?args['fromStart'],
    'end': ?args['fromEnd'],
    'title': ?args['fromTitle'],
    'categoryId': ?args['fromCategoryId'],
  };
  final to = <String, dynamic>{
    'start': ?args['toStart'],
    'end': ?args['toEnd'],
    'title': ?args['title'],
    'categoryId': ?args['categoryId'],
    'taskId': ?args['taskId'],
    'type': ?args['type'],
    'reason': ?args['blockReason'],
    'remainingMinutes': ?args['remainingMinutes'],
  };
  return {
    'action': args['action'],
    'reason': args['reason'],
    'blockId': ?args['blockId'],
    if (from.isNotEmpty) 'from': from,
    if (to.isNotEmpty) 'to': to,
  };
}

/// One generated change before it is bound to a plan: `kind` 0–1 move, 2 add,
/// 3 drop; `target` picks an existing block (3 means an unknown id); `a` and
/// `length` are slots; `mode` makes a move give both times (0), only its start
/// (1) or only its end (2); `type` indexes [_types].
typedef _ItemSpec = ({
  int kind,
  int target,
  int a,
  int length,
  int mode,
  int type,
});

const List<String?> _types = [
  null,
  null,
  null,
  'ai',
  'buffer',
  'manual',
  'cal',
];

class _PlanDiffCase {
  _PlanDiffCase(this.blocks, List<_ItemSpec> specs)
    : items = [for (final spec in specs) _bind(spec, blocks)];

  /// (start slot, end slot) per block, ids `b0`, `b1`, ….
  final List<(int, int)> blocks;
  final List<ChangeItem> items;

  DayPlanEntity plan(DateTime planDate) => makeTestDayPlan(
    planDate: planDate,
    data: DayPlanData(
      planDate: planDate,
      status: const DayPlanStatus.draft(),
      plannedBlocks: [
        for (final (i, (start, end)) in blocks.indexed)
          PlannedBlock(
            id: 'b$i',
            categoryId: 'cat-1',
            startTime: _slot(start),
            endTime: _slot(end),
            title: 'Block $i',
          ),
      ],
    ),
  );

  // Partial moves are placed relative to the block as the plan holds it — a
  // start just before its end, an end just after its start — so each looks
  // valid on its own and the batch decides whether it still is.
  static ChangeItem _bind(_ItemSpec spec, List<(int, int)> blocks) {
    final known = spec.target < 3;
    final index = spec.target % blocks.length;
    final blockId = known ? 'b$index' : 'b-unknown';
    final (origStart, origEnd) = blocks[index];
    final typeName = _types[spec.type];
    String at(int slot) => _slot(slot.clamp(0, 96)).toIso8601String();
    switch (spec.kind) {
      case 0 || 1:
        final (start, end) = switch (spec.mode) {
          0 => (at(spec.a), at(spec.a + spec.length)),
          1 => (at(origEnd - 1 - spec.a % 8), null),
          _ => (null, at(origStart + 1 + spec.a % 8)),
        };
        return ChangeItem(
          toolName: 'move_block',
          args: {
            'blockId': blockId,
            'toStart': ?start,
            'toEnd': ?end,
            'type': ?typeName,
          },
          humanSummary: 'move',
        );
      case 2:
        return ChangeItem(
          toolName: 'add_block',
          args: {
            'categoryId': 'cat-1',
            'title': 'Added',
            'toStart': at(spec.a),
            'toEnd': at(spec.a + spec.length),
            'type': ?typeName,
          },
          humanSummary: 'add',
        );
      default:
        return ChangeItem(
          toolName: 'drop_block',
          args: {'blockId': blockId},
          humanSummary: 'drop',
        );
    }
  }

  @override
  String toString() =>
      '_PlanDiffCase(blocks: $blocks, items: '
      '${items.map((i) => '${i.toolName}${i.args}').toList()})';
}

extension _AnyPlanDiff on glados.Any {
  glados.Generator<_ItemSpec> get _itemSpec =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 97),
        glados.IntAnys(this).intInRange(-2, 16),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, _types.length),
        (int kind, int target, int a, int length, int mode, int type) => (
          kind: kind,
          target: target,
          a: a,
          length: length,
          mode: mode,
          type: type,
        ),
      );

  // Up to three blocks and up to six items, so the same block is often the
  // target of more than one item in a batch.
  glados.Generator<_PlanDiffCase> get planDiffCase =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(
          1,
          4,
          glados.CombinableAny(this).combine2(
            glados.IntAnys(this).intInRange(0, 95),
            glados.IntAnys(this).intInRange(1, 24),
            (int start, int length) => (start, (start + length).clamp(1, 96)),
          ),
        ),
        glados.ListAnys(this).listWithLengthInRange(0, 7, _itemSpec),
        _PlanDiffCase.new,
      );

  glados.Generator<Map<String, dynamic>?> get _rawSnapshot =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(-2, 97),
        glados.IntAnys(this).intInRange(-1, 97),
        glados.IntAnys(this).intInRange(0, _types.length),
        glados.IntAnys(this).intInRange(-2, 90),
        glados.BoolAny(this).bool,
        (int start, int end, int type, int remaining, bool full) => start == -2
            ? null
            : {
                if (start >= 0) 'start': _slot(start).toIso8601String(),
                if (end >= 0) 'end': _slot(end).toIso8601String(),
                'type': ?_types[type],
                if (remaining >= -1) 'remainingMinutes': remaining,
                if (full) ...{
                  'title': ' Focus ',
                  'categoryId': 'cat-1',
                  'taskId': 'task-1',
                  'reason': 'because',
                },
              },
      );

  glados.Generator<Map<String, dynamic>> get rawPlanChange =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 3),
        _rawSnapshot,
        _rawSnapshot,
        (
          int action,
          int blockId,
          Map<String, dynamic>? from,
          Map<String, dynamic>? to,
        ) => {
          'action': PlanDiffAction.values[action].name,
          'reason': 'user asked',
          'blockId': ?const [null, 'block-1', 'block-x'][blockId],
          'from': ?from,
          'to': ?to,
        },
      );
}
