import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/project_proposal_reconciler.dart';

/// The wake's clock. Fixed: nothing here reads a real one.
final _now = DateTime(2026, 9, 9, 10);

ProjectStatus _active() =>
    ProjectStatus.active(id: 's-active', createdAt: _now, utcOffset: 0);

ProjectStatus _onHold(String reason) => ProjectStatus.onHold(
  id: 's-hold',
  createdAt: _now,
  utcOffset: 0,
  reason: reason,
);

ChangeItem _statusItem(String status, {String summary = 'Update status'}) =>
    ChangeItem(
      toolName: ProjectAgentToolNames.updateProjectStatus,
      args: {'status': status, 'reason': 'because'},
      humanSummary: summary,
    );

ChangeItem _taskItem(String title) => ChangeItem(
  toolName: ProjectAgentToolNames.createTask,
  args: {'title': title},
  humanSummary: 'Create task: $title',
);

LedgerEntry _entry(
  ChangeItem item, {
  ChangeItemStatus status = ChangeItemStatus.pending,
  ChangeDecisionVerdict? verdict,
}) => LedgerEntry(
  changeSetId: 'set-1',
  itemIndex: 0,
  toolName: item.toolName,
  args: item.args,
  humanSummary: item.humanSummary,
  fingerprint: ChangeItem.fingerprint(item),
  status: status,
  createdAt: _now,
  verdict: verdict,
);

void main() {
  group('projectStatusProposalIsRedundant', () {
    test('is redundant when the canonical status matches the current one', () {
      expect(
        projectStatusProposalIsRedundant(
          current: _active(),
          args: {'status': 'active'},
        ),
        isTrue,
      );
    });

    test('resolves aliases before comparing, so on_track means active', () {
      // The exact shape of the reported bug: the agent proposed `on_track` on
      // an already-active project, wake after wake.
      expect(
        projectStatusProposalIsRedundant(
          current: _active(),
          args: {'status': 'on_track', 'reason': 'All tasks progressing'},
        ),
        isTrue,
      );
    });

    test('is not redundant when the status would actually change', () {
      expect(
        projectStatusProposalIsRedundant(
          current: _active(),
          args: {'status': 'completed'},
        ),
        isFalse,
      );
    });

    test('is not redundant for a word outside the vocabulary', () {
      // Invalid input belongs to the apply path, which explains what the
      // vocabulary is. Swallowing it here would lose that feedback.
      expect(
        projectStatusProposalIsRedundant(
          current: _active(),
          args: {'status': 'vibing'},
        ),
        isFalse,
      );
    });

    test('is not redundant when status is missing or not a string', () {
      expect(
        projectStatusProposalIsRedundant(current: _active(), args: {}),
        isFalse,
      );
      expect(
        projectStatusProposalIsRedundant(
          current: _active(),
          args: {'status': 7},
        ),
        isFalse,
      );
    });

    test('on hold with the same reason is redundant', () {
      expect(
        projectStatusProposalIsRedundant(
          current: _onHold('Waiting on legal'),
          args: {'status': 'on_hold', 'reason': '  Waiting on legal  '},
        ),
        isTrue,
      );
    });

    test('on hold with a new reason is a real change', () {
      // The reason is user-facing text, so changing it changes what the user
      // reads even though the status word is the same.
      expect(
        projectStatusProposalIsRedundant(
          current: _onHold('Waiting on legal'),
          args: {'status': 'on_hold', 'reason': 'Waiting on the supplier'},
        ),
        isFalse,
      );
    });

    test(
      'on hold without a reason cannot change the reason, so is redundant',
      () {
        expect(
          projectStatusProposalIsRedundant(
            current: _onHold('Waiting on legal'),
            args: {'status': 'on_hold'},
          ),
          isTrue,
        );
      },
    );
  });

  group('normalizeProjectProposalArgs', () {
    test('replaces a status alias with the status it means', () {
      // `on_track` renders and applies as Active, so storing the alias made
      // "Update project status to Active" compare as two different
      // proposals and the band accumulated both.
      expect(
        normalizeProjectProposalArgs(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'on_track', 'reason': 'progressing'},
        ),
        {'status': 'active', 'reason': 'progressing'},
      );
    });

    test('normalizes case, spaces and hyphens through the alias table', () {
      for (final raw in ['ON HOLD', 'on-hold', ' Blocked ']) {
        expect(
          normalizeProjectProposalArgs(
            ProjectAgentToolNames.updateProjectStatus,
            {'status': raw},
          )['status'],
          'on_hold',
          reason: '$raw should normalize like the apply path does',
        );
      }
    });

    test('leaves a word outside the vocabulary verbatim', () {
      // The apply path reports what the vocabulary is; swallowing the word
      // here would lose that.
      expect(
        normalizeProjectProposalArgs(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'vibing'},
        ),
        {'status': 'vibing'},
      );
    });

    test('returns the same map when nothing needs changing', () {
      final args = {'status': 'active'};
      expect(
        identical(
          normalizeProjectProposalArgs(
            ProjectAgentToolNames.updateProjectStatus,
            args,
          ),
          args,
        ),
        isTrue,
      );
    });

    test('leaves a non-string or missing status alone', () {
      expect(
        normalizeProjectProposalArgs(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 7},
        ),
        {'status': 7},
      );
      expect(
        normalizeProjectProposalArgs(
          ProjectAgentToolNames.updateProjectStatus,
          const {},
        ),
        isEmpty,
      );
    });

    test('leaves every other tool untouched', () {
      final args = {'title': 'on_track'};
      expect(
        identical(
          normalizeProjectProposalArgs(
            ProjectAgentToolNames.createTask,
            args,
          ),
          args,
        ),
        isTrue,
      );
    });
  });

  group('reconcileProjectProposals', () {
    test('keeps everything when nothing is open', () {
      final proposed = [_statusItem('completed'), _taskItem('Ship it')];
      expect(
        reconcileProjectProposals(
          proposed: proposed,
          ledger: const ProposalLedger.empty(),
        ),
        proposed,
      );
    });

    test('drops a proposal identical to one already open', () {
      final open = _statusItem('active');
      final result = reconcileProjectProposals(
        proposed: [open, _taskItem('Ship it')],
        ledger: ProposalLedger(open: [_entry(open)], resolved: const []),
      );
      expect(result.map((item) => item.toolName), [
        ProjectAgentToolNames.createTask,
      ]);
    });

    test('drops a proposal that only reads identically to an open one', () {
      // Different args, same rendered summary: the user would see two rows
      // saying exactly the same thing.
      final open = _statusItem('active', summary: 'Update project status');
      const restated = ChangeItem(
        toolName: ProjectAgentToolNames.updateProjectStatus,
        args: {'status': 'active', 'reason': 'a different rationale'},
        humanSummary: 'Update project status',
      );
      expect(
        reconcileProjectProposals(
          proposed: [restated],
          ledger: ProposalLedger(open: [_entry(open)], resolved: const []),
        ),
        isEmpty,
      );
    });

    test('drops a proposal the user already rejected', () {
      final rejected = _taskItem('Write the launch roadmap');
      expect(
        reconcileProjectProposals(
          proposed: [rejected],
          ledger: ProposalLedger(
            open: const [],
            resolved: [
              _entry(
                rejected,
                status: ChangeItemStatus.rejected,
                verdict: ChangeDecisionVerdict.rejected,
              ),
            ],
          ),
        ),
        isEmpty,
      );
    });

    test(
      'keeps a proposal the user confirmed — that one is done, not vetoed',
      () {
        final confirmed = _taskItem('Write the launch roadmap');
        expect(
          reconcileProjectProposals(
            proposed: [confirmed],
            ledger: ProposalLedger(
              open: const [],
              resolved: [
                _entry(
                  confirmed,
                  status: ChangeItemStatus.confirmed,
                  verdict: ChangeDecisionVerdict.confirmed,
                ),
              ],
            ),
          ),
          hasLength(1),
        );
      },
    );

    test('collapses duplicates proposed twice inside one wake', () {
      final item = _taskItem('Ship it');
      expect(
        reconcileProjectProposals(
          proposed: [item, item],
          ledger: const ProposalLedger.empty(),
        ),
        hasLength(1),
      );
    });

    test('collapses same-wake proposals that render the same row', () {
      // Same title, different optional args: different fingerprints, one
      // rendered summary. Keeping both would let the user confirm each and
      // create the task twice.
      const first = ChangeItem(
        toolName: ProjectAgentToolNames.createTask,
        args: {'title': 'Ship it', 'description': 'the long way'},
        humanSummary: 'Create task: Ship it',
      );
      const second = ChangeItem(
        toolName: ProjectAgentToolNames.createTask,
        args: {'title': 'Ship it', 'priority': 'HIGH'},
        humanSummary: 'Create task: Ship it',
      );
      final result = reconcileProjectProposals(
        proposed: [first, second],
        ledger: const ProposalLedger.empty(),
      );

      expect(result, [first], reason: 'the first occurrence wins');
    });

    test('a status alias no longer survives as a second row', () {
      // The end-to-end shape of the accumulation bug, once the args are
      // normalized at the boundary: both spellings reduce to one proposal.
      final open = _statusItem('active', summary: 'Update status to active');
      final alias = ChangeItem(
        toolName: ProjectAgentToolNames.updateProjectStatus,
        args: normalizeProjectProposalArgs(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'on_track', 'reason': 'because'},
        ),
        humanSummary: 'Update status to active',
      );
      expect(
        reconcileProjectProposals(
          proposed: [alias],
          ledger: ProposalLedger(open: [_entry(open)], resolved: const []),
        ),
        isEmpty,
      );
    });

    test('two on-hold proposals with different reasons both survive', () {
      // The reason is user-facing and the apply path treats a new one as a
      // real change, so normalization must not collapse them.
      final first = ChangeItem(
        toolName: ProjectAgentToolNames.updateProjectStatus,
        args: normalizeProjectProposalArgs(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'blocked', 'reason': 'waiting on legal'},
        ),
        humanSummary: 'Put on hold: waiting on legal',
      );
      final second = ChangeItem(
        toolName: ProjectAgentToolNames.updateProjectStatus,
        args: normalizeProjectProposalArgs(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'on_hold', 'reason': 'waiting on the supplier'},
        ),
        humanSummary: 'Put on hold: waiting on the supplier',
      );
      expect(
        reconcileProjectProposals(
          proposed: [second],
          ledger: ProposalLedger(open: [_entry(first)], resolved: const []),
        ),
        [second],
      );
    });

    test('preserves the order of what survives', () {
      final open = _statusItem('active');
      final first = _taskItem('First');
      final second = _taskItem('Second');
      final result = reconcileProjectProposals(
        proposed: [first, open, second],
        ledger: ProposalLedger(open: [_entry(open)], resolved: const []),
      );
      expect(
        result.map((item) => item.args['title']),
        ['First', 'Second'],
      );
    });

    test('an empty proposal list is returned untouched', () {
      expect(
        reconcileProjectProposals(
          proposed: const [],
          ledger: const ProposalLedger.empty(),
        ),
        isEmpty,
      );
    });
  });

  group('canonicalProjectStatusOf', () {
    test('round-trips every status through the alias table', () {
      // The two tables must agree, or the redundancy check silently never
      // fires for whichever status they disagree on.
      final statuses = <ProjectStatus>[
        ProjectStatus.open(id: 'o', createdAt: _now, utcOffset: 0),
        _active(),
        ProjectStatus.monitoring(id: 'm', createdAt: _now, utcOffset: 0),
        _onHold('reason'),
        ProjectStatus.completed(id: 'c', createdAt: _now, utcOffset: 0),
        ProjectStatus.archived(id: 'a', createdAt: _now, utcOffset: 0),
      ];
      for (final status in statuses) {
        final canonical = canonicalProjectStatusOf(status);
        expect(
          canonicalProjectStatus(canonical),
          canonical,
          reason: '$canonical is not a value the wire vocabulary accepts',
        );
      }
      expect(
        statuses.map(canonicalProjectStatusOf).toSet(),
        hasLength(statuses.length),
        reason: 'two statuses must never share a canonical value',
      );
    });
  });
}
