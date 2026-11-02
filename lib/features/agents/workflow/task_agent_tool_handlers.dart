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

      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Report updated (${_reportContent!.length} chars, '
        'tldr=${_reportTldr != null ? "${_reportTldr!.length} chars" : "none"}, '
        'oneLiner=${_reportOneLiner != null ? "${_reportOneLiner!.length} chars" : "none"})',
        subDomain: 'TaskAgentStrategy',
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
  /// Parsed by the shared [parseRecordObservations]: bare strings and
  /// structured `{text, priority?, category?}` items are both accepted, and a
  /// call with nothing usable in it is refused with an error the model can
  /// act on rather than acknowledged as "Recorded 0".
  Future<void> _handleRecordObservations(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final (:records, :error) = parseRecordObservations(args);
    if (error != null) {
      manager.addToolResponse(toolCallId: callId, response: error);
      await _recordToolResultMessage(
        toolName: TaskAgentStrategy.observationToolName,
        errorMessage: error,
      );
      return;
    }
    _observations.addAll(records);

    _domainLogger.log(
      LogDomain.agentWorkflow,
      'Recorded ${records.length} observations',
      subDomain: 'TaskAgentStrategy',
    );

    manager.addToolResponse(
      toolCallId: callId,
      response: 'Recorded ${records.length} observation(s).',
    );

    await _recordToolResultMessage(
      toolName: TaskAgentStrategy.observationToolName,
    );
  }

  /// Handles `find_related_tasks`: searches by meaning, on the device, for
  /// the tasks the model's query describes, and answers with them.
  Future<void> _handleFindRelatedTasks(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final rawQuery = args['query'];
    final query = rawQuery is String ? rawQuery.trim() : '';
    final lookup = relatedTasks;
    final error = lookup == null
        ? 'Error: ${TaskAgentStrategy.findRelatedTasksToolName} is not '
              'available: search by meaning is off on this device.'
        : query.isEmpty
        ? 'Error: "query" must be a non-empty string.'
        : null;
    await _answerRelatedTaskTool(
      toolName: TaskAgentStrategy.findRelatedTasksToolName,
      callId: callId,
      manager: manager,
      error: error,
      answer: () => lookup!.find(taskId, query),
      failure: 'Error: the related-task search failed.',
    );
  }

  /// Handles `get_related_task_details`: reads one task a search of this
  /// wake returned — its TL;DR, or with `includeFullReport` its whole
  /// report. Any other id is refused, so the model cannot read a task it
  /// guessed.
  Future<void> _handleRelatedTaskDetails(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final rawTaskId = args['taskId'];
    final requestedTaskId = rawTaskId is String ? rawTaskId.trim() : '';
    final lookup = relatedTasks;

    final error = lookup == null
        ? 'Error: ${TaskAgentStrategy.relatedTaskDetailsToolName} is not '
              'available: search by meaning is off on this device.'
        : requestedTaskId.isEmpty
        ? 'Error: "taskId" must be a non-empty string.'
        : requestedTaskId == taskId
        ? 'Error: get_related_task_details cannot be used for the current '
              'task. Its details are already in your context.'
        : !lookup.foundIds.contains(requestedTaskId)
        ? 'Error: task "$requestedTaskId" was not returned by '
              '${TaskAgentStrategy.findRelatedTasksToolName} in this wake. '
              'Search for it first; only read tasks a search returned.'
        : null;
    await _answerRelatedTaskTool(
      toolName: TaskAgentStrategy.relatedTaskDetailsToolName,
      callId: callId,
      manager: manager,
      error: error,
      answer: () => lookup!.details(
        requestedTaskId,
        fullReport: args['includeFullReport'] == true,
      ),
      failure:
          'Error: related task details could not be resolved for '
          '"$requestedTaskId".',
    );
  }

  /// Answers a related-task tool call with [error] when there is one,
  /// otherwise with what [answer] returns — or [failure] when it throws or
  /// returns nothing — and records the result.
  Future<void> _answerRelatedTaskTool({
    required String toolName,
    required String callId,
    required ConversationManager manager,
    required String? error,
    required Future<String?> Function() answer,
    required String failure,
  }) async {
    var response = error;
    var failed = error != null;
    if (!failed) {
      try {
        response = await answer();
      } catch (exception, stackTrace) {
        _domainLogger.error(
          LogDomain.agentWorkflow,
          exception,
          stackTrace: stackTrace,
          subDomain: 'TaskAgentStrategy',
          message: '$toolName failed',
        );
      }
      if (response == null || response.trim().isEmpty) {
        response = failure;
        failed = true;
      }
    }
    manager.addToolResponse(toolCallId: callId, response: response!);
    await _recordToolResultMessage(
      toolName: toolName,
      errorMessage: failed ? response : null,
    );
  }

  /// Handles the read-only `get_category_projects` tool: answers with the
  /// projects of the task's category as JSON, or with a plain sentence when
  /// there are none.
  Future<void> _handleCategoryProjects(
    String callId,
    ConversationManager manager,
  ) async {
    final resolver = resolveCategoryProjects;
    String? errorMessage;
    String? response;
    if (resolver == null) {
      errorMessage = 'Error: get_category_projects is not available.';
    } else {
      try {
        response = renderTaskProjectOptions(await resolver());
      } catch (error, stackTrace) {
        _domainLogger.error(
          LogDomain.agentWorkflow,
          error,
          stackTrace: stackTrace,
          subDomain: 'TaskAgentStrategy',
          message: 'Failed to resolve the category projects',
        );
        errorMessage = 'Error: the projects could not be read right now.';
      }
    }

    manager.addToolResponse(
      toolCallId: callId,
      response: errorMessage ?? response!,
    );
    await _recordToolResultMessage(
      toolName: TaskAgentStrategy.categoryProjectsToolName,
      errorMessage: errorMessage,
    );
  }

  /// Handles the read-only pull request tools: `get_unlinked_pull_requests`
  /// answers with the task's unlinked pull requests, ranked against it, and
  /// `refresh_pull_requests` with its linked ones read from GitHub again.
  /// A read that throws answers with a sentence, and the wake goes on.
  Future<void> _handlePullRequestRead(
    String toolName,
    String callId,
    ConversationManager manager,
  ) async {
    final read = switch (toolName) {
      TaskAgentToolNames.getUnlinkedPullRequests =>
        switch (resolveUnlinkedPullRequests) {
          final resolve? => () async => renderTaskPullRequestListing(
            await resolve(),
          ),
          null => null,
        },
      _ => switch (refreshLinkedPullRequests) {
        final refresh? => () async {
          final section = await refresh();
          return section.trim().isEmpty
              ? 'The task has no linked pull request to refresh.'
              : section;
        },
        null => null,
      },
    };
    String? errorMessage;
    String? response;
    if (read == null) {
      errorMessage = 'Error: $toolName is not available.';
    } else {
      try {
        response = await read();
      } catch (error, stackTrace) {
        _domainLogger.error(
          LogDomain.agentWorkflow,
          error,
          stackTrace: stackTrace,
          subDomain: 'TaskAgentStrategy',
          message: '$toolName failed',
        );
        errorMessage =
            'Error: the pull requests could not be read right now. Propose '
            'nothing from them.';
      }
    }

    manager.addToolResponse(
      toolCallId: callId,
      response: errorMessage ?? response!,
    );
    await _recordToolResultMessage(
      toolName: toolName,
      errorMessage: errorMessage,
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

  // ── Argument parsing ───────────────────────────────────────────────────

  // ── Change set helpers ──────────────────────────────────────────────────
}
