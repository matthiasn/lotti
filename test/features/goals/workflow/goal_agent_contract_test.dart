import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';

void main() {
  test('the prompt stays under the eval-enforced hard cap', () {
    // The payload lesson: long prompts get skimmed. The eval suite pins
    // the same bound; this pins it for the production import path. The
    // ceiling is a discipline rather than a model limit — moved to 3.6k with
    // the standing-report rule, which has to hold in every language and so
    // cannot live in the per-wake FACTS block.
    expect(goalAgentSystemPrompt.length, lessThan(3600));
    expect(
      goalAgentSystemPrompt,
      contains('explicitly asks for another ad'),
    );
    expect(goalAgentSystemPrompt, contains('not a general assistant'));
    expect(
      goalAgentSystemPrompt,
      contains(
        'For an unrelated request (coding, trivia, etc.), do not answer',
      ),
    );
    expect(
      goalAgentSystemPrompt,
      contains('`latest.todayStatus=completeOnTarget`'),
    );
    expect(goalAgentSystemPrompt, contains('latestChange'));
    expect(goalAgentSystemPrompt, contains('referenceIsCurrentDay'));
  });

  test('the tool surface includes the shared reply carrier and seven goal '
      'tools', () {
    expect(
      [for (final tool in goalAgentTools) tool.name],
      [
        GoalAgentToolNames.replyToUser,
        GoalAgentToolNames.updateGoalReport,
        GoalAgentToolNames.createGoalAd,
        GoalAgentToolNames.rerunGoalAd,
        GoalAgentToolNames.retireGoalAd,
        GoalAgentToolNames.snoozeGoalAd,
        GoalAgentToolNames.proposeGoalRevision,
        GoalAgentToolNames.recordGoalObservation,
      ],
    );
    for (final tool in goalAgentTools) {
      expect(
        tool.name,
        tool.name == GoalAgentToolNames.replyToUser
            ? AgentConversationToolNames.replyToUser
            : matches(RegExp(r'^[a-z]+_goal_[a-z0-9_]+$')),
      );
    }
    expect(
      GoalAgentToolNames.proposeGoalRevision,
      'propose_goal_revision_v2',
    );
    expect(
      GoalAgentToolNames.isGoalRevisionProposal(
        GoalAgentToolNames.legacyProposeGoalRevision,
      ),
      isTrue,
    );
    final reportTool = goalAgentTools.singleWhere(
      (tool) => tool.name == GoalAgentToolNames.updateGoalReport,
    );
    final properties =
        reportTool.parameters['properties'] as Map<String, dynamic>;
    final required = reportTool.parameters['required'] as List<dynamic>;
    final report = properties['report'] as Map<String, dynamic>;
    final reportProperties = report['properties'] as Map<String, dynamic>;
    expect(
      required,
      containsAll(['status', 'oneLiner', 'report']),
    );
    expect(
      report['required'],
      GoalReportSectionKeys.values,
    );
    expect(
      reportProperties.keys,
      containsAll(GoalReportSectionKeys.values),
    );
    expect(
      (reportProperties[GoalReportSectionKeys.currentPeriod]
          as Map<String, dynamic>)['description'],
      contains('todayGuidance'),
    );
    expect(
      (reportProperties[GoalReportSectionKeys.latestChange]
          as Map<String, dynamic>)['description'],
      contains('exact latest'),
    );
    expect(
      (reportProperties[GoalReportSectionKeys.nextActions]
          as Map<String, dynamic>)['type'],
      'object',
    );
    expect(
      (reportProperties[GoalReportSectionKeys.nextActions]
          as Map<String, dynamic>)['required'],
      GoalReportActionKeys.values,
    );
    final actionProperties =
        (reportProperties[GoalReportSectionKeys.nextActions]
                as Map<String, dynamic>)['properties']
            as Map<String, dynamic>;
    expect(
      ((actionProperties[GoalReportActionKeys.now]
              as Map<String, dynamic>)['items']
          as Map<String, dynamic>)['required'],
      ['criterionId', 'action'],
    );
  });

  test('the enum vocabularies are derived from the real enums — the '
      'contract cannot drift from the model layer', () {
    expect(
      goalTrackStatusNames,
      [for (final v in GoalTrackStatus.values) v.name],
    );
    expect(
      goalBannerAnimationNames,
      [for (final v in NudgeBannerAnimation.values) v.name],
    );
    expect(
      goalBannerAccentNames,
      [for (final v in NudgeBannerAccent.values) v.name],
    );
    expect(
      goalNudgeToneNames,
      [for (final v in NudgeTone.values) v.name],
    );
  });

  group('GoalStructuredReport', () {
    Map<String, Object?> validReport() => {
      'tldr': 'On target today, still above the weekly average.',
      'currentPeriod': 'Logging is complete today.',
      'rollingWindow': 'The rolling average remains above target.',
      'latestChange': '',
      'coverage': '',
      'nextActions': {
        'now': [
          {'criterionId': 'health-weight', 'action': 'Log weight.'},
        ],
        'later': ['Keep the weekly habit moving.'],
      },
    };

    test(
      'parses complete reports and gates current actions when composing',
      () {
        final report = GoalStructuredReport.tryParse(validReport());

        expect(report, isNotNull);
        expect(
          report!.tldr,
          'On target today, still above the weekly average.',
        );
        // The composed body deliberately omits the TLDR: it is rendered above
        // this, and repeating it would open "Show more" with what the reader
        // just read.
        expect(
          report.visibleSummary(
            allowedCurrentActionCriterionIds: const {'health-weight'},
          ),
          isNot(contains(report.tldr)),
        );
        expect(
          report.visibleSummary(
            allowedCurrentActionCriterionIds: const {'health-weight'},
          ),
          'Logging is complete today.\n\n'
          'The rolling average remains above target.\n\n'
          'Log weight.\n\n'
          'Keep the weekly habit moving.',
        );
        expect(
          report.visibleSummary(
            allowedCurrentActionCriterionIds: const {},
          ),
          isNot(contains('Log weight.')),
        );
      },
    );

    test('sections are persisted as data for the card to render', () {
      final report = GoalStructuredReport.tryParse(validReport())!;
      final sections = report.toProvenance(
        allowedCurrentActionCriterionIds: const {'health-weight'},
      );

      // The sentences are model-authored in the user's language, so the
      // composer cannot wrap them in headings without injecting English.
      // Persisting them separately is what lets the card supply localized
      // headings at display time.
      expect(
        sections[GoalReportSectionKeys.currentPeriod],
        'Logging is complete today.',
      );
      expect(sections[GoalReportSectionKeys.nextActions], [
        'Log weight.',
        'Keep the weekly habit moving.',
      ]);
      // Empty slots are absent rather than present-and-blank: the card draws
      // a heading per entry, and a heading with nothing under it is worse
      // than no heading.
      expect(sections.containsKey(GoalReportSectionKeys.latestChange), isFalse);
      expect(sections.containsKey(GoalReportSectionKeys.coverage), isFalse);
    });

    test('the current-action gate applies to the persisted sections too', () {
      final report = GoalStructuredReport.tryParse(validReport())!;
      final sections = report.toProvenance(
        allowedCurrentActionCriterionIds: const {},
      );

      // An action the deterministic filter removed must not reappear just
      // because the card reads sections instead of the composed text.
      expect(sections[GoalReportSectionKeys.nextActions], [
        'Keep the weekly habit moving.',
      ]);
    });

    test('rejects empty required standing sections', () {
      for (final key in ['tldr', 'currentPeriod', 'rollingWindow']) {
        final value = validReport()..[key] = '  ';
        expect(
          GoalStructuredReport.tryParse(value),
          isNull,
          reason: key,
        );
      }
    });

    test('rejects missing, mistyped, and empty action fields', () {
      final malformed = [
        validReport()..remove('coverage'),
        validReport()..['latestChange'] = 7,
        validReport()..['nextActions'] = 'later',
        validReport()
          ..['nextActions'] = {
            'now': [
              {'criterionId': '', 'action': 'Log weight.'},
            ],
            'later': <Object?>[],
          },
        validReport()
          ..['nextActions'] = {
            'now': <Object?>[],
            'later': [''],
          },
      ];

      for (final value in malformed) {
        expect(GoalStructuredReport.tryParse(value), isNull, reason: '$value');
      }
    });

    group('lenient', () {
      test('reads the same fields as tryParse on a complete report', () {
        // The guard runs the same rules whichever view it gets, so a valid
        // report has to look identical through both.
        final strict = GoalStructuredReport.tryParse(validReport())!;
        final loose = GoalStructuredReport.lenient(validReport())!;
        expect(loose.tldr, strict.tldr);
        expect(loose.currentPeriod, strict.currentPeriod);
        expect(loose.rollingWindow, strict.rollingWindow);
        expect(loose.latestChange, strict.latestChange);
        expect(loose.coverage, strict.coverage);
        expect(
          loose.now.map((a) => '${a.criterionId}:${a.action}'),
          strict.now.map((a) => '${a.criterionId}:${a.action}'),
        );
        expect(loose.later, strict.later);
      });

      test('recovers the text present in a report tryParse refused', () {
        // The point of the whole method: `latestChange` is gone, so strict
        // parsing yields nothing at all, while the standing the aggregate
        // rule has to read is sitting right there.
        final value = validReport()..remove('latestChange');
        expect(GoalStructuredReport.tryParse(value), isNull);

        final loose = GoalStructuredReport.lenient(value)!;
        expect(loose.rollingWindow, isNotEmpty);
        expect(loose.rollingWindow, validReport()['rollingWindow']);
        expect(loose.latestChange, isEmpty);
      });

      test('degrades every malformed slot to empty rather than failing', () {
        final loose = GoalStructuredReport.lenient({
          'tldr': 7,
          'rollingWindow': '  Averaging 6000 steps.  ',
          'nextActions': {
            'now': [
              {'criterionId': 'steps'},
              'not an action map',
            ],
            'later': ['Keep walking.', 12],
          },
        })!;
        // Mistyped and absent slots read the same: empty, never a throw.
        expect(loose.tldr, isEmpty);
        expect(loose.currentPeriod, isEmpty);
        expect(loose.coverage, isEmpty);
        // Trimmed exactly as the strict reader trims.
        expect(loose.rollingWindow, 'Averaging 6000 steps.');
        // A map missing `action` survives with an empty one; a non-map is
        // dropped, since there is no field to recover from it.
        expect(loose.now, hasLength(1));
        expect(loose.now.single.criterionId, 'steps');
        expect(loose.now.single.action, isEmpty);
        // Non-strings in `later` are dropped for the same reason.
        expect(loose.later, ['Keep walking.']);
      });

      test('returns null only when there is no report map at all', () {
        for (final value in <Object?>[null, 'report', 7, <Object?>[]]) {
          expect(GoalStructuredReport.lenient(value), isNull, reason: '$value');
        }
        // `nextActions` of the wrong type costs the actions, not the report.
        final loose = GoalStructuredReport.lenient(
          validReport()..['nextActions'] = 'later',
        )!;
        expect(loose.now, isEmpty);
        expect(loose.later, isEmpty);
        expect(loose.rollingWindow, isNotEmpty);
      });
    });
  });
}
