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

  group('system prompt', () {
    test('contains evolution agent role description', () {
      final ctx = buildWithDefaults();

      expect(ctx.systemPrompt, contains('evolution agent'));
      expect(ctx.systemPrompt, contains('propose_directives'));
      expect(ctx.systemPrompt, contains('publish_ritual_recap'));
      expect(ctx.systemPrompt, contains('record_evolution_note'));
      expect(ctx.systemPrompt, contains('Surface the sharpest issue'));
      expect(
        ctx.systemPrompt,
        contains('Start with a short recap since the last 1-on-1'),
      );
      expect(ctx.systemPrompt, contains('BinaryChoicePrompt'));
    });

    test('contains conversation rules', () {
      final ctx = buildWithDefaults();

      expect(ctx.systemPrompt, contains('propose improved directives'));
      expect(ctx.systemPrompt, contains('core identity'));
      expect(
        ctx.systemPrompt,
        contains('Treat aggregate metrics as background only'),
      );
      expect(
        ctx.systemPrompt,
        contains('Keep the opening conversational'),
      );
    });
  });

  group('initial user message', () {
    test('includes template name and current directives', () {
      final ctx = buildWithDefaults();

      expect(ctx.initialUserMessage, contains('Laura'));
      expect(ctx.initialUserMessage, contains('Be helpful and concise.'));
    });

    test('includes operational background without success-rate praise', () {
      final ctx = buildWithDefaults();

      expect(ctx.initialUserMessage, contains('Operational Background'));
      expect(ctx.initialUserMessage, contains('Total wakes: 10'));
      expect(ctx.initialUserMessage, contains('Failed wakes: 2'));
      expect(ctx.initialUserMessage, contains('Active instances: 2'));
      expect(ctx.initialUserMessage, isNot(contains('Success rate:')));
    });

    test('includes delta count when non-zero', () {
      final ctx = buildWithDefaults(changesSinceLastSession: 47);

      expect(ctx.initialUserMessage, contains('47 entity changes'));
    });

    test('omits delta section when zero', () {
      final ctx = buildWithDefaults();

      expect(
        ctx.initialUserMessage,
        isNot(contains('Changes Since Last Session')),
      );
    });

    test('includes version history when multiple versions exist', () {
      final ctx = buildWithDefaults(versionCount: 3);

      expect(ctx.initialUserMessage, contains('Version History'));
      expect(ctx.initialUserMessage, contains('v1'));
      expect(ctx.initialUserMessage, contains('v2'));
    });

    test('omits version history for single version', () {
      final ctx = buildWithDefaults();

      expect(
        ctx.initialUserMessage,
        isNot(contains('Version History')),
      );
    });

    test('includes instance reports', () {
      final ctx = buildWithDefaults(reportCount: 3);

      expect(ctx.initialUserMessage, contains('Recent Instance Reports (3)'));
      expect(ctx.initialUserMessage, contains('Report content 0'));
    });

    test('omits reports section when empty', () {
      final ctx = buildWithDefaults();

      expect(
        ctx.initialUserMessage,
        isNot(contains('Recent Instance Reports')),
      );
    });

    test('includes instance observations', () {
      final ctx = buildWithDefaults(observationCount: 2);

      expect(
        ctx.initialUserMessage,
        contains('Recent Instance Observations (2)'),
      );
    });

    test('includes evolution notes with kind labels', () {
      final ctx = buildWithDefaults(noteCount: 4);

      expect(
        ctx.initialUserMessage,
        contains('Your Notes From Past Sessions (4)'),
      );
      expect(ctx.initialUserMessage, contains('**reflection**'));
      expect(ctx.initialUserMessage, contains('**hypothesis**'));
      expect(ctx.initialUserMessage, contains('**decision**'));
      expect(ctx.initialUserMessage, contains('**pattern**'));
    });

    test('ends with prompt for user interaction', () {
      final ctx = buildWithDefaults();

      expect(ctx.initialUserMessage, contains('sharpest problem'));
      expect(ctx.initialUserMessage, contains('category ratings only if'));
      expect(
        ctx.systemPrompt,
        contains('say that plainly instead of forcing drama'),
      );
    });

    test('uses split directives when generalDirective is populated', () {
      final ctx = builder.build(
        template: makeTestTemplate(displayName: 'Laura'),
        currentVersion: makeTestTemplateVersion(
          generalDirective: 'Be helpful and precise.',
          reportDirective: 'Write concise reports.',
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
        contains('Current General Directive'),
      );
      expect(
        ctx.initialUserMessage,
        contains('Be helpful and precise.'),
      );
      expect(
        ctx.initialUserMessage,
        contains('Current Report Directive'),
      );
      expect(
        ctx.initialUserMessage,
        contains('Write concise reports.'),
      );
      // Legacy "Current Directives" heading should NOT appear.
      expect(
        ctx.initialUserMessage,
        isNot(contains('## Current Directives')),
      );
    });

    test('falls back to legacy directives when split fields are empty', () {
      final ctx = builder.build(
        template: makeTestTemplate(displayName: 'Laura'),
        currentVersion: makeTestTemplateVersion(
          directives: 'Legacy directives text.',
        ),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: const [],
        instanceObservations: const [],
        pastNotes: const [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
      );

      expect(ctx.initialUserMessage, contains('## Current Directives'));
      expect(
        ctx.initialUserMessage,
        contains('Legacy directives text.'),
      );
      expect(
        ctx.initialUserMessage,
        isNot(contains('Current General Directive')),
      );
    });
  });

  group('hard caps', () {
    test('caps reports at maxInstanceReports', () {
      final ctx = buildWithDefaults(
        reportCount: EvolutionContextBuilder.maxInstanceReports + 5,
      );

      expect(
        ctx.initialUserMessage,
        contains(
          'Recent Instance Reports '
          '(${EvolutionContextBuilder.maxInstanceReports})',
        ),
      );
      // Content from the first report should be present.
      expect(ctx.initialUserMessage, contains('Report content 0'));
      // Content beyond the cap should not appear.
      expect(
        ctx.initialUserMessage,
        isNot(
          contains(
            'Report content ${EvolutionContextBuilder.maxInstanceReports + 1}',
          ),
        ),
      );
    });

    test('caps observations at maxInstanceObservations', () {
      final ctx = buildWithDefaults(
        observationCount: EvolutionContextBuilder.maxInstanceObservations + 5,
      );

      expect(
        ctx.initialUserMessage,
        contains(
          'Recent Instance Observations '
          '(${EvolutionContextBuilder.maxInstanceObservations})',
        ),
      );
    });

    test('caps notes at maxPastNotes', () {
      final ctx = buildWithDefaults(
        noteCount: EvolutionContextBuilder.maxPastNotes + 5,
      );

      expect(
        ctx.initialUserMessage,
        contains(
          'Your Notes From Past Sessions '
          '(${EvolutionContextBuilder.maxPastNotes})',
        ),
      );
    });

    test('caps version history at maxVersionHistory', () {
      // +1 for the current version which gets filtered out.
      final ctx = buildWithDefaults(
        versionCount: EvolutionContextBuilder.maxVersionHistory + 3,
      );

      // Count version lines (v1, v2, etc. excluding the current).
      final versionLines = RegExp(r'- v\d+').allMatches(
        ctx.initialUserMessage,
      );
      expect(
        versionLines.length,
        lessThanOrEqualTo(EvolutionContextBuilder.maxVersionHistory),
      );
    });
  });

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

    test('omits section when version predates entries by one day', () {
      // Version created the day after all changelog entries — no entries
      // should be shown.
      final ctx = builder.build(
        template: makeTestTemplate(displayName: 'Laura'),
        currentVersion: makeTestTemplateVersion(
          createdAt: DateTime(2026, 3, 10),
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
}
