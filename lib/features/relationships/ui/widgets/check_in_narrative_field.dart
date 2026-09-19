import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The composer's one field (design 2026-09-13): the note, with *Dictate*
/// inside it, and beneath the note the recordings made so far. The
/// recorder and its failure cards render **in place of the text**, so the
/// user never leaves the thing they are writing.
///
/// A recording is its own entry of the check-in (ADR 0062): its words land
/// on it, shown as the take's preview, never merged into the note — and
/// Save does not wait for them.
///
/// Presentational: every phase and take comes in, and every way out goes
/// back as a callback. The form owns the recorder, the transcript waits and
/// the text; this widget only decides what the box shows.
class CheckInNarrativeField extends StatelessWidget {
  const CheckInNarrativeField({
    required this.controller,
    required this.focusNode,
    required this.phase,
    required this.wordCount,
    required this.recorder,
    required this.onDictate,
    required this.onOpenSettings,
    required this.onDismissFailure,
    this.takes = const [],
    this.onRetryTake,
    this.onRemoveTake,
    this.shortcutHint,
    this.restMinLines = 3,
    this.offersDictation = true,
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

  /// *Open settings* on a denied microphone.
  final VoidCallback? onOpenSettings;

  /// *Type instead* on a failure card.
  final VoidCallback? onDismissFailure;

  /// The recordings made in this composer, oldest first.
  final List<CheckInTake> takes;

  /// *Try again* on a take whose words never came, by audio entry id.
  final ValueChanged<String>? onRetryTake;

  /// *Remove recording*: leave a take out of the check-in, by audio entry
  /// id. The audio stays in the journal.
  final ValueChanged<String>? onRemoveTake;

  /// `⌘↩ to save`, on a desktop with a keyboard; null elsewhere.
  final String? shortcutHint;

  /// The empty field's height at rest — shorter in the desktop dialog,
  /// where a tall empty box is dead space beside a working keyboard.
  final int restMinLines;

  /// Whether the field offers *Dictate* at all. Not when editing a saved
  /// check-in: its timeline is where recordings are added to it.
  final bool offersDictation;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        // The accent hairline means one thing on the field: keyboard focus,
        // the app-wide convention. The red dot, the waveform and the filled
        // Stop already say "live".
        final border = focusNode.hasFocus
            ? tokens.colors.interactive.enabled
            : tokens.colors.decorative.level01;
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
            CheckInSpeechFailed(:final failure) => _typing(
              context,
              failure: failure,
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
    bool quietHint = false,
  }) {
    final tokens = context.designTokens;
    // Under a failure card the placeholder steps down a tier: the card's
    // title is the thing to read, and a bodyLarge hint beneath a bodySmall
    // card body would invert the field's own ladder.
    final hintTier = quietHint
        ? tokens.typography.styles.body.bodyMedium
        : tokens.typography.styles.body.bodyLarge;
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
      // The box above draws the field's one frame. `collapsed` only clears
      // `border`: the app's InputDecorationTheme would still fill in its
      // 2.5 px focused outline, a second ring inside the accent hairline.
      decoration:
          InputDecoration.collapsed(
            hintText: hint,
            hintStyle: hintTier.copyWith(color: tokens.colors.text.lowEmphasis),
          ).copyWith(
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
          ),
    );
  }

  /// The field as text — plain, while preparing, or under a failure card —
  /// then the takes, then the word count and *Dictate* in its footer.
  Widget _typing(
    BuildContext context, {
    bool preparing = false,
    CheckInSpeechFailure? failure,
  }) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // The medium tier, like the More row and the footer reason: low
    // emphasis is for placeholders only.
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    // Under a failure card the field is the way out, not the thing to read:
    // it starts short so the chips and More stay on a phone screen, and a
    // "0 words" count says nothing the card and the held Save do not.
    final underCard = failure != null;
    // What there is, and how to save — a ladder, so a narrow line sheds the
    // count before the shortcut and never wraps on a separator. A zero
    // count adds nothing the empty field does not already say.
    final count = wordCount > 0 ? messages.checkInWordCount(wordCount) : null;
    // The shortcut only once there is something to save with it: beside a
    // held Save, a working shortcut is a promise the footer contradicts.
    final hint = switch (shortcutHint) {
      final hint? when wordCount > 0 || takes.isNotEmpty =>
        messages.checkInSaveShortcutHint(hint),
      _ => null,
    };
    final ladder = <String>{
      for (final keep in [
        [count, hint],
        if (count != null && hint != null) [hint],
      ])
        keep.nonNulls.join(' · '),
    }.where((tier) => tier.isNotEmpty).toList();
    final actions = <Widget>[
      // Under the refused microphone the field's Dictate is the retry, one
      // tier down: the card's pill is the face's one shape.
      if (offersDictation)
        DesignSystemButton(
          key: const ValueKey('check-in-dictate'),
          label: messages.checkInDictateButton,
          leadingIcon: LottiIcons.mic,
          variant: underCard
              ? DesignSystemButtonVariant.tertiary
              : DesignSystemButtonVariant.outlined,
          size: DesignSystemButtonSize.medium,
          isLoading: preparing,
          onPressed: preparing ? null : onDictate,
        ),
    ];
    // The actions sit in one corner: beside the caption when both fit a
    // line, else on their own line at the trailing edge — always at large
    // text, where even a lone button can crowd the caption.
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > TextScales.large;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failure != null) ...[
          _FailureCard(
            failure: failure,
            onOpenSettings: onOpenSettings,
            onDictate: onDictate,
            onTypeInstead: onDismissFailure,
          ),
          SizedBox(height: tokens.spacing.step4),
        ],
        _textField(
          context,
          hint: underCard
              ? messages.checkInOrTypeHint
              : messages.checkInNarrativeHint,
          // "One line is enough": the box says so by not asking for five.
          // Neither does it beside a recording, which already says it.
          minLines: underCard || takes.isNotEmpty ? 1 : restMinLines,
          quietHint: underCard,
        ),
        for (final take in takes) ...[
          SizedBox(height: tokens.spacing.step4),
          CheckInTakeRow(
            key: ValueKey('check-in-take-${take.audioEntryId}'),
            take: take,
            onRetry: onRetryTake == null
                ? null
                : () => onRetryTake!(take.audioEntryId),
            onRemove: onRemoveTake == null
                ? null
                : () => onRemoveTake!(take.audioEntryId),
          ),
        ],
        if (ladder.isNotEmpty || actions.isNotEmpty)
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
        if (ladder.isNotEmpty || actions.isNotEmpty)
          _CaptionAndActions(
            stacked: stacked,
            caption: ladder.isEmpty
                ? null
                : DsTieredText(
                    textKey: const ValueKey('check-in-word-count'),
                    tiers: ladder,
                    style: caption,
                  ),
            actions: actions,
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
}

/// One recording under the note: its length and where its words are on
/// the first line, then the words themselves, the promise that they
/// follow, or the way to ask again — and *Remove recording* on the
/// trailing edge.
class CheckInTakeRow extends StatelessWidget {
  const CheckInTakeRow({
    required this.take,
    this.onRetry,
    this.onRemove,
    super.key,
  });

  final CheckInTake take;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final clock = checkInClockLabel(take.length);
    final meta = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final body = tokens.typography.styles.body.bodyMedium.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final quiet = body.copyWith(color: tokens.colors.text.mediumEmphasis);
    // The route is the first thing a narrow row sheds; the length and the
    // state are the facts.
    final state = switch (take.words) {
      CheckInTakeWords.transcribing => messages.checkInTranscribingLabel,
      CheckInTakeWords.heard => null,
      CheckInTakeWords.missing => messages.checkInStatusTranscriptMissing,
    };
    final tiers = [
      if (state != null && take.route != null)
        '$clock · $state · ${take.route}',
      if (state != null) '$clock · $state',
      clock,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: tokens.spacing.step4,
          top: tokens.spacing.step3,
          bottom: tokens.spacing.step4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step1),
              child: Icon(
                LottiIcons.mic,
                size: IconSizes.s,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsTieredText(
                    textKey: const ValueKey('check-in-take-meta'),
                    tiers: tiers,
                    semanticsLabel: [
                      checkInSpokenClockLabel(messages, take.length),
                      ?state,
                    ].join(' · '),
                    style: meta,
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  switch (take.words) {
                    CheckInTakeWords.transcribing => Text(
                      messages.checkInTakeWordsFollow,
                      key: const ValueKey('check-in-take-follows'),
                      style: quiet,
                    ),
                    CheckInTakeWords.heard => Semantics(
                      liveRegion: true,
                      child: Text(
                        take.transcript ?? '',
                        key: const ValueKey('check-in-take-transcript'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: body,
                      ),
                    ),
                    CheckInTakeWords.missing => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The provider's own detail, when it left any —
                        // never a cause the service cannot tell apart.
                        Text(
                          take.detail ??
                              messages.checkInTranscriptMissingBody(clock),
                          key: const ValueKey('check-in-take-missing'),
                          style: quiet,
                        ),
                        SizedBox(height: tokens.spacing.step2),
                        DesignSystemButton(
                          key: const ValueKey('check-in-retry-transcript'),
                          label: messages.relationshipAgentTryAgain,
                          leadingIcon: LottiIcons.refresh,
                          variant: DesignSystemButtonVariant.tertiary,
                          size: DesignSystemButtonSize.medium,
                          tapTargetSize: MaterialTapTargetSize.padded,
                          onPressed: onRetry,
                        ),
                      ],
                    ),
                  },
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('check-in-take-remove'),
              tooltip: messages.checkInRemoveTake,
              onPressed: onRemove,
              icon: Icon(
                LottiIcons.close,
                size: IconSizes.s,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card at the top of the field when the recorder could not record
/// (option 1f): tone by kind, the reason in plain words, the one thing to
/// do about it, and the way out for someone who would rather type.
class _FailureCard extends StatelessWidget {
  const _FailureCard({
    required this.failure,
    required this.onOpenSettings,
    required this.onDictate,
    required this.onTypeInstead,
  });

  final CheckInSpeechFailure failure;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onDictate;
  final VoidCallback? onTypeInstead;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final alert = tokens.colors.alert;

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
        // Typing is the recovery that always works, so it is a button; the
        // field's own Dictate beneath is the retry, so the card carries the
        // same two actions as every other.
        (
          key: const ValueKey('check-in-type-instead-denied'),
          label: messages.checkInTypeInstead,
          onPressed: onTypeInstead,
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
      announce: true,
      // The recommended action is the secondary pill: the alert tone is the
      // card's one colour, and the filled accent stays Save's alone. The
      // way out beside it is quiet — accent on the escape hatch would make
      // colour and shape point at two buttons.
      actions: [
        DesignSystemButton(
          key: secondary.key,
          label: secondary.label,
          variant: DesignSystemButtonVariant.quiet,
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
/// their own line at the trailing edge, so Dictate lives in the same
/// corner across phases and text scales.
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
