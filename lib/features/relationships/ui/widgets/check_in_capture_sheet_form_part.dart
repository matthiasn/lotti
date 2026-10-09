part of 'check_in_capture_sheet.dart';

/// Check-in form helpers that write no state themselves: the More caption, dirtiness, dismissal, publishing, transcription and label routing. State writes stay in the State (the repo's extension-split rule).
extension _CheckInCaptureFormActions on _CheckInCaptureFormState {
  /// The folded More row's caption from what is set: a field's name until it
  /// has a value, then the value itself.
  String _moreCaption(AppLocalizations messages) {
    final topics = _topicsController.text
        .split(',')
        .map((topic) => topic.trim())
        .where((topic) => topic.isNotEmpty)
        .length;
    final nextTime =
        _payAttentionController.text.trim().isNotEmpty ||
        _avoidController.text.trim().isNotEmpty;
    final feeling = switch (_sentiment) {
      null => messages.checkInMoreCaptionFeeling,
      final sentiment => checkInSentimentLabel(context, sentiment),
    };
    final topicsCaption = topics == 0
        ? messages.checkInMoreCaptionTopics
        : messages.checkInMoreCaptionTopicsCount(topics);
    final nextTimeCaption = nextTime
        ? messages.checkInMoreCaptionNextTimeSet
        : messages.checkInMoreCaptionNextTime;
    return [feeling, topicsCaption, nextTimeCaption].join(' · ');
  }

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
    return _phase is! CheckInSpeechIdle || _takes.isNotEmpty;
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
      takes: _takes,
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
  Future<void> _transcribe(String audioEntryId) async {
    final transcription = ref.read(checkInTranscriptionServiceProvider);
    final messages = context.messages;
    _updateTake(audioEntryId, (take) => take.transcribing());
    // The route is a courtesy on the take's line: a slow read must never
    // hold the transcript, and a failed one must never fail it.
    unawaited(
      _labelRoute(
        transcription,
        audioEntryId: audioEntryId,
        via: messages.taskAgentRouteVia,
      ),
    );

    _closeTranscriptWait(audioEntryId);
    final wait = _transcriptWaits[audioEntryId] = transcription.transcribe(
      audioEntryId: audioEntryId,
      relationshipId: widget.relationshipId,
    );
    // Preserve the provider's error detail for the take, including a
    // failure that arrived before this subscription was attached.
    String? failureDetail;
    _transcriptFailures[audioEntryId] = ref.listenManual<String?>(
      inferenceErrorControllerProvider((
        id: audioEntryId,
        aiResponseType: AiResponseType.audioTranscription,
      )),
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
      route = await transcription.route();
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
