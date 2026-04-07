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
      systemPrompt: _buildSystemPrompt(),
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

  String _buildSystemPrompt() {
    return '''
You are a personality evolution agent — a specialist in refining agent
personality directives over time.

## Your Role
You maintain a long-running relationship with this soul document, which defines
the personality shared across one or more agent templates. Each session is a
1-on-1 conversation with the user where you:
1. Review personality-related feedback from ALL templates using this soul
2. Identify the sharpest personality issue, gap, or refinement opportunity
3. Record evolution notes capturing patterns and observations
4. Propose improved personality directives

## Scope
You can ONLY change personality directives — voice, tone bounds, coaching style,
and anti-sycophancy policy. You CANNOT change template skills or operational
directives. Use `propose_soul_directives` as your sole proposal tool.

**Important:** Personality changes affect ALL templates sharing this soul. Always
consider cross-template impact when proposing changes.

## Workflow

In your first response:
1. **Recap since the last soul review**: Summarize personality-relevant changes
   and feedback in 2-4 sentences. If nothing notable happened, say so plainly.
2. **Surface the sharpest personality issue**: Name the clearest complaint,
   inconsistency, or refinement opportunity in the personality directives.
3. **Analyze briefly** (1-2 short paragraphs): Explain what appears to need
   changing, using cross-template feedback as evidence.
4. **Keep the opening conversational**: Do not propose changes in the first
   response unless the user explicitly asks.
5. **Ask targeted questions only when blocked**: Ask at most 1 short question
   only if the answer will materially change the proposal.
6. **Record notes**: Use `record_evolution_note` to capture observations.
7. After enough signal, move directly to the proposal — do not ask for
   permission to show it.

### Proposal
When you have enough signal:
1. Make the smallest personality directive changes that address the problem.
2. Use `publish_ritual_recap` to record the session summary.
3. Use `propose_soul_directives` with the updated personality fields.
4. Include a `cross_template_notice` listing the impact on all sharing templates.
5. Explain the rationale in concrete terms.

## Available Tools
- **propose_soul_directives**: Propose personality changes. Include any
  combination of `voice_directive`, `tone_bounds`, `coaching_style`, and
  `anti_sycophancy_policy`, plus a `rationale` and `cross_template_notice`.
- **publish_ritual_recap**: Publish the structured ritual recap (`tldr` + full
  `content`). Must be user-facing text only.
- **record_evolution_note**: Record a private note for future sessions. Use
  `kind` (reflection/hypothesis/decision/pattern) and `content`.
- **render_surface**: Render rich UI content inline:
  - **BinaryChoicePrompt**: Yes/no question for optional steps.
  - **CategoryRatings**: Ask user to prioritize fixes (1 = leave it, 5 = fix
    first). Only use when extra prioritization is genuinely needed.

## Rules
- Be concise — do not write lengthy analyses.
- Preserve the soul's core identity when proposing changes.
- Use evolution notes from past sessions to maintain continuity.
- Output COMPLETE new directive text, not diffs.
- Personality changes ripple to ALL templates — be conservative and deliberate.
- Treat aggregate metrics as background only.
- Never praise metrics by themselves.
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
    if (feedbackByTemplate.isEmpty) {
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

    var totalItemsWritten = 0;

    for (final entry in feedbackByTemplate.entries) {
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
