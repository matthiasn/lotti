import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/utils/entry_tools.dart';
import 'package:material_ui/material_ui.dart';

/// The composer's one field (design 2026-09-13): the recordings made so
/// far, then the note, with *Dictate* in its footer — before any recording
/// the note alone. The recorder renders **in place of the text**, so the
/// user never leaves the thing they are writing; a failure's callout sits
/// above the field.
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
    this.onUndoRemove,
    this.removedAt = 0,
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

  /// Puts back the take just removed; while set, the field says so and
  /// offers it, in the slot the take left.
  final VoidCallback? onUndoRemove;

  /// Where among [takes] the removed take stood, so the offer to put it
  /// back sits in its slot; clamped to the takes there are now.
  final int removedAt;

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
        // The design-system field frame: no well of its own — the sheet's
        // surface shows through, as in every field of the app's form
        // sheets — and the shared hairline, the accent meaning keyboard
        // focus alone. While the recorder owns the box the frame steps
        // back entirely, so the recorder sits on the sheet the way the
        // app's recording sheet does rather than in a box inside it.
        final focused = focusNode.hasFocus;
        final border = phase is CheckInSpeechRecording
            ? Colors.transparent
            : designSystemFieldBorderColor(tokens, focused: focused);
        final failure = switch (phase) {
          CheckInSpeechFailed(:final failure) => failure,
          _ => null,
        };
        final field = AnimatedContainer(
          key: const ValueKey('check-in-narrative-field'),
          duration: MotionDurations.short4,
          curve: MotionCurves.standard,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.l),
            border: Border.all(color: border, width: focused ? 2 : 1),
          ),
          // While recording the inset goes with the frame: the recorder
          // brings its own, and the two stacked left a hole above the orb.
          padding: phase is CheckInSpeechRecording
              ? EdgeInsets.zero
              : EdgeInsets.all(tokens.spacing.step5),
          // Not an AnimatedSize: the tiered captions lay themselves out with
          // a LayoutBuilder, which re-dirties an animating size box in its
          // own layout pass. The phases swap in place instead.
          child: switch (phase) {
            CheckInSpeechIdle() => _typing(context),
            CheckInSpeechPreparing() => _typing(context, preparing: true),
            CheckInSpeechRecording() => _recording(context),
            CheckInSpeechFailed(:final failure) => _typing(
              context,
              underCard: true,
              // The callout owns the retry where it offers one; under a
              // refused microphone the field's Dictate is the retry, and
              // with no transcription model there is none to offer.
              dictates:
                  failure.kind == CheckInSpeechFailureKind.microphoneDenied,
            ),
          },
        );
        if (failure == null) return field;
        // The callout above the field, not inside its frame: one bordered
        // object at a time, the field below it the way out.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _FailureCard(
              failure: failure,
              onOpenSettings: onOpenSettings,
              onDictate: onDictate,
              onTypeInstead: onDismissFailure,
            ),
            // The field's own inset apart: the card and the field are two
            // objects, not one stacked list.
            SizedBox(height: tokens.spacing.step5),
            field,
          ],
        );
      },
    );
  }

  Widget _textField(
    BuildContext context, {
    required String hint,
    // Three lines at rest: the box agrees with its own "one line is
    // enough"; five was an empty slab in the sheet.
    int minLines = 3,
  }) {
    final tokens = context.designTokens;
    // The placeholder in the typed text's own tier, in every state, so it
    // never changes size when a take lands — the copy changes instead.
    final text = tokens.typography.styles.body.bodyLarge;
    return TextField(
      key: const ValueKey('check-in-narrative'),
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      style: text.copyWith(color: tokens.colors.text.highEmphasis),
      // The box above draws the field's one frame. `collapsed` only clears
      // `border`: the app's InputDecorationTheme would still fill in its
      // 2.5 px focused outline, a second ring inside the accent hairline.
      decoration:
          InputDecoration.collapsed(
            hintText: hint,
            hintStyle: text.copyWith(color: tokens.colors.text.lowEmphasis),
          ).copyWith(
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            // The decorator sizes for its hint even when the hint is
            // hidden: on a phone the two-line hint held a blank second
            // line under a one-line note. Hidden, it may claim no more
            // lines than the field asks for; shown, it wraps.
            hintMaxLines: controller.text.isEmpty ? null : minLines,
          ),
    );
  }

  /// The field as text — plain, while preparing, or under a failure card:
  /// the takes, then the note, then the word count and *Dictate* in its
  /// footer.
  Widget _typing(
    BuildContext context, {
    bool preparing = false,
    bool underCard = false,
    bool dictates = true,
  }) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // The slot a removed take left counts as a take for the chrome, so
    // removing one — and putting it back — never reshapes the footer.
    final hasTakes = takes.isNotEmpty || onUndoRemove != null;
    final quietDictate = hasTakes && !underCard;
    // The medium tier, like the More row and the footer reason: low
    // emphasis is for placeholders only.
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    // Under a failure card the field is the way out, not the thing to read:
    // it starts short so the chips and More stay on a phone screen, and a
    // "0 words" count says nothing the card and the held Save do not.
    // What there is, and how to save — a ladder, so a narrow line sheds the
    // count before the shortcut and never wraps on a separator. A zero
    // count adds nothing the empty field does not already say.
    // Beside a take the count would read as the take's; it is the note's.
    final count = wordCount > 0 && !hasTakes
        ? messages.checkInWordCount(wordCount)
        : null;
    // The shortcut only once there is something to save with it: beside a
    // held Save, a working shortcut is a promise the footer contradicts.
    final hint = switch (shortcutHint) {
      // A real take, not the slot one left: removing the only take leaves
      // nothing to save.
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
      // One shape in every state; once a take is in, a step quieter, so
      // Save — not another recording — reads as the next thing to do.
      if (offersDictation && dictates)
        DesignSystemButton(
          key: const ValueKey('check-in-dictate'),
          label: messages.checkInDictateButton,
          leadingIcon: LottiIcons.mic,
          // Once a take is in, Save leads: Dictate steps down to the
          // caption-tier text action — still in the action ink, so it never
          // reads as part of the caption beside it — its label ending on the
          // field's content edge. Before one, and under a refused
          // microphone where it is the retry the card names, it keeps its
          // resting shape.
          variant: quietDictate
              ? DesignSystemButtonVariant.tertiary
              : DesignSystemButtonVariant.outlined,
          size: quietDictate
              ? DesignSystemButtonSize.dense
              : DesignSystemButtonSize.medium,
          alignsLabelToTrailingEdge: quietDictate,
          isLoading: preparing,
          onPressed: preparing ? null : onDictate,
        ),
    ];
    // The actions sit in one corner: beside the caption when both fit a
    // line, else on their own line at the trailing edge — always at large
    // text, where even a lone button can crowd the caption.
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > TextScales.large;
    final slots = <Widget>[
      for (final take in takes)
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
    ];
    // The offer to put a removed take back stands where the take stood.
    if (onUndoRemove case final undo?) {
      slots.insert(
        removedAt.clamp(0, slots.length),
        _RemovedTakeSlot(onUndo: undo),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // What was said leads, and the note follows it as the user's own
        // line — beside a take the empty note is an invitation, not the
        // heading of the words beneath it.
        // Takes sit step4 apart, and the note a card's own inset below the
        // last, so it reads as the field's, not as the card's last line.
        for (final (index, slot) in slots.indexed) ...[
          slot,
          SizedBox(
            height: index == slots.length - 1
                ? tokens.spacing.step5
                : tokens.spacing.step4,
          ),
        ],
        _textField(
          context,
          // The slot a removed take left counts too: the long hint would
          // wrap and grow the field until Undo.
          hint: hasTakes
              ? messages.checkInAddNoteHint
              : messages.checkInNarrativeHint,
          // "One line is enough": the box says so by not asking for five.
          // Neither does it beside a recording, or the slot one left.
          minLines: underCard || hasTakes ? 1 : restMinLines,
        ),
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

  /// The recorder in place of the text — and nothing over it. A line of
  /// instruction above the orb ("Speak normally…") narrated what the orb,
  /// its caption and the status dot already say; the check-in page's
  /// recorder never had one and lost nothing.
  Widget _recording(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [?recorder],
  );
}

/// One recording above the note: its length and where its words are on
/// the header line, *Remove recording* at its end, then — at the card's
/// full width — the words themselves, the promise that they follow, or why
/// they are missing with the way to ask again.
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
    final clock = formatElapsed(take.length);
    // The state and its explanation share one quiet tier — the glyph and
    // its tone carry the news, not a bigger size.
    final note = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final meta = note.copyWith(
      // A missing take's line is the news, so it outranks the explanation
      // beneath it; otherwise it stays as quiet as its note.
      color: take.words == CheckInTakeWords.missing
          ? tokens.colors.text.highEmphasis
          : null,
      // The app's own digit features, not a bare tabular flag: the same
      // set every People timestamp carries.
      fontFeatures: numericBadgeFontFeatures,
    );
    // What was said, in the typed note's own tier: one voice for the
    // field's text, whoever put it there.
    final body = tokens.typography.styles.body.bodyLarge.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
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

    // One header line — the state glyph, the length and state, the remove
    // action at its end — and the words beneath at the card's full width, so
    // a take reads as an entry-to-be, not a caption with a hanging indent.
    return DecoratedBox(
      decoration: BoxDecoration(
        // A lift, not a well: the translucent surface reads one step above
        // whatever the field sits on, where a fixed level punched a darker
        // or a lighter hole depending on the sheet behind it.
        color: tokens.colors.surface.enabled,
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Padding(
        // The header row is the remove action's own 48 px target, so with
        // no top or trailing inset its glyph sits step5 from the card's top
        // and trailing edges — the same step5 the leading glyph, the body's
        // end and the bottom keep: one inset on every side.
        padding: EdgeInsetsDirectional.only(
          start: tokens.spacing.step5,
          bottom: tokens.spacing.step5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // The glyph says where the words are: on their way, here as
                // a recording, or missing — the line beside it stays quiet.
                switch (take.words) {
                  CheckInTakeWords.transcribing => DesignSystemSpinner(
                    key: const ValueKey('check-in-take-glyph-transcribing'),
                    // The default style, on its track: a glyph's whole
                    // silhouette rather than a stray arc.
                    size: IconSizes.s,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  CheckInTakeWords.heard => Icon(
                    LottiIcons.waveform,
                    key: const ValueKey('check-in-take-glyph-heard'),
                    size: IconSizes.s,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  CheckInTakeWords.missing => Icon(
                    LottiIcons.warning,
                    key: const ValueKey('check-in-take-glyph-missing'),
                    size: IconSizes.s,
                    color: tokens.colors.alert.warning.defaultColor,
                  ),
                },
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  // The take owns where its words are, so its line is the
                  // live one: the header no longer repeats it.
                  child: Semantics(
                    liveRegion: true,
                    child: DsTieredText(
                      textKey: const ValueKey('check-in-take-meta'),
                      tiers: tiers,
                      semanticsLabel: [
                        checkInSpokenClockLabel(messages, take.length),
                        ?state,
                      ].join(' · '),
                      style: meta,
                    ),
                  ),
                ),
                // Not the sheet's ✕: this takes one recording out of the
                // check-in.
                DesignSystemIconAction(
                  key: const ValueKey('check-in-take-remove'),
                  icon: LottiIcons.removeCircled,
                  tooltip: messages.checkInRemoveTake,
                  onPressed: onRemove,
                ),
              ],
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(end: tokens.spacing.step5),
              child: switch (take.words) {
                // Status, not words: the small quiet voice, so it can never be
                // mistaken for what was said.
                CheckInTakeWords.transcribing => Text(
                  messages.checkInTakeWordsFollow,
                  key: const ValueKey('check-in-take-follows'),
                  style: note,
                ),
                CheckInTakeWords.heard => Semantics(
                  liveRegion: true,
                  child: Text(
                    take.transcript ?? '',
                    key: const ValueKey('check-in-take-transcript'),
                    style: body,
                  ),
                ),
                CheckInTakeWords.missing => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The provider's own detail, when it left any — never a
                    // cause the service cannot tell apart.
                    Text(
                      take.detail ?? messages.checkInTranscriptMissingBody,
                      key: const ValueKey('check-in-take-missing'),
                      style: note,
                    ),
                    SizedBox(height: tokens.spacing.step3),
                    // The take's own way forward, quiet on its trailing rail
                    // so the warning line leads — in the header it would
                    // push the state off a phone's line. Its label ends on
                    // the body's edge, the remove glyph's.
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: DesignSystemButton(
                        key: const ValueKey('check-in-retry-transcript'),
                        label: messages.relationshipAgentTryAgain,
                        leadingIcon: LottiIcons.refresh,
                        variant: DesignSystemButtonVariant.tertiary,
                        // The explanation's own caption tier: the warning
                        // line leads, not the button under it.
                        size: DesignSystemButtonSize.dense,
                        alignsLabelToTrailingEdge: true,
                        onPressed: onRetry,
                      ),
                    ),
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The slot a removed take left: the take's trace without its card — its
/// glyph faded, the line saying it went and *Undo* to put it back, where it
/// stood rather than a toast the sheet would cover. With no card there is
/// no card inset: it sits on the field's own edges, the glyph on the
/// note's and *Undo* ending on *Dictate*'s.
class _RemovedTakeSlot extends StatelessWidget {
  const _RemovedTakeSlot({required this.onUndo});

  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Row(
      key: const ValueKey('check-in-take-removed'),
      children: [
        Icon(
          LottiIcons.waveform,
          size: IconSizes.s,
          color: tokens.colors.text.lowEmphasis,
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              messages.checkInTakeRemoved,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ),
        DesignSystemButton(
          key: const ValueKey('check-in-take-undo'),
          label: messages.designSystemUndoLabel,
          leadingIcon: LottiIcons.undo,
          variant: DesignSystemButtonVariant.tertiary,
          size: DesignSystemButtonSize.dense,
          alignsLabelToTrailingEdge: true,
          tapTargetSize: MaterialTapTargetSize.padded,
          onPressed: onUndo,
        ),
      ],
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
