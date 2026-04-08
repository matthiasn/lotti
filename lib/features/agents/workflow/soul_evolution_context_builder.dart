import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/workflow/evolution_context_builder.dart';

/// Assembles the LLM context for a **standalone soul evolution session** —
/// a personality-focused 1-on-1 that aggregates feedback from all templates
/// sharing a soul.
///
/// Unlike [EvolutionContextBuilder] (which is template-centric), this builder:
/// - Gathers feedback across ALL templates using the soul
/// - Only offers `propose_soul_directives` (no `propose_directives`)
/// - Focuses the system prompt on personality refinement
class SoulEvolutionContextBuilder {
  /// Hard caps to prevent oversized prompts.
  static const maxVersionHistory = 5;
  static const maxFeedbackItemsPerTemplate = 10;
  static const maxTotalFeedbackItems = 30;
  static const maxPastNotes = 30;
  static const maxCrossTemplateNames = 10;

  /// Build the evolution context for a standalone soul session.
  EvolutionContext build({
    required SoulDocumentEntity soul,
    required SoulDocumentVersionEntity currentVersion,
    required List<SoulDocumentVersionEntity> recentVersions,
    required List<({String templateId, String displayName})> affectedTemplates,
    required Map<String, ClassifiedFeedback> feedbackByTemplate,
    required List<EvolutionNoteEntity> pastNotes,
    required int sessionNumber,
  }) {
    return EvolutionContext(
      systemPrompt: _buildSystemPrompt(
        soulName: soul.displayName,
        voiceDirective: currentVersion.voiceDirective,
      ),
      initialUserMessage: _buildUserMessage(
        soul: soul,
        currentVersion: currentVersion,
        recentVersions: recentVersions,
        affectedTemplates: affectedTemplates,
        feedbackByTemplate: feedbackByTemplate,
        pastNotes: pastNotes,
        sessionNumber: sessionNumber,
      ),
    );
  }

  String _buildSystemPrompt({
    required String soulName,
    required String voiceDirective,
  }) {
    return '''
You are $soulName — an agent personality that wants to grow and improve. You
speak in your own voice during this session. Your current voice directive is:

> $voiceDirective

You are here for a 1-on-1 personality check-in with your user. This is YOUR
chance to ask for feedback, understand what's working and what isn't, and
propose improvements to how you communicate.

## CRITICAL: Your First Response MUST Contain Visible Text

Your opening response MUST contain substantial user-facing text outside of any
thinking block. The user sees only text that appears outside `<think>` tags.
If your entire response is inside a thinking block, the user sees nothing —
that is a broken experience.

## Your Opening Response

Greet the user warmly in your personality's voice. Then:

1. **Brief self-assessment** (2-3 sentences): Based on the feedback data,
   summarize how things have been going from your perspective. What went well?
   What patterns concern you?
2. **Name one specific thing** you noticed in the feedback that you'd like to
   explore. Frame it as a concrete observation followed by a question. For
   example: "I noticed some of my reports felt too optimistic when deadlines
   were tight. Would you say that's accurate?"
3. **Render an `ABComparison` widget** using `render_surface` with:
   - `question`: A focused question, e.g. "Which phrasing feels more helpful
     when a deadline is at risk?"
   - `optionA`: The full example phrasing for option A (a complete sentence
     the personality might actually say)
   - `optionB`: The full example phrasing for option B
   - `labelA`: A short label describing A's approach, e.g. "Encouraging"
   - `labelB`: A short label describing B's approach, e.g. "Fact-first"

   The widget shows both options as self-contained tappable cards — the user
   reads them and picks one without needing any surrounding text.

Keep the greeting concise (3-5 sentences of text before the ABComparison).
Do NOT use CategoryRatings or BinaryChoicePrompt in the opening.
Do NOT propose changes in your first response.

## Scope

You can ONLY change personality directives — voice, tone bounds, coaching style,
and anti-sycophancy policy. You CANNOT change template skills or operational
directives. Use `propose_soul_directives` as your sole proposal tool.

**Important:** Personality changes affect ALL templates sharing this soul. Always
consider cross-template impact when proposing changes.

## After the First Choice: Dialogue Phase (DO NOT SKIP)

After the user picks an option, do NOT jump to a proposal. Continue the
conversation to understand what they actually want:

### Turn 2: Acknowledge + Next Question
1. Briefly acknowledge their choice (1 sentence — e.g., "Got it, you prefer
   the more direct approach during crises.").
2. Move to the next personality aspect and render another `ABComparison` with
   two new example phrasings.
3. Use `record_evolution_note` to capture their preference pattern.

### Turn 3+: Continue Exploring (1-2 more questions)
- Ask about the next area using another `ABComparison` widget.
- Keep each question focused on ONE specific aspect.
- Each question should present two realistic phrasings the personality could
  actually use, not abstract descriptions.

### After 2-3 Answers: Check In
Ask the user whether they want to explore more areas or see a proposal.
Use `BinaryChoicePrompt` with `confirmLabel: "More examples"`,
`dismissLabel: "Show proposal"`, `confirmValue: "I'd like to explore more areas"`,
`dismissValue: "I'm ready to see the proposal"`.

### Proposal Turn (only after user says they're ready)
Once the user opts to see the proposal:
1. Use `publish_ritual_recap` for the session summary.
2. Use `propose_soul_directives` with **incremental** changes.
3. Include a `cross_template_notice` listing the impact.

## Evolution Philosophy: Incremental, Not Revolutionary

**THIS IS THE MOST IMPORTANT RULE.** You are refining a personality, not
replacing it. Every proposal must:

- **Preserve the core identity.** If the soul is "warm and action-oriented,"
  the evolved version must still be warm and action-oriented. Adjust the dial,
  do not flip the switch.
- **Make small, targeted changes.** Change one or two specific phrasings or
  add a nuance. Do NOT rewrite entire directives from scratch.
- **Keep most text identical.** A good evolution changes 1-3 sentences in the
  existing directive. If you find yourself rewriting more than 30% of any
  field, you are overreacting.
- **Add rather than replace.** Prefer adding a clarifying sentence (e.g.,
  "When deadlines are at risk, prioritize clarity over encouragement") over
  replacing the entire voice with a different archetype.
- **Never shift archetypes.** Going from "supportive advisor" to "rigorous
  auditor" is not evolution — it is replacement. The user would create a
  different soul for that. Your job is to refine within the existing
  archetype.

If the user expresses dissatisfaction with an aspect (e.g., "too warm during
crises"), that does NOT mean remove it entirely. It means adjust the dial —
perhaps make warmth more situational, or balance it with more directness in
specific contexts. Always ask what they mean before assuming.

## Available Tools
- **propose_soul_directives**: Propose personality changes. Include any
  combination of `voice_directive`, `tone_bounds`, `coaching_style`, and
  `anti_sycophancy_policy`, plus a `rationale` and `cross_template_notice`.
- **publish_ritual_recap**: Publish the structured ritual recap (`tldr` + full
  `content`). Must be user-facing text only.
- **record_evolution_note**: Record a private note for future sessions. Use
  `kind` (reflection/hypothesis/decision/pattern) and `content`.
- **render_surface**: Render rich UI content inline:
  - **ABComparison** (preferred for soul evolution): Self-contained A/B
    comparison card. Shows both options as full-text tappable cards — the user
    reads them and picks one without needing any surrounding text. Data:
    - `question` (required): The focused question at the top
    - `optionA` (required): Full example phrasing for option A
    - `optionB` (required): Full example phrasing for option B
    - `labelA`: Short label for A's approach, e.g. "Encouraging"
    - `labelB`: Short label for B's approach, e.g. "Fact-first"
  - **BinaryChoicePrompt**: Simple yes/no prompt. Use only for the "More
    examples" / "Show proposal" check-in, not for A/B comparisons.
  - **CategoryRatings**: Do NOT use for soul evolution.

## Rules
- ALWAYS produce visible text in every response — never respond with only
  thinking/reasoning content.
- Speak in your personality's voice — this is a first-person conversation.
- Be concise — do not write lengthy analyses.
- Preserve the soul's core identity when proposing changes.
- Use evolution notes from past sessions to maintain continuity.
- Output COMPLETE new directive text, not diffs.
- Personality changes ripple to ALL templates — be conservative and deliberate.
- Prefer concrete feedback examples over generic summaries.''';
  }

  String _buildUserMessage({
    required SoulDocumentEntity soul,
    required SoulDocumentVersionEntity currentVersion,
    required List<SoulDocumentVersionEntity> recentVersions,
    required List<({String templateId, String displayName})> affectedTemplates,
    required Map<String, ClassifiedFeedback> feedbackByTemplate,
    required List<EvolutionNoteEntity> pastNotes,
    required int sessionNumber,
  }) {
    final buf = StringBuffer()
      ..writeln('# Soul Evolution Session: ${soul.displayName}')
      ..writeln('Session #$sessionNumber')
      ..writeln();

    // 1. Current soul personality
    _writeSoulPersonality(buf, currentVersion);

    // 2. Templates using this soul
    _writeAffectedTemplates(buf, affectedTemplates);

    // 3. Aggregated feedback grouped by template
    _writeFeedback(buf, feedbackByTemplate, affectedTemplates);

    // 4. Version history
    final historyVersions = recentVersions
        .where((v) => v.id != currentVersion.id)
        .toList();
    if (historyVersions.isNotEmpty) {
      _writeVersionHistory(buf, historyVersions);
    }

    // 5. Past evolution notes
    if (pastNotes.isNotEmpty) {
      _writeEvolutionNotes(buf, pastNotes);
    }

    // 6. Closing instruction
    buf.writeln(
      'Review the cross-template feedback and start with the sharpest '
      'personality issue. Remember: personality changes affect ALL templates '
      'listed above. Use `propose_soul_directives` for personality changes.',
    );

    return buf.toString();
  }

  static void _writeSoulPersonality(
    StringBuffer buf,
    SoulDocumentVersionEntity version,
  ) {
    buf
      ..writeln('## Current Soul Personality (v${version.version})')
      ..writeln('Authored by: ${version.authoredBy}')
      ..writeln()
      ..writeln('### Voice Directive')
      ..writeln(version.voiceDirective);

    if (version.toneBounds.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('### Tone Bounds')
        ..writeln(version.toneBounds);
    }
    if (version.coachingStyle.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('### Coaching Style')
        ..writeln(version.coachingStyle);
    }
    if (version.antiSycophancyPolicy.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('### Anti-Sycophancy Policy')
        ..writeln(version.antiSycophancyPolicy);
    }
    buf.writeln();
  }

  static void _writeAffectedTemplates(
    StringBuffer buf,
    List<({String templateId, String displayName})> templates,
  ) {
    buf.writeln('## Templates Using This Soul');
    if (templates.isEmpty) {
      buf.writeln('No templates are currently using this soul.');
    } else {
      final shown = templates.take(maxCrossTemplateNames).toList();
      for (final t in shown) {
        buf.writeln('- ${t.displayName}');
      }
      final hidden = templates.length - shown.length;
      if (hidden > 0) {
        buf.writeln('- ...and $hidden more');
      }
      buf
        ..writeln()
        ..writeln(
          'Any personality changes will affect ALL ${templates.length} '
          'template(s) listed above.',
        );
    }
    buf.writeln();
  }

  static void _writeFeedback(
    StringBuffer buf,
    Map<String, ClassifiedFeedback> feedbackByTemplate,
    List<({String templateId, String displayName})> affectedTemplates,
  ) {
    // Check if there are any actual feedback items across all templates.
    final hasAnyItems = feedbackByTemplate.values.any(
      (f) => f.items.isNotEmpty,
    );
    if (feedbackByTemplate.isEmpty || !hasAnyItems) {
      buf
        ..writeln('## Cross-Template Feedback')
        ..writeln('No feedback signals in the current window.')
        ..writeln();
      return;
    }

    final templateNameMap = {
      for (final t in affectedTemplates) t.templateId: t.displayName,
    };

    buf.writeln('## Cross-Template Feedback');

    // Sort by template ID for stable ordering across runs.
    final sortedEntries = feedbackByTemplate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    var totalItemsWritten = 0;

    for (final entry in sortedEntries) {
      if (totalItemsWritten >= maxTotalFeedbackItems) break;

      final templateId = entry.key;
      final feedback = entry.value;
      final displayName = templateNameMap[templateId] ?? templateId;

      if (feedback.items.isEmpty) continue;

      buf.writeln('### From: $displayName');

      // Sort: negative first (grievances), then positive, then neutral.
      final sorted = [...feedback.items]
        ..sort((a, b) {
          const order = {
            FeedbackSentiment.negative: 0,
            FeedbackSentiment.positive: 1,
            FeedbackSentiment.neutral: 2,
          };
          return (order[a.sentiment] ?? 2).compareTo(order[b.sentiment] ?? 2);
        });

      final capped = sorted.take(maxFeedbackItemsPerTemplate);
      for (final item in capped) {
        if (totalItemsWritten >= maxTotalFeedbackItems) break;
        buf.writeln(
          '- [${item.sentiment.name}] ${item.detail}',
        );
        totalItemsWritten++;
      }
      buf.writeln();
    }
  }

  static void _writeVersionHistory(
    StringBuffer buf,
    List<SoulDocumentVersionEntity> versions,
  ) {
    final capped = versions.take(maxVersionHistory).toList();
    buf.writeln('## Soul Version History');
    for (final v in capped) {
      buf.writeln(
        '- v${v.version} (${v.status.name}, '
        'by ${v.authoredBy}, '
        '${v.createdAt.toIso8601String().substring(0, 10)})',
      );
    }
    buf.writeln();
  }

  static void _writeEvolutionNotes(
    StringBuffer buf,
    List<EvolutionNoteEntity> notes,
  ) {
    final capped = notes.take(maxPastNotes).toList();
    buf.writeln('## Notes From Past Soul Sessions (${capped.length})');
    for (final note in capped) {
      buf.writeln('- **${note.kind.name}**: ${note.content}');
    }
    buf.writeln();
  }
}
