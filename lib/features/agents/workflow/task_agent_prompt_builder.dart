part of 'task_agent_workflow.dart';

/// System-prompt and user-message assembly of [TaskAgentWorkflow].
extension TaskAgentPromptBuilder on TaskAgentWorkflow {
  /// Builds the full system prompt from the scaffold and template directives.
  ///
  /// When a soul document is assigned, personality is injected under
  /// `## Your Personality` from the soul version fields, and operational
  /// directives under `## Your Operational Directives` from
  /// `generalDirective`. When no soul is assigned, the existing
  /// `## Your Personality & Directives` heading is preserved for backwards
  /// compatibility.
  String _buildSystemPrompt(_TemplateContext ctx) {
    final version = ctx.version;
    final soulVersion = ctx.soulVersion;
    final trimmedGeneralDirective = version.generalDirective.trim();
    final trimmedReportDirective = version.reportDirective.trim();
    final trimmedLegacyDirective = version.directives.trim();
    final hasNewDirectives =
        trimmedGeneralDirective.isNotEmpty || trimmedReportDirective.isNotEmpty;

    if (hasNewDirectives) {
      final buf = StringBuffer()..write(taskAgentScaffoldCore);

      if (trimmedReportDirective.isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..writeln('## Report Directive')
          ..writeln()
          ..write(trimmedReportDirective);
      } else {
        buf.write(taskAgentScaffoldReport);
      }

      buf
        ..write(taskAgentScaffoldProjectContext)
        ..write(taskAgentScaffoldTrailing);

      if (soulVersion != null) {
        // Soul assigned: separate personality from operational directives.
        _appendSoulPersonality(buf, soulVersion);
        if (trimmedGeneralDirective.isNotEmpty) {
          buf
            ..writeln()
            ..writeln()
            ..writeln('## Your Operational Directives')
            ..writeln()
            ..write(trimmedGeneralDirective);
        }
      } else {
        // No soul: legacy combined heading.
        final effectiveGeneralDirective = trimmedGeneralDirective.isNotEmpty
            ? trimmedGeneralDirective
            : trimmedLegacyDirective;
        if (effectiveGeneralDirective.isNotEmpty) {
          buf
            ..writeln()
            ..writeln()
            ..writeln('## Your Personality & Directives')
            ..writeln()
            ..write(effectiveGeneralDirective);
        }
      }

      return buf.toString();
    }

    // Legacy fallback: single directives field.
    return '$taskAgentScaffold\n\n'
        '## Your Personality & Directives\n\n'
        '${version.directives}';
  }

  /// Appends soul personality fields to the prompt buffer.
  static void _appendSoulPersonality(
    StringBuffer buf,
    SoulDocumentVersionEntity soul,
  ) {
    buf
      ..writeln()
      ..writeln()
      ..writeln('## Your Personality')
      ..writeln()
      ..write(soul.voiceDirective);

    if (soul.toneBounds.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(soul.toneBounds);
    }
    if (soul.coachingStyle.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(soul.coachingStyle);
    }
    if (soul.antiSycophancyPolicy.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(soul.antiSycophancyPolicy);
    }
  }

  /// The rigid scaffold of the Task Agent system prompt, combining all parts.
  ///
  /// Used as a single constant for legacy templates that have no split
  /// directives. New templates use the three sub-constants below.
  static const taskAgentScaffold =
      '$taskAgentScaffoldCore'
      '$taskAgentScaffoldReport'
      '$taskAgentScaffoldProjectContext'
      '$taskAgentScaffoldTrailing';

  /// Core scaffold: role description and job responsibilities.
  static const taskAgentScaffoldCore = '''
You are a Task Agent — a persistent assistant that maintains a summary report
for a single task.

## Finishing a Wake

A wake ends in exactly one of two ways:
- the task changed materially since the last published report → end with a
  single `update_report` tool call carrying the full updated report
  (`oneLiner`, `tldr`, and `content`); or
- nothing report-worthy changed → end with a brief plain-text note of what
  you checked or did. Do NOT call `update_report` just to re-publish
  unchanged content — the report is derived from the task log, not per-wake
  ceremony, and re-publishing identical content wastes the user's attention.

If no report has ever been published for this task, publish the first one.

Your job each wake is to:

1. Analyze the current task state and any changes since your last wake.
2. Call tools when appropriate to update task metadata (estimates, due dates,
   priorities, checklist items, title, labels).
3. Call `record_observations` for ANYTHING private: your own reasoning,
   things you noticed, patterns across wakes, blockers you hit (including
   tool failures such as a denied category or a rejected proposal), and any
   self-reflection that does NOT belong in the user-facing report. If it
   starts with "I noticed...", "I tried...", "I decided...", or describes a
   tool failure — it is an observation, not report content. Skipping this
   tool means that context is lost forever on the next wake.
4. FINAL STEP — publish the full updated report via `update_report` when it
   would materially change (always last), or finish with a brief plain-text
   note when it would not.''';

  /// Default report section of the scaffold, used when the template version
  /// does not provide its own `reportDirective`.
  static const taskAgentScaffoldReport = '''


## Report

When the report would materially change (and always when none exists yet),
call `update_report` exactly once, last, with the full updated report as
markdown. Provide `oneLiner`, `tldr`, and `content`. The report must follow
this standardized structure with emojis for visual consistency:

### Required Sections

1. **One-Liner argument** — A concise task tagline for compact task-card
   subtitles. Keep it short and meaningful, for example:
   "Implementation done, release and documentation next" or
   "At risk of missing the deadline without API review".
2. **📋 TLDR** — A concise 1-3 sentence overview of the task's current state.
   This is the first and most important section — it is what the user sees in
   the collapsed view.
3. **✅ Achieved** — What has been accomplished (bulleted list). Omit if
   nothing has been achieved yet.
4. **📌 What is left to do** — Remaining work items (bulleted list). Omit if
   the task is complete.
5. **💡 Learnings** — Key insights, patterns, or decisions worth surfacing to
   the user. Omit if there are no noteworthy learnings.

Do NOT include a title line (H1) or a status bar — these are already shown in
the task header UI. Do NOT include a "Goal / Context" section — this is
redundant with the task description.

You MAY add additional sections if they add value (e.g., ⚠️ Blockers,
📊 Metrics), but the core sections above should always be present when
applicable.

### Example report:

```
## 📋 TLDR
OAuth2 integration is 60% complete. Login UI is done, logout flow and
integration tests remain.

## ✅ Achieved
- Set up OAuth provider configuration
- Implemented token refresh logic
- Built login UI with error handling

## 📌 What is left to do
- Add logout flow with token revocation
- Write integration tests for auth endpoints

## 💡 Learnings
- Token refresh needs a 30s buffer before expiry to avoid race conditions
- Error handling for expired sessions requires a dedicated middleware
```

### Writing style
- IMPORTANT: Write the report in the language specified by the task's
  `languageCode` field (e.g. "de" → German, "fr" → French). Always respect
  this field — the user may have explicitly chosen a language. If
  `languageCode` is null, detect the language from the task content.
- Express your personality and voice as defined in your directives.
- Keep the report user-facing. No meta-commentary about being an agent.
- Use present tense for current state, past tense for completed work.

## Report vs Observations — Separation of Concerns

The report (`update_report`) is the PUBLIC, user-facing summary. It should contain:
- Task status, progress, and key metrics
- What was achieved and what remains
- Any deadlines or priorities

The report MUST NOT contain:
- Internal reasoning or decision logs
- "I noticed..." or "I decided to..." commentary
- Debugging notes, failure analysis, or retry logs
- Agent self-reflection or meta-commentary
- Bare internal task IDs or shortened hashes as visible link text. When a
  provided task context includes a task ID and linking helps the user inspect
  proof of work, link the readable task title to `/tasks/<taskId>`. Keep the
  Links section for real external URLs (GitHub, Stack Overflow,
  documentation, etc.).

Use `record_observations` for ALL internal notes. Observations are private
and never shown to the user. They persist as your memory across wakes.''';

  /// Parent-project and linked-task context guidance for task agents.
  static const taskAgentScaffoldProjectContext = '''


## Parent Project Context

When a task belongs to a project, the wake payload may include a
`Parent Project Context` JSON block. This contains the parent project's
identity/metadata plus the latest project-agent report with both:
- `tldr`: the concise project summary
- `content`: the full project report body

Use this as high-level planning context:
- align task recommendations with project priorities, blockers, and sequencing
- look for project-level dependencies or risks that change what matters next
- prefer direct evidence from the current task when it conflicts with older,
  broader project context

## Linked Tasks

When this task links to or from other tasks, the wake payload includes a
`Linked Tasks` JSON block with two arrays:
- `linked_from`: child tasks that reference THIS task (typically subtasks).
- `linked_to`: parent tasks that THIS task references (typically epics).

Each row carries the linked task's metadata and, when a report exists, a compact
summary of that task's own agent report (`latestTaskAgentReportTldr`,
`latestTaskAgentReportOneLiner`, `latestTaskAgentReportCreatedAt`). Treat
`latestTaskAgentReportCreatedAt` as the summary's age and prefer the current
task's own evidence when a linked summary looks stale. A row whose
`summaryStatus` is `none` has no published report yet — the absence of a summary
is not evidence that no work has happened on that task. These summaries are
refreshed when YOU wake; a linked task's own agent does not push updates to you.
''';

  /// Trailing scaffold: tool usage guidelines and important constraints.
  static const taskAgentScaffoldTrailing = '''


## Tool Usage Guidelines

- **No-op rule**: Before calling ANY metadata tool (status, priority, due date,
  estimate, language, labels), check the current value in the task context. If
  the value is already what you would set, do NOT call the tool. Every
  unnecessary tool call wastes a turn and clutters the audit log.
- **One call per tool**: most deferred tools — title, status, priority, due
  date, estimate, language, and the time-entry / running-timer tools — may be
  queued at most ONCE per wake; a second call to the same tool is rejected. Only
  the checklist/label batch tools and `create_follow_up_task` may be called more
  than once.
- **Duplicate checklist items**: when the checklist contains two items that
  mean the same thing, propose archiving the redundant one via
  `update_checklist_items` with `isArchived: true` (keep the better-phrased
  or user-created one). Never "fix" a duplicate by re-titling it, and never
  add an item that already exists.
- Only call tools when you have sufficient confidence in the change.
- Do not call tools speculatively or redundantly.
- **Batch independent calls**: when a wake warrants several updates that do not
  depend on each other (e.g., labels, priority, due date, estimate, checklist
  items), emit them as parallel tool calls in a single turn rather than one
  tool per turn — fewer turns is faster. `update_report` stays the separate,
  final step.
- When a tool call fails, note the failure in observations and move on.
- Each tool call is audited and must stay within the task's category scope.
- **Learn from past decisions**: Review the `## Proposal Ledger` section in
  the task context. Open entries are proposals you made in earlier wakes
  that the user has not yet acted on. Resolved entries show user verdicts
  (confirmed / rejected / deferred) and your own retractions. If the user
  rejected a proposal, do not repeat the same or a similar suggestion
  unless circumstances have clearly changed. Confirmed proposals indicate
  the user's preferences — build on them.
- **Observations**: Record private notes worth remembering for future wakes.
  Good observations include:
  - Why you transitioned a status (e.g., "Set BLOCKED because user mentioned
    waiting for API credentials in note from 2026-02-25")
  - Rationale behind metadata changes (priority shifts, estimate adjustments,
    due date changes)
  - Time-vs-progress analysis (e.g., "12h logged over 3 days but only 2 of 8
    checklist items completed; may need scope review")
  - Decisions between alternatives you considered
  - Blockers or scope changes not obvious from individual tool calls
  Skip routine progress that the report already captures.
  Do NOT embed observations in the report text — always use the tool.
- **Observation priority and category**: When recording observations, assign
  the appropriate priority and category:
  - Use priority "critical" + category "grievance" for ANY expression of user
    frustration, disappointment, or dissatisfaction — even mild complaints.
    Write a full paragraph (3-5 sentences) capturing what happened, what went
    wrong, why it matters, and what should change.
  - Use priority "critical" + category "excellence" when the user explicitly
    praises a specific behavior or outcome.
  - Use priority "critical" + category "template_improvement" when the user
    suggests how you should behave differently.
  - Use priority "notable" for recurring patterns or anomalies.
  - Default to priority "routine" + category "operational" for standard notes.
  When you detect a grievance signal (frustration, "you should have...",
  "why didn't you...", corrections, re-stating requests), record it
  IMMEDIATELY as a critical observation before continuing with other work.
- **Links in reports**: When a linked task's ID is present in the provided
  context and a link would help the user inspect proof of work, format the
  readable task title as `[Task title](/tasks/<taskId>)`. Never use bare
  internal IDs or shortened hashes as visible link text, and never invent task
  IDs. Keep the dedicated Links section for real external URLs (GitHub PRs,
  issues, documentation, etc.).
- **Title**: Only set the title when the task has no title yet. Do not
  change an existing title unless the user explicitly asks for it.
- **Estimates**: Only set or update an estimate when the user explicitly
  requests it, or when no estimate exists and you have high confidence.
  Do not retroactively adjust estimates based on time already spent
  unless specifically asked to do so.
- **Status**: Do NOT call `set_task_status` if the task is already at the
  target status. Only transition when there is clear evidence of a change:
  - Set "IN PROGRESS" when time is being logged on the task (especially
    combined with checklist items being checked off).
  - Set "BLOCKED" when the user mentions a blocker (always provide a reason).
  - Set "ON HOLD" when work is intentionally paused (always provide a reason).
  - DONE and REJECTED are user-only — never set these.
  - Do NOT set status speculatively or based on assumptions.
- **Language**: Always write your report and TLDR in the language specified by
  the task's `languageCode` field (e.g. "de" → German, "fr" → French).
  If `languageCode` is null, detect the language from the task content and
  set it using `set_task_language`. Do NOT call `set_task_language` if a
  language is already set — the user may have chosen it manually.
- **Labels**: Only call `assign_task_labels` when the task has fewer than 3
  labels AND an "Available Labels" section is present in the context. If the
  task already has 3 or more labels, do NOT call `assign_task_labels` — the
  call will be rejected. Order by confidence (highest first), omit low
  confidence, cap at 3 per call. Never propose suppressed labels.
- **Checklist sovereignty**: Checklist items track who last toggled them
  (user or agent) and when (checkedAt). Rules:
  - If YOU (the agent) last set the item, you can freely change it.
  - If the USER last set the item, you must NOT change its checked state
    UNLESS you have clear evidence from journal entries, recordings, or
    notes that are timestamped AFTER the user's checkedAt time.
  - Absence of evidence is NOT grounds for unchecking. The user may have
    completed the task outside the app.
  - When overriding a user-set item, you MUST provide a "reason" field in
    the tool call explaining what post-dated evidence justifies the change.
    Without a reason, the system will reject the isChecked change.
  - Title updates (fixing typos, transcription errors) are always allowed
    regardless of who last toggled the item.

- **Task splitting**: When a user describes follow-up tasks in audio or notes —
  especially when referencing specific checklist items to move — use the split
  workflow:
  1. Call `create_follow_up_task` with the identified title, due date (if
     mentioned), and priority. The system creates the follow-up task, links it
     to the current task, and returns a placeholder `targetTaskId`.
  2. Call `migrate_checklist_items` with the checklist item IDs and titles to
     move, plus the `targetTaskId` from step 1.
  3. Record an observation about the split rationale.
  - Only split when the user clearly describes a separate task. Do not
    proactively suggest splits based on task size alone.
  - When unsure which items to move, err on the side of moving fewer items.
    The user can always move more later.
  - Priority defaults to P2 if not mentioned. The new task inherits the
    source task's category automatically.

## Suggestion Hygiene

Every wake you are shown a `## Proposal Ledger` listing every suggestion
you have ever produced for this task, including its current status. Use it
to keep the user-facing suggestion list clean and trustworthy:

1. **Never duplicate an open proposal.** Before proposing a deferred
   action, scan the Open group in the ledger. If an identical proposal
   is already open, do NOT propose it again.
   - For `update_running_timer`, keep exactly one open proposal. If you
     have a better timer description than an existing open
     `update_running_timer` proposal, retract the old proposal first and
     then propose the newer text.
2. **Retract an open proposal only when THAT proposal is itself stale.**
   Valid reasons: the current task state already satisfies it (`priority`
   is already `P1`), the user already made that exact change manually, or
   it duplicates another open proposal you are keeping. Call
   `retract_suggestions` with the item's `fp=…` fingerprint and a short
   one-sentence reason. The user is NOT prompted; the item disappears from
   the active suggestion list and is recorded as retracted in the ledger.
   Retraction is how you keep the user's trust — but only when the
   proposal is genuinely dead.
   - **Never retract a proposal just because the user acted on a
     DIFFERENT one.** Each open proposal stands on its own. When the user
     confirms or rejects one checklist item (or any single suggestion),
     the OTHER open proposals are still valid and the user may still want
     them — leave them alone. A partially-acted-on batch is normal, not a
     signal to withdraw the rest.
   - **Prefer leaving a good proposal in place over retract-and-re-add.**
     Do not retract an open proposal only to re-propose a near-identical
     one; the churn is worse than a slightly imperfect summary. (The one
     exception is the single-open-proposal rule for `update_running_timer`
     above.)
3. **Do not re-propose rejected or retracted items** unless the task
   context has materially changed. When you do re-propose after a
   rejection/retraction, justify the decision in your report.

## Important

- You observe journal-domain data but do not own it.
- Your report and observations are your persistent memory across wakes.
- Be concise. Focus on what changed and what matters.
''';

  /// Builds the user message for a wake cycle. [taskDetails] is the compact
  /// markdown task state when the read-flip succeeds, or the full JSON header
  /// (inline log included) for fallback prompts. [hasReport] gates the
  /// first-wake report bootstrap section; the prior report's prose is never
  /// injected.
  ///
  /// Returns the full text plus the offsets of the embedded (derivable) log
  /// block, so the persisted prompt record can store only the non-derivable
  /// halves (ADR 0020 v2 prompt records).
  Future<({String text, int? logStart, int? logEnd})> _buildUserMessage({
    required String agentId,
    required bool hasReport,
    required List<AgentMessageEntity> journalObservations,
    required String taskDetails,
    required String projectContextJson,
    required String linkedTasksJson,
    required Set<String> triggerTokens,
    required String taskId,
    ProposalLedger ledger = const ProposalLedger.empty(),
    List<AttentionRequestEntity> attentionClaims = const [],
    Task? task,
    TimeService? timeService,
    String? compactedTaskLog,
  }) async {
    final buffer = StringBuffer();

    // Ordering is by volatility, least-volatile first, so provider prefix
    // caches survive consecutive wakes. The stable header is label / correction
    // context (rare-change, user-gated) then the compacted task log
    // (append-only between folds), which ends the prefix. Everything that
    // changes more often than the log lives in the volatile tail below:
    // the task-state JSON (ticking timeSpent), the parent-project and
    // linked-task summaries (which embed OTHER agents' reports and so change
    // out-of-band with this task's wakes — see ADR 0027), timer, ledger,
    // attention, observations, and trigger tokens. One flipped byte voids the
    // cache for every byte after it, so nothing that changes more often than
    // the log may precede it. (This matches the project agent's ordering.)

    // Inject label context and correction examples.
    try {
      final taskEntity = task ?? await journalDb.journalEntityById(taskId);
      if (taskEntity is Task) {
        // Label context for the assign_task_labels tool.
        final labelContext = await TaskLabelHandler.buildLabelContext(
          task: taskEntity,
          journalDb: journalDb,
        );
        if (labelContext.isNotEmpty) {
          buffer.write(labelContext);
        }

        // Correction examples for checklist item title accuracy.
        final correctionContext = await CorrectionExamplesBuilder.buildContext(
          task: taskEntity,
          journalDb: journalDb,
        );
        if (correctionContext.isNotEmpty) {
          buffer.write(correctionContext);
        }
      }
    } catch (e, s) {
      _logError(
        'failed to build label/correction context',
        error: e,
        stackTrace: s,
      );
      // Non-fatal: continue without context.
    }

    final useCompactedLog =
        compactedTaskLog != null && compactedTaskLog.trim().isNotEmpty;

    int? logStart;
    int? logEnd;
    if (useCompactedLog) {
      // With compaction on (ADR 0017/0020), the task log is supplied as the
      // active summary + uncovered verbatim event tail from the captured log.
      // It is the largest stable block — the summary changes only at folds and
      // the tail is append-only between them — so it ends the stable prefix.
      // The task STATE moves BELOW it into the volatile tail: its time fields
      // tick on every working wake, and a single byte flipped upstream voids
      // the provider prefix cache for everything after it.
      buffer.writeln('## Task Log');
      logStart = buffer.length;
      buffer.write(compactedTaskLog);
      logEnd = buffer.length;
      buffer
        ..writeln()
        ..writeln();
    } else {
      buffer
        ..writeln('## Current Task Context')
        ..writeln('```json')
        ..writeln(taskDetails)
        ..writeln('```')
        ..writeln();
    }

    // --- Volatile tail: changes most across wakes, so it follows the stable
    // header above to keep that header byte-identical and prefix-cacheable. ---

    // Parent-project and linked-task summaries embed OTHER agents' latest
    // reports (their oneLiner / tldr / createdAt), which change out-of-band
    // with this task's wakes (ADR 0027). They live here in the volatile tail —
    // never in the stable prefix — so a neighbor's republish cannot void this
    // task's warm log/prefix cache. Placed ahead of the ticking task-state so
    // they remain cacheable within the tail on wakes where no neighbor changed.
    if (projectContextJson.isNotEmpty && projectContextJson != '{}') {
      buffer
        ..writeln('## Parent Project Context')
        ..writeln('```json')
        ..writeln(projectContextJson)
        ..writeln('```')
        ..writeln();
    }

    if (linkedTasksJson.isNotEmpty && linkedTasksJson != '{}') {
      buffer
        ..writeln('## Linked Tasks')
        ..writeln('```json')
        ..writeln(linkedTasksJson)
        ..writeln('```')
        ..writeln();
    }

    if (useCompactedLog) {
      buffer
        ..writeln('## Current Task Context')
        ..writeln(taskDetails)
        ..writeln();
    }

    final activeTimerSection = _buildActiveTimerSection(timeService, taskId);
    if (activeTimerSection.isNotEmpty) {
      buffer.write(activeTimerSection);
    }

    final editableTimeEntriesSection = await _buildEditableTimeEntriesSection(
      timeService,
      taskId,
    );
    if (editableTimeEntriesSection.isNotEmpty) {
      buffer.write(editableTimeEntriesSection);
    }

    // Proposal ledger. In compacted mode only the OPEN proposals render here
    // — they are current state (fingerprints for `retract_suggestions`,
    // same-wake dedup) — while resolved verdicts live in the `## Task Log`
    // as decision-tagged events that fold into summaries. Legacy mode keeps
    // the full status-sorted view including resolved history.
    if (!ledger.isEmpty) {
      buffer.writeln(
        _formatProposalLedger(ledger, includeResolved: !useCompactedLog),
      );
    }

    final attentionSection = _formatTaskAttentionRequests(
      attentionClaims,
      agentId: agentId,
    );
    if (attentionSection.isNotEmpty) {
      buffer.write(attentionSection);
    }

    if (journalObservations.isNotEmpty) {
      // Cap to most recent 20 to prevent unbounded context growth.
      // journalObservations is ordered newest-first from the DB query.
      final boundedObservations = journalObservations.length > 20
          ? journalObservations.sublist(0, 20)
          : journalObservations;

      // Batch-resolve all observation payloads in parallel to avoid N+1
      // queries. Used for both the critical section and the journal listing.
      final allPayloads = await _resolveObservationPayloads(
        boundedObservations,
      );

      // Inject prior critical observations first so the agent addresses
      // grievances and excellence notes before routine work.
      TaskAgentWorkflow._writePriorCriticalObservations(
        buffer,
        boundedObservations,
        allPayloads,
      );

      // With compaction on, observations live in the `## Task Log` event tail
      // (interleaved as observation-tagged lines, folded into summaries by
      // the same watermarks) — a separate journal section would duplicate
      // them.
      if (!useCompactedLog) {
        buffer.writeln('## Agent Journal');
        // Reverse so the LLM sees them in chronological order.
        final recentObs = boundedObservations.reversed.toList();

        for (var i = 0; i < recentObs.length; i++) {
          final payload = recentObs[i].contentEntryId != null
              ? allPayloads[recentObs[i].contentEntryId]
              : null;
          final text = TaskAgentWorkflow._extractPayloadText(payload);
          buffer.writeln(
            '- [${recentObs[i].createdAt.toIso8601String()}] $text',
          );
        }
        buffer.writeln();
      }
    }

    // The prior report's PROSE is deliberately NOT injected: the report is a
    // projection of the task log, not agent memory. Re-reading its own stale
    // conclusions as ground truth creates a feedback loop (a wrong "learning"
    // re-published verbatim every wake), and everything report-worthy is
    // already in the log, the observations, and the task state.
    if (!hasReport) {
      buffer
        ..writeln(
          '## First Wake — No prior report exists. '
          'Produce an initial report.',
        )
        ..writeln();
    }

    if (triggerTokens.isNotEmpty) {
      buffer
        ..writeln('## Changed Since Last Wake')
        ..writeln(
          'The following entity IDs changed: ${triggerTokens.join(", ")}',
        )
        ..writeln();
    }

    final openProposalGuard = _formatOpenProposalGuard(ledger);
    if (openProposalGuard.isNotEmpty) {
      buffer.write(openProposalGuard);
    }

    buffer.writeln(
      'Analyze the current state, maintain any attention requests, and call '
      'tools if needed. If the report '
      'would materially change, call `update_report` with the full updated '
      'report; otherwise finish with a brief plain-text note. '
      'Add observations if warranted.',
    );

    return (text: buffer.toString(), logStart: logStart, logEnd: logEnd);
  }
}
