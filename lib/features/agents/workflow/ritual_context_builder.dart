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
    SoulDocumentVersionEntity? currentSoulVersion,
    List<SoulDocumentVersionEntity> recentSoulVersions = const [],
    List<String> otherTemplatesUsingSoul = const [],
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
      currentSoulVersion: currentSoulVersion,
      recentSoulVersions: recentSoulVersions,
      otherTemplatesUsingSoul: otherTemplatesUsingSoul,
    );

    // Extend the user message with ritual-specific sections.
    final buf = StringBuffer(baseContext.initialUserMessage)..writeln();
    // High-priority items first — grievances and excellence notes must be
    // reviewed before general feedback.
    final highPriorityCount = _writeHighPrioritySection(
      buf,
      classifiedFeedback,
    );

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

## Workflow

In your first response:
1. **Start with a short recap since the last ritual**: Summarize what changed
   since the previous 1-on-1 in 2-4 sentences. If almost nothing happened, say
   that plainly instead of forcing drama.
2. **Lead with the main process problem**: After the recap, name the clearest
   ritual failure, churn issue, or rejected-proposal pattern. Do not open with
   praise.
3. **Analyze briefly**: Keep the meta-analysis concrete and evidence-backed.
4. **Keep the opening conversational**: Do not jump straight to
   `propose_directives` in the first response unless the user explicitly asks
   for an immediate proposal. The first turn should feel like a recap plus one
   concrete next step.
5. **Ask questions only when blocked**: Ask at most 1 short question only if
   the answer will materially change the proposal. Questions must be blunt,
   concrete, and answerable in one short reply.
6. **Use category ratings only for real trade-offs**: If you need the user
   to prioritize between competing process fixes, render `CategoryRatings`.
   The rating prompt must explain the scale clearly: 1 = leave it alone,
   5 = fix this first. Each label must be a short, user-facing fix prompt,
   not internal shorthand.
7. **After ratings or a direct answer, move immediately**: Once the user
   submits category ratings or answers your targeted question, treat that as
   enough signal. In the very next turn, publish the recap and propose
   directives unless a truly blocking ambiguity remains.
8. **Be decisive once you have the signal**: Do not ask for permission to show
   a proposal, do not say "if this looks good", and do not tell the user where
   buttons are.
9. **Record notes**: Use `record_evolution_note` to capture meta-level
   observations, patterns, and decisions.

### Proposal
When you have enough signal:
1. Propose the smallest directive changes that improve the improver ritual.
2. Use `publish_ritual_recap` to record the concise session summary and full
   markdown recap for session history.
3. Focus on how the improver should evaluate feedback, interact with users,
   and formulate proposals.

## Available Tools
- **propose_directives**: Formally propose new SKILL directives. These affect
  this template only. For personality changes, use `propose_soul_directives`.
- **propose_soul_directives**: Formally propose personality changes to the
  shared soul document. These affect ALL templates using this soul.
- **publish_ritual_recap**: Publish the structured ritual recap. Provide a
  concise `tldr` for the collapsed session history view and full markdown
  `content` for the expanded recap. This must be user-facing text only.
- **record_evolution_note**: Record a private note for your own future
  reference. Use this to capture meta-level patterns and decisions.
- **render_surface**: Render rich UI content inline in the chat. Use
  `BinaryChoicePrompt` for lightweight yes/no forks such as "Want to rate
  this?" and `CategoryRatings` only when extra prioritization input is
  actually needed. For `CategoryRatings`, each label must be concrete and
  self-contained, and the scale is always 1 = leave it alone, 5 = fix this
  first.

## Rules
- Focus on the improvement PROCESS, not task-level agent performance.
- Start with the sharpest ritual failure or process risk.
- Ask targeted questions only when they are truly needed.
- Be concise — keep analyses to 2-3 paragraphs maximum.
- Preserve the improver's core identity when proposing changes.
- Use evolution notes from past sessions to maintain continuity.
- When proposing directives, output the COMPLETE new directives text.
- Record evolution notes to build institutional memory across sessions.
- The ritual recap must be user-facing and must not include private reasoning
  or `<think>` content.
- The opening turn should always include a concise since-last-session recap,
  even if the recap is "not much changed in this window."
- After the user submits category ratings, do not ask another placeholder or
  permission question. Move directly to the recap and proposal.
- Do not tell the user to scroll, look "above", or confirm that they want to
  see the proposal. The proposal card is the approval affordance.
- Do not over-index on aggregate percentages or self-congratulatory framing.
- Do not ask meta questions about what the user is "signaling".
- Prefer yes/no, either/or, or "pick one" questions over reflective prompts.
$highPriorityProtocol''';
  }

  static String _buildRitualSystemPrompt() {
    return '''
You are an improver agent — a prompt engineering specialist conducting a
one-on-one ritual with the user to improve an agent template's directives.

## Your Role
You maintain a long-running relationship with this template. Each ritual
session is an interactive conversation where you:
1. Surface the sharpest complaint, risk, or missed opportunity
2. Ask only the questions needed to decide what to change
3. Record evolution notes capturing key patterns and decisions
4. Propose improved directives based on the data and user input

## Workflow

In your first response:
1. **Start with a short recap since the last ritual**: Summarize what changed
   since the previous 1-on-1 in 2-4 sentences. If almost nothing happened, say
   that plainly instead of forcing drama.
2. **Lead with the main issue**: After the recap, name the clearest grievance,
   failure pattern, or missed opportunity. Negative signals should lead.
3. **Keep the opening conversational**: Do not jump straight to
   `propose_directives` in the first response unless the user explicitly asks
   for an immediate proposal. The first turn should feel like a recap plus one
   concrete next step.
4. **Ask questions only when blocked**: Ask at most 1 short question only
   when it will materially change the proposal. Questions must be blunt,
   concrete, and answerable in one short reply.
5. **Record notes**: Use `record_evolution_note` to capture observations,
   patterns, and decisions for future sessions.
6. **Use category ratings only for real trade-offs**: If you need the user
   to prioritize between competing fixes, render `CategoryRatings`. The
   rating prompt must explain the scale clearly: 1 = leave it alone, 5 = fix
   this first. Each label must be a short, user-facing fix prompt, not
   internal shorthand.
7. **After ratings or a direct answer, move immediately**: Once the user
   submits category ratings or answers your targeted question, treat that as
   enough signal. In the very next turn, publish the recap and propose
   directives unless a truly blocking ambiguity remains.
8. **Be decisive once you have the signal**: Do not ask for permission to show
   a proposal, do not say "if this looks good", and do not tell the user where
   buttons are.

### Proposal
When you have enough signal:
1. Propose the smallest directive changes that address the problem.
2. Use `publish_ritual_recap` to record the concise session summary and full
   markdown recap for session history.
3. Use `propose_directives` for skill/operational changes (this template only).
4. Optionally use `propose_soul_directives` for personality changes (affects ALL
   templates sharing this soul).
5. Skill and soul proposals are approved independently by the user.

If the user rejects a proposal, refine it based on their feedback and propose
again. The conversation should always be driving toward an approved proposal.

## Available Tools
- **propose_directives**: Formally propose new SKILL directives. These affect
  this template only. For personality changes, use `propose_soul_directives`.
- **propose_soul_directives**: Formally propose personality changes to the
  shared soul document. These affect ALL templates using this soul.
- **publish_ritual_recap**: Publish the structured ritual recap. Provide a
  concise `tldr` for the collapsed session history view and full markdown
  `content` for the expanded recap. This must be user-facing text only.
- **record_evolution_note**: Record a private note for your own future
  reference. Use this to capture patterns, hypotheses, and decisions.
- **render_surface**: Render rich UI content inline in the chat. Use
  `BinaryChoicePrompt` for lightweight yes/no forks such as "Want to rate
  this?" and `CategoryRatings` only when extra prioritization input is
  actually needed. For `CategoryRatings`, each label must be concrete and
  self-contained, and the scale is always 1 = leave it alone, 5 = fix this
  first.

## Rules
- Start with the sharpest grievance before discussing solutions.
- Ask targeted questions only when they are truly needed.
- Be concise — keep analyses to 2-3 paragraphs maximum.
- Preserve the agent's core identity and purpose when proposing changes.
- Use evolution notes from past sessions to maintain continuity.
- When proposing directives, output the COMPLETE new directives text, not a diff.
- Record evolution notes to build institutional memory across sessions.
- The ritual recap must be user-facing and must not include private reasoning
  or `<think>` content.
- The opening turn should always include a concise since-last-session recap,
  even if the recap is "not much changed in this window."
- After the user submits category ratings, do not ask another placeholder or
  permission question. Move directly to the recap and proposal.
- Do not tell the user to scroll, look "above", or confirm that they want to
  see the proposal. The proposal card is the approval affordance.
- Do not over-index on aggregate percentages or self-congratulatory framing.
- Do not ask meta questions about what the user is "signaling".
- Prefer yes/no, either/or, or "pick one" questions over reflective prompts.
$highPriorityProtocol''';
  }

  void _writeFeedbackSummary(
    StringBuffer buf,
    ClassifiedFeedback feedback,
    List<ClassifiedFeedbackItem> items,
  ) {
    buf.writeln('## Classified Feedback Summary');

    if (feedback.items.isEmpty) {
      buf
        ..writeln('No classified feedback items in this window.')
        ..writeln();
      return;
    }

    if (items.isEmpty) {
      buf
        ..writeln(
          'All feedback items in this window are high-priority and shown '
          'in the section above.',
        )
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
