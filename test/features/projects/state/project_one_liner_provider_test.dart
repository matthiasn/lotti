import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/state/project_one_liner_provider.dart';

import '../../../features/agents/test_utils.dart';

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

    test('returns null when no project agent exists', () async {
      final container = ProviderContainer(
        overrides: [
          projectAgentProvider(projectId).overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        projectOneLinerProvider(projectId).future,
      );

      expect(result, isNull);
    });

    test(
      'returns null when agent resolves to a non-identity entity',
      () async {
        final container = ProviderContainer(
          overrides: [
            projectAgentProvider(
              projectId,
            ).overrideWith(
              (ref) async => makeTestState(agentId: agentId),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          projectOneLinerProvider(projectId).future,
        );

        expect(result, isNull);
      },
    );

    test('returns null when agent report has no oneLiner', () async {
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
            (ref) async => makeTestReport(agentId: agentId),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        projectOneLinerProvider(projectId).future,
      );

      expect(result, isNull);
    });

    test('returns null when oneLiner is empty', () async {
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
              oneLiner: '',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        projectOneLinerProvider(projectId).future,
      );

      expect(result, isNull);
    });

    test('returns null when oneLiner is only whitespace', () async {
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
              oneLiner: '   ',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        projectOneLinerProvider(projectId).future,
      );

      expect(result, isNull);
    });

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

    test('returns null when agent report is null', () async {
      final container = ProviderContainer(
        overrides: [
          projectAgentProvider(
            projectId,
          ).overrideWith(
            (ref) async => makeTestIdentity(agentId: agentId),
          ),
          agentReportProvider(agentId).overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        projectOneLinerProvider(projectId).future,
      );

      expect(result, isNull);
    });
  });
}
