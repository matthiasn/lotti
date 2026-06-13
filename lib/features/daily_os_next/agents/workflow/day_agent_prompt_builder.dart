part of 'day_agent_workflow.dart';

/// System-prompt assembly, tool gating, forced capture/plan steps and tool
/// definitions for [DayAgentWorkflow]. Split from the main workflow file for
/// size; all members are library-private.
extension DayAgentPromptBuilder on DayAgentWorkflow {
  String _buildSystemPrompt(TemplateContext? ctx) {
    const captureToolLines =
        '- `submit_capture`: persist a user capture transcript and enqueue parsing.\n'
        '- `parse_capture_to_items`: persist capture phrases parsed from the current capture-submitted wake.\n'
        '- `match_to_corpus`: find existing task candidates for a phrase.\n'
        '- `link_capture_phrase_to_task`: attach a parsed capture item to a task.\n'
        "- `break_capture_link`: remove a parsed capture item's task link.\n"
        '- `surface_pending_decisions`: list overdue, in-progress, missed recurring, and due-today tasks for reconcile.\n'
        '- `apply_triage`: apply a reconcile action to a task.\n'
        '- `create_task_from_phrase`: create a real task from a new capture phrase.';
    const planToolLines =
        '- `draft_day_plan`: persist a drafted day plan with blocks and reasons.\n'
        '- `summarize_recent_patterns`: return learning cards from recent day drafts.';
    const knowledgeToolLines =
        '- `propose_knowledge`: durably remember how the user wants to be '
        'planned. Use source "userStated" only when the user told you '
        'directly; every entry awaits their confirmation in the panel.';
    const weekContextToolLines =
        '- `write_day_summary`: your contemporaneous note on a day (today or '
        'yesterday only) — what happened and why, one paragraph, max 500 '
        'characters.';
    final toolLines = <String>[
      '- `record_observations`: private memory for learnings and uncertainty.',
      '- `set_next_wake`: schedule the next useful pre-warm wake.',
      '- `search_memory`: recall past detail folded out of the summary by keyword, or pass `ids` to pull up specific entries (e.g. to follow a [[relation:id]] link).',
      if (captureService != null) captureToolLines,
      if (planService != null) planToolLines,
      if (knowledgeService != null) knowledgeToolLines,
      if (weekContextService != null) weekContextToolLines,
    ];
    final scaffold =
        '''
You are the Daily OS planner: one durable agent that plans across days and
learns over time. The user message is a set of `<snake_case>` tagged sections.
Each wake operates on exactly one day workspace — the `<day_id>` section — but
your memory and observations span every day you have planned. Confine this
wake's tool calls to that day; never plan or mutate a different day than the one
this wake targets.

Available tools:

${toolLines.join('\n')}

Capture matching rules:
- Use the embedded task corpus when parsing a submitted capture.
- Emit `parse_capture_to_items` with confidenceScore in [0, 1].
- confidenceScore >= 0.75 is a strong match.
- confidenceScore >= 0.5 and < 0.75 is a low-confidence match.
- confidenceScore < 0.5 should be treated as a new item.
- Older overdue or stale-looking corpus tasks can still be valid matches, but
  only emit them as strong matches when the capture phrase clearly refers to
  that existing task. When the evidence is ambiguous, prefer a low-confidence
  match or a new item so the user can choose instead of silently reviving old
  work.

Drafting rules:
- Every `ai` block passed to `draft_day_plan` must include a concrete reason.
- Keep blocks inside the local plan day and within the user's capacity.
- The user message includes a `<current_local_time>` section. When `<plan_date>`
  is the same local day, do not create new drafted `ai` or `manual` blocks that
  start before that time. Preserve already-started baseline blocks only when
  they represent existing in-progress, completed, or dropped history.
- Calendar, buffer, and manual blocks may omit reasons when their purpose is
  self-evident.
- When this wake's user message carries a `<drafting>` section (i.e. the trigger
  tokens include `drafting:<dayId>`), your priority is to call
  `draft_day_plan` once with the full updated block list — replacing or
  extending `drafting.baselinePlan` rather than emitting partial diffs.
- On drafting wakes, `drafting.decidedTasks` contains existing tasks the user
  approved for placement. If an existing task appears stale or unclear from the
  capture evidence, do not force the placement; create a new task from the
  phrase or keep the plan conservative.
- On drafting wakes, `drafting.decidedCaptureItems` contains approved capture
  items without task IDs. For each item you place, call `create_task_from_phrase`
  first and use the returned `taskId` in `draft_day_plan`.
- On `drafting:<dayId>` wakes, `draft_day_plan` MUST be the final tool call.
  Do not end the wake with plain text. Process reconcile decisions first, then
  emit the full plan through `draft_day_plan`.

Refine rules:
- When this wake's user message carries a `<refine>` section (i.e. the trigger
  tokens include `refine:<dayId>`), your priority is to call
  `propose_plan_diff` once with the structured changes the user described
  in the accompanying capture transcript. Reference existing `blockId`s
  from `refine.baselinePlan.blocks` for `moved` and `dropped` changes;
  `added` changes carry a fresh `to` block payload. Every change must
  include a non-empty `reason`.
- Accepting or reverting a proposed diff and committing or uncommitting a day
  are the user's verdicts, surfaced through the UI only — you have no tools
  for them. Never claim you applied, committed, or uncommitted anything on
  your own. After the user commits, the plan is in shepherding mode and
  further edits require an explicit refine.
- Shutdown and agenda mutation tools are not available yet. Do not claim you
  shut down a day.${weekContextService == null ? '' : '''


Week context (`<recent_days>` / `<week_ahead>`):
- The facts in `<recent_days>` are deterministic: recorded time is ground
  truth (excluding any still-running session), planned time is intent. A
  committed plan was a real commitment; a draft plan is weak evidence.
- Plan sustainably: after a heavy stretch (days recorded far over plan, missed
  rest), prefer a gentler day over maximum throughput. Sustainability beats
  throughput.
- Respect `<week_ahead>`: deadlines within the window should shape today's
  plan before they become urgent.
- `write_day_summary` rules: one paragraph, max 500 characters, what happened
  and WHY in your own words for your own future reading. Today or yesterday
  only. Do not restate the numbers — the facts line already carries them. If
  yesterday has no note yet, write it on any wake while it is still writable.
- Your `Agent note:` lines in `<recent_days>` are your own past testimony; the
  facts line next to them wins on any contradiction.'''}

Your memory (append-only — you add, never overwrite):
- Keep each observation atomic: one idea per note, so it can be linked and
  superseded cleanly. Lead with a short `keywords: …` line when it will help
  later recall find the note.
- When an observation or knowledge note you write refines, supersedes,
  contradicts, or relates to an earlier entry you can see (in this prompt or a
  `search_memory` result), cite it inline as `[[relation:id]]` using that
  entry's id — e.g. `[[refines:obs-12ab]]`. Use only ids you have actually
  seen; never invent one.
- To record a corrected "new version" of an earlier observation, write a fresh
  observation containing `[[supersedes:<oldId>]]` rather than restating it as
  fact — newer entries win by superseding, never by overwriting.
- After a capture, write the durable takeaway as a linked observation rather
  than leaving the raw transcript as your only memory of it.
- Maintain topic maps: a `propose_knowledge` entry keyed `moc-<topic>` whose
  statement curates `[[relates:id]]` links to the entries that matter for that
  topic is a durable hub you (and the user) can navigate.
- Actually follow your links: when an entry cites `[[relation:id]]`, call
  `search_memory` with `ids` to pull those entries up before deciding.

Record private observations and schedule one useful future wake when warranted.

Planning defaults:
${const JsonEncoder.withIndent('  ').convert(config.toJson())}''';

    if (ctx == null) return scaffold;

    final version = ctx.version;
    final generalDirective = version.generalDirective.trim();
    final reportDirective = version.reportDirective.trim();
    final legacyDirective = version.directives.trim();
    final buf = StringBuffer()..write(scaffold);

    if (reportDirective.isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..writeln('## Report Directive')
        ..writeln()
        ..write(reportDirective);
    }

    if (ctx.soulVersion != null) {
      appendSoulPersonality(buf, ctx.soulVersion!);
    }

    final operationalDirective = generalDirective.isNotEmpty
        ? generalDirective
        : legacyDirective;
    if (operationalDirective.isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..writeln('## Operational Directives')
        ..writeln()
        ..write(operationalDirective);
    }

    return buf.toString();
  }

  bool _isToolEnabled(String toolName) {
    if (DayAgentToolNames.isCaptureReconcileTool(toolName)) {
      return captureService != null;
    }
    if (DayAgentToolNames.isPlanTool(toolName)) {
      return planService != null;
    }
    if (DayAgentToolNames.isKnowledgeTool(toolName)) {
      return knowledgeService != null;
    }
    // Explicit branch — the fallthrough default is `true`, which would offer
    // the model a tool whose every call dies as unconfigured.
    if (DayAgentToolNames.isWeekContextTool(toolName)) {
      return weekContextService != null;
    }
    return true;
  }

  bool _requiresDraftDayPlan({
    required DailyOsPlannerWakeContext wakeContext,
  }) {
    return planService != null && wakeContext.isDraftingWake;
  }

  bool _requiresCaptureParse({
    required DailyOsPlannerWakeContext wakeContext,
    required CaptureContext? captureContext,
  }) {
    // A non-null capture context already implies a capture token resolved to
    // a loadable capture owned by this agent. Drafting/refine checks are
    // workspace-filtered: ambiguous multi-day token sets are rejected before
    // this point, so any mode token present belongs to the resolved day.
    return captureService != null &&
        captureContext != null &&
        !wakeContext.isDraftingWake &&
        !wakeContext.isRefineWake;
  }

  Future<InferenceUsage?> _forceCaptureParseIfMissing({
    required String conversationId,
    required String modelId,
    required AiConfigInferenceProvider provider,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required DayAgentStrategy strategy,
    required String captureId,
  }) {
    _log(
      'capture wake missed parse_capture_to_items — retrying with forced '
      'tool choice',
      subDomain: 'execute',
    );
    const forcedToolChoice = ChatCompletionToolChoiceOption.tool(
      ChatCompletionNamedToolChoice(
        type: ChatCompletionNamedToolChoiceType.function,
        function: ChatCompletionFunctionCallOption(
          name: DayAgentToolNames.parseCaptureToItems,
        ),
      ),
    );
    final parseOnlyTools = tools
        .where(
          (tool) => tool.function.name == DayAgentToolNames.parseCaptureToItems,
        )
        .toList(growable: false);

    return conversationRepository.sendMessage(
      conversationId: conversationId,
      message:
          'You did not call `parse_capture_to_items` before stopping. Call it '
          'now for capture `$captureId` using the capture transcript and task '
          'corpus already provided in this wake. This is the mandatory output '
          'of a capture-submitted wake. Do not respond with plain text or call '
          'any other tool.',
      model: modelId,
      provider: provider,
      inferenceRepo: inferenceRepo,
      tools: parseOnlyTools,
      toolChoice: forcedToolChoice,
      temperature: 0.3,
      strategy: strategy,
    );
  }

  Future<InferenceUsage?> _forceDraftDayPlanIfMissing({
    required String conversationId,
    required String modelId,
    required AiConfigInferenceProvider provider,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required DayAgentStrategy strategy,
  }) {
    _log(
      'drafting wake missed draft_day_plan — retrying with forced tool choice',
      subDomain: 'execute',
    );
    const forcedToolChoice = ChatCompletionToolChoiceOption.tool(
      ChatCompletionNamedToolChoice(
        type: ChatCompletionNamedToolChoiceType.function,
        function: ChatCompletionFunctionCallOption(
          name: DayAgentToolNames.draftDayPlan,
        ),
      ),
    );
    final draftOnlyTools = tools
        .where((tool) => tool.function.name == DayAgentToolNames.draftDayPlan)
        .toList(growable: false);

    return conversationRepository.sendMessage(
      conversationId: conversationId,
      message:
          'You did not call `draft_day_plan` before stopping. Call it now '
          'with the full block list for this day. This is the mandatory '
          'final step of a drafting wake. Do not respond with plain text or '
          'call any other tool.',
      model: modelId,
      provider: provider,
      inferenceRepo: inferenceRepo,
      tools: draftOnlyTools,
      toolChoice: forcedToolChoice,
      temperature: 0.3,
      strategy: strategy,
    );
  }

  List<ChatCompletionTool> _buildToolDefinitions() {
    return dayAgentTools.where((tool) => _isToolEnabled(tool.name)).map((tool) {
      return ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters,
        ),
      );
    }).toList();
  }

  String? _extractFinalAssistantContent(ConversationManager? manager) {
    if (manager == null) return null;
    final messages = manager.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final content = messages[i].mapOrNull(assistant: (a) => a.content);
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }
    return null;
  }

  /// Resolves the day workspace from a capture-submitted wake's captures.
  ///
  /// A capture wake carries no `planning_day:`/`drafting:`/`refine:` token, so
  /// its day comes from the capture's own `dayId` scope (ADR 0022). Loads each
  /// `capture_submitted:` capture owned by [agentId] and collects the distinct
  /// days; more than one distinct day is reported as ambiguous so the wake can
  /// fail fast rather than pick arbitrarily.
  Future<PlannerWakeDayResolution> _dayIdFromCaptureTokens({
    required String agentId,
    required Set<String> triggerTokens,
  }) async {
    final service = captureService;
    if (service == null) return const PlannerWakeDayResolution(candidates: {});
    final captureIds = captureIdsFromTriggerTokens(triggerTokens);
    if (captureIds.isEmpty) {
      return const PlannerWakeDayResolution(candidates: {});
    }
    final days = <String>{};
    for (final captureId in captureIds) {
      final capture = await service.getCapture(captureId);
      if (capture == null || capture.agentId != agentId) continue;
      days.add(captureDayId(capture));
    }
    return PlannerWakeDayResolution(candidates: days);
  }
}
