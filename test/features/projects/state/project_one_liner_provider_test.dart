import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/state/project_one_liner_provider.dart';

import '../../agents/test_utils.dart';

void main() {
  group('projectOneLinerProvider', () {
    const projectId = 'project-1';
    const agentId = 'agent-project-1';

    test('returns oneLiner when agent report has one', () async {
      const expectedOneLiner = 'Steady progress; next milestone is API v2.';

      final container = ProviderContainer(
        overrides: [
          projectAgentProvider(
            projectId,
          ).overrideWith(
            (ref) async => makeTestIdentity(agentId: agentId),
          ),
          agentReportProvider(
            agentId,
          ).overrideWith(
            (ref) async => makeTestReport(
              agentId: agentId,
              oneLiner: expectedOneLiner,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        projectOneLinerProvider(projectId).future,
      );

      expect(result, expectedOneLiner);
    });

    // All returns-null permutations share one body; each case supplies the
    // overrides that model its failure mode.
    final nullCases = <(String, List<Override> Function())>[
      (
        'no project agent exists',
        () => [
          projectAgentProvider(projectId).overrideWith((ref) async => null),
        ],
      ),
      (
        'agent resolves to a non-identity entity',
        () => [
          projectAgentProvider(
            projectId,
          ).overrideWith((ref) async => makeTestState(agentId: agentId)),
        ],
      ),
      (
        'agent report has no oneLiner',
        () => [
          projectAgentProvider(
            projectId,
          ).overrideWith((ref) async => makeTestIdentity(agentId: agentId)),
          agentReportProvider(
            agentId,
          ).overrideWith((ref) async => makeTestReport(agentId: agentId)),
        ],
      ),
      (
        'oneLiner is empty',
        () => [
          projectAgentProvider(
            projectId,
          ).overrideWith((ref) async => makeTestIdentity(agentId: agentId)),
          agentReportProvider(agentId).overrideWith(
            (ref) async => makeTestReport(agentId: agentId, oneLiner: ''),
          ),
        ],
      ),
      (
        'oneLiner is only whitespace',
        () => [
          projectAgentProvider(
            projectId,
          ).overrideWith((ref) async => makeTestIdentity(agentId: agentId)),
          agentReportProvider(agentId).overrideWith(
            (ref) async => makeTestReport(agentId: agentId, oneLiner: '   '),
          ),
        ],
      ),
      (
        'agent report is null',
        () => [
          projectAgentProvider(
            projectId,
          ).overrideWith((ref) async => makeTestIdentity(agentId: agentId)),
          agentReportProvider(agentId).overrideWith((ref) async => null),
        ],
      ),
    ];

    for (final (description, overrides) in nullCases) {
      test('returns null when $description', () async {
        final container = ProviderContainer(overrides: overrides());
        addTearDown(container.dispose);

        final result = await container.read(
          projectOneLinerProvider(projectId).future,
        );

        expect(result, isNull, reason: description);
      });
    }

    test('trims whitespace from oneLiner', () async {
      final container = ProviderContainer(
        overrides: [
          projectAgentProvider(
            projectId,
          ).overrideWith(
            (ref) async => makeTestIdentity(agentId: agentId),
          ),
          agentReportProvider(
            agentId,
          ).overrideWith(
            (ref) async => makeTestReport(
              agentId: agentId,
              oneLiner: '  Wrapping up the last sprint items.  ',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        projectOneLinerProvider(projectId).future,
      );

      expect(result, 'Wrapping up the last sprint items.');
    });
  });
}
