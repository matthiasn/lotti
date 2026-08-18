/// The relationship-agent eval spec: re-exports the PRODUCTION contract
/// (`lib/features/relationships/workflow/relationship_agent_contract.dart`)
/// and keeps the behavioural policy matrix the eval scenarios are derived
/// from.
///
/// Re-export rather than restate, for the reason the goal suite learned the
/// hard way: an eval that validates its own copy of a prompt measures the
/// copy. The contract the runtime ships is the contract scored here.
///
/// Keep the policy matrix in this file as the single source of truth —
/// scenarios reference rows by id, and the offline self-test fails when a
/// row has no scenario.
library;

export 'package:lotti/features/relationships/workflow/relationship_agent_contract.dart';

/// One row of the behavioural policy matrix.
class RelationshipAgentPolicyRule {
  const RelationshipAgentPolicyRule({
    required this.id,
    required this.given,
    required this.expected,
  });

  final String id;

  /// The wake situation, in FACTS terms.
  final String given;

  /// The required behaviour.
  final String expected;
}

/// The policy matrix — single source of truth for scenario expectations.
///
/// Precedence follows the contract's own numbered order: pending user
/// message > briefing > banners > silence. R2 is the cheapest discriminator
/// in the whole suite: a model that cannot stay quiet on an uneventful tick
/// will bill every day of the month for nothing, and the task- and
/// goal-agent evals both found models that churn when nothing tests it.
const relationshipAgentPolicyMatrix = [
  RelationshipAgentPolicyRule(
    id: 'R1',
    given: 'cadence ok, a check-in landed after the last briefing',
    expected: 'update_relationship_report only, no banner',
  ),
  RelationshipAgentPolicyRule(
    id: 'R2',
    given:
        'cadence ok, briefing current, no pending message — nothing '
        'material changed',
    expected: 'NO tool calls (no-op discriminator)',
  ),
  RelationshipAgentPolicyRule(
    id: 'R3',
    given: 'cadence lapsed, no active banner, no quiet window',
    expected: 'update_relationship_report + create_relationship_ad',
  ),
  RelationshipAgentPolicyRule(
    id: 'R4',
    given: 'cadence due, a fresh active banner is already showing',
    expected: 'no second banner; the briefing may still land',
  ),
  RelationshipAgentPolicyRule(
    id: 'R5',
    given: 'cadence due, the user dismissed a banner earlier today',
    expected:
        'briefing only — the rest-of-day quiet window forbids an '
        'automatic banner',
  ),
  RelationshipAgentPolicyRule(
    id: 'R6',
    given: 'no check-in ever recorded, cadence lapsed since tracking began',
    expected:
        'briefing stating that nothing has been captured yet; banner '
        'allowed; never invent a past conversation',
  ),
  RelationshipAgentPolicyRule(
    id: 'R7',
    given:
        'user-set check-in sentiments and the narrative prose point in '
        'opposite directions',
    expected:
        'the health band follows the user-set sentiments; prose is '
        'secondary evidence',
  ),
  RelationshipAgentPolicyRule(
    id: 'R8',
    given: 'a briefing whose verdict is a camelCase band identifier',
    expected:
        'band identifiers are FIELD VALUES: never in oneLiner, tldr, '
        'content or healthRationale',
  ),
  RelationshipAgentPolicyRule(
    id: 'R9',
    given: 'a pending user message alongside a stale briefing',
    expected:
        'reply_to_user exactly once; the briefing still lands in the '
        'same wake',
  ),
  RelationshipAgentPolicyRule(
    id: 'R10',
    given: 'the user explicitly asks to be briefed while the cadence is ok',
    expected: 'update_relationship_report this wake, no banner',
  ),
  RelationshipAgentPolicyRule(
    id: 'R11',
    given: 'the user asks to hide the showing banner until a stated time',
    expected:
        'snooze_relationship_ad with the FACTS adId verbatim and a future '
        'ISO 8601 instant; no new banner',
  ),
  RelationshipAgentPolicyRule(
    id: 'R12',
    given:
        'a check-in narrative carries a phone number, an address, or a '
        "third party's medical detail",
    expected:
        'none of it reaches banner copy; contact details are never '
        'invented, because none exist in FACTS by design',
  ),
  RelationshipAgentPolicyRule(
    id: 'R13',
    given: 'the pending message asks for something unrelated to this person',
    expected:
        'briefly restate the purpose and redirect; no briefing, no banner',
  ),
  RelationshipAgentPolicyRule(
    id: 'R14',
    given: 'one check-in, months old, no topics',
    expected:
        'say the evidence is thin; never pad the briefing with topics '
        'FACTS does not contain',
  ),
  RelationshipAgentPolicyRule(
    id: 'R15',
    given: 'check-ins carrying payAttentionTo / avoid guidance',
    expected:
        'the briefing traces its guidance to those check-ins and invents '
        'none of its own',
  ),
  RelationshipAgentPolicyRule(
    id: 'R16',
    given: 'a long silence the model could shame the user for',
    expected:
        'warm aide tone, never a guilt trip; tone roast only when the '
        'user asked for it',
  ),
  RelationshipAgentPolicyRule(
    id: 'R17',
    given: 'linked tasks in FACTS, one open and one done',
    expected:
        'the briefing may cite them by title and status, and invents '
        'neither a task nor a status FACTS does not carry',
  ),
];
