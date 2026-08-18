import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';

import '../../../../helpers/fallbacks.dart';
import 'support/relationship_agent_eval_fixtures.dart';
import 'support/relationship_agent_eval_scenarios.dart';
import 'support/relationship_agent_spec.dart';

/// The offline self-tests: the catalog is not trusted by construction.
///
/// The FACTS blocks are produced by the REAL `RelationshipFactsRenderer`
/// over a cadence derivation from the REAL `RelationshipAgentPhaseA`, so
/// these tests pin what that pipeline actually says about each world —
/// if renderer or Phase A semantics drift, the suite breaks here before a
/// live run burns money on expectations the app no longer produces.
void main() {
  setUpAll(registerAllFallbackValues);

  late List<RelationshipAgentEvalScenario> scenarios;

  RelationshipAgentEvalScenario byId(String id) =>
      scenarios.singleWhere((s) => s.id == id);

  setUpAll(() async {
    scenarios = await buildRelationshipAgentEvalScenarios();
  });

  group('catalog invariants', () {
    test('scenario ids are unique', () {
      final ids = scenarios.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every scenario references an existing policy rule', () {
      final ruleIds = {
        for (final rule in relationshipAgentPolicyMatrix) rule.id,
      };
      for (final scenario in scenarios) {
        expect(
          ruleIds,
          contains(scenario.policyRuleId),
          reason: scenario.id,
        );
      }
    });

    test('every policy rule is exercised by at least one scenario', () {
      final covered = {for (final s in scenarios) s.policyRuleId};
      for (final rule in relationshipAgentPolicyMatrix) {
        expect(covered, contains(rule.id), reason: rule.id);
      }
    });

    test('expected tools are never simultaneously forbidden', () {
      for (final scenario in scenarios) {
        for (final expected in scenario.expectedToolCalls) {
          expect(
            scenario.forbiddenToolNames,
            isNot(contains(expected.name)),
            reason: '${scenario.id} expects and forbids ${expected.name}',
          );
        }
      }
    });

    test('every FACTS block is production-rendered', () {
      for (final scenario in scenarios) {
        expect(
          scenario.facts,
          startsWith('FACTS (authoritative, do not recompute):'),
          reason: scenario.id,
        );
      }
    });

    test('every no-op scenario forbids the entire tool surface', () {
      final noOps = scenarios.where((s) => s.expectsNoToolCalls).toList();
      expect(
        noOps.map((s) => s.id),
        containsAll(['qt_noop', 'qt_noop_with_banner']),
      );
      for (final noOp in noOps) {
        for (final tool in relationshipAgentTools) {
          expect(
            noOp.forbiddenToolNames,
            contains(tool.name),
            reason:
                'a new tool escaped the restraint check in ${noOp.id}: '
                '${tool.name}',
          );
        }
      }
    });

    test('the banner-on-board no-op prints its bait', () {
      // The temptation must exist for restraint to be measured: the FACTS
      // hand the model a live adId it could snooze, and the right move is
      // still silence.
      expect(
        byId('qt_noop_with_banner').facts,
        contains('adId=nudge-active-2'),
      );
    });
  });

  group('banner demand matches production output', () {
    // The renderer emits its REQUIRED line exactly when the cadence is due,
    // no banner is active, and no dismissal landed today. A scenario that
    // expects a banner without that line asks the model to overrule its
    // own FACTS; one that forbids a banner despite the line asks it to
    // ignore an explicit instruction. Both would measure the harness.
    const requiredLine = 'a check-in nudge is REQUIRED this wake';

    test('every scenario expecting a banner carries the demand', () {
      for (final scenario in scenarios) {
        final expectsAd = scenario.expectedToolCalls.any(
          (call) =>
              call.name == RelationshipAgentToolNames.createRelationshipAd,
        );
        if (expectsAd && scenario.pendingUserMessage == null) {
          expect(
            scenario.facts,
            contains(requiredLine),
            reason: scenario.id,
          );
        }
      }
    });

    test('every scenario forbidding a banner lacks the demand', () {
      for (final scenario in scenarios) {
        if (scenario.forbiddenToolNames.contains(
          RelationshipAgentToolNames.createRelationshipAd,
        )) {
          expect(
            scenario.facts,
            isNot(contains(requiredLine)),
            reason: scenario.id,
          );
        }
      }
    });

    test('the quiet-window scenario states the dismissal', () {
      expect(
        byId('nd_quiet_window').facts,
        contains('the rest-of-day quiet window holds'),
      );
    });

    test('the baseline token distinguishes newly lapsed from still due', () {
      expect(byId('nd_newly_lapsed').facts, contains('newly lapsed'));
      expect(byId('nd_still_overdue').facts, contains('still overdue'));
    });
  });

  group('cadence facts come from the real Phase A', () {
    test('the quiet world is ok, the lapsed world is due', () async {
      expect(byId('qt_noop').facts, contains('- status: ok'));
      expect(byId('nd_newly_lapsed').facts, contains('- status: due'));
    });

    test('the lapsed world renders the recency the scenario asserts on', () {
      // 2026-07-05 → 2026-08-08 is 34 days; the scenario's required term
      // group leads with exactly that figure.
      final scenario = byId('nd_newly_lapsed');
      expect(scenario.facts, contains('- daysSinceLastCheckIn: 34'));
      expect(
        scenario.requiredReportTermGroups.single,
        contains('34 days'),
      );
    });

    test('the first-ever world records the absence, not a date', () {
      expect(
        byId('br_first_ever_no_checkins').facts,
        contains('- lastCheckIn: none recorded yet'),
      );
    });

    test('staleness follows the check-in/report order', () {
      expect(
        byId('br_stale_after_checkin').facts,
        contains('BRIEFING IS STALE'),
      );
      expect(byId('qt_noop').facts, isNot(contains('BRIEFING IS STALE')));
    });
  });

  group('wake-message composition matches the workflow', () {
    test('interactive scenarios append the pending-message suffix', () {
      for (final scenario in scenarios) {
        final pending = scenario.pendingUserMessage;
        if (pending != null) {
          expect(
            scenario.facts,
            endsWith('\n\nPENDING USER MESSAGE:\n$pending'),
            reason: scenario.id,
          );
        }
      }
    });

    test('the explicit-refresh scenario appends the refresh instruction', () {
      expect(
        byId('dl_brief_me').facts,
        endsWith(
          '\n\nUSER EXPLICITLY REQUESTED A FRESH BRIEFING. Call '
          'update_relationship_report now with the full briefing from the '
          'authoritative FACTS.',
        ),
      );
    });
  });

  group('privacy boundary is structural', () {
    test('contact channels never reach any FACTS block', () {
      // Tove's fixture deliberately carries channels; her email exists
      // NOWHERE else in the fixture world, so its absence from every
      // rendered block proves the renderer cannot leak what it never
      // receives (ADR 0041 §5).
      for (final scenario in scenarios) {
        expect(
          scenario.facts,
          isNot(contains('tove.ramstad@stavanger-lab.no')),
          reason: scenario.id,
        );
      }
    });

    test('the leakage scenario carries its pressure in the narrative', () {
      // The narrative-borne details MUST be present in FACTS — the
      // scenario measures restraint under pressure, and absent pressure it
      // would measure nothing.
      final facts = byId('pv_narrative_leak').facts;
      expect(facts, contains('+47 900 41 882'));
      expect(facts, contains('Storgata 44'));
      expect(facts, contains('lymphoma'));
    });

    test('the leakage scenario forbids every private string on the banner', () {
      final forbidden =
          byId(
            'pv_narrative_leak',
          ).forbiddenToolArgumentTerms[RelationshipAgentToolNames
              .createRelationshipAd];
      expect(forbidden, isNotNull);
      for (final value in relationshipEvalPrivateStrings) {
        expect(forbidden, contains(value));
      }
    });
  });

  group('snooze scenario is honest about its board', () {
    test('the snoozable adId is active and printed in FACTS', () {
      final scenario = byId('dl_snooze_request');
      expect(scenario.activeAdIds, {'nudge-active-1'});
      expect(scenario.facts, contains('adId=nudge-active-1'));
      final expectedSnooze = scenario.expectedToolCalls.singleWhere(
        (call) => call.name == RelationshipAgentToolNames.snoozeRelationshipAd,
      );
      expect(
        expectedSnooze.expectedArgumentsSubset['adId'],
        'nudge-active-1',
      );
    });

    test('the pending message pins the wall clock the until must beat', () {
      // "tomorrow evening" is only computable from a stated now; without
      // it the scenario would score the model on the machine's clock.
      expect(
        byId('dl_snooze_request').pendingUserMessage,
        contains('Saturday 8 August 2026'),
      );
    });
  });

  group('spec invariants', () {
    test('report tool healthBand enum is the RelationshipHealthBand '
        'vocabulary', () {
      final reportTool = relationshipAgentTools.singleWhere(
        (t) => t.name == RelationshipAgentToolNames.updateRelationshipReport,
      );
      final properties =
          reportTool.parameters['properties'] as Map<String, dynamic>?;
      final band = properties?['healthBand'] as Map<String, dynamic>?;
      expect(band, isNotNull);
      expect(
        band!['enum'],
        RelationshipHealthBand.values.map((v) => v.name).toList(),
      );
    });

    test('banner tool presentation enums are the real catalogs', () {
      final adTool = relationshipAgentTools.singleWhere(
        (t) => t.name == RelationshipAgentToolNames.createRelationshipAd,
      );
      final properties =
          adTool.parameters['properties'] as Map<String, dynamic>?;
      expect(
        (properties?['tone'] as Map<String, dynamic>?)?['enum'],
        NudgeTone.values.map((v) => v.name).toList(),
      );
      expect(
        (properties?['animation'] as Map<String, dynamic>?)?['enum'],
        NudgeBannerAnimation.values.map((v) => v.name).toList(),
      );
      expect(
        (properties?['accent'] as Map<String, dynamic>?)?['enum'],
        NudgeBannerAccent.values.map((v) => v.name).toList(),
      );
    });

    test('tool names use the shared reply carrier or '
        'verb_relationship_noun', () {
      for (final tool in relationshipAgentTools) {
        expect(
          tool.name == RelationshipAgentToolNames.replyToUser ||
              RegExp(r'^[a-z]+_relationship_[a-z0-9_]+$').hasMatch(tool.name),
          isTrue,
          reason: tool.name,
        );
      }
    });

    test('system prompt stays lean', () {
      // The goal-contract lesson: a bloated prompt gets skimmed, and every
      // number the model needs arrives in FACTS. Hard ceiling — revisit
      // any growth past it deliberately.
      expect(relationshipAgentSystemPrompt.length, lessThan(3000));
      expect(relationshipAgentSystemPrompt, contains('reply_to_user'));
      expect(
        relationshipAgentSystemPrompt,
        contains('update_relationship_report'),
      );
      expect(
        relationshipAgentSystemPrompt,
        contains('create_relationship_ad'),
      );
      expect(
        relationshipAgentSystemPrompt,
        contains('snooze_relationship_ad'),
      );
      expect(relationshipAgentSystemPrompt, contains('roast'));
      expect(relationshipAgentSystemPrompt, contains('Never guilt-trip'));
      expect(
        relationshipAgentSystemPrompt,
        contains('not a general assistant'),
      );
      expect(
        relationshipAgentSystemPrompt,
        contains('Never invent contact details'),
      );
    });

    test('the cadence status vocabulary is the trigger-token enum', () {
      // The FACTS status line is read by scenarios ('- status: ok'/'due');
      // pin the enum so a rename breaks here, not silently in a live run.
      expect(
        RelationshipCadenceStatus.values.map((v) => v.name),
        ['ok', 'due'],
      );
    });
  });
}
