import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';

void main() {
  group('AgentTokenUsageSummary', () {
    test('computes totalTokens as input + output + thoughts', () {
      const summary = AgentTokenUsageSummary(
        modelId: 'gemini-2.5-pro',
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
        wakeCount: 3,
      );

      // cachedInputTokens is a subset of inputTokens, not additive.
      expect(summary.totalTokens, 175);
    });

    test('defaults to zero for all counts', () {
      const summary = AgentTokenUsageSummary(modelId: 'test');

      expect(summary.inputTokens, 0);
      expect(summary.outputTokens, 0);
      expect(summary.thoughtsTokens, 0);
      expect(summary.cachedInputTokens, 0);
      expect(summary.wakeCount, 0);
      expect(summary.totalTokens, 0);
    });

    test('equality compares all fields', () {
      const a = AgentTokenUsageSummary(
        modelId: 'model-a',
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
        wakeCount: 2,
      );
      const b = AgentTokenUsageSummary(
        modelId: 'model-a',
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
        wakeCount: 2,
      );
      const c = AgentTokenUsageSummary(
        modelId: 'model-a',
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
        wakeCount: 3, // different
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString includes all fields', () {
      const summary = AgentTokenUsageSummary(
        modelId: 'gemini-2.5-pro',
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
        wakeCount: 3,
      );

      final str = summary.toString();
      expect(str, contains('gemini-2.5-pro'));
      expect(str, contains('100'));
      expect(str, contains('50'));
      expect(str, contains('25'));
      expect(str, contains('10'));
      expect(str, contains('3'));
    });
  });

  group('InstanceTokenBreakdown', () {
    test('totalTokens computed correctly from summaries', () {
      const breakdown = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: [
          AgentTokenUsageSummary(
            modelId: 'gemini-2.5-pro',
            inputTokens: 100,
            outputTokens: 50,
            thoughtsTokens: 25,
          ),
          AgentTokenUsageSummary(
            modelId: 'claude-sonnet',
            inputTokens: 200,
            outputTokens: 100,
            thoughtsTokens: 50,
          ),
        ],
      );

      // (100+50+25) + (200+100+50) = 175 + 350 = 525
      expect(breakdown.totalTokens, 525);
    });

    test('empty summaries list returns 0 totalTokens', () {
      const breakdown = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: [],
      );

      expect(breakdown.totalTokens, 0);
    });

    test('equality and hashCode', () {
      const a = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: [
          AgentTokenUsageSummary(
            modelId: 'gemini-2.5-pro',
            inputTokens: 100,
            outputTokens: 50,
          ),
        ],
      );
      const b = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: [
          AgentTokenUsageSummary(
            modelId: 'gemini-2.5-pro',
            inputTokens: 100,
            outputTokens: 50,
          ),
        ],
      );
      const c = InstanceTokenBreakdown(
        agentId: 'agent-2',
        displayName: 'Agent Two',
        lifecycle: AgentLifecycle.dormant,
        summaries: [],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString includes relevant fields', () {
      const breakdown = InstanceTokenBreakdown(
        agentId: 'agent-1',
        displayName: 'Agent One',
        lifecycle: AgentLifecycle.active,
        summaries: [
          AgentTokenUsageSummary(
            modelId: 'gemini-2.5-pro',
            inputTokens: 100,
            outputTokens: 50,
            thoughtsTokens: 25,
          ),
        ],
      );

      final str = breakdown.toString();
      expect(str, contains('agent-1'));
      expect(str, contains('Agent One'));
      expect(str, contains('active'));
      expect(str, contains('175'));
    });
  });
}
