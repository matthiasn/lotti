part of 'task_agent_strategy.dart';

/// The document tools of [TaskAgentStrategy] (ADR 0167): reading a
/// document's text, and validating and queueing a proposed version.
extension TaskAgentDocumentHandlers on TaskAgentStrategy {
  /// Answers `read_document` with the text of the version the document
  /// shows, as the user's data. A document the task does not hold, or a
  /// read that fails, answers with a sentence, and the wake goes on.
  Future<void> _handleReadDocument(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    const tool = TaskAgentToolNames.readDocument;
    final rawId = args['documentId'];
    final documentId = rawId is String ? rawId.trim() : '';
    final read = readTaskDocument;
    String? errorMessage;
    String? response;
    if (read == null) {
      errorMessage = 'Error: $tool is not available.';
    } else if (documentId.isEmpty) {
      errorMessage =
          'Error: "documentId" is required, as listed in the Documents '
          'section.';
    } else {
      try {
        final text = await read(documentId);
        if (text == null) {
          errorMessage =
              'Error: this task holds no document `$documentId`. Use an id '
              'the Documents section lists.';
        } else {
          response = renderTaskDocumentText(text);
        }
      } catch (error, stackTrace) {
        _domainLogger.error(
          LogDomain.agentWorkflow,
          error,
          stackTrace: stackTrace,
          subDomain: 'TaskAgentStrategy',
          message: 'Failed to read a task document',
        );
        errorMessage = 'Error: the document could not be read right now.';
      }
    }
    manager.addToolResponse(
      toolCallId: callId,
      response: errorMessage ?? response!,
    );
    await _recordToolResultMessage(toolName: tool, errorMessage: errorMessage);
  }

  /// Validates and queues a `propose_document_version`.
  ///
  /// Fail-closed: the text must be there, and the proposal names either a
  /// document the wake's Documents section listed or a title for a new one.
  /// The version it is drafted against is filled in here from that listing,
  /// never taken from the model, so the compare-and-set at confirmation
  /// checks what the agent was actually shown. One version per document
  /// waits for the user at a time: a document with a version pending — from
  /// an earlier wake or this one — is refused, and the agent is told to
  /// retract the pending one first if this draft replaces it.
  Future<String> _queueDocumentProposal(
    ChangeSetBuilder csBuilder,
    Map<String, dynamic> args,
  ) async {
    const tool = TaskAgentToolNames.proposeDocumentVersion;
    final markdown = args['markdown'];
    if (markdown is! String || markdown.trim().isEmpty) {
      return 'ERROR: $tool requires the complete "markdown" of the version. '
          'No proposal was queued.';
    }
    final rawSummary = args['changeSummary'];
    final changeSummary = rawSummary is String ? rawSummary.trim() : '';
    final rawId = args['documentId'];
    final rawTitle = args['newTitle'];
    final documentId = rawId is String ? rawId.trim() : '';
    final newTitle = rawTitle is String ? rawTitle.trim() : '';
    if (documentId.isEmpty == newTitle.isEmpty) {
      return 'ERROR: give either "documentId" of a document the Documents '
          'section lists, or "newTitle" for a new document — one of them. '
          'No proposal was queued.';
    }

    final Map<String, dynamic> canonicalArgs;
    if (documentId.isNotEmpty) {
      final document = taskDocuments
          .where((candidate) => candidate.id == documentId)
          .firstOrNull;
      if (document == null) {
        return 'ERROR: this task holds no document `$documentId`. Use an id '
            'the Documents section lists, or "newTitle" to create one. No '
            'proposal was queued.';
      }
      final queuedThisWake = csBuilder.items.any(
        (item) =>
            item.toolName == tool && item.args['documentId'] == documentId,
      );
      if (queuedThisWake || pendingDocumentProposalIds.contains(documentId)) {
        return 'ERROR: a version of ${jsonEncode(document.title)} is already '
            'waiting for the user. If this draft replaces it, retract that '
            'one with ${TaskAgentToolNames.retractSuggestions} first. No '
            'proposal was queued.';
      }
      canonicalArgs = {
        'documentId': documentId,
        // For the review row, which names the document.
        'title': document.title,
        'baseVersionId': ?document.versionId,
        'markdown': markdown,
        'changeSummary': changeSummary,
      };
    } else {
      canonicalArgs = {
        'newTitle': newTitle,
        'markdown': markdown,
        'changeSummary': changeSummary,
      };
    }

    final addRedundancy = await csBuilder.addItem(
      toolName: tool,
      args: canonicalArgs,
      humanSummary: TaskAgentChangeHandlers._generateHumanSummary(
        tool,
        canonicalArgs,
      ),
    );
    if (addRedundancy != null) {
      return 'Skipped: $addRedundancy';
    }

    _domainLogger.log(
      LogDomain.agentWorkflow,
      'Deferred tool $tool to change set '
      '(${csBuilder.items.length} items total)',
      subDomain: 'TaskAgentStrategy',
    );

    return 'OK — $tool proposal recorded. The user reads and confirms it; '
        'nothing has changed yet.${_remainingDeferredToolHint(tool)}';
  }
}
