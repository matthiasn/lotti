import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The composer's one field (design 2026-09-13): the narrative, with
/// *Dictate* inside it. Recording, transcribing, transcript-ready and both
/// failure cards render **in place of the text**, so the user never leaves
/// the thing they are writing.
///
/// Presentational: every phase comes in as [phase] and every way out goes
/// back as a callback. The form owns the recorder, the transcript wait and
/// the text; this widget only decides what the box shows for each phase.
class CheckInNarrativeField extends StatelessWidget {
  const CheckInNarrativeField({
    required this.controller,
    required this.focusNode,
    required this.phase,
    required this.wordCount,
    required this.recorder,
    required this.onDictate,
    required this.onAddMore,
    required this.onReRecord,
    required this.onTypeInstead,
    required this.onRetryTranscript,
    required this.onOpenSettings,
    required this.onDismissFailure,
    this.shortcutHint,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final CheckInSpeechPhase phase;
  final int wordCount;

  /// The inline recorder, built by the form while [phase] is
  /// [CheckInSpeechRecording]; ignored otherwise.
  final Widget? recorder;

  /// *Dictate*: start a recording. Null while the composer cannot.
  final VoidCallback? onDictate;

  /// *Add more*: record again and append below the transcript.
  final VoidCallback? onAddMore;

  /// *Re-record*: take the transcript back out and record again.
  final VoidCallback? onReRecord;

  /// *Type instead*: stop waiting for words and hand the field back.
  final VoidCallback? onTypeInstead;

  /// *Try again* on a missing transcript: ask for it once more.
  final VoidCallback? onRetryTranscript;

  /// *Open settings* on a denied microphone.
  final VoidCallback? onOpenSettings;

  /// *Dismiss* a failure card.
  final VoidCallback? onDismissFailure;

  /// `⌘↩ to save`, on a desktop with a keyboard; null elsewhere.
  final String? shortcutHint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final border = switch (phase) {
          CheckInSpeechRecording() => tokens.colors.alert.error.defaultColor,
          CheckInSpeechReady() => tokens.colors.interactive.enabled,
          _ =>
            focusNode.hasFocus
                ? tokens.colors.interactive.enabled
                : tokens.colors.decorative.level01,
        };
        return AnimatedContainer(
          key: const ValueKey('check-in-narrative-field'),
          duration: MotionDurations.short4,
          curve: MotionCurves.standard,
          decoration: BoxDecoration(
            color: tokens.colors.background.level01,
            borderRadius: BorderRadius.circular(tokens.radii.l),
            border: Border.all(color: border),
          ),
          padding: EdgeInsets.all(tokens.spacing.step5),
          child: switch (phase) {
            CheckInSpeechIdle() => _typing(context),
            CheckInSpeechPreparing() => _typing(context, preparing: true),
            CheckInSpeechRecording() => _recording(context),
            CheckInSpeechTranscribing(:final length, :final route) =>
              _transcribing(context, length: length, route: route),
            CheckInSpeechReady() => _typing(context, ready: true),
            CheckInSpeechFailed(:final failure) => _typing(
              context,
              failure: failure,
            ),
          },
        );
      },
    );
  }

  Widget _textField(BuildContext context, {required String hint}) {
    final tokens = context.designTokens;
    return TextField(
      key: const ValueKey('check-in-narrative'),
      controller: controller,
      focusNode: focusNode,
      minLines: 5,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      style: tokens.typography.styles.body.bodyLarge.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
      decoration: InputDecoration.collapsed(
        hintText: hint,
        hintStyle: tokens.typography.styles.body.bodyLarge.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      ),
    );
  }

  /// The field as text — plain, after a transcript, while preparing, or
  /// under a failure card — with the word count and the one speech action
  /// in its footer.
  Widget _typing(
    BuildContext context, {
    bool preparing = false,
    bool ready = false,
    CheckInSpeechFailure? failure,
  }) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final count = messages.checkInWordCount(wordCount);
    final meta = shortcutHint == null
        ? count
        : '$count · ${messages.checkInSaveShortcutHint(shortcutHint!)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failure != null) ...[
          _FailureCard(
            failure: failure,
            onRetryTranscript: onRetryTranscript,
            onOpenSettings: onOpenSettings,
            onDictate: onDictate,
            onTypeInstead: onDismissFailure,
            onDismiss: onDismissFailure,
          ),
          SizedBox(height: tokens.spacing.step4),
        ],
        _textField(
          context,
          hint: failure == null
              ? messages.checkInNarrativeHint
              : messages.checkInOrTypeHint,
        ),
        if (ready) ...[
          SizedBox(height: tokens.spacing.step4),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(
                  LottiIcons.confirmCircled,
                  size: IconSizes.s,
                  color: tokens.colors.interactive.enabled,
                ),
                SizedBox(width: tokens.spacing.step2),
                Expanded(
                  child: Text(
                    messages.checkInTranscriptAdded,
                    key: const ValueKey('check-in-transcript-added'),
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (failure?.hasRecording ?? false) ...[
          SizedBox(height: tokens.spacing.step4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LottiIcons.info,
                size: IconSizes.s,
                color: tokens.colors.text.lowEmphasis,
              ),
              SizedBox(width: tokens.spacing.step2),
              Expanded(
                child: Text(
                  messages.checkInAudioKeptNote,
                  key: const ValueKey('check-in-audio-kept'),
                  style: caption,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: tokens.spacing.step4),
        if (preparing)
          Semantics(
            liveRegion: true,
            child: Text(
              messages.checkInPreparingLabel,
              key: const ValueKey('check-in-preparing'),
              style: caption,
            ),
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step3,
          children: [
            Text(
              meta,
              key: const ValueKey('check-in-word-count'),
              style: caption,
            ),
            if (ready)
              Wrap(
                spacing: tokens.spacing.step3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DesignSystemButton(
                    key: const ValueKey('check-in-re-record'),
                    label: messages.checkInReRecordButton,
                    variant: DesignSystemButtonVariant.tertiary,
                    size: DesignSystemButtonSize.medium,
                    onPressed: onReRecord,
                  ),
                  DesignSystemButton(
                    key: const ValueKey('check-in-add-more'),
                    label: messages.checkInAddMoreButton,
                    leadingIcon: LottiIcons.mic,
                    variant: DesignSystemButtonVariant.outlined,
                    size: DesignSystemButtonSize.medium,
                    onPressed: onAddMore,
                  ),
                ],
              )
            else
              DesignSystemButton(
                key: const ValueKey('check-in-dictate'),
                label: messages.checkInDictateButton,
                leadingIcon:
                    failure?.kind == CheckInSpeechFailureKind.microphoneDenied
                    ? LottiIcons.micIdle
                    : LottiIcons.mic,
                variant: DesignSystemButtonVariant.constructiveOutlined,
                size: DesignSystemButtonSize.medium,
                isLoading: preparing,
                onPressed: preparing ? null : onDictate,
              ),
          ],
        ),
      ],
    );
  }

  /// The recorder in place of the text, under the line that says what
  /// happens next.
  Widget _recording(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          messages.checkInRecordingHint,
          key: const ValueKey('check-in-recording-hint'),
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step6),
        ?recorder,
      ],
    );
  }

  /// Placeholder lines where the words will land, the saved-audio line, and
  /// the way out for someone who would rather type.
  Widget _transcribing(
    BuildContext context, {
    required Duration length,
    required String? route,
  }) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final clock = checkInClockLabel(length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          label: messages.checkInTranscribingLabel,
          child: const ExcludeSemantics(child: _TranscriptSkeleton()),
        ),
        SizedBox(height: tokens.spacing.step6),
        Container(
          key: const ValueKey('check-in-audio-saved'),
          padding: EdgeInsets.all(tokens.spacing.step4),
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.m),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LottiIcons.confirmCircled,
                size: IconSizes.s,
                color: tokens.colors.interactive.enabled,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  route == null
                      ? messages.checkInAudioSaved(clock)
                      : messages.checkInAudioSavedRoute(clock, route),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: DesignSystemButton(
            key: const ValueKey('check-in-type-instead'),
            label: messages.checkInTypeInstead,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.medium,
            onPressed: onTypeInstead,
          ),
        ),
      ],
    );
  }
}

/// Three quiet lines standing in for the transcript, breathing slowly —
/// and holding still for a reduced-motion reader, who still has the header
/// and the live region to say what is happening.
class _TranscriptSkeleton extends StatefulWidget {
  const _TranscriptSkeleton();

  @override
  State<_TranscriptSkeleton> createState() => _TranscriptSkeletonState();
}

class _TranscriptSkeletonState extends State<_TranscriptSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: MotionDurations.long2,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return FadeTransition(
      opacity: Tween<double>(
        begin: SurfaceAlphas.muted,
        end: 1,
      ).animate(CurvedAnimation(parent: _pulse, curve: MotionCurves.standard)),
      child: Column(
        key: const ValueKey('check-in-transcript-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final width in const [0.85, 0.7, 0.55]) ...[
            FractionallySizedBox(
              widthFactor: width,
              child: Container(
                height: tokens.spacing.step4,
                decoration: BoxDecoration(
                  color: tokens.colors.background.level03,
                  borderRadius: BorderRadius.circular(tokens.radii.s),
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
          ],
        ],
      ),
    );
  }
}

/// The card at the top of the field when speech failed (options 1e / 1f):
/// tone by kind, the reason in plain words, the one thing to do about it,
/// and the way out for someone who would rather type.
class _FailureCard extends StatelessWidget {
  const _FailureCard({
    required this.failure,
    required this.onRetryTranscript,
    required this.onOpenSettings,
    required this.onDictate,
    required this.onTypeInstead,
    required this.onDismiss,
  });

  final CheckInSpeechFailure failure;
  final VoidCallback? onRetryTranscript;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onDictate;
  final VoidCallback? onTypeInstead;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final alert = tokens.colors.alert;
    final length = failure.length == null
        ? null
        : checkInClockLabel(failure.length!);

    final (
      tone,
      icon,
      title,
      body,
      primary,
      secondary,
    ) = switch (failure.kind) {
      CheckInSpeechFailureKind.microphoneDenied => (
        alert.error.defaultColor,
        LottiIcons.micIdle,
        messages.checkInMicrophoneDeniedTitle,
        messages.checkInMicrophoneDeniedBody,
        (
          key: const ValueKey('check-in-open-settings'),
          label: messages.checkInOpenSettingsButton,
          icon: null,
          onPressed: onOpenSettings,
        ),
        (
          key: const ValueKey('check-in-dismiss-failure'),
          label: messages.checkInDismissButton,
          onPressed: onDismiss,
        ),
      ),
      CheckInSpeechFailureKind.recordingFailed => (
        alert.error.defaultColor,
        LottiIcons.micIdle,
        messages.checkInRecordingFailedTitle,
        messages.checkInRecordingFailedBody,
        (
          key: const ValueKey('check-in-retry-audio'),
          label: messages.relationshipAgentTryAgain,
          icon: LottiIcons.refresh,
          onPressed: onDictate,
        ),
        (
          key: const ValueKey('check-in-dismiss-failure'),
          label: messages.checkInTypeInstead,
          onPressed: onTypeInstead,
        ),
      ),
      CheckInSpeechFailureKind.transcriptionUnavailable => (
        alert.warning.defaultColor,
        LottiIcons.transcribe,
        messages.checkInTranscriptionUnavailableTitle,
        messages.checkInTranscriptUnavailable,
        null,
        (
          key: const ValueKey('check-in-dismiss-failure'),
          label: messages.checkInTypeInstead,
          onPressed: onTypeInstead,
        ),
      ),
      CheckInSpeechFailureKind.transcriptMissing => (
        alert.warning.defaultColor,
        LottiIcons.cloudOff,
        messages.checkInTranscriptMissingTitle,
        failure.detail ?? messages.checkInTranscriptMissingBody(length ?? ''),
        (
          key: const ValueKey('check-in-retry-transcript'),
          label: messages.relationshipAgentTryAgain,
          icon: LottiIcons.refresh,
          onPressed: onRetryTranscript,
        ),
        (
          key: const ValueKey('check-in-dismiss-failure'),
          label: messages.checkInTypeInstead,
          onPressed: onTypeInstead,
        ),
      ),
    };

    return Container(
      key: const ValueKey('check-in-speech-failure'),
      padding: EdgeInsets.all(tokens.spacing.step5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tone.withValues(alpha: SurfaceAlphas.tint),
          tokens.colors.background.level01,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: tone.withValues(alpha: SurfaceAlphas.muted),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: IconSizes.l, color: tone),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    title,
                    key: const ValueKey('check-in-speech-failure-title'),
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.step2),
                Text(
                  body,
                  key: const ValueKey('check-in-speech-failure-body'),
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step4),
                Wrap(
                  spacing: tokens.spacing.step3,
                  runSpacing: tokens.spacing.step3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (primary != null)
                      DesignSystemButton(
                        key: primary.key,
                        label: primary.label,
                        leadingIcon: primary.icon,
                        size: DesignSystemButtonSize.medium,
                        onPressed: primary.onPressed,
                      ),
                    DesignSystemButton(
                      key: secondary.key,
                      label: secondary.label,
                      variant: DesignSystemButtonVariant.tertiary,
                      size: DesignSystemButtonSize.medium,
                      onPressed: secondary.onPressed,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
