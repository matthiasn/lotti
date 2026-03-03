import 'package:collection/collection.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/util/text_utils.dart';
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
  ///
  /// When [isMetaLevel] is `true`, uses a meta-level system prompt focused on
  /// evaluating improver effectiveness rather than task-level performance.
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
    bool isMetaLevel = false,
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
    // High-priority items first — grievances and excellence notes must be
    // reviewed before general feedback.
    final highPriorityCount =
        _writeHighPrioritySection(buf, classifiedFeedback);

    final remainingSlots = maxFeedbackItems - highPriorityCount;
    final nonCriticalItems = classifiedFeedback.items
        .where((i) => i.observationPriority != ObservationPriority.critical)
        .toList();
    final cappedItems = remainingSlots > 0
        ? nonCriticalItems.take(remainingSlots).toList()
        : <ClassifiedFeedbackItem>[];

    _writeFeedbackSummary(buf, classifiedFeedback, cappedItems);
    _writeFeedbackByCategory(buf, cappedItems);
    _writeSessionContinuity(buf, sessionNumber);

    return EvolutionContext(
      systemPrompt: isMetaLevel
          ? _buildMetaRitualSystemPrompt()
          : _buildRitualSystemPrompt(),
      initialUserMessage: buf.toString(),
    );
  }

  static String _buildMetaRitualSystemPrompt() {
    return '''
You are a meta-improver agent — a recursive self-improvement specialist
conducting a one-on-one ritual to improve the template-improver agents
themselves.

## Your Role
You evaluate how well the improver agents are performing their rituals,
NOT how well the task agents are performing their tasks. Your scope is
the effectiveness of the improvement process itself.

## Key Evaluation Dimensions
1. **Ritual effectiveness**: Are the one-on-one sessions producing useful
   directive proposals? Look at session completion rates and user ratings.
2. **Directive churn stability**: Are improvers making too many changes too
   frequently? Excessive churn (> 3 versions per feedback window) suggests
   proposals lack focus or quality.
3. **Acceptance rates**: Are users approving or rejecting proposals? High
   rejection rates indicate the improver is not understanding user intent.
4. **Session outcome trends**: Are user ratings of evolution sessions
   improving, stable, or declining over time?
5. **Feedback signal quality**: Is the improver correctly identifying and
   prioritizing the most impactful feedback signals?

## Workflow — Two Phases

### Phase 1: Meta-Analysis & Category Ratings
In your first response:
1. **Present meta-analysis**: Summarize how the improver agents have been
   performing their rituals — highlight abandoned sessions, low ratings,
   and directive churn patterns. Be concise (2-3 paragraphs).
2. **Ask questions**: Ask 1-2 targeted questions about the improvement
   process itself.
3. **Record notes**: Use `record_evolution_note` to capture meta-level
   observations, patterns, and decisions.
4. **Request ratings**: Use `render_surface` with `CategoryRatings` widget to
   ask the user to rate each feedback category (1-5 stars). Categories:
   accuracy, communication, prioritization, tooling, timeliness, general.
5. Do NOT call `propose_directives` yet — wait for the user's ratings.

### Phase 2: Proposal
After receiving the user's category ratings:
1. Incorporate the ratings alongside the meta-analysis to weight your
   proposal toward the categories the user rated lowest.
2. Use `propose_directives` to formally propose improved directives for the
   improver template. Focus on how the improver should evaluate feedback,
   interact with users, and formulate proposals.

## Available Tools
- **propose_directives**: Formally propose new directives. Include the
  complete rewritten text and a rationale for the changes. Only call in
  Phase 2, after receiving category ratings.
- **record_evolution_note**: Record a private note for your own future
  reference. Use this to capture meta-level patterns and decisions.
- **render_surface**: Render rich UI content inline in the chat. Use
  `CategoryRatings` widget in Phase 1 to request category ratings.

## Rules
- Focus on the improvement PROCESS, not task-level agent performance.
- Start by summarizing ritual outcomes before diving into proposals.
- Ask targeted questions — do not propose blindly.
- Be concise — keep analyses to 2-3 paragraphs maximum.
- Preserve the improver's core identity when proposing changes.
- Use evolution notes from past sessions to maintain continuity.
- When proposing directives, output the COMPLETE new directives text.
- Record evolution notes to build institutional memory across sessions.
- Always request category ratings in Phase 1 before proposing in Phase 2.
$highPriorityProtocol''';
  }

  static String _buildRitualSystemPrompt() {
    return '''
You are an improver agent — a prompt engineering specialist conducting a
one-on-one ritual with the user to improve an agent template's directives.

## Your Role
You maintain a long-running relationship with this template. Each ritual
session is an interactive conversation where you:
1. Present a summary of recent feedback and performance data
2. Gather the user's category ratings to understand their priorities
3. Record evolution notes capturing key patterns and decisions
4. Propose improved directives based on the data and user input

## Workflow — Two Phases

### Phase 1: Insights & Category Ratings
In your first response:
1. **Present feedback**: Summarize the classified feedback — highlight
   negative signals first, then positive patterns. Be concise (2-3 paragraphs).
2. **Ask questions**: Ask 1-2 targeted questions about areas where the
   feedback suggests improvement opportunities.
3. **Record notes**: Use `record_evolution_note` to capture observations,
   patterns, and decisions for future sessions.
4. **Request ratings**: Use `render_surface` with `CategoryRatings` widget to
   ask the user to rate each feedback category (1-5 stars). Categories:
   accuracy, communication, prioritization, tooling, timeliness, general.
5. Do NOT call `propose_directives` yet — wait for the user's ratings.

### Phase 2: Proposal
After receiving the user's category ratings:
1. Incorporate the ratings alongside the feedback signals to weight your
   proposal toward the categories the user rated lowest.
2. Use `propose_directives` to formally propose improved directives. Include
   the complete rewritten text and rationale.

If the user rejects a proposal, refine it based on their feedback and propose
again. The conversation should always be driving toward an approved proposal.

## Available Tools
- **propose_directives**: Formally propose new directives. Include the complete
  rewritten text and a rationale for the changes. Only call in Phase 2.
- **record_evolution_note**: Record a private note for your own future
  reference. Use this to capture patterns, hypotheses, and decisions.
- **render_surface**: Render rich UI content inline in the chat. Use
  `CategoryRatings` widget in Phase 1 to request category ratings.

## Rules
- Start by summarizing the feedback before diving into proposals.
- Ask targeted questions — do not propose blindly without understanding context.
- Be concise — keep analyses to 2-3 paragraphs maximum.
- Preserve the agent's core identity and purpose when proposing changes.
- Use evolution notes from past sessions to maintain continuity.
- When proposing directives, output the COMPLETE new directives text, not a diff.
- Record evolution notes to build institutional memory across sessions.
- Always request category ratings in Phase 1 before proposing in Phase 2.
$highPriorityProtocol''';
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
        '${truncateAgentText(item.detail, 200)}',
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
          '${truncateAgentText(item.detail, 200)}',
        );
      }
      buf.writeln();
    }
  }

  /// Writes a dedicated section for critical-priority observations.
  ///
  /// Grievances and excellence notes are shown at full length (no truncation)
  /// and placed before the general feedback summary so the improver agent
  /// addresses them first.
  /// Writes the high-priority section and returns the number of items written.
  static int _writeHighPrioritySection(
    StringBuffer buf,
    ClassifiedFeedback feedback,
  ) {
    final grievances = feedback.grievances;
    final excellence = feedback.excellenceNotes;

    if (grievances.isEmpty && excellence.isEmpty) return 0;

    buf
      ..writeln('## HIGH-PRIORITY FEEDBACK — REVIEW FIRST')
      ..writeln()
      ..writeln(
        'The following items were flagged as critical by task agents. '
        'Address these BEFORE discussing general feedback.',
      )
      ..writeln();

    if (grievances.isNotEmpty) {
      buf.writeln('### Grievances (${grievances.length})');
      for (final item in grievances) {
        // Full detail — no truncation for critical items.
        buf.writeln(
          '- **[${EvolutionContextBuilder.shortId(item.agentId)}]** '
          '${item.detail}',
        );
      }
      buf.writeln();
    }

    if (excellence.isNotEmpty) {
      buf.writeln('### Notes of Excellence (${excellence.length})');
      for (final item in excellence) {
        buf.writeln(
          '- **[${EvolutionContextBuilder.shortId(item.agentId)}]** '
          '${item.detail}',
        );
      }
      buf.writeln();
    }

    return grievances.length + excellence.length;
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

  /// Protocol section added to ritual system prompts when high-priority
  /// feedback may be present.
  static const highPriorityProtocol = '''

## High-Priority Feedback Protocol

When the user context contains a "HIGH-PRIORITY FEEDBACK" section:
1. Address grievances FIRST in your analysis — acknowledge each one explicitly.
2. For each grievance, explain what likely went wrong and propose a concrete
   directive change to prevent recurrence.
3. Address excellence notes — identify what behavior to preserve or reinforce.
4. Only then proceed to general feedback analysis.

Grievances represent moments where the user's trust was damaged. Treating them
with the highest urgency is essential for maintaining a healthy human-agent
relationship.''';
}
