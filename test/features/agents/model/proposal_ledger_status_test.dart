import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger_status.dart';

import '../test_data/change_set_factories.dart';

void main() {
  group('proposal-ledger status state machine (exhaustive matrix)', () {
    test('isPendingLike: only pending and partiallyResolved are active', () {
      const expected = {
        ChangeSetStatus.pending: true,
        ChangeSetStatus.partiallyResolved: true,
        ChangeSetStatus.resolved: false,
        ChangeSetStatus.expired: false,
      };
      for (final status in ChangeSetStatus.values) {
        expect(isPendingLike(status), expected[status], reason: '$status');
      }
    });

    test(
      'effectiveLedgerStatus over the full '
      'setIsActive x itemStatus x verdict cross-product',
      () {
        ChangeItemStatus statusFor(ChangeDecisionVerdict verdict) =>
            switch (verdict) {
              ChangeDecisionVerdict.confirmed => ChangeItemStatus.confirmed,
              ChangeDecisionVerdict.rejected => ChangeItemStatus.rejected,
              ChangeDecisionVerdict.deferred => ChangeItemStatus.deferred,
              ChangeDecisionVerdict.retracted => ChangeItemStatus.retracted,
            };

        for (final setIsActive in [false, true]) {
          for (final itemStatus in ChangeItemStatus.values) {
            for (final verdict in [null, ...ChangeDecisionVerdict.values]) {
              final item = ChangeItem(
                toolName: 'update_task_estimate',
                args: const {'estimate': 30},
                humanSummary: 'Set estimate',
                status: itemStatus,
              );
              final decision = verdict == null
                  ? null
                  : makeTestChangeDecision(verdict: verdict);

              // Oracle, mirroring the documented contract:
              //  * a non-pending embedded status is always authoritative;
              //  * no decision leaves a pending item pending;
              //  * a confirmed verdict on an ACTIVE set keeps the item
              //    pending (dispatch may have failed and reverted it);
              //  * otherwise the decision's verdict closes the item.
              final ChangeItemStatus expected;
              if (itemStatus != ChangeItemStatus.pending) {
                expected = itemStatus;
              } else if (verdict == null) {
                expected = ChangeItemStatus.pending;
              } else if (setIsActive &&
                  verdict == ChangeDecisionVerdict.confirmed) {
                expected = ChangeItemStatus.pending;
              } else {
                expected = statusFor(verdict);
              }

              expect(
                effectiveLedgerStatus(
                  setIsActive: setIsActive,
                  item: item,
                  decision: decision,
                ),
                expected,
                reason:
                    'setIsActive=$setIsActive itemStatus=$itemStatus '
                    'verdict=$verdict',
              );
            }
          }
        }
      },
    );
  });
}
