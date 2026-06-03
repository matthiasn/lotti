import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_kind.dart';

import '../../../agents/test_data/entity_factories.dart';

void main() {
  group('DayAgentKind', () {
    test('wires the shared day-agent kind and template constants', () {
      expect(DayAgentKind.agentKind, AgentKinds.dayAgent);
      expect(DayAgentKind.templateKind, AgentTemplateKind.dayAgent);
    });

    test('matches() is true for a day-agent identity', () {
      final identity = makeTestIdentity(kind: AgentKinds.dayAgent);
      expect(DayAgentKind.matches(identity), isTrue);
    });

    test('matches() is false for an identity of a different kind', () {
      expect(
        DayAgentKind.matches(makeTestIdentity(kind: 'project_agent')),
        isFalse,
      );
      expect(
        DayAgentKind.matches(makeTestIdentity(kind: 'some_other_kind')),
        isFalse,
      );
    });
  });
}
