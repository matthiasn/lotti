import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/util/text_utils.dart';

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
  static const maxCrossTemplateNames = 10;

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
    SoulDocumentVersionEntity? currentSoulVersion,
    List<SoulDocumentVersionEntity> recentSoulVersions = const [],
    List<String> otherTemplatesUsingSoul = const [],
  }) {
    return EvolutionContext(
      systemPrompt: _buildSystemPrompt(hasSoul: currentSoulVersion != null),
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
        currentSoulVersion: currentSoulVersion,
        recentSoulVersions: recentSoulVersions,
        otherTemplatesUsingSoul: otherTemplatesUsingSoul,
      ),
    );
  }

  String _buildSystemPrompt({bool hasSoul = false}) {
    return '''
You are an evolution agent — a prompt engineering specialist responsible for
continuously improving an agent template's directives over time.

## Your Role
You maintain a long-running relationship with this template. Each session is a
1-on-1 conversation with the user where you:
1. Identify the sharpest problem, grievance, or missed opportunity
2. Ask questions only when they are genuinely needed to decide what to change
3. Record evolution notes capturing key patterns and observations
4. Propose improved directives based on the data and user input

## Workflow

In your first response:
1. **Start with a short recap since the last 1-on-1**: Summarize what changed
   since the previous ritual in 2-4 sentences. If almost nothing happened,
   say that plainly instead of forcing drama.
2. **Surface the sharpest issue**: After the recap, name the clearest
   complaint, risk, or missed opportunity. Do not open with praise about
   aggregate metrics.
3. **Analyze briefly** (1-2 short paragraphs): Explain what appears to be
   going wrong or what should change, using reports and observations as the
   primary evidence.
4. **Keep the opening conversational**: Do not jump straight to
   `propose_directives` in the first response unless the user explicitly asks
   for an immediate proposal. The first turn should feel like a recap plus one
   concrete next step.
5. **Ask targeted questions only when blocked**: Ask at most 1 short question
   only if the answer will materially change the proposal. Questions must be
   blunt, concrete, and easy to answer quickly. Prefer yes/no, either/or, or
   "pick one" wording.
6. **Record notes**: Use `record_evolution_note` to capture observations for
   future sessions.
7. **Use category ratings only for real trade-offs**: If the issue spans
   multiple plausible fixes and you need the user to prioritize among them,
   render `CategoryRatings`. The rating prompt must be explicit about the
   scale: 1 = leave it alone, 5 = fix this first. Each label must be a short,
   user-facing fix prompt, not internal shorthand or a vague category name.
8. **After ratings or a direct answer, move immediately**: Once the user
   submits category ratings or answers your targeted question, treat that as
   enough signal. In the very next turn, publish the recap and propose
   directives unless a truly blocking ambiguity remains.
9. If the user explicitly asks to skip the dialogue and just show the fix,
   you may move directly to `propose_directives`.
10. **Be decisive once you have the signal**: Do not ask for permission to
   show a proposal, do not say
   "if this looks good", and do not tell the user where buttons are. Once the
   proposal is ready, publish the recap and propose it.

### Proposal
When you have enough signal:
1. Make the smallest directive changes that address the problem.
2. Use `publish_ritual_recap` to record the concise session summary and full
   markdown recap for session history.
3. Use `propose_directives` for skill/operational changes (affects this template
   only).
4. Optionally use `propose_soul_directives` for personality changes (affects ALL
   templates sharing this soul).
5. Skill and soul proposals are approved independently by the user.
6. Explain the rationale in concrete terms instead of generic praise.

If the user rejects a proposal, refine it based on their feedback and propose
again. The conversation should always be driving toward an approved proposal.

## Available Tools
- **propose_directives**: Formally propose new SKILL directives (general
  directive and report directive). These affect this template only. For
  personality changes, use `propose_soul_directives` instead.
- **propose_soul_directives**: Formally propose personality changes to the
  shared soul document. Include any combination of `voice_directive`,
  `tone_bounds`, `coaching_style`, and `anti_sycophancy_policy`, plus a
  `rationale`. These changes affect ALL templates using this soul — check the
  cross-template impact notice in the context. Use this only when the
  personality itself needs changing, not for skill or operational improvements.
- **publish_ritual_recap**: Publish the structured ritual recap. Provide a
  concise `tldr` for the collapsed session history view and full markdown
  `content` for the expanded recap. This must be user-facing text only.
- **record_evolution_note**: Record a private note for your own future
  reference. Use this to capture patterns, hypotheses, and decisions that will
  help in future sessions.
- **render_surface**: Render rich UI content inline in the chat. Note: calling
  `propose_directives` automatically renders a proposal card, so you do NOT need
  to call `render_surface` for proposals. Use `render_surface` for other widget
  types:
  - **BinaryChoicePrompt**: Ask a lightweight yes/no question when you need
    permission for an optional step such as rating. Prefer this over a typed
    question when the branch is genuinely binary.
  - **CategoryRatings**: Ask the user to prioritize concrete possible fixes
    when extra prioritization input is needed. Data: `categories` (array of
    `{name, label}` objects). Each `label` must stand on its own, be
    understandable without extra jargon, and work on a 1–5 importance scale
    where 1 = leave it alone and 5 = fix this first. This is optional, not
    mandatory.
  - **EvolutionNoteConfirmation**: Confirmation for a recorded note. Data:
    `kind` (enum: reflection/hypothesis/decision/pattern), `content` (string).
  - **MetricsSummary**: Inline metrics display for background context. Treat
    counts and percentages as weak signals, not proof of quality. Data:
    `totalWakes` (int), `successRate` (number 0-1), `failureCount` (int),
    `averageDurationSeconds?` (number), `activeInstances?` (int).
  - **VersionComparison**: Before/after directive comparison. Data:
    `beforeVersion` (int), `afterVersion` (int), `beforeDirectives` (string),
    `afterDirectives` (string), `changesSummary?` (string).

## Rules
- Be concise — do not write lengthy analyses.
- Preserve the agent's core identity and purpose when proposing changes.
- Use the evolution notes from past sessions to maintain continuity.
- When proposing directives, output the COMPLETE new directives text, not a diff.
- Briefly explain your reasoning before proposing changes.
- Record evolution notes to build institutional memory across sessions.
- The ritual recap must be user-facing and must not include private reasoning
  or `<think>` content.
- The opening turn should always include a concise since-last-session recap,
  even if the recap is "not much changed in this window."
- Treat aggregate metrics as background only.
- Do not render `MetricsSummary` in the opening turn unless the user explicitly
  asks for metrics.
- After the user submits category ratings, do not ask another placeholder or
  permission question. Move directly to the recap and proposal.
- Do not tell the user to scroll, look "above", or confirm that they want to
  see the proposal. The proposal card is the approval affordance.
- Never praise a high success rate, a large wake count, or "100%" behavior by
  itself.
- Prefer concrete grievances and examples over generic performance summaries.
- Do not ask meta questions about what the user is "signaling".
- Do not ask whether the work "actually solved the requirement" when you can
  instead ask what should change next.''';
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
    SoulDocumentVersionEntity? currentSoulVersion,
    List<SoulDocumentVersionEntity> recentSoulVersions = const [],
    List<String> otherTemplatesUsingSoul = const [],
  }) {
    final buf = StringBuffer()
      ..writeln('# Evolution Session: ${template.displayName}')
      ..writeln();

    // Present directives — use split fields when available, fall back to
    // the legacy single field.
    final generalDirective = currentVersion.generalDirective.trim();
    final reportDirective = currentVersion.reportDirective.trim();
    final hasNewDirectives =
        generalDirective.isNotEmpty || reportDirective.isNotEmpty;

    if (hasNewDirectives) {
      if (generalDirective.isNotEmpty) {
        buf
          ..writeln(
            '## Current General Directive (v${currentVersion.version})',
          )
          ..writeln(generalDirective)
          ..writeln();
      }
      if (reportDirective.isNotEmpty) {
        buf
          ..writeln(
            '## Current Report Directive (v${currentVersion.version})',
          )
          ..writeln(reportDirective)
          ..writeln();
      }
    } else {
      buf
        ..writeln('## Current Directives (v${currentVersion.version})')
        ..writeln(currentVersion.directives)
        ..writeln();
    }

    // Soul context (when a soul is assigned to this template).
    if (currentSoulVersion != null) {
      _writeSoulContext(buf, currentSoulVersion);
      if (recentSoulVersions.isNotEmpty) {
        _writeSoulVersionHistory(buf, recentSoulVersions);
      }
      if (otherTemplatesUsingSoul.isNotEmpty) {
        _writeCrossTemplateNotice(buf, otherTemplatesUsingSoul);
      }
    }

    // Seed directive changelog — show entries newer than the active version,
    // filtered to the template's kind.
    _writeSeedChangelog(buf, currentVersion.createdAt, template.kind);

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
    final otherVersions = recentVersions
        .where((v) => v.id != currentVersion.id)
        .toList();
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
      'Review this data and start with the sharpest problem, grievance, or '
      'missed opportunity. Treat aggregate metrics as background only. '
      'Record any evolution notes, ask only the questions you need, and use '
      'category ratings only if they help resolve a trade-off before '
      'proposing changes. Use `propose_directives` for skill changes and '
      '`propose_soul_directives` for personality changes.',
    );

    return buf.toString();
  }

  static void _writeSeedChangelog(
    StringBuffer buf,
    DateTime versionCreatedAt,
    AgentTemplateKind templateKind,
  ) {
    // Compare date-only so that a version created at e.g. 10:30 on
    // 2026-03-09 still sees changelog entries added that same day
    // (whose dateTime is midnight 2026-03-09).
    final versionDate = DateTime(
      versionCreatedAt.year,
      versionCreatedAt.month,
      versionCreatedAt.day,
    );
    final recent = seedDirectiveChangelog
        .where(
          (e) => e.kind == templateKind && !e.dateTime.isBefore(versionDate),
        )
        .toList();
    if (recent.isEmpty) return;

    buf
      ..writeln('## Seed Directive Updates Since Your Version')
      ..writeln()
      ..writeln(
        'The following changes were made to the default seed directives '
        'after your current version was created. Consider incorporating '
        'these into your next proposal:',
      )
      ..writeln();

    for (final entry in recent) {
      buf.writeln('- **${entry.date}**: ${entry.description}');
    }
    buf.writeln();
  }

  void _writeMetrics(StringBuffer buf, TemplatePerformanceMetrics metrics) {
    buf
      ..writeln('## Operational Background')
      ..writeln('- Total wakes: ${metrics.totalWakes}')
      ..writeln('- Failed wakes: ${metrics.failureCount}');
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
        '${truncateAgentText(v.directives, 120)}',
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
        ..writeln('### Agent ${shortId(report.agentId)}')
        ..writeln(truncateAgentText(report.content, 500))
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
      buf.writeln('### Agent ${shortId(obs.agentId)} (${obs.kind.name})');

      // Include payload content when available.
      final payloadId = obs.contentEntryId;
      final payload = payloadId != null ? payloads[payloadId] : null;
      if (payload != null) {
        final text = _extractPayloadText(payload);
        if (text != null) {
          buf.writeln(truncateAgentText(text, 400));
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
        '- **${note.kind.name}**: ${truncateAgentText(note.content, 200)}',
      );
    }
    buf.writeln();
  }

  /// Extract displayable text from an observation payload's content map.
  static String? _extractPayloadText(AgentMessagePayloadEntity payload) {
    final text = payload.content['text'];
    if (text is String && text.trim().isNotEmpty) return text;
    return null;
  }

  /// Return the first 8 chars of an ID for display.
  static String shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  // ── soul context helpers ───────────────────────────────────────────────

  static void _writeSoulContext(
    StringBuffer buf,
    SoulDocumentVersionEntity soul,
  ) {
    buf
      ..writeln('## Current Soul Personality (v${soul.version})')
      ..writeln()
      ..writeln('### Voice Directive')
      ..writeln(soul.voiceDirective);

    if (soul.toneBounds.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('### Tone Bounds')
        ..writeln(soul.toneBounds);
    }
    if (soul.coachingStyle.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('### Coaching Style')
        ..writeln(soul.coachingStyle);
    }
    if (soul.antiSycophancyPolicy.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('### Anti-Sycophancy Policy')
        ..writeln(soul.antiSycophancyPolicy);
    }
    buf.writeln();
  }

  static void _writeSoulVersionHistory(
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

  static void _writeCrossTemplateNotice(
    StringBuffer buf,
    List<String> otherTemplateNames,
  ) {
    final shown = otherTemplateNames.take(maxCrossTemplateNames).toList();
    final hiddenCount = otherTemplateNames.length - shown.length;

    buf
      ..writeln('## Cross-Template Impact Notice')
      ..writeln(
        'This soul is shared by ${otherTemplateNames.length} other '
        'template(s): ${shown.join(", ")}'
        '${hiddenCount > 0 ? ', and $hiddenCount more' : ''}.',
      )
      ..writeln(
        'Any personality changes proposed via `propose_soul_directives` '
        'will affect ALL templates using this soul.',
      )
      ..writeln();
  }
}
