import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/service/agent_retention_policy.dart';

void main() {
  const policy = AgentRetentionPolicy();

  test('default retention windows preserve protected read ranges', () {
    expect(policy.observations, greaterThan(policy.dayStatusEvents));
    expect(policy.dayStatusEvents, greaterThan(const Duration(days: 3)));
  });

  test('default sweep limits are positive and bounded', () {
    expect(policy.agentsPerSweep, greaterThan(0));
    expect(
      policy.maxAgentsPerSweep,
      greaterThanOrEqualTo(policy.agentsPerSweep),
    );
    expect(policy.maxAgentMessages, greaterThan(0));
    expect(policy.batchSize, greaterThan(0));
    expect(policy.maxBatchesPerSweep, greaterThan(0));
  });
}
