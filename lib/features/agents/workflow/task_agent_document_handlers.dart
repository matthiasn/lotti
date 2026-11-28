part of 'task_agent_strategy.dart';

/// The document tools of [TaskAgentStrategy] (ADR 0167): reading a
/// document's text, and validating and writing a version of one.
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
          // What a version written later in this wake is written over.
          _readDocumentVersions[documentId] = text.summary.versionId;
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

  /// Validates a `write_document_version` and writes it (ADR 0167).
  ///
  /// The version is written at once, as the agent's: the user reads it on
  /// the document and goes back through its history if it is not wanted.
  /// What stands in for a confirmation is checked here, fail-closed:
  ///
  /// - the text is there, and the call names either a document the wake's
  ///   Documents section listed or a title for a new one;
  /// - a document that has text was read in this wake, so the new version
  ///   starts from what the document says now, not from nothing;
  /// - the version it is written over is the one that read returned (the
  ///   listed one for a document without text) — never taken from the model
  ///   — so the write lands only while the document still shows it, and an
  ///   edit the user made meanwhile is never replaced;
  /// - one version per document in a wake, and one new document per title.
  ///
  /// A refused write, a stale one included, tells the agent what to do next;
  /// a stale one has to be read again first.
  Future<void> _handleWriteDocumentVersion(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    const tool = TaskAgentToolNames.writeDocumentVersion;
    Future<void> refuse(String message) async {
      await _recordActionMessage(toolName: tool, args: args);
      manager.addToolResponse(toolCallId: callId, response: message);
      await _recordToolResultMessage(toolName: tool, errorMessage: message);
    }

    final markdown = args['markdown'];
    if (markdown is! String || markdown.trim().isEmpty) {
      return refuse(
        'ERROR: $tool requires the complete "markdown" of the version. '
        'Nothing was written.',
      );
    }
    final rawSummary = args['changeSummary'];
    final changeSummary = rawSummary is String ? rawSummary.trim() : '';
    final rawId = args['documentId'];
    final rawTitle = args['newTitle'];
    final documentId = rawId is String ? rawId.trim() : '';
    final newTitle = rawTitle is String ? rawTitle.trim() : '';
    if (documentId.isEmpty == newTitle.isEmpty) {
      return refuse(
        'ERROR: give either "documentId" of a document the Documents '
        'section lists, or "newTitle" for a new document — one of them. '
        'Nothing was written.',
      );
    }

    final String writtenKey;
    final Map<String, dynamic> canonicalArgs;
    if (documentId.isNotEmpty) {
      final document = taskDocuments
          .where((candidate) => candidate.id == documentId)
          .firstOrNull;
      if (document == null) {
        return refuse(
          'ERROR: this task holds no document `$documentId`. Use an id the '
          'Documents section lists, or "newTitle" to create one. Nothing '
          'was written.',
        );
      }
      writtenKey = 'id:$documentId';
      if (_writtenDocuments.contains(writtenKey)) {
        return refuse(
          'ERROR: you already wrote a version of '
          '${jsonEncode(document.title)} in this wake. Nothing was written.',
        );
      }
      final wasRead = _readDocumentVersions.containsKey(documentId);
      if (!wasRead && document.versionId != null) {
        return refuse(
          'ERROR: call ${TaskAgentToolNames.readDocument} for '
          '`$documentId` first, then write the new version from its text, '
          'keeping what the user did not ask to change. Nothing was '
          'written.',
        );
      }
      final baseVersionId = wasRead
          ? _readDocumentVersions[documentId]
          : document.versionId;
      canonicalArgs = {
        'documentId': documentId,
        'baseVersionId': ?baseVersionId,
        'markdown': markdown,
        'changeSummary': changeSummary,
      };
    } else {
      writtenKey = 'title:${newTitle.toLowerCase()}';
      if (_writtenDocuments.contains(writtenKey)) {
        return refuse(
          'ERROR: you already created ${jsonEncode(newTitle)} in this '
          'wake. Nothing was written.',
        );
      }
      canonicalArgs = {
        'newTitle': newTitle,
        'markdown': markdown,
        'changeSummary': changeSummary,
      };
    }

    // The executor enforces the category policy and records the call and
    // its result.
    final result = await executor.execute(
      toolName: tool,
      args: canonicalArgs,
      targetEntityId: taskId,
      resolveCategoryId: resolveCategoryId,
      executeHandler: () => executeToolHandler(tool, canonicalArgs, manager),
      readVectorClock: readVectorClock,
    );
    manager.addToolResponse(toolCallId: callId, response: result.output);
    if (result.success) {
      _writtenDocuments.add(writtenKey);
      _recordSuccessfulMutation(
        tool,
        // Not the text: the report's editor needs only what was written.
        {...canonicalArgs}..remove('markdown'),
      );
    } else {
      // Whatever was read is no longer known to be what the document shows.
      _readDocumentVersions.remove(documentId);
    }
  }
}
