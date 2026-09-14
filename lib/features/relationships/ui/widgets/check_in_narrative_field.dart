import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
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
        // The recorder wears the accent: a live take is not an error, and
        // red on the field stays reserved for one. A landed transcript is
        // ordinary text again — the caption row says it landed, the filled
        // Save says what is next — so it rests like any other field.
        final border = switch (phase) {
          CheckInSpeechRecording() => tokens.colors.interactive.enabled,
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
          // Not an AnimatedSize: the tiered captions lay themselves out with
          // a LayoutBuilder, which re-dirties an animating size box in its
          // own layout pass. The phases swap in place instead.
          child: switch (phase) {
            CheckInSpeechIdle() => _typing(context),
            CheckInSpeechPreparing() => _typing(context, preparing: true),
            CheckInSpeechRecording() => _recording(context),
            CheckInSpeechTranscribing(:final length, :final route) =>
              _transcribing(context, length: length, route: route),
            CheckInSpeechReady() => _typing(context, ready: true),
            CheckInSpeechFailed(:final failure, :final cardDismissed) =>
              _typing(
                context,
                failure: failure,
                cardDismissed: cardDismissed,
              ),
          },
        );
      },
    );
  }

  Widget _textField(
    BuildContext context, {
    required String hint,
    int minLines = 5,
  }) {
    final tokens = context.designTokens;
    return TextField(
      key: const ValueKey('check-in-narrative'),
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
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
    bool cardDismissed = false,
  }) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    // *Type instead* on a missing transcript folds the card into one
    // caption row that keeps the retry.
    final collapsed = failure != null && cardDismissed;
    // Under a failure card the field is the way out, not the thing to read:
    // it starts short so the chips and More stay on a phone screen, and a
    // "0 words" count says nothing the card and the held Save do not.
    final underCard = failure != null && !collapsed;
    // One caption row: what just landed, how much there is, how to save —
    // a ladder, so a narrow line sheds the hint, then the count, and never
    // wraps on a separator. A zero count adds nothing the empty field does
    // not already say.
    final status = collapsed
        ? messages.checkInAudioSaved(checkInClockLabel(failure.length!))
        : ready
        ? messages.checkInTranscriptAdded
        : null;
    // Under a card with nothing typed, the field carries no caption at all:
    // the card is the message, and a lone shortcut hint only competes.
    final parts = [
      ?status,
      if (ready || wordCount > 0) messages.checkInWordCount(wordCount),
      if (shortcutHint case final hint? when !underCard || wordCount > 0)
        messages.checkInSaveShortcutHint(hint),
    ];
    final ladder = [
      for (var n = parts.length; n >= 1; n--) parts.take(n).join(' · '),
    ];
    final meta = ladder.isEmpty ? '' : ladder.first;
    // What landed reads at the medium tier; a bare count or hint stays low.
    final captionStyle = status == null
        ? caption
        : caption.copyWith(color: tokens.colors.text.mediumEmphasis);
    final actions = <Widget>[
      if (ready) ...[
        // Only while the transcript is exactly what landed: once it is
        // edited, taking it back out would take the edits with it.
        // Quiet, with its own glyph: the accent is for the way
        // forward, and Re-record must not read as a twin of Add more.
        if (onReRecord != null)
          DesignSystemButton(
            key: const ValueKey('check-in-re-record'),
            label: messages.checkInReRecordButton,
            leadingIcon: LottiIcons.refresh,
            variant: DesignSystemButtonVariant.quiet,
            size: DesignSystemButtonSize.medium,
            tapTargetSize: MaterialTapTargetSize.padded,
            onPressed: onReRecord,
          ),
        DesignSystemButton(
          key: const ValueKey('check-in-add-more'),
          label: messages.checkInAddMoreButton,
          leadingIcon: LottiIcons.mic,
          variant: DesignSystemButtonVariant.outlined,
          size: DesignSystemButtonSize.medium,
          tapTargetSize: MaterialTapTargetSize.padded,
          onPressed: onAddMore,
        ),
      ] else if (collapsed)
        DesignSystemButton(
          key: const ValueKey('check-in-retry-transcript'),
          label: messages.relationshipAgentTryAgain,
          leadingIcon: LottiIcons.refresh,
          variant: DesignSystemButtonVariant.tertiary,
          size: DesignSystemButtonSize.medium,
          tapTargetSize: MaterialTapTargetSize.padded,
          onPressed: onRetryTranscript,
        )
      // A take waiting for *Try again*, or a microphone the OS refused,
      // has its way forward on the card; a second recorder button in
      // the field would be a dead door beside a live one.
      else if (failure == null || _dictatesUnder(failure.kind))
        DesignSystemButton(
          key: const ValueKey('check-in-dictate'),
          label: messages.checkInDictateButton,
          leadingIcon: LottiIcons.mic,
          variant: DesignSystemButtonVariant.outlined,
          size: DesignSystemButtonSize.medium,
          isLoading: preparing,
          onPressed: preparing ? null : onDictate,
        ),
    ];
    // The actions sit in one corner across every phase: beside the caption
    // when both fit a line, else on their own line at the trailing edge —
    // always at large text, where even a lone button can crowd the caption.
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) > TextScales.large;
    final stacked =
        largeText ||
        (ready &&
            MediaQuery.sizeOf(context).width < WoltModalConfig.pageBreakpoint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (underCard) ...[
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
          hint: underCard
              ? messages.checkInOrTypeHint
              : messages.checkInNarrativeHint,
          // "One line is enough": the box says so by not asking for five.
          minLines: underCard ? 2 : 3,
        ),
        if (meta.isNotEmpty || actions.isNotEmpty)
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
        if (meta.isNotEmpty || actions.isNotEmpty)
          _CaptionAndActions(
            stacked: stacked,
            caption: meta.isEmpty
                ? null
                : Semantics(
                    liveRegion: ready,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ready || collapsed) ...[
                          Icon(
                            LottiIcons.confirmCircled,
                            key: ready
                                ? const ValueKey('check-in-transcript-added')
                                : const ValueKey('check-in-audio-saved'),
                            size: IconSizes.s,
                            color: tokens.colors.text.mediumEmphasis,
                          ),
                          SizedBox(width: tokens.spacing.step2),
                        ],
                        Flexible(
                          child: DsTieredText(
                            textKey: const ValueKey('check-in-word-count'),
                            tiers: ladder,
                            style: captionStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
            actions: actions,
          ),
      ],
    );
  }

  /// Whether the field keeps its own *Dictate* under a failure card of
  /// [kind]: not when the card's own retry is the way to record again.
  static bool _dictatesUnder(CheckInSpeechFailureKind kind) => switch (kind) {
    CheckInSpeechFailureKind.transcriptMissing ||
    CheckInSpeechFailureKind.microphoneDenied => false,
    CheckInSpeechFailureKind.recordingFailed ||
    CheckInSpeechFailureKind.recordingNotSaved ||
    CheckInSpeechFailureKind.recorderBusy ||
    CheckInSpeechFailureKind.transcriptionUnavailable => true,
  };

  /// The recorder in place of the text, under the line that says what
  /// happens next.
  Widget _recording(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The field's own text tier, centred like the recorder beneath it:
        // pressing Dictate must not change what size the box speaks in.
        Text(
          messages.checkInRecordingHint,
          key: const ValueKey('check-in-recording-hint'),
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodyLarge.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
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
        // Named, not live: the header's status line is the one announcer
        // of this phase, so a reader hears "Transcribing" once.
        Semantics(
          label: messages.checkInTranscribingLabel,
          child: const ExcludeSemantics(child: _TranscriptSkeleton()),
        ),
        SizedBox(height: tokens.spacing.step6),
        // A caption row, like the transcript-added line it precedes — not
        // a second box inside the field.
        // One caption row, like every other phase's: the saved line leading
        // and Type instead on the trailing edge, the route shed first on a
        // narrow phone.
        _CaptionAndActions(
          stacked: MediaQuery.textScalerOf(context).scale(1) > TextScales.large,
          caption: Row(
            key: const ValueKey('check-in-audio-saved'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LottiIcons.confirmCircled,
                size: IconSizes.s,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step2),
              Flexible(
                child: DsTieredText(
                  tiers: [
                    if (route != null)
                      messages.checkInAudioSavedRoute(clock, route),
                    messages.checkInAudioSaved(clock),
                  ],
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            DesignSystemButton(
              key: const ValueKey('check-in-type-instead'),
              label: messages.checkInTypeInstead,
              variant: DesignSystemButtonVariant.tertiary,
              size: DesignSystemButtonSize.medium,
              tapTargetSize: MaterialTapTargetSize.padded,
              onPressed: onTypeInstead,
            ),
          ],
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
          for (final (index, width) in const [0.85, 0.7, 0.55].indexed) ...[
            if (index > 0) SizedBox(height: tokens.spacing.step4),
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
        messages.checkInMicrophoneDeniedCalloutTitle,
        messages.checkInMicrophoneDeniedBody,
        (
          key: const ValueKey('check-in-open-settings'),
          label: messages.checkInOpenSettingsButton,
          icon: LottiIcons.settings,
          onPressed: onOpenSettings,
        ),
        // The body says "then try again", so the card offers exactly that;
        // typing a word instead lets the card go on its own.
        (
          key: const ValueKey('check-in-retry-audio'),
          label: messages.relationshipAgentTryAgain,
          onPressed: onDictate,
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
      CheckInSpeechFailureKind.recordingNotSaved => (
        alert.error.defaultColor,
        LottiIcons.micIdle,
        messages.checkInRecordingNotSavedTitle,
        messages.checkInRecordingNotSavedBody,
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
      CheckInSpeechFailureKind.recorderBusy => (
        alert.warning.defaultColor,
        LottiIcons.mic,
        messages.checkInRecorderBusyTitle,
        messages.checkInRecorderBusyBody,
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
        // The header already names the state; the card's title is the next
        // step. The provider's own detail, when it left any, is the body —
        // never a cause the service cannot tell apart.
        messages.checkInTranscriptMissingCalloutTitle,
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

    // The design system's own callout: the tone on the hairline and the
    // glyph, the surface's ink for the words, and the actions on the
    // trailing rail with the filled one last, like Save, Stop and Add more.
    return DesignSystemInlineCallout(
      key: const ValueKey('check-in-speech-failure'),
      icon: icon,
      tone: tone,
      title: title,
      text: body,
      // The recommended action is the secondary pill: the alert tone is the
      // card's one colour, and the filled accent stays Save's alone.
      actions: [
        // Typing is the recovery that always works, so the refused
        // microphone offers it as a button rather than as placeholder ink.
        if (failure.kind == CheckInSpeechFailureKind.microphoneDenied)
          DesignSystemButton(
            key: const ValueKey('check-in-type-instead-denied'),
            label: messages.checkInTypeInstead,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.medium,
            tapTargetSize: MaterialTapTargetSize.padded,
            onPressed: onTypeInstead,
          ),
        DesignSystemButton(
          key: secondary.key,
          label: secondary.label,
          variant: DesignSystemButtonVariant.tertiary,
          size: DesignSystemButtonSize.medium,
          tapTargetSize: MaterialTapTargetSize.padded,
          onPressed: secondary.onPressed,
        ),
        if (primary != null)
          DesignSystemButton(
            key: primary.key,
            label: primary.label,
            leadingIcon: primary.icon,
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.medium,
            tapTargetSize: MaterialTapTargetSize.padded,
            onPressed: primary.onPressed,
          ),
      ],
    );
  }
}

/// The field's footer: a caption and its actions beside each other when
/// they share a line, or — [stacked] — the caption above and the actions on
/// their own line at the trailing edge, so Dictate, Try again and
/// Re-record · Add more all live in the same corner across phases and text
/// scales.
class _CaptionAndActions extends StatelessWidget {
  const _CaptionAndActions({
    required this.stacked,
    required this.caption,
    required this.actions,
  });

  final bool stacked;
  final Widget? caption;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final group = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: actions,
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption case final caption?) ...[
            caption,
            SizedBox(height: tokens.spacing.step3),
          ],
          Align(alignment: AlignmentDirectional.centerEnd, child: group),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: caption ?? const SizedBox.shrink()),
        if (actions.isNotEmpty) ...[
          SizedBox(width: tokens.spacing.step3),
          group,
        ],
      ],
    );
  }
}
