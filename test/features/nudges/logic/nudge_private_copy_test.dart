import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/nudges/logic/nudge_private_copy.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';

void main() {
  NudgeEntityView nudge(Map<String, String> provenance) => NudgeEntityView.of(
    AgentDomainEntity.goalNudge(
      id: 'nudge-1',
      agentId: 'goal-1',
      status: NudgeStatus.active,
      brief: const NudgeBrief(
        headline: 'Your agent has a question',
        cta: 'Answer in chat',
        tone: NudgeTone.encourage,
        animation: NudgeBannerAnimation.steady,
      ),
      briefDigest: 'digest',
      createdAt: DateTime.utc(2026, 8, 13),
      updatedAt: DateTime.utc(2026, 8, 13),
      vectorClock: null,
      provenance: provenance,
    ),
  )!;

  const private = {
    nudgePrivateHeadlineKey: 'Did the physio clear the ridge walk?',
    nudgePrivateTaglineKey: 'You wanted to know before Saturday.',
  };

  test('shows the private words only while private entries are shown', () {
    final shown = nudgeDisplayBrief(nudge(private), showPrivate: true);
    expect(shown.headline, 'Did the physio clear the ridge walk?');
    expect(shown.tagline, 'You wanted to know before Saturday.');
    // Everything else stays the stored brief's.
    expect(shown.cta, 'Answer in chat');
    expect(shown.tone, NudgeTone.encourage);

    final hidden = nudgeDisplayBrief(nudge(private), showPrivate: false);
    expect(hidden.headline, 'Your agent has a question');
    expect(hidden.tagline, isNull);
  });

  test('a banner without private words, or with blank ones, shows its brief '
      'either way', () {
    for (final provenance in [
      const <String, String>{},
      const {nudgePrivateHeadlineKey: '  '},
    ]) {
      expect(
        nudgeDisplayBrief(nudge(provenance), showPrivate: true).headline,
        'Your agent has a question',
      );
    }
  });
}
