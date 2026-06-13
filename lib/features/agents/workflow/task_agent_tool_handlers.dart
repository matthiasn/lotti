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
}
