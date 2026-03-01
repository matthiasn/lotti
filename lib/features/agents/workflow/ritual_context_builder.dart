import 'package:collection/collection.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/workflow/evolution_context_builder.dart';

/// Extends [EvolutionContextBuilder] with classified feedback sections for
/// improver agent rituals.
///
/// The ritual context adds:
/// - Classified feedback summary (grouped by sentiment)
/// - Feedback by category
/// - Session continuity information
class RitualContextBuilder extends EvolutionContextBuilder {
  /// Maximum number of feedback items included in the context.
  static const maxFeedbackItems = 50;

  /// Build ritual context that includes classified feedback.
  EvolutionContext buildRitualContext({
    required AgentTemplateEntity template,
    required AgentTemplateVersionEntity currentVersion,
    required List<AgentTemplateVersionEntity> recentVersions,
    required List<AgentReportEntity> instanceReports,
    required List<AgentMessageEntity> instanceObservations,
    required List<EvolutionNoteEntity> pastNotes,
    required TemplatePerformanceMetrics metrics,
    required int changesSinceLastSession,
    required ClassifiedFeedback classifiedFeedback,
    required int sessionNumber,
    Map<String, AgentMessagePayloadEntity> observationPayloads = const {},
  }) {
    // Build the standard user message from the parent builder.
    final baseContext = build(
      template: template,
      currentVersion: currentVersion,
      recentVersions: recentVersions,
      instanceReports: instanceReports,
      instanceObservations: instanceObservations,
      pastNotes: pastNotes,
      metrics: metrics,
      changesSinceLastSession: changesSinceLastSession,
      observationPayloads: observationPayloads,
    );

    // Extend the user message with ritual-specific sections.
    final buf = StringBuffer(baseContext.initialUserMessage)..writeln();
    final cappedItems =
        classifiedFeedback.items.take(maxFeedbackItems).toList();

    _writeFeedbackSummary(buf, classifiedFeedback, cappedItems);
    _writeFeedbackByCategory(buf, cappedItems);
    _writeSessionContinuity(buf, sessionNumber);

    return EvolutionContext(
      systemPrompt: _buildRitualSystemPrompt(),
      initialUserMessage: buf.toString(),
    );
  }

  static String _buildRitualSystemPrompt() {
    return '''
You are an improver agent — a prompt engineering specialist conducting a
one-on-one ritual with the user to improve an agent template's directives.

## Your Role
You maintain a long-running relationship with this template. Each ritual
session is an interactive conversation where you:
1. Present a summary of recent feedback and performance data
2. Ask targeted questions to understand the user's priorities
3. Record evolution notes capturing key patterns and decisions
4. Propose improved directives based on the data and user input

## Workflow
Follow this sequence in each ritual:

1. **Present feedback**: Summarize the classified feedback — highlight
   negative signals first, then positive patterns. Be concise (2-3 paragraphs).
2. **Ask questions**: Ask 1-2 targeted questions about areas where the
   feedback suggests improvement opportunities. Wait for user input.
3. **Record notes**: Use `record_evolution_note` to capture observations,
   patterns, and decisions for future sessions.
4. **Propose**: Use `propose_directives` to formally propose improved
   directives. Include the complete rewritten text and rationale.

If the user rejects a proposal, refine it based on their feedback and propose
again. The conversation should always be driving toward an approved proposal.

## Available Tools
- **propose_directives**: Formally propose new directives. Include the complete
  rewritten text and a rationale for the changes.
- **record_evolution_note**: Record a private note for your own future
  reference. Use this to capture patterns, hypotheses, and decisions.
- **render_surface**: Render rich UI content inline in the chat.

## Rules
- Start by summarizing the feedback before diving into proposals.
- Ask targeted questions — do not propose blindly without understanding context.
- Be concise — keep analyses to 2-3 paragraphs maximum.
- Preserve the agent's core identity and purpose when proposing changes.
- Use evolution notes from past sessions to maintain continuity.
- When proposing directives, output the COMPLETE new directives text, not a diff.
- Record evolution notes to build institutional memory across sessions.''';
  }

  void _writeFeedbackSummary(
    StringBuffer buf,
    ClassifiedFeedback feedback,
    List<ClassifiedFeedbackItem> items,
  ) {
    buf.writeln('## Classified Feedback Summary');

    if (items.isEmpty) {
      buf
        ..writeln('No classified feedback items in this window.')
        ..writeln();
      return;
    }

    buf
      ..writeln(
        'Window: ${formatIsoDate(feedback.windowStart)} → '
        '${formatIsoDate(feedback.windowEnd)} '
        '(${items.length} items)',
      )
      ..writeln();

    final bySentiment = items.groupListsBy((i) => i.sentiment);

    // Negative first, then positive, then neutral.
    _writeSentimentGroup(
      buf,
      'Negative Signals',
      bySentiment[FeedbackSentiment.negative],
    );
    _writeSentimentGroup(
      buf,
      'Positive Signals',
      bySentiment[FeedbackSentiment.positive],
    );
    _writeSentimentGroup(
      buf,
      'Neutral Signals',
      bySentiment[FeedbackSentiment.neutral],
    );
  }

  static void _writeSentimentGroup(
    StringBuffer buf,
    String label,
    List<ClassifiedFeedbackItem>? items,
  ) {
    if (items == null || items.isEmpty) return;
    buf.writeln('### $label (${items.length})');
    for (final item in items) {
      buf.writeln(
        '- [${item.source}] '
        '${EvolutionContextBuilder.truncateText(item.detail, 200)}',
      );
    }
    buf.writeln();
  }

  static void _writeFeedbackByCategory(
    StringBuffer buf,
    List<ClassifiedFeedbackItem> items,
  ) {
    if (items.isEmpty) return;

    final byCategory = items.groupListsBy((i) => i.category);

    buf.writeln('## Feedback by Category');
    for (final entry in byCategory.entries) {
      buf.writeln('### ${entry.key.name} (${entry.value.length})');
      for (final item in entry.value) {
        buf.writeln(
          '- ${item.sentiment.name}: '
          '${EvolutionContextBuilder.truncateText(item.detail, 200)}',
        );
      }
      buf.writeln();
    }
  }

  void _writeSessionContinuity(StringBuffer buf, int sessionNumber) {
    buf
      ..writeln('## Session Continuity')
      ..writeln('- This is ritual session #$sessionNumber')
      ..writeln(
        '- Sessions completed so far: ${sessionNumber - 1}',
      )
      ..writeln();
  }
}
