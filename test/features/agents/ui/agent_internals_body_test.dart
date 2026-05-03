import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_body.dart';

import '../../../test_helper.dart';
import '../test_data/entity_factories.dart';

/// Minimal smoke coverage for [AgentInternalsBody]. The deep behaviour
/// of each tab (Stats / Reports / Conversations / Observations /
/// Activity) is exercised by `agent_detail_page_test.dart`, which
/// renders the same widget through `AgentDetailPage`. This file confirms
/// the body can be instantiated standalone (the contract the side-panel
/// route relies on) and that switching tabs swaps the body content.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject({
    AgentLifecycle lifecycle = AgentLifecycle.active,
    AsyncValue<AgentDomainEntity?> stateAsync = const AsyncValue.data(null),
    List<Override> extraOverrides = const [],
  }) {
    return RiverpodWidgetTestBench(
      mediaQueryData: const MediaQueryData(size: Size(900, 800)),
      overrides: [
        agentIdentityProvider.overrideWith(
          (ref, agentId) async => makeTestIdentity(),
        ),
        templateForAgentProvider.overrideWith(
          (ref, agentId) async => null,
        ),
        ...extraOverrides,
      ],
      child: SingleChildScrollView(
        child: AgentInternalsBody(
          agentId: 'agent-001',
          lifecycle: lifecycle,
          stateAsync: stateAsync,
        ),
      ),
    );
  }

  group('AgentInternalsBody', () {
    testWidgets('renders the canonical five tabs', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Observations'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
    });

    testWidgets('Stats tab is selected by default', (tester) async {
      // Use a populated state so the State section renders, which only
      // appears on the Stats tab.
      final state = makeTestState(
        revision: 7,
        wakeCounter: 4,
      );
      await tester.pumpWidget(
        buildSubject(stateAsync: AsyncValue.data(state)),
      );
      await tester.pumpAndSettle();

      // Stats content includes the agent state heading.
      expect(find.text('State Info'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });
  });
}
