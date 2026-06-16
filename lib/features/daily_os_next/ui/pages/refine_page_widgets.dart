part of 'refine_page.dart';

class _RefinementPanel extends ConsumerWidget {
  const _RefinementPanel({
    required this.draft,
    required this.state,
  });

  final DraftPlan draft;
  final RefineState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final notifier = ref.read(refineControllerProvider(draft).notifier);
    // Only the phase here — orb and waveform watch the meter fields
    // themselves so amplitude ticks don't rebuild the whole panel.
    final capturePhase = ref.watch(
      captureControllerProvider.select((s) => s.phase),
    );
    final captureNotifier = ref.read(captureControllerProvider.notifier);
    final messages = context.messages;

    listenCaptureForRefine(ref, draft);

    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The side panel has no other title, so it keeps the eyebrow.
          Text(
            messages.dailyOsNextRefineOverline,
            style: calmEyebrowStyle(tokens, color: teal),
          ),
          // step6 clearance: the listening shader spills past the orb's
          // layout field (which no longer reserves the old +128 padding),
          // so the neighbours need room for it to breathe.
          SizedBox(height: tokens.spacing.step6),
          Center(
            child: Consumer(
              builder: (context, ref, _) {
                final dbfs = ref.watch(
                  captureControllerProvider.select((s) => s.dbfs),
                );
                return VoiceButton(
                  phase: refineOrbPhaseFor(state.phase, capturePhase),
                  dbfs: dbfs,
                  semanticLabel: refineVoiceLabel(context, state.phase),
                  size: 88,
                  onTap: () {
                    handleRefineVoiceTap(
                      refineState: state,
                      refineNotifier: notifier,
                      captureNotifier: captureNotifier,
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: tokens.spacing.step6),
          _StatusLine(state: state),
          if (state.problem != null) ...[
            SizedBox(height: tokens.spacing.step3),
            _ProblemNotice(
              problem: state.problem!,
            ),
          ],
          if (state.phase == RefinePhase.listening) ...[
            SizedBox(height: tokens.spacing.step3),
            Center(
              child: Consumer(
                builder: (context, ref, _) {
                  final amplitudes = ref.watch(
                    captureControllerProvider.select((s) => s.amplitudes),
                  );
                  return LiveWaveform(
                    amplitudes: amplitudes,
                    width: 180,
                    height: 22,
                  );
                },
              ),
            ),
          ],
          if (state.phase == RefinePhase.reviewing) ...[
            SizedBox(height: tokens.spacing.step3),
            _TranscriptReview(draft: draft, transcript: state.transcript),
          ] else if (state.transcript.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.step3),
            _TranscriptCard(
              transcript: state.transcript,
              listening: state.phase == RefinePhase.listening,
            ),
          ],
          if (state.diff != null) ...[
            SizedBox(height: tokens.spacing.step4),
            for (final change in state.diff!.changes) ...[
              DiffRow(
                change: change,
                decision: state.decisionFor(change),
                resolving: state.resolvingChangeId == change.id,
                onAccept: () => notifier.acceptChange(change.id),
                onReject: () => notifier.rejectChange(change.id),
              ),
              SizedBox(height: tokens.spacing.step3),
            ],
            _ActionRow(draft: draft),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.04),
        border: Border(
          left: BorderSide(color: teal.withValues(alpha: 0.18)),
        ),
      ),
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: content,
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final RefineState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final (text, color) = switch (state.phase) {
      RefinePhase.idle => (
        messages.dailyOsNextRefineStatusIdle,
        tokens.colors.text.mediumEmphasis,
      ),
      RefinePhase.listening => (
        messages.dailyOsNextRefineStatusListening,
        tokens.colors.interactive.enabled,
      ),
      RefinePhase.reviewing => (
        messages.dailyOsNextCaptureCaptured,
        tokens.colors.interactive.enabled,
      ),
      RefinePhase.thinking => (
        messages.dailyOsNextRefineStatusThinking,
        tokens.colors.interactive.enabled,
      ),
      RefinePhase.diffReady => (
        messages.dailyOsNextRefineStatusDiffReady,
        tokens.colors.alert.success.defaultColor,
      ),
      RefinePhase.accepted => (
        messages.dailyOsNextRefineStatusAccepted,
        tokens.colors.alert.success.defaultColor,
      ),
    };
    return Text(
      text,
      textAlign: TextAlign.center,
      style: tokens.typography.styles.body.bodySmall.copyWith(color: color),
    );
  }
}

class _ProblemNotice extends StatelessWidget {
  const _ProblemNotice({
    required this.problem,
  });

  final RefineProblem problem;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final message = switch (problem) {
      RefineProblem.noChanges => context.messages.dailyOsNextRefineNoChanges,
      RefineProblem.proposalFailed => context.messages.dailyOsNextGenericError,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.alert.error.defaultColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(
          color: tokens.colors.alert.error.defaultColor.withValues(alpha: 0.36),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step3),
        child: Text(
          message,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.alert.error.defaultColor,
          ),
        ),
      ),
    );
  }
}

class _TranscriptReview extends ConsumerWidget {
  const _TranscriptReview({required this.draft, required this.transcript});

  final DraftPlan draft;
  final String transcript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final notifier = ref.read(refineControllerProvider(draft).notifier);
    final canSubmit = transcript.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TranscriptEditor(
          fieldKey: const Key('daily_os_refine_transcript_editor'),
          transcript: transcript,
          onChanged: notifier.updateTranscript,
        ),
        SizedBox(height: tokens.spacing.step3),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: canSubmit
                ? () => unawaited(notifier.submitReviewedTranscript())
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(context.messages.dailyOsNextRefineTitle),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.colors.interactive.enabled,
              foregroundColor: tokens.colors.text.onInteractiveAlert,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radii.m),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.transcript, required this.listening});

  final String transcript;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Text(
        transcript,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.highEmphasis,
          fontStyle: listening ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.draft});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final messages = context.messages;
    final notifier = ref.read(refineControllerProvider(draft).notifier);
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      alignment: WrapAlignment.end,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.undo_rounded, size: 14),
          label: Text(messages.dailyOsNextRefineRevert),
          style: TextButton.styleFrom(
            foregroundColor: tokens.colors.text.mediumEmphasis,
          ),
          onPressed: notifier.revert,
        ),
        TextButton.icon(
          icon: Icon(Icons.mic_rounded, size: 14, color: teal),
          label: Text(messages.dailyOsNextRefineKeepTalking),
          style: TextButton.styleFrom(foregroundColor: teal),
          onPressed: notifier.keepTalking,
        ),
      ],
    );
  }
}
