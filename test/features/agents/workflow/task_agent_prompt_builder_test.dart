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
          evidenceSynthesis: true,
          evidenceSynthesisModelId: 'mistral-small-4-119b-instruct',
        ),
        evolvedDirective.trim(),
      );
      expect(
        TaskAgentPromptBuilder.effectiveReportDirective(
          version: makeTestTemplateVersion(
            reportDirective: taskAgentReportDirective,
          ),
          evidenceSynthesis: true,
          evidenceSynthesisModelId: 'mistral-small-4-119b-instruct',
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

      // Falls into the legacy branch: full scaffold + single directives field.
      expect(prompt, contains(TaskAgentPromptBuilder.taskAgentScaffold));
      expect(prompt, contains('## Your Personality & Directives'));
      expect(prompt, contains('You are precise and concise.'));
      // Legacy branch never emits the default report section twice or a
      // standalone Report Directive heading.
      expect(prompt, isNot(contains('## Report Directive')));
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
      'keeps the default report scaffold when only generalDirective set',
      () {
        final version = makeTestTemplateVersion(
          generalDirective: 'Stay terse.',
        );

        final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
          version: version,
          soulVersion: null,
        );

        expect(
          prompt,
          contains(TaskAgentPromptBuilder.taskAgentScaffoldReport),
        );
        expect(prompt, isNot(contains('## Report Directive')));
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
        evidenceSynthesis: true,
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
          evidenceSynthesis: true,
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
        evidenceSynthesis: true,
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
        evidenceSynthesis: true,
        evidenceSynthesisModelId: 'mistral-small-4-119b-instruct',
      );
      final qwenPrompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: version,
        soulVersion: null,
        evidenceSynthesis: true,
        evidenceSynthesisModelId: 'qwen3.5-122b-a10b',
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
      expect(qwenPrompt, contains('Omit absent'));
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
        evidenceSynthesis: true,
        evidenceSynthesisModelId: 'qwen3.5-122b-a10b',
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
}
