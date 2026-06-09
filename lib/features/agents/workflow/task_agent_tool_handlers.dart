part of 'task_agent_strategy.dart';

/// Tool-call handlers, change-set deferral, summaries, and message
/// recording of [TaskAgentStrategy]. All members are private to the
/// library; the class-side `processToolCalls` dispatches into them.
extension TaskAgentToolHandlers on TaskAgentStrategy {
  /// Handles the `update_report` tool call by capturing the one-liner, TLDR,
  /// and content.
  ///
  /// If the LLM calls this more than once per wake, the last call wins — the
  /// previous content is silently replaced. This is by design: the agent
  /// contract requires exactly one call, so multiple calls indicate an LLM
  /// error and the latest version is the most refined.
  Future<void> _handleUpdateReport(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final contentArg = args['content'];
    final rawTldr = args['tldr'];
    final rawOneLiner = args['oneLiner'];
    final tldr = (rawTldr is String && rawTldr.trim().isNotEmpty)
        ? rawTldr.trim()
        : null;
    final oneLiner = (rawOneLiner is String && rawOneLiner.trim().isNotEmpty)
        ? rawOneLiner.trim()
        : null;

    if (contentArg is String && contentArg.trim().isNotEmpty) {
      final missingFields = <String>[
        if (tldr == null) 'tldr',
        if (oneLiner == null) 'oneLiner',
      ];

      if (missingFields.isNotEmpty) {
        final errorMsg =
            'Error: ${missingFields.map((f) => '"$f"').join(' and ')} '
            'must be a non-empty string.';
        manager.addToolResponse(
          toolCallId: callId,
          response: errorMsg,
        );

        await _recordToolResultMessage(
          toolName: TaskAgentStrategy.reportToolName,
          errorMessage: errorMsg,
        );
        return;
      }

      _reportContent = contentArg.trim();
      _reportTldr = tldr;
      _reportOneLiner = oneLiner;

      developer.log(
        'Report updated (${_reportContent!.length} chars, '
        'tldr=${_reportTldr != null ? "${_reportTldr!.length} chars" : "none"}, '
        'oneLiner=${_reportOneLiner != null ? "${_reportOneLiner!.length} chars" : "none"})',
        name: 'TaskAgentStrategy',
      );

      manager.addToolResponse(
        toolCallId: callId,
        response: 'Report updated.',
      );

      await _recordToolResultMessage(
        toolName: TaskAgentStrategy.reportToolName,
      );
    } else {
      const errorMsg = 'Error: "content" must be a non-empty string.';
      manager.addToolResponse(
        toolCallId: callId,
        response: errorMsg,
      );

      await _recordToolResultMessage(
        toolName: TaskAgentStrategy.reportToolName,
        errorMessage: errorMsg,
      );
    }
  }

  /// Handles the `record_observations` tool call by accumulating observations
  /// and sending an acknowledgement back to the conversation.
  ///
  /// Accepts both legacy bare-string items and new structured items with
  /// `text`, `priority`, and `category` fields. Legacy items default to
  /// [ObservationPriority.routine] / [ObservationCategory.operational].
  Future<void> _handleRecordObservations(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final rawList = args['observations'];
    if (rawList is List) {
      var count = 0;
      for (final item in rawList) {
        final record = _parseObservationItem(item);
        if (record != null) {
          _observations.add(record);
          count++;
        }
      }

      developer.log(
        'Recorded $count observations',
        name: 'TaskAgentStrategy',
      );

      manager.addToolResponse(
        toolCallId: callId,
        response: 'Recorded $count observation(s).',
      );

      await _recordToolResultMessage(
        toolName: TaskAgentStrategy.observationToolName,
      );
    } else {
      const errorMsg = 'Error: "observations" must be an array.';
      manager.addToolResponse(
        toolCallId: callId,
        response: errorMsg,
      );

      await _recordToolResultMessage(
        toolName: TaskAgentStrategy.observationToolName,
        errorMessage: errorMsg,
      );
    }
  }

  /// Handles the read-only related-task drill-down tool.
  Future<void> _handleRelatedTaskDetails(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final rawTaskId = args['taskId'];
    final requestedTaskId = rawTaskId is String ? rawTaskId.trim() : '';

    String? errorMessage;
    if (requestedTaskId.isEmpty) {
      errorMessage = 'Error: "taskId" must be a non-empty string.';
    } else if (requestedTaskId == taskId) {
      errorMessage =
          'Error: get_related_task_details cannot be used for the current '
          'task. Choose another task from the related-tasks directory.';
    } else if (!allowedRelatedTaskIds.contains(requestedTaskId)) {
      errorMessage =
          'Error: taskId "$requestedTaskId" is not available in the current '
          'related-tasks directory. Only inspect sibling task IDs that were '
          'included in this wake context.';
    }

    if (errorMessage != null) {
      manager.addToolResponse(toolCallId: callId, response: errorMessage);
      await _recordToolResultMessage(
        toolName: TaskAgentStrategy.relatedTaskDetailsToolName,
        errorMessage: errorMessage,
      );
      return;
    }

    final resolver = resolveRelatedTaskDetails;
    String? response;
    try {
      response = resolver != null ? await resolver(requestedTaskId) : null;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to resolve related task details for '
        '${DomainLogger.sanitizeId(requestedTaskId)}',
        name: 'TaskAgentStrategy',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    if (response == null || response.trim().isEmpty) {
      final toolError =
          'Error: related task details could not be resolved for '
          '"$requestedTaskId".';
      manager.addToolResponse(toolCallId: callId, response: toolError);
      await _recordToolResultMessage(
        toolName: TaskAgentStrategy.relatedTaskDetailsToolName,
        errorMessage: toolError,
      );
      return;
    }

    manager.addToolResponse(toolCallId: callId, response: response);
    await _recordToolResultMessage(
      toolName: TaskAgentStrategy.relatedTaskDetailsToolName,
    );
  }

  /// Handles the `retract_suggestions` tool call: parses the proposals
  /// array, dispatches each retraction to [SuggestionRetractionService],
  /// and feeds a per-entry outcome report back to the LLM.
  Future<void> _handleRetractSuggestions(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final service = retractionService;
    if (service == null) {
      const errorMsg =
          'Error: retract_suggestions is not wired up for this agent.';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: TaskAgentStrategy.retractSuggestionsToolName,
        errorMessage: errorMsg,
      );
      return;
    }

    final rawProposals = args['proposals'];
    if (rawProposals is! List || rawProposals.isEmpty) {
      const errorMsg =
          'Error: "proposals" must be a non-empty array of '
          '{fingerprint, reason} objects.';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: TaskAgentStrategy.retractSuggestionsToolName,
        errorMessage: errorMsg,
      );
      return;
    }

    final requests = <RetractionRequest>[];
    final parseErrors = <String>[];
    for (var i = 0; i < rawProposals.length; i++) {
      final entry = rawProposals[i];
      if (entry is! Map) {
        parseErrors.add('proposals[$i] is not an object');
        continue;
      }
      final fp = entry['fingerprint'];
      final reason = entry['reason'];
      if (fp is! String || fp.trim().isEmpty) {
        parseErrors.add('proposals[$i].fingerprint missing or empty');
        continue;
      }
      if (reason is! String || reason.trim().isEmpty) {
        parseErrors.add('proposals[$i].reason missing or empty');
        continue;
      }
      requests.add(
        RetractionRequest(fingerprint: fp.trim(), reason: reason.trim()),
      );
    }

    if (requests.isEmpty) {
      final errorMsg =
          'Error: no valid proposals to retract. '
          '${parseErrors.join('; ')}';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: TaskAgentStrategy.retractSuggestionsToolName,
        errorMessage: errorMsg,
      );
      return;
    }

    final plan = await service.plan(
      agentId: agentId,
      taskId: taskId,
      requests: requests,
      alreadyStagedKeys: _stagedRetractionKeys,
    );

    // Stage for end-of-wake application so the retraction commits atomically
    // with this wake's new proposals — the suggestion list never flashes empty
    // between a retraction and its replacement.
    for (final retraction in plan.staged) {
      _stagedRetractions.add(retraction);
      _stagedRetractionKeys.add(retraction.key);
    }

    final response = StringBuffer('Retraction results:');
    for (final r in plan.results) {
      final label = switch (r.outcome) {
        RetractionOutcome.retracted => 'retracted',
        RetractionOutcome.notOpen => 'not_open (already resolved)',
        RetractionOutcome.notFound => 'not_found',
      };
      final summary = r.humanSummary?.trim();
      final detail = (summary != null && summary.isNotEmpty)
          ? ' — "$summary"'
          : (r.toolName != null ? ' — ${r.toolName}' : '');
      response.writeln('\n- [fp=${r.fingerprint}] $label$detail');
    }
    if (parseErrors.isNotEmpty) {
      response
        ..writeln()
        ..writeln('Skipped malformed entries: ${parseErrors.join('; ')}');
    }

    manager.addToolResponse(
      toolCallId: callId,
      response: response.toString().trim(),
    );
    await _recordToolResultMessage(
      toolName: TaskAgentStrategy.retractSuggestionsToolName,
    );
  }

  /// Parses a single observation item from the tool call arguments.
  ///
  /// Handles both legacy bare strings and new structured objects.
  static ObservationRecord? _parseObservationItem(Object? item) {
    // Legacy format: bare string.
    if (item is String) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) {
        return ObservationRecord(text: trimmed);
      }
    }

    // New structured format: {text, priority?, category?}.
    if (item is Map<String, dynamic>) {
      final rawText = item['text'];
      if (rawText is String) {
        final text = rawText.trim();
        if (text.isEmpty) return null;
        final rawPriority = item['priority'];
        final rawCategory = item['category'];
        return ObservationRecord(
          text: text,
          priority:
              parseEnumByName(
                ObservationPriority.values,
                rawPriority is String ? rawPriority : null,
              ) ??
              ObservationPriority.routine,
          category:
              parseEnumByName(
                ObservationCategory.values,
                rawCategory is String ? rawCategory : null,
              ) ??
              ObservationCategory.operational,
        );
      }
    }

    return null;
  }

  // ── Argument parsing ───────────────────────────────────────────────────

  // ── Change set helpers ──────────────────────────────────────────────────

  /// Route a deferred tool call to the change set builder.
  ///
  /// Batch tools (listed in [AgentToolRegistry.explodedBatchTools]) are
  /// exploded into individual items; all others are added as a single item.
  ///
  /// Returns a response string for the LLM. For batch tools with skipped
  /// items, the response includes a warning.
  Future<String> _addToChangeSet(
    ChangeSetBuilder csBuilder,
    String toolName,
    Map<String, dynamic> rawArgs,
  ) async {
    // Normalize incidental whitespace in the entity-reference id (entryId /
    // timerId) so validation, the queued proposal, and apply all use the same
    // canonical value — a model that pads a copied id must not be falsely
    // rejected. (Label/checklist ids are normalized inside the exploder.)
    final args = _normalizeEntityReferenceArgs(toolName, rawArgs);

    // Fail-closed entity-reference validation for the non-batch deferred tools
    // that reference an existing entity by id. A hallucinated id is rejected
    // with model-facing feedback instead of being queued as a proposal that
    // surfaces a raw id and cannot be applied. (Label/checklist batch tools are
    // gated inside the exploder; metadata tools reference no foreign id.)
    final referenceError = await _checkEntityReference(toolName, args);
    if (referenceError != null) {
      return referenceError;
    }

    // Route create_follow_up_task to the dedicated builder method that
    // injects a placeholder ID and returns it for migrate_checklist_items.
    if (toolName == TaskAgentToolNames.createFollowUpTask) {
      final placeholderId = await csBuilder.addFollowUpTask(
        args: args,
        humanSummary: _generateHumanSummary(toolName, args),
      );

      developer.log(
        'Deferred tool $toolName to change set '
        '(${csBuilder.items.length} items total)',
        name: 'TaskAgentStrategy',
      );

      return 'Proposal queued for user review. '
          'Use targetTaskId: "$placeholderId" for migrate_checklist_items.';
    }

    final batchKey = AgentToolRegistry.explodedBatchTools[toolName];
    String response;
    if (batchKey != null) {
      var effectiveArgs = args;

      // For migrate_checklist_items, replace the LLM's targetTaskId with the
      // real placeholder from the builder. The LLM often hallucinate its own
      // placeholder string (e.g. "placeholder_targetTaskId_1") instead of
      // using the UUID v5 we returned.
      if (toolName == TaskAgentToolNames.migrateChecklistItems) {
        final realPlaceholder = csBuilder.followUpPlaceholderId;
        if (realPlaceholder != null) {
          effectiveArgs = {...args, 'targetTaskId': realPlaceholder};
        }
      }

      final groupId = toolName == TaskAgentToolNames.migrateChecklistItems
          ? effectiveArgs['targetTaskId'] as String?
          : null;
      final result = await csBuilder.addBatchItem(
        toolName: toolName,
        args: effectiveArgs,
        summaryPrefix: _humanToolPrefix(toolName),
        groupId: groupId,
      );
      response = ChangeProposalFilter.formatBatchResponse(result);
    } else {
      // Check for redundancy on non-batch deferred tools.
      final redundancyMsg = await _checkTaskMetadataRedundancy(toolName, args);
      if (redundancyMsg != null) {
        response = redundancyMsg;
      } else {
        final addRedundancy = await csBuilder.addItem(
          toolName: toolName,
          args: args,
          humanSummary: _generateHumanSummary(toolName, args),
        );
        if (addRedundancy != null) {
          response = 'Skipped: $addRedundancy';
        } else {
          final remaining = _remainingDeferredToolHint(toolName);
          response =
              'OK — $toolName proposal recorded successfully. '
              'Do NOT call $toolName again.$remaining';
        }
      }
    }

    developer.log(
      'Deferred tool $toolName to change set '
      '(${csBuilder.items.length} items total)',
      name: 'TaskAgentStrategy',
    );

    return response;
  }

  /// Returns a model-facing error string when [toolName]'s arguments reference
  /// an entity by id that cannot be looked up (a hallucinated id), or `null`
  /// when the reference is valid, unvalidatable (no resolver wired), or the
  /// resolver failed transiently (kept conservatively — we cannot prove the id
  /// is fake). Only the id-referencing non-batch deferred tools are checked.
  Future<String?> _checkEntityReference(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    if (toolName == TaskAgentToolNames.updateTimeEntry) {
      final resolver = resolveEditableTimeEntryIds;
      if (resolver == null) return null;
      final entryId = args['entryId'];
      if (entryId is! String || entryId.isEmpty) {
        return 'ERROR: update_time_entry requires a string "entryId" from the '
            '"Editable Time Entries" section. No entry was queued.';
      }
      final Set<String> editableIds;
      try {
        editableIds = await resolver();
      } catch (_) {
        // Transient lookup failure — keep conservatively.
        return null;
      }
      if (!editableIds.contains(entryId)) {
        return 'ERROR: time entry "$entryId" is not an editable time entry for '
            'this task. Only use entryId values listed in the "Editable Time '
            'Entries" section; do not invent ids. No entry was queued.';
      }
    }

    if (toolName == TaskAgentToolNames.updateRunningTimer) {
      final resolver = resolveRunningTimerId;
      if (resolver == null) return null;
      final timerId = args['timerId'];
      if (timerId is! String || timerId.isEmpty) {
        return 'ERROR: update_running_timer requires a string "timerId". '
            'No proposal was queued.';
      }
      final String? runningTimerId;
      try {
        runningTimerId = await resolver();
      } catch (_) {
        // Transient lookup failure — keep conservatively.
        return null;
      }
      if (runningTimerId == null) {
        return 'ERROR: no timer is currently running for this task, so '
            'update_running_timer cannot be used. No proposal was queued.';
      }
      if (timerId != runningTimerId) {
        return 'ERROR: timer "$timerId" is not the timer running for this task. '
            'Use the timerId from the "Active Running Timer" section; do not '
            'invent ids. No proposal was queued.';
      }
    }

    return null;
  }

  /// Returns [args] with the entity-reference id for [toolName] trimmed of
  /// incidental whitespace, so a model that pads a copied id (e.g. `"  e1  "`)
  /// is not falsely rejected and the queued proposal carries the canonical id.
  /// Tools that reference no foreign id, and non-string ids, pass through
  /// unchanged.
  static Map<String, dynamic> _normalizeEntityReferenceArgs(
    String toolName,
    Map<String, dynamic> args,
  ) {
    final key = switch (toolName) {
      TaskAgentToolNames.updateTimeEntry => 'entryId',
      TaskAgentToolNames.updateRunningTimer => 'timerId',
      _ => null,
    };
    if (key == null) return args;
    final value = args[key];
    if (value is! String) return args;
    final trimmed = value.trim();
    if (trimmed == value) return args;
    return {...args, key: trimmed};
  }

  /// Generate a human-readable summary for a single (non-batch) tool call.
  static String _generateHumanSummary(
    String toolName,
    Map<String, dynamic> args,
  ) {
    return switch (toolName) {
      TaskAgentToolNames.setTaskTitle =>
        'Set title to "${args['title'] ?? ''}"',
      TaskAgentToolNames.updateTaskEstimate =>
        'Set estimate to ${args['minutes'] ?? '?'} minutes',
      TaskAgentToolNames.updateTaskDueDate =>
        'Set due date to ${args['dueDate'] ?? '?'}',
      TaskAgentToolNames.updateTaskPriority =>
        'Set priority to ${args['priority'] ?? '?'}',
      TaskAgentToolNames.setTaskStatus =>
        'Set status to ${args['status'] ?? '?'}',
      TaskAgentToolNames.setTaskLanguage =>
        'Set language to "${args['languageCode'] ?? '?'}"',
      TaskAgentToolNames.assignTaskLabels => () {
        final labels = args['labels'];
        final count = labels is List ? labels.length : 0;
        return 'Assign $count label(s)';
      }(),
      TaskAgentToolNames.createFollowUpTask =>
        'Create follow-up task: "${args['title'] ?? ''}"',
      TaskAgentToolNames.createTimeEntry => () {
        final startRaw = args['startTime'] is String
            ? args['startTime'] as String
            : null;
        final hasEndTime = args.containsKey('endTime');
        final endRaw = args['endTime'] is String
            ? args['endTime'] as String
            : null;
        final summary = args['summary'] is String
            ? (args['summary'] as String).trim()
            : '';
        final start = startRaw != null
            ? parseTimeEntryLocalDateTime(startRaw)
            : null;
        final end = endRaw != null ? parseTimeEntryLocalDateTime(endRaw) : null;
        final startStr = start != null
            ? formatTimeEntryHhMm(start)
            : (startRaw ?? '?');
        final endStr = end != null ? formatTimeEntryHhMm(end) : (endRaw ?? '?');
        final timeRange = hasEndTime ? '$startStr–$endStr' : 'from $startStr';
        return 'Time entry $timeRange: "$summary"';
      }(),
      TaskAgentToolNames.updateRunningTimer => () {
        final summary = args['summary'] is String
            ? (args['summary'] as String).trim()
            : '';
        return 'Update running timer text: "$summary"';
      }(),
      TaskAgentToolNames.updateTimeEntry => () {
        final startRaw = args['startTime'] is String
            ? args['startTime'] as String
            : null;
        final endRaw = args['endTime'] is String
            ? args['endTime'] as String
            : null;
        final summary = args['summary'] is String
            ? (args['summary'] as String).trim()
            : '';
        final start = startRaw != null
            ? parseTimeEntryLocalDateTime(startRaw)
            : null;
        final end = endRaw != null ? parseTimeEntryLocalDateTime(endRaw) : null;
        final startStr = start != null ? formatTimeEntryHhMm(start) : startRaw;
        final endStr = end != null ? formatTimeEntryHhMm(end) : endRaw;
        final range = switch ((startStr, endStr)) {
          (final String s, final String e) => '$s–$e',
          (final String s, null) => 'from $s',
          (null, final String e) => 'until $e',
          _ => '',
        };
        if (summary.isEmpty) {
          return range.isEmpty
              ? 'Update time entry'
              : 'Update time entry $range';
        }

        return range.isEmpty
            ? 'Revise time entry text: "$summary"'
            : 'Update time entry $range: "$summary"';
      }(),
      _ => '$toolName(${args.keys.join(", ")})',
    };
  }

  /// Generate a human-readable prefix for batch tool explosion summaries.
  static String _humanToolPrefix(String toolName) {
    return switch (toolName) {
      TaskAgentToolNames.addMultipleChecklistItems => 'Checklist',
      TaskAgentToolNames.updateChecklistItems => 'Checklist update',
      TaskAgentToolNames.assignTaskLabels => 'Label',
      TaskAgentToolNames.migrateChecklistItems => 'Migrate to follow-up',
      _ => toolName,
    };
  }

  /// Check whether a non-batch deferred tool proposal is redundant against
  /// the current task metadata.
  ///
  /// Returns a feedback message for the LLM if the proposal is redundant,
  /// or `null` if the proposal should be kept.
  ///
  /// The snapshot is resolved once and cached for the lifetime of this
  /// strategy instance to avoid repeated DB lookups when the LLM proposes
  /// multiple deferred tools in the same wake.
  Future<String?> _checkTaskMetadataRedundancy(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final resolver = resolveTaskMetadata;
    if (resolver == null) return null;

    if (!_taskMetadataResolved) {
      _taskMetadataResolved = true;
      try {
        _cachedTaskMetadata = await resolver();
      } catch (e) {
        // Conservative: if we can't resolve, keep the proposal.
        _cachedTaskMetadata = null;
      }
    }

    final snapshot = _cachedTaskMetadata;
    if (snapshot == null) return null;

    return ChangeProposalFilter.checkTaskMetadataRedundancy(
      toolName,
      args,
      snapshot,
    );
  }

  /// Returns true when the named scalar field on the current task is
  /// empty, meaning the corresponding deferred tool (e.g.
  /// `set_task_title`, `set_task_language`) should apply immediately
  /// instead of waiting for user confirmation.
  ///
  /// Always re-resolves: the auto-apply path is the only write that
  /// bypasses user confirmation, so it must see the freshest snapshot.
  /// A stale cached snapshot would let a follow-up call overwrite a
  /// value the user or a previous auto-apply just populated.
  ///
  /// When the resolver is unavailable or throws, returns false so the
  /// deferred-approval path is used conservatively.
  Future<bool> _shouldAutoApplyInitialField(
    String? Function(TaskMetadataSnapshot snapshot) read,
  ) async {
    final resolver = resolveTaskMetadata;
    if (resolver == null) return false;

    TaskMetadataSnapshot? snapshot;
    try {
      snapshot = await resolver();
    } catch (_) {
      snapshot = null;
    }
    _cachedTaskMetadata = snapshot;
    _taskMetadataResolved = true;

    if (snapshot == null) return false;
    final current = read(snapshot)?.trim();
    return current == null || current.isEmpty;
  }

  /// Builds a hint string listing remaining non-batch deferred tools that
  /// haven't been used yet, guiding the model to call different tools.
  String _remainingDeferredToolHint(String justUsed) {
    // Derive single-use tools dynamically: all deferred tools minus batch
    // ones and minus tools that legitimately support multiple calls.
    final singleUseTools = AgentToolRegistry.deferredTools
        .where(
          (tool) =>
              !AgentToolRegistry.explodedBatchTools.containsKey(tool) &&
              tool != TaskAgentToolNames.createFollowUpTask,
        )
        .toSet();

    final remaining = singleUseTools.difference(_usedDeferredTools).difference({
      justUsed,
    });

    if (remaining.isEmpty) {
      return ' When your analysis is complete, call update_report if the '
          'report would materially change; otherwise finish with a brief '
          'plain-text note.';
    }

    final toolList = remaining.toList()..sort();
    return ' Consider using: ${toolList.join(', ')} — then call '
        'update_report if the report would materially change, or finish '
        'with a brief plain-text note.';
  }

  // ── Persistence helpers ──────────────────────────────────────────────────

  /// Records an action message for a locally-handled tool call.
  ///
  /// The [AgentToolExecutor] creates these automatically for tools it handles,
  /// but locally-handled tools (update_report, record_observations) must
  /// create their own action messages so the conversation log tool-call count
  /// is accurate.
  Future<void> _recordActionMessage({
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    final now = clock.now();
    final payloadId = TaskAgentStrategy._uuid.v4();

    await syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{'text': jsonEncode(args)},
      ),
    );

    await syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: TaskAgentStrategy._uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.action,
        createdAt: now,
        vectorClock: null,
        contentEntryId: payloadId,
        metadata: AgentMessageMetadata(
          runKey: runKey,
          toolName: toolName,
        ),
      ),
    );
  }

  /// Records an assistant message (with or without tool calls) to the agent
  /// message log.
  Future<void> _recordAssistantMessage({
    List<ChatCompletionMessageToolCall>? toolCalls,
  }) async {
    final now = clock.now();
    final toolNames =
        toolCalls?.map((tc) => tc.function.name).toList() ?? <String>[];

    await syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: TaskAgentStrategy._uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.thought,
        createdAt: now,
        vectorClock: null,
        metadata: AgentMessageMetadata(
          runKey: runKey,
          toolName: toolNames.isNotEmpty ? toolNames.join(',') : null,
        ),
      ),
    );
  }

  /// Records a tool result message to the agent message log.
  Future<void> _recordToolResultMessage({
    required String toolName,
    String? errorMessage,
  }) async {
    final now = clock.now();
    await syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: TaskAgentStrategy._uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.toolResult,
        createdAt: now,
        vectorClock: null,
        metadata: AgentMessageMetadata(
          runKey: runKey,
          toolName: toolName,
          errorMessage: errorMessage,
        ),
      ),
    );
  }
}
