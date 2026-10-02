import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_audit.dart';
import 'package:lotti/features/agents/wake/wake_budget.dart';
import 'package:lotti/services/domain_logging.dart';

void main() {
  group('formatWakeAudit', () {
    test('writes greppable key=value pairs and only the fields it has', () {
      final line = formatWakeAudit(
        stage: 'execute',
        agentId: 'agent-1',
        cause: WakeDecisionCause.budgetExhausted,
        reason: 'subscription',
        initiator: WakeInitiator.automation,
        reasonId: 'agent-1_project_direct_p',
        tokenCount: 3,
        budgetUsed: 10,
        budgetMax: 10,
        detail: 'x',
      );

      expect(
        line,
        'wake suppressed stage=execute '
        'agent=${DomainLogger.sanitizeId('agent-1')} '
        'cause=budgetExhausted reason=subscription initiator=automation '
        'source=${DomainLogger.sanitizeId('agent-1_project_direct_p')} '
        'tokens=3 budget=10/10 detail=x',
      );
      expect(
        formatWakeAudit(
          stage: 'enqueue',
          agentId: 'agent-1',
          cause: WakeDecisionCause.allowed,
        ),
        'wake allowed stage=enqueue '
        'agent=${DomainLogger.sanitizeId('agent-1')} cause=allowed',
      );
    });

    test('never prints a trigger token, only how many there were', () {
      final line = formatWakeAudit(
        stage: 'enqueue',
        agentId: 'agent-1',
        cause: WakeDecisionCause.allowed,
        tokenCount: 2,
      );
      expect(line, isNot(contains('task-')));
      expect(line, contains('tokens=2'));
    });
  });

  group('WakePolicyDecision.fromBudget', () {
    test('maps every budget verdict to its cause and keeps the usage', () {
      final expected = {
        WakeBudgetVerdict.allowed: WakeDecisionCause.allowed,
        WakeBudgetVerdict.automaticBudgetExhausted:
            WakeDecisionCause.budgetExhausted,
        WakeBudgetVerdict.hardCeilingReached:
            WakeDecisionCause.hardCeilingReached,
      };
      for (final MapEntry(key: verdict, value: cause) in expected.entries) {
        final decision = WakePolicyDecision.fromBudget(
          verdict,
          used: 4,
          max: 5,
        );
        expect(decision.cause, cause);
        expect(decision.allowed, verdict.isAllowed);
        expect(decision.budgetUsed, 4);
        expect(decision.budgetMax, 5);
      }
    });

    test('a refusal error names its cause', () {
      expect(
        const WakeRefusedError(WakeDecisionCause.agentInactive).toString(),
        'WakeRefusedError(agentInactive)',
      );
    });
  });
}
