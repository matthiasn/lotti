import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/task_agent_prompt_builder.dart';

import '../test_utils.dart';

void main() {
  group('TaskAgentPromptBuilder.buildSystemPrompt', () {
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
  });
}
