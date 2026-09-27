import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_link_slot.dart';

import '../test_data/link_factories.dart';
import '../test_data/soul_factories.dart';

void main() {
  group('AgentLinkSlot.of', () {
    test('a soul assignment fills the soul slot of its fromId template', () {
      final slot = AgentLinkSlot.of(
        makeTestSoulAssignmentLink(fromId: 'tpl', toId: 'soul'),
      );
      expect(slot, const AgentLinkSlot.soul('tpl'));
      expect(slot!.type, AgentLinkTypes.soulAssignment);
      expect(slot.keyedByFromId, isTrue);
    });

    test('an improver target fills the improver slot of its toId template', () {
      final slot = AgentLinkSlot.of(
        makeTestImproverTargetLink(fromId: 'improver', toId: 'tpl'),
      );
      expect(slot, const AgentLinkSlot.improver('tpl'));
      expect(slot!.type, AgentLinkTypes.improverTarget);
      expect(slot.keyedByFromId, isFalse);
    });

    test('any other link has no slot', () {
      expect(AgentLinkSlot.of(makeTestBasicLink()), isNull);
    });
  });

  test('slots of different templates or kinds are different', () {
    expect(
      const AgentLinkSlot.soul('a'),
      isNot(const AgentLinkSlot.soul('b')),
    );
    expect(
      const AgentLinkSlot.soul('a'),
      isNot(const AgentLinkSlot.improver('a')),
    );
    expect(
      const AgentLinkSlot.soul('a').hashCode,
      const AgentLinkSlot.soul('a').hashCode,
    );
  });
}
