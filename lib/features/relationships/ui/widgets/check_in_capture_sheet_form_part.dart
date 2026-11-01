part of 'check_in_capture_sheet.dart';

/// Check-in form helpers that write no state themselves: dirtiness, dismissal, publishing, transcription and label routing. State writes stay in the State (the repo's extension-split rule).
extension _CheckInCaptureFormActions on _CheckInCaptureFormState {
  /// Whether leaving now would lose something: text, details or context
  /// that differ from what the composer opened with, or a recording.
  bool get _isDirty {
    final initial = widget.initial;
    final data = initial?.data;
    if (_narrativeController.text.trim() !=
        (initial?.entryText?.plainText ?? '').trim()) {
      return true;
    }
    if (_interactionType != _openingType ||
        _interactionTime != _openingTime ||
        _duration != _openingDuration) {
      return true;
    }
    if (_topicsController.text.trim() != (data?.topics.join(', ') ?? '')) {
      return true;
    }
    if (_payAttentionController.text.trim() != (data?.payAttentionTo ?? '')) {
      return true;
    }
    if (_avoidController.text.trim() != (data?.avoid ?? '')) return true;
    if (_sentiment != data?.sentiment) return true;
    // A recorder that failed to start recorded nothing: a composer opened
    // speaking, onto a busy recorder, still closes at once.
    final speaking = switch (_phase) {
      CheckInSpeechIdle() || CheckInSpeechFailed() => false,
      _ => true,
    };
    return speaking || _takes.isNotEmpty;
  }

  /// Leaves the composer, asking first when [_isDirty]. The question names
  /// a running recording, and confirming discards the take with the draft:
  /// a button labelled Discard must discard, not leave a recorder running
  /// behind a closed sheet.
  Future<void> _dismiss() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    // A stop already in flight holds the sheet: `cancel` would return at
    // once without discarding anything, and the take would land in the
    // journal behind a closed sheet. It lands within a moment, and the
    // composer then asks the ordinary question.
    if (_phase is CheckInSpeechRecording &&
        (widget.handle.recorder?.isFinishing ?? false)) {
      return;
    }
    final messages = context.messages;
    // The question says what discarding does to the audio: a live take is
    // deleted with the draft; a recording already in the journal stays.
    final confirmed = await showConfirmationModal(
      context: context,
      message: switch (_phase) {
        CheckInSpeechRecording() =>
          messages.checkInDiscardDraftRecordingMessage,
        _ when _takes.isNotEmpty =>
          messages.checkInDiscardDraftAudioKeptMessage,
        _ => messages.checkInDiscardDraftMessage,
      },
      confirmLabel: messages.audioRecordingDiscardDialogConfirm,
    );
    if (!confirmed || !mounted) return;
    if (_phase is CheckInSpeechRecording) {
      await widget.handle.recorder?.cancel();
      if (!mounted) return;
    }
    Navigator.of(context).pop();
  }

  /// The chrome reads the form through its handle; publish after the frame
  /// so a listener never rebuilds while this widget is still building.
  void _publish(BuildContext context, {required bool recorderPaused}) {
    final messages = context.messages;
    final block = _block;
    final status = checkInComposerStatusOf(
      _phase,
      recorderPaused: recorderPaused,
    );
    final summary = messages.checkInContextSummary(
      checkInInteractionLabel(context, _interactionType),
      _startedLabel(context),
      _duration == Duration.zero
          ? messages.checkInNoDuration
          : checkInDurationLabel(context, _duration),
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.handle.publish(
        save: _handleSave,
        delete: _isEditing ? _handleDelete : null,
        dismiss: _dismiss,
        unfocus: _narrativeFocus.unfocus,
        block: block,
        status: status,
        summary: summary,
        fieldFocused: _narrativeFocus.hasFocus,
      );
    });
  }

  /// Asks for the words of [audioEntryId] and shows them on its take when
  /// they land, filling the start, length and channel they name into the
  /// chips the user has not chosen (`_fillFromDictation`). The recorder suppressed automatic inference for this
  /// capture; the transcription service owns the one explicit request, and
  /// runs on after the sheet closes — the words land on the recording, and
  /// the service tells the saved check-in (ADR 0062).
  ///
  /// With [request] false it only listens again, for a take whose request is
  /// still running (a take put back by *Undo*): asking twice would run
  /// inference twice. A [retry] answers the failure already on record, so
  /// that failure is cleared first — the run clears it too, but only after
  /// awaits of its own, and the watch below would read it back at once and
  /// end the retry before it began.
  Future<void> _transcribe(
    String audioEntryId, {
    bool request = true,
    bool retry = false,
  }) async {
    final transcription = ref.read(checkInTranscriptionServiceProvider);
    final messages = context.messages;
    _updateTake(audioEntryId, (take) => take.transcribing());
    // The route is a courtesy on the take's line: a slow read must never
    // hold the transcript, and a failed one must never fail it. A take
    // listened to again still carries the one it was given.
    if (request) {
      unawaited(
        _labelRoute(
          transcription,
          audioEntryId: audioEntryId,
          via: messages.taskAgentRouteVia,
        ),
      );
    }

    final failure = inferenceErrorControllerProvider((
      id: audioEntryId,
      aiResponseType: AiResponseType.audioTranscription,
    ));
    if (retry) ref.read(failure.notifier).setError(null);

    _closeTranscriptWait(audioEntryId);
    final wait = _transcriptWaits[audioEntryId] = request
        ? transcription.transcribe(
            summarize: true,
            audioEntryId: audioEntryId,
            relationshipId: widget.relationshipId,
          )
        : transcription.watch(audioEntryId: audioEntryId);
    // Preserve the provider's error detail for the take, including a
    // failure that arrived before this subscription was attached.
    String? failureDetail;
    _transcriptFailures[audioEntryId] = ref.listenManual<String?>(
      failure,
      (previous, next) {
        final detail = next?.trim();
        if (detail == null || detail.isEmpty) return;
        failureDetail = detail;
        wait.cancel();
      },
      fireImmediately: true,
    );
    try {
      final transcript = await wait.result;
      if (!mounted || !_holds(audioEntryId)) return;
      _updateTake(
        audioEntryId,
        (take) => transcript == null
            ? take.missing(failureDetail)
            : take.heard(transcript),
      );
      // The words stay on their take; only the chips they speak about move.
      if (transcript != null) _fillFromDictation();
    } finally {
      if (identical(_transcriptWaits[audioEntryId], wait)) {
        _forgetTranscriptWait(audioEntryId);
      }
    }
  }

  Future<void> _labelRoute(
    CheckInTranscriptionService transcription, {
    required String audioEntryId,
    required String via,
  }) async {
    final CheckInTranscriptionRoute? route;
    try {
      route = await transcription.route(
        relationshipId: widget.relationshipId,
      );
    } catch (exception, stackTrace) {
      _logger.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'CheckInCaptureForm',
        message: 'Could not name the transcription route',
      );
      return;
    }
    if (route == null) return;
    final label = '${route.model} · $via ${route.provider}';
    _updateTake(audioEntryId, (take) => take.withRoute(label));
  }
}
