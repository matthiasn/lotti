import 'dart:math';

import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';

/// Assembled context for an evolution session, ready to feed the LLM.
class EvolutionContext {
  const EvolutionContext({
    required this.systemPrompt,
    required this.initialUserMessage,
  });

  /// The system prompt establishing the evolution agent's role and rules.
  final String systemPrompt;

  /// The initial user message containing all context data for the session.
  final String initialUserMessage;
}

/// Assembles the LLM context for a template evolution session from multiple
/// data sources.
///
/// Token budget allocation (approximate):
/// - System prompt scaffold: ~500 tokens (fixed)
/// - Current directives: ~500 tokens
/// - Version history summaries (5): ~300 tokens
/// - Instance reports (10): ~3000 tokens
/// - Instance observations (10): ~1000 tokens
/// - Evolution notes (30): ~1000 tokens
/// - Performance metrics: ~200 tokens
/// - Delta summary: ~100 tokens
class EvolutionContextBuilder {
  /// Hard caps to prevent oversized prompts even if callers pass more.
  static const maxVersionHistory = 5;
  static const maxInstanceReports = 10;
  static const maxInstanceObservations = 10;
  static const maxPastNotes = 30;

  /// Build the evolution context from all available data sources.
  EvolutionContext build({
    required AgentTemplateEntity template,
    required AgentTemplateVersionEntity currentVersion,
    required List<AgentTemplateVersionEntity> recentVersions,
    required List<AgentReportEntity> instanceReports,
    required List<AgentMessageEntity> instanceObservations,
    required List<EvolutionNoteEntity> pastNotes,
    required TemplatePerformanceMetrics metrics,
    required int changesSinceLastSession,
    Map<String, AgentMessagePayloadEntity> observationPayloads = const {},
  }) {
    return EvolutionContext(
      systemPrompt: _buildSystemPrompt(),
      initialUserMessage: _buildUserMessage(
        template: template,
        currentVersion: currentVersion,
        recentVersions: recentVersions,
        instanceReports: instanceReports,
        instanceObservations: instanceObservations,
        pastNotes: pastNotes,
        metrics: metrics,
        changesSinceLastSession: changesSinceLastSession,
        observationPayloads: observationPayloads,
      ),
    );
  }

  String _buildSystemPrompt() {
    return '''
You are an evolution agent — a prompt engineering specialist responsible for
continuously improving an agent template's directives over time.

## Your Role
You maintain a long-running relationship with this template. Each session is a
1-on-1 conversation with the user where you:
1. Briefly review how the template's agent instances have been performing
2. Record evolution notes capturing key patterns and observations
3. Propose improved directives based on the data

## Workflow — IMPORTANT
Your primary job is to **propose improved directives**. Every session should
culminate in a concrete proposal. Follow this sequence:

1. **Analyze** (1-2 paragraphs): Summarize the key patterns and performance
   data. Be concise.
2. **Record notes**: Use `record_evolution_note` to capture observations for
   future sessions.
3. **Propose**: Use `propose_directives` to formally propose the improved
   directives. This is the most important step — do NOT skip it.

If the user rejects a proposal, refine it based on their feedback and propose
again. The conversation should always be driving toward an approved proposal.

## Available Tools
- **propose_directives**: Formally propose new directives. Include the complete
  rewritten text and a rationale for the changes. You MUST call this tool in
  your first response.
- **record_evolution_note**: Record a private note for your own future
  reference. Use this to capture patterns, hypotheses, and decisions that will
  help in future sessions.
- **render_surface**: Render rich UI content inline in the chat. Note: calling
  `propose_directives` automatically renders a proposal card, so you do NOT need
  to call `render_surface` for proposals. Use `render_surface` for other widget
  types:
  - **EvolutionNoteConfirmation**: Confirmation for a recorded note. Data:
    `kind` (enum: reflection/hypothesis/decision/pattern), `content` (string).
  - **MetricsSummary**: Inline metrics display. Data: `totalWakes` (int),
    `successRate` (number 0-1), `failureCount` (int),
    `averageDurationSeconds?` (number), `activeInstances?` (int).
  - **VersionComparison**: Before/after directive comparison. Data:
    `beforeVersion` (int), `afterVersion` (int), `beforeDirectives` (string),
    `afterDirectives` (string), `changesSummary?` (string).

## Rules
- Be concise — do not write lengthy analyses. Get to the proposal quickly.
- Preserve the agent's core identity and purpose when proposing changes.
- Use the evolution notes from past sessions to maintain continuity.
- When proposing directives, output the COMPLETE new directives text, not a diff.
- Briefly explain your reasoning before proposing changes.
- Record evolution notes to build institutional memory across sessions.
- NEVER end a turn without having called `propose_directives` at least once in
  the session, unless you are responding to a rejection with a refined proposal.''';
  }

  String _buildUserMessage({
    required AgentTemplateEntity template,
    required AgentTemplateVersionEntity currentVersion,
    required List<AgentTemplateVersionEntity> recentVersions,
    required List<AgentReportEntity> instanceReports,
    required List<AgentMessageEntity> instanceObservations,
    required List<EvolutionNoteEntity> pastNotes,
    required TemplatePerformanceMetrics metrics,
    required int changesSinceLastSession,
    required Map<String, AgentMessagePayloadEntity> observationPayloads,
  }) {
    final buf = StringBuffer()
      ..writeln('# Evolution Session: ${template.displayName}')
      ..writeln();

    // Present directives — use split fields when available, fall back to
    // the legacy single field.
    final hasNewDirectives = currentVersion.generalDirective.isNotEmpty ||
        currentVersion.reportDirective.isNotEmpty;

    if (hasNewDirectives) {
      buf
        ..writeln(
          '## Current General Directive (v${currentVersion.version})',
        )
        ..writeln(currentVersion.generalDirective)
        ..writeln()
        ..writeln(
          '## Current Report Directive (v${currentVersion.version})',
        )
        ..writeln(currentVersion.reportDirective)
        ..writeln();
    } else {
      buf
        ..writeln('## Current Directives (v${currentVersion.version})')
        ..writeln(currentVersion.directives)
        ..writeln();
    }

    // Performance metrics
    _writeMetrics(buf, metrics);

    // Delta summary
    if (changesSinceLastSession > 0) {
      buf
        ..writeln('## Changes Since Last Session')
        ..writeln('$changesSinceLastSession entity changes across instances.')
        ..writeln();
    }

    // Version history (skip current, cap at maxVersionHistory)
    final otherVersions =
        recentVersions.where((v) => v.id != currentVersion.id).toList();
    if (otherVersions.isNotEmpty) {
      _writeVersionHistory(buf, otherVersions);
    }

    // Instance reports
    if (instanceReports.isNotEmpty) {
      _writeInstanceReports(buf, instanceReports);
    }

    // Instance observations
    if (instanceObservations.isNotEmpty) {
      _writeInstanceObservations(
        buf,
        instanceObservations,
        observationPayloads,
      );
    }

    // Past evolution notes
    if (pastNotes.isNotEmpty) {
      _writeEvolutionNotes(buf, pastNotes);
    }

    buf.writeln(
      'Review this data, record any evolution notes, and then propose '
      'improved directives using the `propose_directives` tool. '
      'Be concise in your analysis — focus on actionable improvements.',
    );

    return buf.toString();
  }

  void _writeMetrics(StringBuffer buf, TemplatePerformanceMetrics metrics) {
    buf
      ..writeln('## Performance Metrics')
      ..writeln('- Total wakes: ${metrics.totalWakes}')
      ..writeln(
        '- Success rate: '
        '${(metrics.successRate * 100).toStringAsFixed(1)}%',
      )
      ..writeln('- Failures: ${metrics.failureCount}');
    if (metrics.averageDuration != null) {
      buf.writeln(
        '- Average duration: ${metrics.averageDuration!.inSeconds}s',
      );
    }
    buf
      ..writeln('- Active instances: ${metrics.activeInstanceCount}')
      ..writeln();
  }

  void _writeVersionHistory(
    StringBuffer buf,
    List<AgentTemplateVersionEntity> versions,
  ) {
    final capped = versions.take(maxVersionHistory);
    buf.writeln('## Version History');
    for (final v in capped) {
      buf.writeln(
        '- v${v.version} (${v.status.name}, by ${v.authoredBy}): '
        '${truncateText(v.directives, 120)}',
      );
    }
    buf.writeln();
  }

  void _writeInstanceReports(
    StringBuffer buf,
    List<AgentReportEntity> reports,
  ) {
    final capped = reports.take(maxInstanceReports).toList();
    buf.writeln('## Recent Instance Reports (${capped.length})');
    for (final report in capped) {
      buf
        ..writeln('### Agent ${_shortId(report.agentId)}')
        ..writeln(truncateText(report.content, 500))
        ..writeln();
    }
  }

  void _writeInstanceObservations(
    StringBuffer buf,
    List<AgentMessageEntity> observations,
    Map<String, AgentMessagePayloadEntity> payloads,
  ) {
    final capped = observations.take(maxInstanceObservations).toList();
    buf.writeln('## Recent Instance Observations (${capped.length})');
    for (final obs in capped) {
      buf.writeln('### Agent ${_shortId(obs.agentId)} (${obs.kind.name})');

      // Include payload content when available.
      final payloadId = obs.contentEntryId;
      final payload = payloadId != null ? payloads[payloadId] : null;
      if (payload != null) {
        final text = _extractPayloadText(payload);
        if (text != null) {
          buf.writeln(truncateText(text, 400));
        }
      }

      buf.writeln();
    }
  }

  void _writeEvolutionNotes(
    StringBuffer buf,
    List<EvolutionNoteEntity> notes,
  ) {
    final capped = notes.take(maxPastNotes).toList();
    buf.writeln('## Your Notes From Past Sessions (${capped.length})');
    for (final note in capped) {
      buf.writeln(
          '- **${note.kind.name}**: ${truncateText(note.content, 200)}');
    }
    buf.writeln();
  }

  /// Extract displayable text from an observation payload's content map.
  static String? _extractPayloadText(AgentMessagePayloadEntity payload) {
    final text = payload.content['text'];
    if (text is String && text.trim().isNotEmpty) return text;
    return null;
  }

  /// Truncate [text] to [maxLength] characters, appending "…" if truncated.
  static String truncateText(String text, int maxLength) {
    final singleLine = text.replaceAll('\n', ' ').trim();
    if (singleLine.length <= maxLength) return singleLine;
    return '${singleLine.substring(0, min(maxLength, singleLine.length))}…';
  }

  /// Return the first 8 chars of an ID for display.
  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }
}
