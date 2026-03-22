import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';

void main() {
  group('ProjectAgentSummaryState', () {
    test(
      'isSummaryOutdated is true when report exists and activity is pending',
      () {
        final state = ProjectAgentSummaryState(
          agentId: 'agent-1',
          hasReport: true,
          pendingProjectActivityAt: DateTime(2026, 3, 22, 12),
        );

        expect(state.isSummaryOutdated, isTrue);
      },
    );

    test('isSummaryOutdated is false when no pending activity', () {
      const state = ProjectAgentSummaryState(
        agentId: 'agent-1',
        hasReport: true,
      );

      expect(state.isSummaryOutdated, isFalse);
    });

    test('isSummaryOutdated is false when no report', () {
      final state = ProjectAgentSummaryState(
        agentId: 'agent-1',
        hasReport: false,
        pendingProjectActivityAt: DateTime(2026, 3, 22, 12),
      );

      expect(state.isSummaryOutdated, isFalse);
    });

    test(
      'isSummaryOutdated is false when both report and activity are absent',
      () {
        const state = ProjectAgentSummaryState(
          agentId: 'agent-1',
          hasReport: false,
        );

        expect(state.isSummaryOutdated, isFalse);
      },
    );

    test('exposes all constructor fields', () {
      final wake = DateTime(2026, 3, 23, 6);
      final pending = DateTime(2026, 3, 22, 12);
      final state = ProjectAgentSummaryState(
        agentId: 'agent-42',
        hasReport: true,
        pendingProjectActivityAt: pending,
        scheduledWakeAt: wake,
      );

      expect(state.agentId, 'agent-42');
      expect(state.hasReport, isTrue);
      expect(state.pendingProjectActivityAt, pending);
      expect(state.scheduledWakeAt, wake);
    });
  });
}
