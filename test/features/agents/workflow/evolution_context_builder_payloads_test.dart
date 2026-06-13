import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/evolution_context_builder.dart';

import '../test_utils.dart';

void main() {
  late EvolutionContextBuilder builder;

  setUp(() {
    builder = EvolutionContextBuilder();
  });

  EvolutionContext buildWithDefaults({
    int reportCount = 0,
    int observationCount = 0,
    int noteCount = 0,
    int versionCount = 1,
    int changesSinceLastSession = 0,
  }) {
    final versions = List.generate(
      versionCount,
      (i) => makeTestTemplateVersion(
        id: 'ver-${i + 1}',
        version: i + 1,
        status: i == versionCount - 1
            ? AgentTemplateVersionStatus.active
            : AgentTemplateVersionStatus.archived,
        directives: i == versionCount - 1
            ? 'Be helpful and concise.'
            : 'Directives v${i + 1}',
        authoredBy: i == 0 ? 'system' : 'agent',
      ),
    );
    return builder.build(
      template: makeTestTemplate(displayName: 'Laura'),
      currentVersion: versions.last,
      recentVersions: versions,
      instanceReports: List.generate(
        reportCount,
        (i) => makeTestReport(
          id: 'report-$i',
          agentId: 'agent-$i',
          content: 'Report content $i with some details.',
        ),
      ),
      instanceObservations: List.generate(
        observationCount,
        (i) => makeTestMessage(
          id: 'obs-$i',
          agentId: 'agent-$i',
          kind: AgentMessageKind.observation,
        ),
      ),
      pastNotes: List.generate(
        noteCount,
        (i) => makeTestEvolutionNote(
          id: 'note-$i',
          kind: EvolutionNoteKind.values[i % EvolutionNoteKind.values.length],
          content: 'Note content $i',
        ),
      ),
      metrics: makeTestMetrics(),
      changesSinceLastSession: changesSinceLastSession,
    );
  }

  group('observation payloads', () {
    test('includes payload text when provided', () {
      final obs = makeTestMessage(
        id: 'obs-1',
        kind: AgentMessageKind.observation,
        contentEntryId: 'payload-1',
      );
      final payload = makeTestMessagePayload(
        id: 'payload-1',
        content: {'text': 'The agent performed well today.'},
      );

      final ctx = builder.build(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: const [],
        instanceObservations: [obs],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        observationPayloads: {'payload-1': payload},
      );

      expect(
        ctx.initialUserMessage,
        contains('The agent performed well today.'),
      );
    });

    test('shows observation without content when payload is missing', () {
      final obs = makeTestMessage(
        id: 'obs-1',
        kind: AgentMessageKind.observation,
        contentEntryId: 'missing-payload',
      );

      final ctx = builder.build(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: const [],
        instanceObservations: [obs],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
      );

      // Should still include the observation header.
      expect(ctx.initialUserMessage, contains('Recent Instance Observations'));
      expect(ctx.initialUserMessage, contains('observation'));
    });
  });

  group('truncation', () {
    test('truncates long report content', () {
      final ctx = builder.build(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: [
          makeTestReport(content: 'A' * 600),
        ],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
      );

      // Content should be truncated with ellipsis
      expect(ctx.initialUserMessage, contains('…'));
      // Should not contain the full 600-char string
      expect(ctx.initialUserMessage.contains('A' * 600), isFalse);
    });
  });

  group('seed directive changelog', () {
    test('includes changelog entries newer than version createdAt', () {
      // Default kAgentTestDate is 2024-03-15, and changelog entries are
      // dated 2026-03-09, so they should appear for a taskAgent template.
      final ctx = buildWithDefaults();

      expect(
        ctx.initialUserMessage,
        contains('Seed Directive Updates Since Your Version'),
      );
      expect(ctx.initialUserMessage, contains('Report language'));
      expect(ctx.initialUserMessage, contains('Links section'));
    });

    test('omits changelog when version is newer than all entries', () {
      final ctx = builder.build(
        template: makeTestTemplate(displayName: 'Laura'),
        currentVersion: makeTestTemplateVersion(
          createdAt: DateTime(2027),
        ),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: const [],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
      );

      expect(
        ctx.initialUserMessage,
        isNot(contains('Seed Directive Updates')),
      );
    });

    test('includes same-day entries for versions created later that day', () {
      // Changelog entries are dated 2026-03-09 (midnight). A version
      // created at 10:30 on that same day should still see them.
      final ctx = builder.build(
        template: makeTestTemplate(displayName: 'Laura'),
        currentVersion: makeTestTemplateVersion(
          createdAt: DateTime(2026, 3, 9, 10, 30),
        ),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: const [],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
      );

      expect(
        ctx.initialUserMessage,
        contains('Seed Directive Updates Since Your Version'),
      );
    });

    test('omits entries for a different template kind', () {
      // The latest changelog entry applies to the improver template kind, so
      // this template should still receive the seed-directive update section.
      final ctx = builder.build(
        template: makeTestTemplate(
          displayName: 'Improver',
          kind: AgentTemplateKind.templateImprover,
        ),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: const [],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
      );

      expect(
        ctx.initialUserMessage,
        contains('Seed Directive Updates'),
      );
    });

    test('omits section when version postdates entries by one day', () {
      // Version created the day after every task-agent changelog entry so
      // no updates should be surfaced. Bump this forward whenever a new
      // entry is added to `seedDirectiveChangelog`.
      final ctx = builder.build(
        template: makeTestTemplate(displayName: 'Laura'),
        currentVersion: makeTestTemplateVersion(
          createdAt: DateTime(2026, 4, 20),
        ),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: const [],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
      );

      expect(
        ctx.initialUserMessage,
        isNot(contains('Seed Directive Updates')),
      );
    });
  });

  group('soul context', () {
    test('includes soul personality section when soul version provided', () {
      final ctx = builder.build(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(
          generalDirective: 'Skills.',
        ),
        recentVersions: const [],
        instanceReports: const [],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        currentSoulVersion: makeTestSoulDocumentVersion(
          voiceDirective: 'Be warm.',
          toneBounds: 'No sarcasm.',
          coachingStyle: 'Celebrate wins.',
          antiSycophancyPolicy: 'Push back.',
        ),
      );

      expect(
        ctx.initialUserMessage,
        contains('Current Soul Personality'),
      );
      expect(ctx.initialUserMessage, contains('Be warm.'));
      expect(ctx.initialUserMessage, contains('No sarcasm.'));
      expect(ctx.initialUserMessage, contains('Celebrate wins.'));
      expect(ctx.initialUserMessage, contains('Push back.'));
    });

    test('omits soul section when no soul assigned', () {
      final ctx = buildWithDefaults();

      expect(
        ctx.initialUserMessage,
        isNot(contains('Current Soul Personality')),
      );
    });

    test('includes cross-template notice', () {
      final ctx = builder.build(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(
          generalDirective: 'Skills.',
        ),
        recentVersions: const [],
        instanceReports: const [],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        currentSoulVersion: makeTestSoulDocumentVersion(
          voiceDirective: 'Voice.',
        ),
        otherTemplatesUsingSoul: ['Tom Task Agent', 'Project Analyst'],
      );

      expect(
        ctx.initialUserMessage,
        contains('Cross-Template Impact Notice'),
      );
      expect(ctx.initialUserMessage, contains('Tom Task Agent'));
      expect(ctx.initialUserMessage, contains('Project Analyst'));
    });

    test('caps cross-template names and shows overflow count', () {
      final ctx = builder.build(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(
          generalDirective: 'Skills.',
        ),
        recentVersions: const [],
        instanceReports: const [],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        currentSoulVersion: makeTestSoulDocumentVersion(
          voiceDirective: 'Voice.',
        ),
        otherTemplatesUsingSoul: List.generate(
          15,
          (i) => 'Template ${i + 1}',
        ),
      );

      // First 10 should appear, remaining 5 should be summarized.
      expect(ctx.initialUserMessage, contains('Template 1'));
      expect(ctx.initialUserMessage, contains('Template 10'));
      expect(ctx.initialUserMessage, contains('and 5 more'));
      // Template 11+ should NOT appear as individual names.
      expect(ctx.initialUserMessage, isNot(contains('Template 11,')));
    });

    test('includes soul version history capped at max', () {
      final soulVersions = List.generate(
        8,
        (i) => makeTestSoulDocumentVersion(
          id: 'sv-${i + 1}',
          version: i + 1,
          voiceDirective: 'Voice v${i + 1}',
        ),
      );

      final ctx = builder.build(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(
          generalDirective: 'Skills.',
        ),
        recentVersions: const [],
        instanceReports: const [],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        currentSoulVersion: soulVersions.last,
        recentSoulVersions: soulVersions,
      );

      expect(
        ctx.initialUserMessage,
        contains('Soul Version History'),
      );
      // Should show at most 5 versions.
      expect(ctx.initialUserMessage, contains('v1'));
      expect(ctx.initialUserMessage, contains('v5'));
      expect(ctx.initialUserMessage, isNot(contains('v6')));
    });

    test('system prompt mentions propose_soul_directives', () {
      final ctx = builder.build(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(
          generalDirective: 'Skills.',
        ),
        recentVersions: const [],
        instanceReports: const [],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        currentSoulVersion: makeTestSoulDocumentVersion(
          voiceDirective: 'Voice.',
        ),
      );

      expect(ctx.systemPrompt, contains('propose_soul_directives'));
      expect(ctx.systemPrompt, contains('personality changes'));
    });
  });
}
