import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_contract.dart';

void main() {
  test('the system prompt stays lean — growth is argued, not accreted '
      '(the goal-contract hard-cap discipline)', () {
    expect(relationshipAgentSystemPrompt.length, lessThanOrEqualTo(3600));
  });

  test('the prompt carries the ADR 0040 honesty rules and the privacy '
      'boundary', () {
    expect(relationshipAgentSystemPrompt, contains('ONLY captured check-ins'));
    expect(relationshipAgentSystemPrompt, contains('recency'));
    expect(
      relationshipAgentSystemPrompt,
      contains("user's own judgment"),
      reason: 'sentiments ground the band first (ADR 0038/0040)',
    );
    expect(
      relationshipAgentSystemPrompt,
      contains('Never invent contact details'),
      reason: 'ADR 0041 §5 — channels are structurally absent from FACTS',
    );
    expect(relationshipAgentSystemPrompt, contains('No images'));
  });

  test('tool names keep the uniform verb_relationship_noun prefix', () {
    expect(
      RelationshipAgentToolNames.updateRelationshipReport,
      'update_relationship_report',
    );
    expect(
      RelationshipAgentToolNames.createRelationshipAd,
      'create_relationship_ad',
    );
    expect(
      RelationshipAgentToolNames.snoozeRelationshipAd,
      'snooze_relationship_ad',
    );
    expect(RelationshipAgentToolNames.replyToUser, 'reply_to_user');
  });

  test('the tool surface is exactly the four tools of plan v2 phase 5', () {
    expect(relationshipAgentTools.map((tool) => tool.name), [
      RelationshipAgentToolNames.replyToUser,
      RelationshipAgentToolNames.updateRelationshipReport,
      RelationshipAgentToolNames.createRelationshipAd,
      RelationshipAgentToolNames.snoozeRelationshipAd,
    ]);
  });

  test('the catalogs are derived from the real enums — the contract cannot '
      'drift from the code-owned presets (ADR 0058)', () {
    expect(
      relationshipHealthBandNames,
      [for (final band in RelationshipHealthBand.values) band.name],
    );
    expect(
      relationshipNudgeToneNames,
      [for (final tone in NudgeTone.values) tone.name],
    );
    expect(
      relationshipBannerAnimationNames,
      [for (final a in NudgeBannerAnimation.values) a.name],
    );
    expect(
      relationshipBannerAccentNames,
      [for (final a in NudgeBannerAccent.values) a.name],
    );
  });

  test('the report tool requires the full briefing including the grounded '
      'health verdict', () {
    final report = relationshipAgentTools.singleWhere(
      (tool) =>
          tool.name == RelationshipAgentToolNames.updateRelationshipReport,
    );
    expect(report.parameters['required'], [
      'healthBand',
      'healthRationale',
      'oneLiner',
      'tldr',
      'content',
    ]);
    final properties = report.parameters['properties']! as Map<String, dynamic>;
    expect(
      (properties['healthBand'] as Map<String, dynamic>)['enum'],
      relationshipHealthBandNames,
    );
  });

  test('the ad tool requires headline, tone and animation — copy plus '
      'presets, never an image', () {
    final ad = relationshipAgentTools.singleWhere(
      (tool) => tool.name == RelationshipAgentToolNames.createRelationshipAd,
    );
    expect(ad.parameters['required'], ['headline', 'tone', 'animation']);
  });
}
