import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_item_dedup.dart';

import '../test_data/change_set_factories.dart';

ChangeItem _item(
  String toolName, {
  Map<String, dynamic> args = const {},
  String summary = 'summary',
  ChangeItemStatus status = ChangeItemStatus.pending,
}) => ChangeItem(
  toolName: toolName,
  args: args,
  humanSummary: summary,
  status: status,
);

ChangeItem _timeEntryEdit({
  String? entryId,
  String? summary,
  String? startTime,
  String? endTime,
  ChangeItemStatus status = ChangeItemStatus.pending,
}) => ChangeItem(
  toolName: TaskAgentToolNames.updateTimeEntry,
  args: {
    'entryId': ?entryId,
    'summary': ?summary,
    'startTime': ?startTime,
    'endTime': ?endTime,
  },
  humanSummary: 'Revise time entry text: "$summary"',
  status: status,
);

/// A proposal persisted under the retired `update_running_timer` name.
ChangeItem _legacyRunningTimer({
  String? timerId,
  String summary = 'Running timer text',
  ChangeItemStatus status = ChangeItemStatus.pending,
}) => ChangeItem(
  toolName: TaskAgentToolNames.updateRunningTimer,
  args: {'timerId': ?timerId, 'summary': summary},
  humanSummary: 'Update running timer text: "$summary"',
  status: status,
);

void main() {
  group('deduplicateItems', () {
    test('returns proposed unchanged when no existing or rejections', () {
      final proposed = [
        _item('set_task_title', args: const {'title': 'A'}),
        _item('set_task_title', args: const {'title': 'B'}),
      ];

      final result = deduplicateItems(proposed, const []);

      // Same instance is returned (fast path) and contents are untouched.
      expect(result, same(proposed));
      expect(result.map((i) => i.args['title']), ['A', 'B']);
    });

    test('drops items whose fingerprint already exists', () {
      final existing = [
        _item('set_task_title', args: const {'title': 'A'}, summary: 'A'),
      ];
      final proposed = [
        // Identical fingerprint to existing (humanSummary is ignored).
        _item('set_task_title', args: const {'title': 'A'}, summary: 'other'),
        _item('set_task_title', args: const {'title': 'B'}, summary: 'B'),
      ];

      final result = deduplicateItems(proposed, existing);

      expect(result, hasLength(1));
      expect(result.single.args['title'], 'B');
    });

    test('keeps distinct items', () {
      final existing = [
        _item('set_task_title', args: const {'title': 'A'}, summary: 'A'),
      ];
      final proposed = [
        _item('set_task_title', args: const {'title': 'B'}, summary: 'B'),
        _item(
          'update_task_estimate',
          args: const {'minutes': 30},
          summary: 'est',
        ),
      ];

      final result = deduplicateItems(proposed, existing);

      expect(result, hasLength(2));
      expect(result[0].args['title'], 'B');
      expect(result[1].args['minutes'], 30);
    });

    test('preserves proposed order for kept items', () {
      final existing = [
        _item('set_task_title', args: const {'title': 'B'}, summary: 'B'),
      ];
      final proposed = [
        _item('set_task_title', args: const {'title': 'A'}, summary: 'A'),
        // Filtered out (duplicate of existing).
        _item('set_task_title', args: const {'title': 'B'}, summary: 'B'),
        _item('set_task_title', args: const {'title': 'C'}, summary: 'C'),
      ];

      final result = deduplicateItems(proposed, existing);

      expect(result.map((i) => i.args['title']), ['A', 'C']);
    });

    test('blocks items matching rejectedFingerprints', () {
      final proposed = [
        _item('set_task_title', args: const {'title': 'A'}),
        _item('set_task_title', args: const {'title': 'B'}),
      ];
      final rejected = ChangeItem.fingerprintFromParts(
        'set_task_title',
        const {'title': 'A'},
      );

      final result = deduplicateItems(
        proposed,
        const [],
        rejectedFingerprints: {rejected},
      );

      expect(result, hasLength(1));
      expect(result.single.args['title'], 'B');
    });

    test('blocks items matching rejectedDisplayKeys', () {
      final blocked = _item(
        'check_off_item',
        args: const {'itemId': 'x'},
        summary: 'Check off: "Buy milk"',
      );
      final allowed = _item(
        'check_off_item',
        args: const {'itemId': 'y'},
        summary: 'Check off: "Walk dog"',
      );
      final rejectedKey = ChangeItem.displayDuplicateKey(blocked);
      expect(rejectedKey, isNotNull);

      final result = deduplicateItems(
        [blocked, allowed],
        const [],
        rejectedDisplayKeys: {rejectedKey!},
      );

      expect(result, hasLength(1));
      expect(result.single.args['itemId'], 'y');
    });

    test('drops items whose display key matches an existing item', () {
      // Same rendered summary, but different args (so fingerprints differ).
      final existing = [
        _item(
          'check_off_item',
          args: const {'itemId': 'x'},
          summary: 'Check off: "Buy milk"',
        ),
      ];
      final proposed = [
        _item(
          'check_off_item',
          args: const {'itemId': 'y'},
          summary: 'Check off: "Buy milk"',
        ),
      ];

      // Fingerprints differ but the display keys collide.
      expect(
        ChangeItem.fingerprint(existing.single),
        isNot(ChangeItem.fingerprint(proposed.single)),
      );
      expect(
        ChangeItem.displayDuplicateKey(existing.single),
        ChangeItem.displayDuplicateKey(proposed.single),
      );

      final result = deduplicateItems(proposed, existing);

      expect(result, isEmpty);
    });
  });

  group('timeEntryEdit', () {
    test('reads the trimmed entry and the fields an update sets', () {
      final edit = timeEntryEdit(
        _timeEntryEdit(entryId: '  e1 ', summary: 'x', endTime: '15:00'),
      );

      expect(edit?.entryId, 'e1');
      expect(edit?.fields, {'summary', 'endTime'});
    });

    test('reads a retired running-timer proposal as a text edit', () {
      final edit = timeEntryEdit(_legacyRunningTimer(timerId: 't1'));

      expect(edit?.entryId, 't1');
      expect(edit?.fields, {'summary'});
    });

    test('is null for any other tool, even one carrying an entryId', () {
      expect(
        timeEntryEdit(_item('set_task_title', args: const {'entryId': 'e1'})),
        isNull,
      );
    });

    test('is null when the entry id is missing, blank or not a string', () {
      expect(timeEntryEdit(_timeEntryEdit(summary: 'x')), isNull);
      expect(
        timeEntryEdit(_timeEntryEdit(entryId: '  ', summary: 'x')),
        isNull,
      );
      expect(
        timeEntryEdit(
          _item(
            TaskAgentToolNames.updateTimeEntry,
            args: const {'entryId': 42, 'summary': 'x'},
          ),
        ),
        isNull,
      );
      expect(timeEntryEdit(_legacyRunningTimer()), isNull);
    });
  });

  group('supersedesTimeEntryEdit', () {
    test('a newer text for the same entry replaces the older text', () {
      expect(
        supersedesTimeEntryEdit(
          _timeEntryEdit(entryId: 'e1', summary: 'better'),
          _timeEntryEdit(entryId: 'e1', summary: 'terse'),
        ),
        isTrue,
      );
    });

    test('never crosses entries', () {
      expect(
        supersedesTimeEntryEdit(
          _timeEntryEdit(entryId: 'e2', summary: 'better'),
          _timeEntryEdit(entryId: 'e1', summary: 'terse'),
        ),
        isFalse,
      );
    });

    test('a text revision does not swallow a pending end-time correction', () {
      expect(
        supersedesTimeEntryEdit(
          _timeEntryEdit(entryId: 'e1', summary: 'better'),
          _timeEntryEdit(entryId: 'e1', summary: 'x', endTime: '15:00'),
        ),
        isFalse,
      );
    });

    test('an edit covering every field of the older one replaces it', () {
      expect(
        supersedesTimeEntryEdit(
          _timeEntryEdit(entryId: 'e1', summary: 'x', endTime: '16:00'),
          _timeEntryEdit(entryId: 'e1', endTime: '15:00'),
        ),
        isTrue,
      );
    });

    test('an identical re-proposal is a duplicate, not a replacement', () {
      expect(
        supersedesTimeEntryEdit(
          _timeEntryEdit(entryId: 'e1', summary: 'same'),
          _timeEntryEdit(entryId: 'e1', summary: 'same'),
        ),
        isFalse,
      );
    });

    test('a text revision replaces a retired running-timer proposal', () {
      expect(
        supersedesTimeEntryEdit(
          _timeEntryEdit(entryId: 't1', summary: 'better'),
          _legacyRunningTimer(timerId: 't1'),
        ),
        isTrue,
      );
    });

    test('non time-entry proposals never supersede or get superseded', () {
      final title = _item('set_task_title', args: const {'title': 'A'});
      final edit = _timeEntryEdit(entryId: 'e1', summary: 'x');

      expect(supersedesTimeEntryEdit(title, edit), isFalse);
      expect(supersedesTimeEntryEdit(edit, title), isFalse);
    });

    glados.Glados(
      glados.any.timeEntryEditPair,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'only relates distinct edits of one entry, and both ways only when '
      'they set the same fields',
      (pair) {
        final (a, b) = pair;
        expect(supersedesTimeEntryEdit(a, a), isFalse, reason: '$a');

        final ab = supersedesTimeEntryEdit(a, b);
        final ba = supersedesTimeEntryEdit(b, a);
        if (ab || ba) {
          expect(
            timeEntryEdit(a)!.entryId,
            timeEntryEdit(b)!.entryId,
            reason: '$a / $b',
          );
        }
        if (ab && ba) {
          expect(
            timeEntryEdit(a)!.fields,
            timeEntryEdit(b)!.fields,
            reason: '$a / $b',
          );
        }
      },
      tags: 'glados',
    );
  });

  group('isSupersededByProposals', () {
    final newer = _timeEntryEdit(entryId: 'e1', summary: 'better');

    test('matches a pending edit that a proposal replaces', () {
      expect(
        isSupersededByProposals(
          _timeEntryEdit(entryId: 'e1', summary: 'terse'),
          [newer],
        ),
        isTrue,
      );
    });

    test('never matches a resolved edit', () {
      for (final status in [
        ChangeItemStatus.confirmed,
        ChangeItemStatus.rejected,
        ChangeItemStatus.retracted,
      ]) {
        expect(
          isSupersededByProposals(
            _timeEntryEdit(entryId: 'e1', summary: 'terse', status: status),
            [newer],
          ),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('never matches one of the proposals themselves', () {
      // Both set the same field, so each supersedes the other; neither may
      // retract the other because the list carries no order.
      final other = _timeEntryEdit(entryId: 'e1', summary: 'other');

      expect(isSupersededByProposals(other, [newer, other]), isFalse);
      expect(isSupersededByProposals(newer, [newer, other]), isFalse);
    });
  });

  group('locateSupersededTimeEntryEdits', () {
    test('finds every pending edit the proposals replace, across sets', () {
      final setA = makeTestChangeSet(
        id: 'set-a',
        items: [
          _legacyRunningTimer(timerId: 'e1'),
          _item('set_task_title', args: const {'title': 'X'}),
          _timeEntryEdit(
            entryId: 'e2',
            summary: 'done',
            status: ChangeItemStatus.confirmed,
          ),
        ],
      );
      final setB = makeTestChangeSet(
        id: 'set-b',
        items: [
          _timeEntryEdit(entryId: 'e2', summary: 'terse'),
          _timeEntryEdit(entryId: 'e3', summary: 'untouched'),
        ],
      );

      final matches = locateSupersededTimeEntryEdits(
        [setA, setB],
        [
          _timeEntryEdit(entryId: 'e1', summary: 'better'),
          _timeEntryEdit(entryId: 'e2', summary: 'better'),
        ],
      );

      // The legacy e1 proposal in set-a and the pending e2 one in set-b. The
      // confirmed e2 edit and the e3 edit nothing replaced are left alone.
      expect(
        matches.map((m) => (m.changeSet.id, m.itemIndex)),
        [('set-a', 0), ('set-b', 0)],
      );
      expect(matches.first.item, setA.items.first);
    });

    test('finds nothing when nothing was proposed', () {
      final set = makeTestChangeSet(
        items: [_timeEntryEdit(entryId: 'e1', summary: 'x')],
      );

      expect(locateSupersededTimeEntryEdits([set], const []), isEmpty);
    });
  });

  group('markItemsRetracted', () {
    test('retracts only matched indexes and leaves other sets untouched', () {
      final target = makeTestChangeSet(
        id: 'target',
        items: [
          _timeEntryEdit(entryId: 't1', summary: 'old'),
          _item('set_task_title', args: const {'title': 'X'}),
          _timeEntryEdit(entryId: 't2', summary: 'old'),
        ],
      );
      final untouched = makeTestChangeSet(
        id: 'untouched',
        items: [_timeEntryEdit(entryId: 't9', summary: 'old')],
      );

      final matches = locateSupersededTimeEntryEdits(
        [target, untouched],
        [_timeEntryEdit(entryId: 't1', summary: 'new')],
      );
      expect(matches, hasLength(1));

      final result = markItemsRetracted([target, untouched], matches);

      final updatedTarget = result.firstWhere((s) => s.id == 'target');
      expect(updatedTarget.items[0].status, ChangeItemStatus.retracted);
      // Non-matched items keep their original status.
      expect(updatedTarget.items[1].status, ChangeItemStatus.pending);
      expect(updatedTarget.items[2].status, ChangeItemStatus.pending);

      // A set with no matches is returned as the same instance.
      expect(result.firstWhere((s) => s.id == 'untouched'), same(untouched));
    });

    test('returns sets unchanged when matches are empty', () {
      final set = makeTestChangeSet(
        items: [_timeEntryEdit(entryId: 't1', summary: 'x')],
      );
      final result = markItemsRetracted([set], const []);
      expect(result.single, same(set));
    });
  });

  group('property: deduplicateItems invariants', () {
    glados.Glados(
      glados.any.dedupScenario,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'output never grows and every kept fingerprint is unique vs existing',
      (scenario) {
        final existing = scenario.existing;
        final proposed = scenario.proposed;

        final result = deduplicateItems(proposed, existing);

        // Output length is bounded by the input.
        expect(
          result.length,
          lessThanOrEqualTo(proposed.length),
          reason: '$scenario',
        );

        final existingFingerprints = existing
            .map(ChangeItem.fingerprint)
            .toSet();
        for (final item in result) {
          // No kept item collides with an existing fingerprint.
          expect(
            existingFingerprints.contains(ChangeItem.fingerprint(item)),
            isFalse,
            reason: '$scenario',
          );
          // Every kept item came from the proposed list (no fabrication).
          expect(proposed, contains(item), reason: '$scenario');
        }

        // Kept items preserve their relative order from proposed.
        var lastIndex = -1;
        for (final item in result) {
          final idx = proposed.indexOf(item, lastIndex + 1);
          expect(idx, greaterThan(lastIndex), reason: '$scenario');
          lastIndex = idx;
        }
      },
      tags: 'glados',
    );
  });

  group('retireConsolidatedSet', () {
    test('retracts pending items, keeps other statuses, resolves the set', () {
      final set = makeTestChangeSet(
        items: [
          _item('set_task_title', args: const {'title': 'A'}),
          _item('set_task_title', status: ChangeItemStatus.confirmed),
          _item('set_task_title', status: ChangeItemStatus.rejected),
        ],
      );

      final retired = withClock(
        Clock.fixed(DateTime(2026, 3, 15, 12)),
        () => retireConsolidatedSet(set),
      );

      expect(retired.items.map((i) => i.status), [
        ChangeItemStatus.retracted,
        ChangeItemStatus.confirmed,
        ChangeItemStatus.rejected,
      ]);
      expect(retired.status, ChangeSetStatus.resolved);
      expect(retired.resolvedAt, DateTime(2026, 3, 15, 12));
      // Everything else is preserved.
      expect(retired.id, set.id);
      expect(retired.items, hasLength(3));
    });
  });
}

class _DedupScenario {
  const _DedupScenario({required this.existing, required this.proposed});

  final List<ChangeItem> existing;
  final List<ChangeItem> proposed;

  @override
  String toString() =>
      '_DedupScenario(existing: ${existing.map((i) => i.args).toList()}, '
      'proposed: ${proposed.map((i) => i.args).toList()})';
}

extension _AnyDedupScenario on glados.Any {
  glados.Generator<ChangeItem> get dedupItem =>
      glados.CombinableAny(this).combine2(
        glados.AnyUtils(this).choose(const ['set_task_title', 'set_task_note']),
        glados.IntAnys(this).intInRange(0, 4),
        (String toolName, int titleSeed) => _item(
          toolName,
          args: {'title': 'T$titleSeed'},
          summary: 'Summary $titleSeed',
        ),
      );

  glados.Generator<_DedupScenario> get dedupScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 4, dedupItem),
        glados.ListAnys(this).listWithLengthInRange(0, 6, dedupItem),
        (List<ChangeItem> existing, List<ChangeItem> proposed) =>
            _DedupScenario(existing: existing, proposed: proposed),
      );
}

extension _AnyTimeEntryEditPair on glados.Any {
  glados.Generator<ChangeItem> get timeEntryEditItem =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 2),
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(0, 3),
        (int entrySeed, int fieldMask, int textSeed) => fieldMask == 0
            // The retired shape: text only, the entry named as a timer.
            ? _legacyRunningTimer(
                timerId: 'e$entrySeed',
                summary: 'T$textSeed',
              )
            : _timeEntryEdit(
                entryId: 'e$entrySeed',
                summary: fieldMask & 1 != 0 ? 'T$textSeed' : null,
                startTime: fieldMask & 2 != 0 ? 'S$textSeed' : null,
                endTime: fieldMask & 4 != 0 ? 'E$textSeed' : null,
              ),
      );

  glados.Generator<(ChangeItem, ChangeItem)> get timeEntryEditPair =>
      glados.CombinableAny(this).combine2(
        timeEntryEditItem,
        timeEntryEditItem,
        (ChangeItem a, ChangeItem b) => (a, b),
      );
}
