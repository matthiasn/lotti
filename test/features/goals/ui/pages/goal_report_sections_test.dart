import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/goals/ui/pages/goal_report_sections.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

AgentReportEntity _report({
  String? tldr,
  String content = '',
  Map<String, Object?>? sections,
}) =>
    AgentDomainEntity.agentReport(
          id: 'report-1',
          agentId: 'goal-1',
          scope: 'current',
          createdAt: DateTime(2026, 8, 11),
          vectorClock: null,
          content: content,
          tldr: tldr,
          provenance: {
            GoalReportProvenanceKeys.sections: ?sections,
          },
        )
        as AgentReportEntity;

void main() {
  final messages = AppLocalizationsEn();

  String spoken(
    AgentReportEntity? report, {
    bool expanded = false,
    String? fallback,
  }) => goalReportSpokenText(
    report: report,
    fallback: fallback,
    expanded: expanded,
    messages: messages,
  );

  group('goalReportSections', () {
    test('a payload counts only when a known section renders', () {
      expect(goalReportSections(null), isNull);
      expect(goalReportSections(_report()), isNull);
      // Blanks, and keys this build does not know, render nothing.
      expect(
        goalReportSections(
          _report(
            sections: {
              GoalReportSectionKeys.currentPeriod: '  ',
              GoalReportSectionKeys.nextActions: <Object?>['', 3],
              'futureKey': 'Something new.',
            },
          ),
        ),
        isNull,
      );
      // One action is enough.
      expect(
        goalReportSections(
          _report(
            sections: {
              GoalReportSectionKeys.nextActions: ['Walk'],
            },
          ),
        ),
        isNotNull,
      );
    });

    test('actions and the reflection are read trimmed, blanks dropped', () {
      final sections = {
        GoalReportSectionKeys.nextActions: [' Walk ', '', 7, 'Rest'],
        GoalReportSectionKeys.reflection: '  You slept badly. ',
      };
      expect(goalReportActions(sections), ['Walk', 'Rest']);
      expect(goalReportReflection(sections), 'You slept badly.');
      expect(goalReportActions(null), isNull);
      expect(
        goalReportReflection({GoalReportSectionKeys.reflection: ' '}),
        isNull,
      );
    });

    test('expanded sections come in reading order under their headings', () {
      expect(
        goalReportExpandedSections({
          GoalReportSectionKeys.coverage: 'All logged.',
          GoalReportSectionKeys.latestChange: '',
          GoalReportSectionKeys.currentPeriod: ' On track. ',
          GoalReportSectionKeys.rollingWindow: 'Better than May.',
        }, messages),
        [
          (messages.goalReportSectionStanding, 'On track.'),
          (messages.goalReportSectionWindow, 'Better than May.'),
          (messages.goalReportSectionCoverage, 'All logged.'),
        ],
      );
    });
  });

  group('goalReportExpandable', () {
    test('needs a summary and something more than it', () {
      expect(goalReportExpandable(null), isFalse);
      expect(goalReportExpandable(_report(content: 'Only text.')), isFalse);
      // A full text that repeats the summary adds nothing.
      expect(
        goalReportExpandable(_report(tldr: 'Same.', content: ' Same. ')),
        isFalse,
      );
      expect(
        goalReportExpandable(_report(tldr: 'Short.', content: 'Longer.')),
        isTrue,
      );
      // Sections keep it expandable even when the text equals the summary.
      expect(
        goalReportExpandable(
          _report(
            tldr: 'Same.',
            content: 'Same.',
            sections: {GoalReportSectionKeys.coverage: 'All logged.'},
          ),
        ),
        isTrue,
      );
    });
  });

  group('goalReportSpokenText', () {
    test('without a report the fallback is spoken, or nothing', () {
      expect(spoken(null, fallback: ' Halfway there. '), 'Halfway there.');
      expect(spoken(null), isEmpty);
    });

    test('a report without a summary speaks its text', () {
      expect(spoken(_report(content: 'The whole read.')), 'The whole read.');
    });

    test('a flat report speaks its full text only while expanded', () {
      final report = _report(tldr: 'Short.', content: 'Short. And longer.');
      expect(spoken(report), 'Short.');
      expect(spoken(report, expanded: true), 'Short.\n\nShort. And longer.');
    });

    test('expanded with nothing more to show adds nothing', () {
      final report = _report(tldr: 'Same.', content: 'Same.');
      expect(spoken(report, expanded: true), 'Same.');
    });

    test('headings and actions end in a stop; their own marks are kept', () {
      final report = _report(
        tldr: 'Two of three.',
        sections: {
          GoalReportSectionKeys.reflection: 'Mornings are hard',
          GoalReportSectionKeys.nextActions: ['Walk at noon', 'Rest?'],
          GoalReportSectionKeys.latestChange: 'A walk on Monday.',
        },
      );
      expect(
        spoken(report),
        'Two of three.\n\n'
        'From your check-ins.\n\nMornings are hard\n\n'
        "What's next.\n\nWalk at noon.\n\nRest?",
      );
      expect(
        spoken(report, expanded: true),
        endsWith('Latest change.\n\nA walk on Monday.'),
      );
    });
  });
}
