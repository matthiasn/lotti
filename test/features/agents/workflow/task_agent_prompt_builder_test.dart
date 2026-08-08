import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/seeded_directive_content.dart';
import 'package:lotti/features/agents/workflow/task_agent_prompt_builder.dart';

import '../test_utils.dart';

void main() {
  group('TaskAgentPromptBuilder.buildSystemPrompt', () {
    test('identifies only empty and seeded report directives as built in', () {
      for (final scenario in [
        (directive: '', expected: true),
        (directive: taskAgentReportDirective, expected: true),
        (directive: '  $taskAgentReportDirective  ', expected: true),
        (directive: 'Lead with a risk callout.', expected: false),
      ]) {
        expect(
          TaskAgentPromptBuilder.usesBuiltInReportContract(
            makeTestTemplateVersion(reportDirective: scenario.directive),
          ),
          scenario.expected,
          reason: scenario.directive,
        );
      }
    });

    test('resolves the same evolved directive for executor and editor', () {
      const evolvedDirective = '''
Lead with the delivery decision, then list only evidence-backed next moves.
Use the task language and omit empty sections.
''';
      final version = makeTestTemplateVersion(
        reportDirective: '  $evolvedDirective  ',
      );

      expect(
        TaskAgentPromptBuilder.effectiveReportDirective(
          version: version,
          modelId: 'mistral-small-4-119b-instruct',
        ),
        evolvedDirective.trim(),
      );
      expect(
        TaskAgentPromptBuilder.effectiveReportDirective(
          version: makeTestTemplateVersion(
            reportDirective: taskAgentReportDirective,
          ),
          modelId: 'mistral-small-4-119b-instruct',
        ),
        contains('## Progress'),
      );
    });

    test('legacy directives-only template uses the combined heading', () {
      final version = makeTestTemplateVersion(
        directives: 'You are precise and concise.',
      );

      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: version,
        soulVersion: null,
      );

      expect(prompt, contains(TaskAgentPromptBuilder.taskAgentScaffoldCore));
      expect(prompt, contains('## Report Directive'));
      expect(prompt, contains('## Evidence-First Synthesis Protocol'));
      expect(prompt, contains('## Your Personality & Directives'));
      expect(prompt, contains('You are precise and concise.'));
    });

    test('new-style reportDirective replaces the default report scaffold', () {
      final version = makeTestTemplateVersion(
        reportDirective: 'Lead the report with a risk callout.',
        generalDirective: 'Be proactive about blockers.',
      );

      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: version,
        soulVersion: null,
      );

      expect(prompt, contains(TaskAgentPromptBuilder.taskAgentScaffoldCore));
      expect(prompt, contains('## Report Directive'));
      expect(prompt, contains('Lead the report with a risk callout.'));
      // The default report scaffold is omitted when a custom one is supplied.
      expect(
        prompt,
        isNot(contains(TaskAgentPromptBuilder.taskAgentScaffoldReport.trim())),
      );
      // No soul → general directive uses the combined heading.
      expect(prompt, contains('## Your Personality & Directives'));
      expect(prompt, contains('Be proactive about blockers.'));
    });

    test(
      'uses evidence-first report guidance when only generalDirective is set',
      () {
        final version = makeTestTemplateVersion(
          generalDirective: 'Stay terse.',
        );

        final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
          version: version,
          soulVersion: null,
        );

        expect(prompt, contains('## Report Directive'));
        expect(prompt, contains('Write free-form Markdown'));
        expect(prompt, isNot(contains('Include 1-2 relevant emojis')));
        expect(prompt, contains('Stay terse.'));
      },
    );

    test('soul splits personality from operational directives', () {
      final version = makeTestTemplateVersion(
        generalDirective: 'Escalate blockers quickly.',
        reportDirective: 'Keep the TLDR to one line.',
      );
      final soul = makeTestSoulDocumentVersion(
        voiceDirective: 'Warm but direct.',
        toneBounds: 'Never sarcastic.',
        coachingStyle: 'Ask before assuming.',
        antiSycophancyPolicy: 'Do not flatter.',
      );

      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: version,
        soulVersion: soul,
      );

      expect(prompt, contains('## Your Personality'));
      expect(prompt, contains('Warm but direct.'));
      expect(prompt, contains('Never sarcastic.'));
      expect(prompt, contains('Ask before assuming.'));
      expect(prompt, contains('Do not flatter.'));
      expect(prompt, contains('## Your Operational Directives'));
      expect(prompt, contains('Escalate blockers quickly.'));
      // Soul path never emits the legacy combined heading.
      expect(prompt, isNot(contains('## Your Personality & Directives')));
    });

    test('falls back to legacy directives when generalDirective empty under '
        'a new reportDirective and no soul', () {
      final version = makeTestTemplateVersion(
        directives: 'Legacy voice.',
        reportDirective: 'Custom report.',
      );

      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: version,
        soulVersion: null,
      );

      expect(prompt, contains('Custom report.'));
      expect(prompt, contains('## Your Personality & Directives'));
      expect(prompt, contains('Legacy voice.'));
    });

    test('appends evidence synthesis after the active template directives', () {
      final version = makeTestTemplateVersion(
        generalDirective: 'Keep the report conversational.',
        reportDirective: 'Choose the Markdown structure that fits the task.',
      );

      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: version,
        soulVersion: null,
      );

      expect(prompt, contains('Choose the Markdown structure that fits'));
      expect(prompt, contains('## Evidence-First Synthesis Protocol'));
      expect(
        prompt.indexOf('## Evidence-First Synthesis Protocol'),
        greaterThan(prompt.indexOf('Keep the report conversational.')),
      );
    });

    test(
      'replaces only the built-in report directive with compact synthesis',
      () {
        final version = makeTestTemplateVersion(
          generalDirective: 'Remain factual.',
          reportDirective: taskAgentReportDirective,
        );

        final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
          version: version,
          soulVersion: null,
        );

        expect(prompt, contains('Write free-form Markdown'));
        expect(prompt, contains('headings are optional'));
        expect(prompt, isNot(contains('Include 1-2 relevant emojis')));
        expect(prompt, isNot(contains('### Required Sections')));
      },
    );

    test('also appends evidence synthesis to legacy templates', () {
      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: makeTestTemplateVersion(directives: 'Legacy directive.'),
        soulVersion: null,
      );

      expect(prompt, contains('Legacy directive.'));
      expect(
        prompt,
        endsWith('not Markdown structure or voice.\n'),
      );
    });

    test('uses compact evidence scaffold for efficient model families', () {
      final version = makeTestTemplateVersion(
        reportDirective: taskAgentReportDirective,
      );

      final mistralPrompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: version,
        soulVersion: null,
        modelId: 'mistral-small-4-119b-instruct',
      );
      final qwenPrompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: version,
        soulVersion: null,
        modelId: 'qwen3.5-122b-a10b',
      );

      expect(
        mistralPrompt,
        contains(TaskAgentPromptBuilder.taskAgentCompactScaffold),
      );
      expect(
        qwenPrompt,
        contains(TaskAgentPromptBuilder.taskAgentCompactScaffold),
      );
      expect(mistralPrompt, isNot(contains('A wake ends in exactly')));
      expect(mistralPrompt, contains('Examples of the boundary:'));
      expect(mistralPrompt, contains('date appears only in prose'));
      expect(mistralPrompt, contains('promote it to the task due date'));
      expect(
        mistralPrompt,
        contains('A committed multi-step plan is mutation intent'),
      );
      expect(
        mistralPrompt,
        contains('Only an explicit request to transition status'),
      );
      expect(mistralPrompt, contains('Include only sections that'));
      expect(qwenPrompt, isNot(contains('Maybe revisit catering later')));
      expect(qwenPrompt, contains('Write free-form Markdown'));
      expect(qwenPrompt, contains('## Scope Erasure'));
      expect(qwenPrompt, contains('## Direct Report Grounding'));
      expect(qwenPrompt, contains('invent a root cause'));
      expect(qwenPrompt, contains('"underway"'));
      expect(qwenPrompt, contains('investigation is needed'));
      expect(qwenPrompt, contains('generic downstream fixes'));
      expect(qwenPrompt, contains('promote it to the task due date'));
      expect(qwenPrompt, contains('Omit absent'));
    });

    test('both scaffolds teach the typed-relationship tools', () {
      // The full scaffold: relation-aware Linked Tasks reading plus the
      // link_task / create_follow_up_task+relation guidance.
      const full =
          TaskAgentPromptBuilder.taskAgentScaffoldProjectContext +
          TaskAgentPromptBuilder.taskAgentScaffoldTrailing;
      expect(full, contains('`relations` array'));
      expect(full, contains('with THIS task as the subject'));
      expect(full, isNot(contains('typically subtasks')));
      expect(full, isNot(contains('typically epics')));
      expect(full, contains('link_task'));
      expect(full, contains('`is_blocked_by`'));
      expect(full, contains('never assert both directions'));
      expect(full, contains('`create_follow_up_task` with a\n    `relation`'));

      // The compact scaffold carries the same capability in short form.
      const compact = TaskAgentPromptBuilder.taskAgentCompactScaffold;
      expect(compact, contains('link_task'));
      expect(compact, contains('`relation`'));
      expect(compact, contains('never invent ids'));
    });

    test('compact scaffold preserves soul and custom directives', () {
      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: makeTestTemplateVersion(
          generalDirective: 'Escalate contractual blockers immediately.',
          reportDirective: 'Use any Markdown structure that fits the task.',
        ),
        soulVersion: makeTestSoulDocumentVersion(
          voiceDirective: 'Calm, direct, and specific.',
          toneBounds: 'Never invent progress.',
        ),
        modelId: 'qwen3.5-122b-a10b',
      );

      expect(prompt, contains('## Your Personality'));
      expect(prompt, contains('Calm, direct, and specific.'));
      expect(prompt, contains('Never invent progress.'));
      expect(prompt, contains('## Your Operational Directives'));
      expect(prompt, contains('Escalate contractual blockers immediately.'));
      expect(
        prompt,
        contains('Use any Markdown structure that fits the task.'),
      );
      expect(prompt, contains('## Evidence-First Synthesis Protocol'));
    });
  });

  group('the constitution is code-owned', () {
    // The rules an agent must never lose — user sovereignty, tool discipline,
    // input handling — belong to the scaffold, not to the evolvable
    // `generalDirective`. See docs/adr/0052-agent-directive-constitution.md.
    // Each assertion names a rule that used to live only in the seeded
    // directive, which one evolution session could paraphrase away.
    const codeOwnedRules = <String>[
      'Checklist sovereignty', // user-checked items keep their state
      'a value the user set is sovereign', // priority and due date
      'the user wins — make no call at all', // no-op rule
      'Never change an existing title', // title
      'DONE and\n  REJECTED are user-only', // status
      '## Input Handling', // rough transcripts, ask rather than assume
      '**Past decisions**', // proposal-ledger discipline
    ];

    test('identifies only an empty and the seeded general directive as built '
        'in', () {
      for (final scenario in [
        (directive: '', expected: true),
        (directive: taskAgentGeneralDirective, expected: true),
        (directive: '  $taskAgentGeneralDirective  ', expected: true),
        (directive: 'Escalate contractual blockers.', expected: false),
      ]) {
        final version = makeTestTemplateVersion(
          generalDirective: scenario.directive,
        );
        expect(
          TaskAgentPromptBuilder.usesBuiltInGeneralDirective(version),
          scenario.expected,
          reason: scenario.directive,
        );
        expect(
          TaskAgentPromptBuilder.effectiveGeneralDirective(version),
          scenario.expected ? '' : scenario.directive.trim(),
          reason: scenario.directive,
        );
      }
    });

    test('a stock template gets the rules from the scaffold, not a second '
        'editable copy', () {
      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: makeTestTemplateVersion(
          generalDirective: taskAgentGeneralDirective,
          reportDirective: taskAgentReportDirective,
        ),
        soulVersion: null,
      );

      for (final rule in codeOwnedRules) {
        expect(prompt, contains(rule), reason: rule);
      }
      // The seeded wording is not rendered on top of it: two wordings of one
      // rule cost payload and can disagree once one of them is evolved.
      expect(
        prompt,
        isNot(contains('User input is direct evidence of user intent.')),
        reason: 'the seeded restatement must not be rendered as well',
      );
      expect(prompt, isNot(contains('## Your Personality & Directives')));
    });

    test('an evolved directive that drops the rules cannot remove them', () {
      // The failure this design prevents: `propose_directives` takes a whole
      // rewrite, so a session that paraphrases and omits a bullet used to
      // delete a sovereignty guarantee outright.
      const evolved = '''
## Voice

Lead with the decision. Keep it to three sentences.''';

      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: makeTestTemplateVersion(generalDirective: evolved),
        soulVersion: null,
      );

      for (final rule in codeOwnedRules) {
        expect(prompt, contains(rule), reason: rule);
      }
      // The evolved text is still honoured — it adds, it does not replace.
      expect(prompt, contains('Lead with the decision.'));
      expect(
        prompt.indexOf('Lead with the decision.'),
        greaterThan(prompt.indexOf('## Input Handling')),
        reason: 'template guidance is appended after the constitution',
      );
    });

    test('the measured compact prompt is unchanged for a stock template', () {
      // The compact scaffold already suppressed the seeded directive and
      // carries its own constitution; the numbers behind it were measured on
      // that exact text. A stock template must therefore produce the scaffold
      // plus the evidence protocol and nothing else.
      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: makeTestTemplateVersion(
          generalDirective: taskAgentGeneralDirective,
          reportDirective: taskAgentReportDirective,
        ),
        soulVersion: null,
        modelId: 'qwen3.5-122b-a10b',
      );

      expect(
        prompt,
        startsWith(TaskAgentPromptBuilder.taskAgentCompactScaffold),
      );
      expect(prompt, isNot(contains('## Your Personality & Directives')));
      expect(prompt, isNot(contains('## Your Operational Directives')));
      expect(prompt, contains('User actions are sovereign.'));
    });

    test('an install seeded on an older release is still recognised', () {
      // The whole reason provenance decides before text: both seeded constants
      // have been edited, so a template seeded before the last edit stores text
      // that matches neither constant. Judged on text alone it reads as
      // customised — which renders a stale constitution *and* disables the
      // model-tuned report contract, the one that tells a wake not to
      // republish an unchanged report.
      const oldSeededGeneral =
          '## User Sovereignty\n\nAn older release wrote '
          'this text, which no constant matches today.';
      const oldSeededReport =
          '## MANDATORY FINAL TOOL CALL\n\nAn older '
          'release wrote this too.';
      final version = makeTestTemplateVersion(
        generalDirective: oldSeededGeneral,
        reportDirective: oldSeededReport,
        authoredBy: 'system',
      );

      expect(TaskAgentPromptBuilder.usesBuiltInGeneralDirective(version), true);
      expect(TaskAgentPromptBuilder.usesBuiltInReportContract(version), true);

      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: version,
        soulVersion: null,
      );

      expect(prompt, isNot(contains('An older release wrote this text')));
      expect(prompt, isNot(contains('MANDATORY FINAL TOOL CALL')));
      expect(prompt, contains('do not republish unchanged content'));
      expect(prompt, contains('## Input Handling'));
    });

    test('a config-change stamp never counts as system authorship', () {
      // `system:config_change` is stamped on versions that COPY directives
      // forward, so on an install that evolved a template and then changed its
      // model it sits on evolved text. Treating it as seeding would delete a
      // user-approved directive from the prompt.
      final version = makeTestTemplateVersion(
        generalDirective: 'Escalate contractual blockers within one wake.',
        reportDirective: 'Lead with the delivery decision.',
        authoredBy: 'system:config_change',
      );

      expect(
        TaskAgentPromptBuilder.usesBuiltInGeneralDirective(version),
        false,
      );
      expect(TaskAgentPromptBuilder.usesBuiltInReportContract(version), false);

      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: version,
        soulVersion: null,
      );

      expect(
        prompt,
        contains('Escalate contractual blockers within one wake.'),
      );
      expect(prompt, contains('Lead with the delivery decision.'));
    });

    test('an evolved directive is never mistaken for a seeded one', () {
      final version = makeTestTemplateVersion(
        generalDirective: 'Escalate contractual blockers within one wake.',
        authoredBy: 'evolution_agent',
      );

      expect(
        TaskAgentPromptBuilder.usesBuiltInGeneralDirective(version),
        false,
      );
      expect(
        TaskAgentPromptBuilder.effectiveGeneralDirective(version),
        'Escalate contractual blockers within one wake.',
      );
    });

    test('a stock template never surfaces its legacy persona blob', () {
      // Seeded templates carry both a `directives` blurb and the seeded
      // general directive. Suppressing the latter must not promote the former:
      // the legacy fallback is for versions that predate the split fields.
      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: makeTestTemplateVersion(
          directives: 'You are Laura, a diligent task management agent.',
          generalDirective: taskAgentGeneralDirective,
        ),
        soulVersion: null,
      );

      expect(prompt, isNot(contains('You are Laura')));
      expect(prompt, contains('## Input Handling'));
    });
  });

  group('the seeded report directive is never rendered', () {
    // The constant reads like the live rule and contradicts it. On 2026-08-08
    // it was mistaken for production behaviour and a correct evaluation result
    // was retracted because of it. These assertions make the distinction
    // mechanical instead of something a reader has to know.
    for (final seeded in <({String label, String directive})>[
      (label: 'empty directive', directive: ''),
      (label: 'stock seeded directive', directive: taskAgentReportDirective),
    ]) {
      test('is substituted for a ${seeded.label}', () {
        final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
          version: makeTestTemplateVersion(
            id: 'v-sentinel',
            agentId: 'a-sentinel',
            generalDirective: taskAgentGeneralDirective,
            reportDirective: seeded.directive,
          ),
          soulVersion: null,
          modelId: 'glm-5.2',
        );

        expect(
          prompt,
          isNot(contains('MANDATORY FINAL TOOL CALL')),
          reason: 'the seeded text must never reach a stock agent',
        );
        expect(
          prompt,
          contains('do not republish unchanged content'),
          reason: 'the substituted contract is what the model actually gets',
        );
      });
    }

    test('a genuinely custom directive is sent verbatim', () {
      const custom = '## Custom contract\n\nAlways include a haiku.';
      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: makeTestTemplateVersion(
          id: 'v-custom',
          agentId: 'a-custom',
          generalDirective: taskAgentGeneralDirective,
          reportDirective: custom,
        ),
        soulVersion: null,
        modelId: 'glm-5.2',
      );

      expect(prompt, contains('Always include a haiku.'));
      expect(
        prompt,
        isNot(contains('do not republish unchanged content')),
        reason: 'substitution must not override an evolved directive',
      );
    });
  });
}
