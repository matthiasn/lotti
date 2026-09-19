import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/shortcut_label_formatter.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_composer_header.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_context_chips.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_duration_picker.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_inline_recorder.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_narrative_field.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

/// The localized label for an interaction type — shared by the capture sheet
/// and the detail page's check-in rows.
String checkInInteractionLabel(
  BuildContext context,
  CheckInInteractionType type,
) => switch (type) {
  CheckInInteractionType.inPerson =>
    context.messages.checkInInteractionInPerson,
  CheckInInteractionType.call => context.messages.checkInInteractionCall,
  CheckInInteractionType.videoCall =>
    context.messages.checkInInteractionVideoCall,
  CheckInInteractionType.message => context.messages.checkInInteractionMessage,
  CheckInInteractionType.other => context.messages.checkInInteractionOther,
};

/// The icon for an interaction type — shared by the detail page's check-in
/// rows and the journal card, so the two can't drift apart.
IconData checkInInteractionIcon(CheckInInteractionType type) => switch (type) {
  CheckInInteractionType.inPerson => LottiIcons.people,
  CheckInInteractionType.call => LottiIcons.call,
  CheckInInteractionType.videoCall => LottiIcons.video,
  CheckInInteractionType.message => LottiIcons.chat,
  CheckInInteractionType.other => LottiIcons.forum,
};

/// The localized label for a sentiment — shared by the capture sheet and the
/// detail page's check-in rows.
String checkInSentimentLabel(
  BuildContext context,
  CheckInSentiment sentiment,
) => switch (sentiment) {
  CheckInSentiment.delightful => context.messages.checkInSentimentDelightful,
  CheckInSentiment.good => context.messages.checkInSentimentGood,
  CheckInSentiment.neutral => context.messages.checkInSentimentNeutral,
  CheckInSentiment.strained => context.messages.checkInSentimentStrained,
  CheckInSentiment.difficult => context.messages.checkInSentimentDifficult,
};

/// Opens the OS's settings for this app, where a refused microphone
/// permission is turned back on. A seam, so the composer's *Open settings*
/// is testable without the platform channel behind it.
typedef CheckInSettingsOpener = Future<bool> Function();

final checkInSettingsOpenerProvider = Provider<CheckInSettingsOpener>(
  (ref) => permissions.openAppSettings,
  name: 'checkInSettingsOpenerProvider',
);

/// What the composer's chrome needs from the form inside it — the pinned
/// action bar's save and delete intents and why Save is held, the header's
/// status line, the keyboard bar's one-line summary — published after every
/// state change; the chrome listens. The form still works on a plain page
/// and in a plain test: it publishes whether or not anyone is listening.
class CheckInFormHandle extends ChangeNotifier {
  Future<void> Function()? _save;
  Future<void> Function()? _delete;
  Future<void> Function()? _dismiss;
  VoidCallback? _unfocus;
  AudioRecorderController? _recorder;
  CheckInSaveBlock _block = CheckInSaveBlock.emptyNarrative;
  CheckInComposerStatus _status = CheckInComposerStatus.idle;
  String _summary = '';
  bool _fieldFocused = false;
  double? _barHeight;

  bool get canSave => _block == CheckInSaveBlock.none;

  /// The pinned bar's rendered height, once it has laid out — what the form
  /// reserves under its last field when the bar turns out taller than
  /// [CheckInStickyActions.height] predicted (a long-label locale stacking
  /// Cancel and Save on a narrow phone, say).
  double? get barHeight => _barHeight;

  /// Called by the bar after every layout that changed its height.
  void reportBarHeight(double height) {
    if (_barHeight == height) return;
    _barHeight = height;
    notifyListeners();
  }

  bool get canDelete => _delete != null;

  /// Why Save is held, for the bar to say so.
  CheckInSaveBlock get block => _block;

  /// What the field is doing, for the header's status line.
  CheckInComposerStatus get status => _status;

  /// `Call · Now · no duration`, for the slim bar above the keyboard.
  String get summary => _summary;

  /// Whether the narrative field has focus — on a phone, whether the
  /// keyboard is up. The sheet removes the keyboard inset from what its
  /// pinned bar can see, so focus is the signal the bar slims on.
  bool get fieldFocused => _fieldFocused;

  Future<void> save() => _save?.call() ?? Future.value();
  Future<void> delete() => _delete?.call() ?? Future.value();

  /// Leaves the composer — asking first when there is something to lose.
  /// Cancel, the header's close and the sheet's own back gesture all come
  /// through here, so a draft is guarded the same way whichever way out is
  /// taken.
  Future<void> dismiss() => _dismiss?.call() ?? Future.value();

  /// Drops the keyboard, so the chips the summary stands for come back.
  void unfocus() => _unfocus?.call();

  /// The form hands over the app-wide recorder the moment it starts a
  /// recording, so the sheet can put the floating indicator back once it
  /// has closed — and only then, and only if a recording was ever started:
  /// a composer that never dictated never touches the recorder at all.
  set recorder(AudioRecorderController recorder) => _recorder = recorder;

  /// The recorder a recording was started on, until the sheet releases it.
  AudioRecorderController? get recorder => _recorder;

  /// Shows the floating indicator again for a recording the sheet left
  /// running; a no-op when nothing was recorded.
  void releaseRecorder() {
    _recorder?.setModalVisible(modalVisible: false);
    _recorder = null;
  }

  void publish({
    required Future<void> Function()? save,
    required Future<void> Function()? delete,
    required Future<void> Function()? dismiss,
    required VoidCallback? unfocus,
    required CheckInSaveBlock block,
    required CheckInComposerStatus status,
    required String summary,
    bool fieldFocused = false,
  }) {
    _save = save;
    _delete = delete;
    _dismiss = dismiss;
    _unfocus = unfocus;
    // The callbacks are rebound on every publish; the chrome only needs a
    // frame when something it draws has changed — not on every keystroke.
    final changed =
        _block != block ||
        _status != status ||
        _summary != summary ||
        _fieldFocused != fieldFocused;
    _block = block;
    _status = status;
    _summary = summary;
    _fieldFocused = fieldFocused;
    if (changed) notifyListeners();
  }
}

/// Opens the check-in composer for a person (design 2026-09-13): one
/// surface that opens on the narrative, with *Dictate* inside the field.
/// Resolves to the created [CheckInEntry], or `null` when dismissed.
///
/// [prefilledInteractionType], [prefilledTime] and [prefilledDuration] let a
/// caller open the composer already describing an interaction that just
/// happened — the post-call prompt passes what it recorded when the user
/// left to make the call (plan v2 phase 7 item 5). They are starting values
/// only: everything stays editable, and nothing is saved until the user
/// says so. [startSpeaking] starts the recorder after the first frame —
/// the page's mic doorway, which means "say it" rather than "show me the
/// form".
Future<CheckInEntry?> showCheckInCaptureSheet({
  required BuildContext context,
  required String relationshipId,
  CheckInInteractionType? prefilledInteractionType,
  DateTime? prefilledTime,
  Duration? prefilledDuration,
  bool startSpeaking = false,
}) => _showComposer(
  context: context,
  relationshipId: relationshipId,
  title: context.messages.relationshipLogCheckIn,
  form: (handle, {required dialog}) => CheckInCaptureForm(
    dialog: dialog,
    relationshipId: relationshipId,
    prefilledInteractionType: prefilledInteractionType,
    prefilledTime: prefilledTime,
    prefilledDuration: prefilledDuration,
    startSpeaking: startSpeaking,
    handle: handle,
  ),
);

/// Opens the same composer prefilled from [checkIn] for editing. Resolves
/// to the updated [CheckInEntry], or `null` when dismissed or deleted.
Future<CheckInEntry?> showCheckInEditSheet({
  required BuildContext context,
  required CheckInEntry checkIn,
}) => _showComposer(
  context: context,
  relationshipId: checkIn.data.relationshipId,
  title: context.messages.checkInEditTitle,
  editing: true,
  form: (handle, {required dialog}) => CheckInCaptureForm(
    dialog: dialog,
    relationshipId: checkIn.data.relationshipId,
    initial: checkIn,
    handle: handle,
  ),
);

Future<CheckInEntry?> _showComposer({
  required BuildContext context,
  required String relationshipId,
  required String title,
  required CheckInCaptureForm Function(
    CheckInFormHandle handle, {
    required bool dialog,
  })
  form,
  bool editing = false,
}) async {
  final handle = CheckInFormHandle();
  final tokens = context.designTokens;
  // The same width rule the modal picks its shape by, decided here on the
  // caller's window — inside the sheet the media query is the sheet's own.
  final dialog =
      MediaQuery.sizeOf(context).width >= WoltModalConfig.pageBreakpoint;
  // The title is measured against the width the modal will actually have,
  // so the toolbar reserves exactly the lines it takes at large text.
  final scaler = MediaQuery.textScalerOf(context);
  final titleLines = CheckInComposerHeader.titleLinesFor(
    title: title,
    style: ModalUtils.modalTitleStyle(context),
    scaler: scaler,
    tokens: tokens,
    width: ModalUtils.modalTypeBuilder(
      context,
    ).layoutModal(MediaQuery.sizeOf(context)).maxWidth,
    direction: Directionality.of(context),
  );
  try {
    return await ModalUtils.showSinglePageModal<CheckInEntry>(
      context: context,
      hasTopBarLayer: false,
      showCloseButton: false,
      navBarHeight: CheckInComposerHeader.height(
        tokens,
        scaler,
        titleLines: titleLines,
      ),
      leadingNavBarWidget: CheckInComposerHeader(
        relationshipId: relationshipId,
        handle: handle,
        title: title,
        titleLines: titleLines,
        editing: editing,
      ),
      padding: _formPadding(context),
      stickyActionBarBuilder: (_) =>
          CheckInStickyActions(handle: handle, dialog: dialog),
      builder: (modalContext) => form(handle, dialog: dialog),
    );
  } finally {
    // The inline recorder hides the floating indicator while it is up. A
    // sheet dismissed mid-recording leaves the recording running — the
    // recording sheet's own rule — so the indicator has to come back here,
    // once the sheet is gone, for the user to stop it from.
    handle.releaseRecorder();
  }
}

/// Air between the pinned header and the field, and room under the form
/// for the pinned action bar, so the last field can scroll fully above it
/// with a step of air to spare. The reserve is the bar's predicted height
/// for this layout, so the desktop dialog — whose bar has no reason line of
/// its own — carries no blank band above its footer; the form adds any
/// slack the *measured* bar turns out to need (see [_BarSlack]).
EdgeInsets _formPadding(BuildContext context) {
  final tokens = context.designTokens;
  final dialog =
      MediaQuery.sizeOf(context).width >= WoltModalConfig.pageBreakpoint;
  return EdgeInsets.fromLTRB(
    tokens.spacing.step5,
    tokens.spacing.step4,
    tokens.spacing.step5,
    CheckInStickyActions.height(
          tokens,
          MediaQuery.textScalerOf(context),
          dialog: dialog,
        ) +
        tokens.spacing.step3,
  );
}

/// The composer's pinned actions (design 2026-09-13): *Save check-in* is
/// always visible, and when it is held the bar says why. Cancel beside it —
/// and, while editing, delete on the leading edge. On a phone with the
/// keyboard up the bar slims to the context summary and a short *Save*, so
/// the words the user is typing keep the room (option 1g). Reads the form
/// through its [handle].
class CheckInStickyActions extends StatelessWidget {
  const CheckInStickyActions({
    required this.handle,
    this.dialog = false,
    super.key,
  });

  final CheckInFormHandle handle;

  /// Whether the composer is the desktop dialog rather than the phone
  /// sheet: the reason then sits on the leading edge with the two actions
  /// together on the trailing edge, and the bar never slims for a keyboard.
  final bool dialog;

  /// The bar's height per layout, so the form reserves exactly what the
  /// bar covers and no more: the actions row (stacked above the large-text
  /// bar), and on the phone the reason line beneath it.
  static double height(
    DsTokens tokens,
    TextScaler scaler, {
    required bool dialog,
  }) {
    final stacked = scaler.scale(1) > TextScales.large;
    final button =
        _line(tokens.typography.styles.subtitle.subtitle1, scaler) +
        tokens.spacing.step4 * 2;
    final actions = stacked ? button * 2 + tokens.spacing.step3 : button;
    final reason = reasonLineHeight(tokens, scaler) * reasonLines(scaler);
    final reasonRow = dialog && !stacked ? 0 : reason + tokens.spacing.step3;
    return tokens.spacing.step5 * 2 + actions + reasonRow;
  }

  /// Lines the reason may take: one, or two above the large-text bar.
  static int reasonLines(TextScaler scaler) =>
      scaler.scale(1) > TextScales.large ? 2 : 1;

  /// The reason slot's fixed height: one caption line as the text engine
  /// lays it out. Fixed, because an empty line and a worded one can differ
  /// by a pixel under a real font, and the buttons above must never jump
  /// as Save goes from held to free.
  static double reasonLineHeight(DsTokens tokens, TextScaler scaler) =>
      _line(tokens.typography.styles.others.caption, scaler);

  static double _line(TextStyle style, TextScaler scaler) =>
      scaler.scale(style.fontSize! * (style.height ?? 1)).ceilToDouble();

  /// The reason Save is held, or null when it is not.
  static String? blockLabel(
    AppLocalizations messages,
    CheckInSaveBlock block,
  ) => switch (block) {
    CheckInSaveBlock.none || CheckInSaveBlock.saving => null,
    CheckInSaveBlock.preparing => messages.checkInPreparingLabel,
    CheckInSaveBlock.recording => messages.checkInSaveBlockedRecording,
    CheckInSaveBlock.emptyNarrative => messages.checkInSaveBlockedEmpty,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final wide = dialog;
    final padding = EdgeInsets.all(tokens.spacing.step5);

    return _BarHeightReporter(
      onHeight: handle.reportBarHeight,
      child: ListenableBuilder(
        listenable: handle,
        builder: (context, _) {
          final keyboardUp =
              !wide &&
              (handle.fieldFocused ||
                  MediaQuery.viewInsetsOf(context).bottom > 0);
          final reason = blockLabel(messages, handle.block);
          final reasonStyle = tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          );

          if (keyboardUp) {
            return DesignSystemGlassStrip(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step5,
                  vertical: tokens.spacing.step3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DesignSystemChip(
                          key: const ValueKey('check-in-context-summary'),
                          label: handle.summary,
                          trailing: const Icon(
                            LottiIcons.chevronUp,
                            size: IconSizes.s,
                          ),
                          size: DesignSystemChipSize.compactPillTouch,
                          onPressed: handle.unfocus,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    DesignSystemButton(
                      key: const ValueKey('check-in-save'),
                      label: messages.checkInSaveShortButton,
                      size: DesignSystemButtonSize.large,
                      onPressed: handle.canSave ? handle.save : null,
                    ),
                  ],
                ),
              ),
            );
          }

          final delete = handle.canDelete
              ? DesignSystemIconAction(
                  key: const ValueKey('check-in-delete'),
                  icon: LottiIcons.delete,
                  tooltip: messages.deleteButton,
                  tone: tokens.colors.alert.error.ink,
                  onPressed: handle.delete,
                )
              : null;
          // Cancel is quiet text on both viewports: the header's close
          // already exits, and the one bright shape in the bar is Save's —
          // even while Save is held.
          final cancel = DesignSystemButton(
            key: const ValueKey('check-in-cancel'),
            label: messages.cancelButton,
            variant: DesignSystemButtonVariant.quiet,
            size: DesignSystemButtonSize.large,
            // On the phone its label sits on the content column, like the
            // card's quiet actions; in the dialog it trails beside Save, and
            // centred under Save in the stacked large-text bar it keeps both
            // insets, or it would sit off-centre.
            alignsLabelToLeadingEdge:
                !wide &&
                MediaQuery.textScalerOf(context).scale(1) <= TextScales.large,
            onPressed: handle.dismiss,
          );
          // A held Save says why on the control itself: a reader who lands
          // on it hears the next step, not only "dimmed".
          final save = MergeSemantics(
            child: Semantics(
              hint: handle.canSave ? null : reason,
              child: DesignSystemButton(
                key: const ValueKey('check-in-save'),
                label: messages.checkInSaveButton,
                size: DesignSystemButtonSize.large,
                fullWidth: !wide,
                onPressed: handle.canSave ? handle.save : null,
              ),
            ),
          );
          // The slot is always laid out, even with nothing to say, so the
          // bar keeps one height as Save goes from held to free and the
          // buttons never jump; a live region announces the reason as it
          // changes.
          // Live only for the blocks the header does not already announce —
          // the header speaks for the recorder and the transcript wait.
          final reasonText = Semantics(
            liveRegion: handle.block == CheckInSaveBlock.emptyNarrative,
            // Two lines above the large-text bar, where a stacked bar has
            // the room and a one-line reason would lose its end.
            child: SizedBox(
              height:
                  reasonLineHeight(tokens, MediaQuery.textScalerOf(context)) *
                  reasonLines(MediaQuery.textScalerOf(context)),
              child: Text(
                reason ?? '',
                key: const ValueKey('check-in-save-reason'),
                maxLines: reasonLines(MediaQuery.textScalerOf(context)),
                overflow: TextOverflow.ellipsis,
                style: reasonStyle,
              ),
            ),
          );

          if (wide) {
            // The dialog's footer: the reason on the leading edge where the
            // eye lands after the field, the two actions together on the
            // trailing edge.
            return DesignSystemModalActionBar(
              glass: true,
              padding: padding,
              layout: DesignSystemModalActionBarLayout.compactPrimary,
              secondary: [?delete, reasonText],
              primary: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  cancel,
                  SizedBox(width: tokens.spacing.step3),
                  save,
                ],
              ),
            );
          }

          return DesignSystemGlassStrip(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DesignSystemModalActionBar(
                    secondary: [?delete, cancel],
                    primary: save,
                  ),
                  SizedBox(height: tokens.spacing.step3),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: reasonText,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Reports the pinned bar's rendered height to the form, after its first
/// layout and after every layout that changes it, so the reserve under the
/// last field follows the bar that is actually there.
class _BarHeightReporter extends StatefulWidget {
  const _BarHeightReporter({required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<_BarHeightReporter> createState() => _BarHeightReporterState();
}

class _BarHeightReporterState extends State<_BarHeightReporter> {
  void _report() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) widget.onHeight(box.size.height);
    });
  }

  @override
  Widget build(BuildContext context) {
    _report();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _report();
        return true;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}

/// The air the form adds under its last field when the pinned bar measured
/// taller than [CheckInStickyActions.height] predicted — nothing in the
/// common case, so the reserve never jumps, and exactly the difference when
/// the bar stacked its actions on a narrow phone.
class _BarSlack extends StatelessWidget {
  const _BarSlack({required this.handle});

  final CheckInFormHandle handle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dialog =
        MediaQuery.sizeOf(context).width >= WoltModalConfig.pageBreakpoint;
    final predicted = CheckInStickyActions.height(
      tokens,
      MediaQuery.textScalerOf(context),
      dialog: dialog,
    );
    return ListenableBuilder(
      listenable: handle,
      builder: (context, _) {
        final measured = handle.barHeight;
        if (measured == null || measured <= predicted) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          key: const ValueKey('check-in-bar-slack'),
          height: measured - predicted,
        );
      },
    );
  }
}

/// The check-in composer (design 2026-09-13): the narrative field first,
/// with *Dictate* inside it and every speech phase rendered in place of the
/// text; then type · started · duration as one chip row; then sentiment,
/// topics and the "next time" guidance folded under *More*. Persists
/// through [RelationshipRepository]. With [initial] set it edits that
/// check-in instead, and offers deletion.
class CheckInCaptureForm extends ConsumerStatefulWidget {
  const CheckInCaptureForm({
    required this.relationshipId,
    required this.handle,
    this.initial,
    this.prefilledInteractionType,
    this.prefilledTime,
    this.prefilledDuration,
    this.startSpeaking = false,
    this.dialog = false,
    super.key,
  });

  final String relationshipId;

  /// Whether the composer is the desktop dialog: the field then takes
  /// focus at once, since the typed common case is open → type → ⌘↩ and
  /// no keyboard rises over the form.
  final bool dialog;

  /// When set, the form edits this check-in instead of creating one.
  final CheckInEntry? initial;

  /// Starting interaction type for a new check-in, when the caller already
  /// knows what happened. Ignored while editing, where [initial] is the
  /// authority.
  final CheckInInteractionType? prefilledInteractionType;

  /// Starting interaction time for a new check-in — when the call was
  /// actually placed, rather than when the user got round to logging it.
  final DateTime? prefilledTime;

  /// How long the interaction lasted, when the caller already knows — the
  /// post-call offer's elapsed time. Persisted as the check-in's end time
  /// (`dateTo − dateFrom` is the duration; no schema change), so the
  /// duration the offer quoted is the one the log shows. Ignored while
  /// editing, where the existing check-in's own length is kept.
  final Duration? prefilledDuration;

  /// Opens straight into a spoken check-in: the recorder replaces the field
  /// after the first frame. Everything else about the form is unchanged,
  /// and discarding the recording leaves the form as it was.
  final bool startSpeaking;

  /// The chrome's view of this form — its only way out: the form has no
  /// inline actions.
  final CheckInFormHandle handle;

  @override
  ConsumerState<CheckInCaptureForm> createState() => _CheckInCaptureFormState();
}

class _CheckInCaptureFormState extends ConsumerState<CheckInCaptureForm> {
  late final TextEditingController _topicsController;
  late final TextEditingController _narrativeController;
  late final TextEditingController _payAttentionController;
  late final TextEditingController _avoidController;
  final FocusNode _narrativeFocus = FocusNode(debugLabel: 'check-in-narrative');
  late CheckInInteractionType _interactionType;
  late CheckInSentiment? _sentiment;
  late DateTime _interactionTime;

  /// The check-in's length; zero means "no duration". Kept across a change
  /// of the start time so editing when a call began does not erase how
  /// long it ran.
  late Duration _duration;

  /// The context the composer opened with — the edited check-in's, the
  /// post-call offer's or the defaults — so a changed chip counts as a draft
  /// worth guarding just as changed words do.
  late final CheckInInteractionType _openingType;
  late final DateTime _openingTime;
  late final Duration _openingDuration;

  /// Optional sentiment, topics and next-time guidance, folded by default;
  /// open from the start when a check-in being edited already has any of it.
  late bool _moreOpen;

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

  bool _isSaving = false;

  /// The narrative as last seen, so a focus change is not mistaken for typing.
  String _lastNarrative = '';

  CheckInSpeechPhase _phase = const CheckInSpeechIdle();

  /// The person's category, read during the preflight, so the recording
  /// files where their other entries do.
  String? _categoryId;

  /// Whether the recorder attaches to this person's recording already
  /// running — a sheet dismissed mid-take and reopened — instead of
  /// starting one.
  bool _adoptRunning = false;

  /// The recordings made here, oldest first — the check-in's entries once
  /// it is saved (ADR 0062).
  List<CheckInTake> _takes = const [];

  /// Each take's in-flight transcript wait, so dismissing the sheet stops
  /// them instead of leaving database listeners running out the timeout.
  /// The transcription itself runs on: its words land on the recording.
  final Map<String, CheckInTranscriptWait> _transcriptWaits = {};

  /// Watches the inference-error controller for each take being
  /// transcribed, so a failed run ends its wait instead of running it out.
  final Map<String, ProviderSubscription<String?>> _transcriptFailures = {};

  bool get _isEditing => widget.initial != null;

  /// Whether the composer offers *Dictate*: only for a new check-in. A saved
  /// one is added to from its timeline, where a recording becomes its entry
  /// at once.
  bool get _offersDictation => !_isEditing;

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

  /// An existing check-in's length, or null when there is none to keep.
  static Duration? _lengthOf(CheckInEntry? entry) {
    if (entry == null) return null;
    return entry.meta.dateTo.difference(entry.meta.dateFrom);
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final data = initial?.data;
    // The detail fields rebuild the form as they change, so the pop guard's
    // `canPop` — read at build time — never lags an edit made only there.
    _topicsController = TextEditingController(
      text: data?.topics.join(', ') ?? '',
    )..addListener(_onDetailChanged);
    _narrativeController = TextEditingController(
      text: initial?.entryText?.plainText ?? '',
    )..addListener(_onNarrativeChanged);
    _lastNarrative = _narrativeController.text;
    _payAttentionController = TextEditingController(
      text: data?.payAttentionTo ?? '',
    )..addListener(_onDetailChanged);
    _avoidController = TextEditingController(text: data?.avoid ?? '')
      ..addListener(_onDetailChanged);
    _narrativeFocus.addListener(_onNarrativeChanged);
    _interactionType =
        data?.interactionType ??
        widget.prefilledInteractionType ??
        CheckInInteractionType.inPerson;
    // Sentiment is never pre-filled, by any caller: it is the user's own
    // judgment of how it felt, and a default would put words in their mouth
    // (ADR 0038).
    _sentiment = data?.sentiment;
    _interactionTime =
        initial?.meta.dateFrom ?? widget.prefilledTime ?? clock.now();
    final length =
        _lengthOf(initial) ?? widget.prefilledDuration ?? Duration.zero;
    _duration = length.isNegative ? Duration.zero : length;
    _openingType = _interactionType;
    _openingTime = _interactionTime;
    _openingDuration = _duration;
    _moreOpen =
        _sentiment != null ||
        _topicsController.text.isNotEmpty ||
        _payAttentionController.text.isNotEmpty ||
        _avoidController.text.isNotEmpty;
    // On the desktop dialog the typed common case is open → type → ⌘↩,
    // so the field takes focus at once; a phone would raise its keyboard
    // over the sheet, so there the first tap still chooses.
    if (widget.dialog && !widget.startSpeaking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _narrativeFocus.requestFocus();
      });
    }
    if (widget.startSpeaking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_dictate());
      });
    }
  }

  @override
  void dispose() {
    for (final wait in _transcriptWaits.values) {
      wait.cancel();
    }
    for (final subscription in _transcriptFailures.values) {
      subscription.close();
    }
    _transcriptWaits.clear();
    _transcriptFailures.clear();
    _narrativeController
      ..removeListener(_onNarrativeChanged)
      ..dispose();
    _narrativeFocus
      ..removeListener(_onNarrativeChanged)
      ..dispose();
    _topicsController
      ..removeListener(_onDetailChanged)
      ..dispose();
    _payAttentionController
      ..removeListener(_onDetailChanged)
      ..dispose();
    _avoidController
      ..removeListener(_onDetailChanged)
      ..dispose();
    super.dispose();
  }

  /// The word count and the save rule both read the field, and the pinned
  /// bar reads its focus, so every keystroke and focus change is a state
  /// change here. Typing under a failure card is the user choosing to type
  /// instead, so the card goes.
  void _onNarrativeChanged() {
    if (!mounted) return;
    final text = _narrativeController.text;
    final typed = text != _lastNarrative;
    _lastNarrative = text;
    if (_phase is CheckInSpeechFailed && typed && text.trim().isNotEmpty) {
      _phase = const CheckInSpeechIdle();
    }
    setState(() {});
  }

  /// A detail edit is a state change for the pop guard, which reads
  /// [_isDirty] at build time.
  void _onDetailChanged() {
    if (mounted) setState(() {});
  }

  List<String> get _topics => _topicsController.text
      .split(',')
      .map((topic) => topic.trim())
      .where((topic) => topic.isNotEmpty)
      .toList();

  bool get _hasWords => checkInWordCount(_narrativeController.text) > 0;

  CheckInSaveBlock get _block => checkInSaveBlockOf(
    phase: _phase,
    hasWords: _hasWords,
    hasTakes: _takes.isNotEmpty,
    saving: _isSaving,
  );

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

  /// *Started*: the day, then the time ([pickCheckInStart]).
  Future<void> _pickStart() async {
    final picked = await pickCheckInStart(
      context: context,
      initial: _interactionTime,
    );
    if (!mounted || picked == null) return;
    setState(() => _interactionTime = picked);
  }

  /// *Duration*: the wheel behind the chip. Zero is "no duration".
  Future<void> _pickDuration() async {
    final picked = await showCheckInDurationPicker(
      context: context,
      initialDuration: _duration,
    );
    if (!mounted || picked == null) return;
    setState(() => _duration = picked);
  }

  Future<void> _pickType() async {
    final picked = await showCheckInTypePicker(
      context: context,
      current: _interactionType,
    );
    if (!mounted || picked == null) return;
    setState(() => _interactionType = picked);
  }

  bool get _speechIdle => switch (_phase) {
    CheckInSpeechIdle() || CheckInSpeechFailed() => true,
    _ => false,
  };

  /// *Dictate*: the preflight, then the recorder in place of the text.
  ///
  /// Audio is linked to the person — the check-in does not exist yet — and
  /// becomes the check-in's entry when it is saved. Transcription uses only
  /// the system's selected default inference profile; the recorder's
  /// automatic path is suppressed, so this explicit request runs once.
  /// Preflight refuses recording if the default has no transcription slot.
  Future<void> _dictate() async {
    if (!_speechIdle || _isSaving) return;
    // The keyboard goes first: the recorder is about to take the field.
    _narrativeFocus.unfocus();
    setState(() => _phase = const CheckInSpeechPreparing());
    // Every provider is read up front: each `await` below can outlive this
    // widget, and reading through `ref` after that throws.
    final repository = ref.read(relationshipRepositoryProvider);
    final transcription = ref.read(checkInTranscriptionServiceProvider);
    try {
      // Both reads hit the database and neither depends on the other;
      // running them in series doubled the delay before the recorder
      // appeared.
      final (relationship, canTranscribe) = await (
        repository.getRelationshipById(widget.relationshipId),
        transcription.canTranscribe(),
      ).wait.timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (!canTranscribe) {
        setState(
          () => _phase = const CheckInSpeechFailed(
            CheckInSpeechFailure(
              CheckInSpeechFailureKind.transcriptionUnavailable,
            ),
          ),
        );
        return;
      }
      _categoryId = relationship?.meta.categoryId;
      // The app-wide recorder may already be running: this person's take,
      // left running when the sheet was dismissed, is adopted; anyone
      // else's is left alone, because `record()` on a running recorder
      // toggles it OFF — the earlier take would be saved wordless and the
      // new one would never start.
      final running = ref.read(audioRecorderControllerProvider);
      final busy = running.status != AudioRecorderStatus.stopped;
      if (busy && running.linkedId != widget.relationshipId) {
        setState(
          () => _phase = const CheckInSpeechFailed(
            CheckInSpeechFailure(CheckInSpeechFailureKind.recorderBusy),
          ),
        );
        return;
      }
      _adoptRunning = busy;
      widget.handle.recorder = ref.read(
        audioRecorderControllerProvider.notifier,
      );
      setState(() => _phase = const CheckInSpeechRecording());
    } catch (exception, stackTrace) {
      developer.log(
        'Spoken check-in failed to start',
        name: 'CheckInCaptureForm',
        error: exception,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(
        () => _phase = const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.recordingFailed),
        ),
      );
    }
  }

  void _onRecorded(String audioEntryId, Duration length) {
    setState(() {
      _phase = const CheckInSpeechIdle();
      _takes = [
        ..._takes,
        CheckInTake(audioEntryId: audioEntryId, length: length),
      ];
    });
    unawaited(_transcribe(audioEntryId));
  }

  void _onRecordingDiscarded() {
    if (!mounted) return;
    setState(() => _phase = const CheckInSpeechIdle());
  }

  void _onRecordingFailed(CheckInSpeechFailureKind failure) {
    if (!mounted) return;
    // The recorder hid the floating indicator on the way in; a start that
    // never happened has nothing for it to point at, but a stop that could
    // not save may leave the app-wide recorder as it was — either way the
    // indicator is the user's again, now rather than when the sheet closes.
    widget.handle.releaseRecorder();
    setState(() => _phase = CheckInSpeechFailed(CheckInSpeechFailure(failure)));
  }

  /// Replaces the take for [audioEntryId] through [update], when it is
  /// still one of this composer's.
  void _updateTake(
    String audioEntryId,
    CheckInTake Function(CheckInTake) update,
  ) {
    if (!mounted) return;
    setState(
      () => _takes = [
        for (final take in _takes)
          if (take.audioEntryId == audioEntryId) update(take) else take,
      ],
    );
  }

  bool _holds(String audioEntryId) =>
      _takes.any((take) => take.audioEntryId == audioEntryId);

  /// Asks for the words of [audioEntryId] and shows them on its take when
  /// they land. The recorder suppressed automatic inference for this
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
      developer.log(
        'Could not name the transcription route',
        name: 'CheckInCaptureForm',
        error: exception,
        stackTrace: stackTrace,
      );
      return;
    }
    if (route == null) return;
    final label = '${route.model} · $via ${route.provider}';
    _updateTake(audioEntryId, (take) => take.withRoute(label));
  }

  /// *Try again* on a take whose words never came: the same recording,
  /// asked for once more — never a second recording.
  void _retryTake(String audioEntryId) => unawaited(_transcribe(audioEntryId));

  /// *Remove recording*: the take stays out of the check-in. Its audio stays
  /// in the journal, linked to the person, as the discard question says.
  void _removeTake(String audioEntryId) {
    _closeTranscriptWait(audioEntryId);
    setState(
      () => _takes = [
        for (final take in _takes)
          if (take.audioEntryId != audioEntryId) take,
      ],
    );
  }

  /// *Type instead* on a failure card: the field comes back as plain text.
  void _typeInstead() {
    setState(() => _phase = const CheckInSpeechIdle());
    _narrativeFocus.requestFocus();
  }

  Future<void> _openSettings() => ref.read(checkInSettingsOpenerProvider)();

  /// Stops listening for [audioEntryId]'s words.
  void _closeTranscriptWait(String audioEntryId) {
    _transcriptWaits[audioEntryId]?.cancel();
    _forgetTranscriptWait(audioEntryId);
  }

  /// Drops a wait that has ended, and its failure watch.
  void _forgetTranscriptWait(String audioEntryId) {
    _transcriptWaits.remove(audioEntryId);
    _transcriptFailures.remove(audioEntryId)?.close();
  }

  Future<void> _handleSave() async {
    if (_block != CheckInSaveBlock.none) return;
    setState(() => _isSaving = true);

    final repository = ref.read(relationshipRepositoryProvider);
    final narrative = _narrativeController.text.trim();
    final payAttentionTo = _payAttentionController.text.trim();
    final avoid = _avoidController.text.trim();
    final data = CheckInData(
      relationshipId: widget.relationshipId,
      interactionType: _interactionType,
      sentiment: _sentiment,
      topics: _topics,
      payAttentionTo: payAttentionTo.isEmpty ? null : payAttentionTo,
      avoid: avoid.isEmpty ? null : avoid,
    );
    final entryText = EntryText(plainText: narrative);

    try {
      if (_isEditing) {
        final initial = widget.initial!;
        final updated = initial.copyWith(
          data: data,
          entryText: entryText,
          meta: initial.meta.copyWith(
            dateFrom: _interactionTime,
            dateTo: _interactionTime.add(_duration),
          ),
        );
        final success = await repository.updateCheckIn(updated);
        if (!mounted) return;
        if (success) {
          Navigator.of(context).pop(updated);
        } else {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.checkInErrorCreateFailed,
          );
        }
      } else {
        final created = await repository.createCheckIn(
          data: data,
          entryText: entryText,
          dateFrom: _interactionTime,
          dateTo: _interactionTime.add(_duration),
        );
        // The recordings become the check-in's entries. The check-in is
        // saved either way: a link that fails is logged by the repository
        // and must not turn into "save failed", which a retry would answer
        // with a duplicate check-in.
        if (created != null && _takes.isNotEmpty) {
          await repository.attachEntriesToCheckIn(
            checkInId: created.id,
            entryIds: [for (final take in _takes) take.audioEntryId],
          );
        }
        if (!mounted) return;
        if (created != null) {
          Navigator.of(context).pop(created);
        } else {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.checkInErrorCreateFailed,
          );
        }
      }
    } catch (e, s) {
      developer.log(
        'Failed to save check-in',
        name: 'CheckInCaptureForm',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.checkInErrorCreateFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final initial = widget.initial;
    if (initial == null || _isSaving) return;

    final confirmed = await showConfirmationModal(
      context: context,
      message: context.messages.checkInDeleteConfirmMessage,
      confirmLabel: context.messages.deleteButton,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final deleted = await ref
          .read(relationshipRepositoryProvider)
          .deleteCheckIn(initial.id);
      if (!mounted) return;
      if (deleted) {
        Navigator.of(context).pop();
      } else {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.checkInErrorDeleteFailed,
        );
      }
    } catch (e, s) {
      developer.log(
        'Failed to delete check-in',
        name: 'CheckInCaptureForm',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.checkInErrorDeleteFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// `Now · 12:46` while the start is this very minute, otherwise the day
  /// and the time — what the *Started* chip reads.
  String _startedLabel(BuildContext context) =>
      checkInStartedLabelOf(context, _interactionTime);

  /// The save shortcut and its label — desktop only, where a keyboard is a
  /// given and the field's footer has room to say so.
  ({SingleActivator activator, String label})? _saveShortcut(
    BuildContext context,
  ) {
    if (!isDesktop) return null;
    final platform = Theme.of(context).platform;
    final activator = platform == TargetPlatform.macOS
        ? const SingleActivator(LogicalKeyboardKey.enter, meta: true)
        : const SingleActivator(LogicalKeyboardKey.enter, control: true);
    return (
      activator: activator,
      label: ShortcutLabelFormatter.activatorLabel(
        context.messages,
        activator,
        platform,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final recording = _phase is CheckInSpeechRecording;
    // Watched only while the recorder is up, so an idle form never
    // rebuilds on the app-wide recorder's level ticks.
    final recorderPaused =
        recording &&
        ref.watch(
          audioRecorderControllerProvider.select(
            (state) => state.status == AudioRecorderStatus.paused,
          ),
        );
    _publish(context, recorderPaused: recorderPaused);

    // One level under the fold trigger: the same size, the quieter ink.
    Widget sectionLabel(String text) => Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: Text(
        text,
        style: tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
    Widget caption(String text) => Text(
      text,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.lowEmphasis,
      ),
    );

    final prefilledFrom =
        !_isEditing &&
            widget.prefilledInteractionType != null &&
            widget.prefilledTime != null &&
            widget.prefilledDuration != null
        ? widget.prefilledInteractionType
        : null;
    final shortcut = _saveShortcut(context);
    final speechIdle = _speechIdle && !_isSaving;

    // One scrollable, not two. The modal page already scrolls its child and
    // adds a top bar, padding and the bottom safe area on top of it, so a
    // form that also capped itself at `modalMaxHeightFraction` of the SCREEN
    // overflowed the page — and because the inner `SingleChildScrollView`
    // consumed the drag, the outer one never moved and the action row below
    // it could not be reached at all. Let the page own the scrolling.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckInNarrativeField(
          controller: _narrativeController,
          focusNode: _narrativeFocus,
          phase: _phase,
          wordCount: checkInWordCount(_narrativeController.text),
          shortcutHint: shortcut?.label,
          restMinLines: widget.dialog ? 2 : 3,
          offersDictation: _offersDictation,
          recorder: recording
              ? CheckInInlineRecorder(
                  linkedId: widget.relationshipId,
                  categoryId: _categoryId,
                  adoptRunning: _adoptRunning,
                  onRecorded: _onRecorded,
                  onDiscarded: _onRecordingDiscarded,
                  onFailed: _onRecordingFailed,
                )
              : null,
          takes: _takes,
          onDictate: speechIdle ? _dictate : null,
          onRetryTake: _isSaving ? null : _retryTake,
          onRemoveTake: _isSaving ? null : _removeTake,
          onOpenSettings: _openSettings,
          onDismissFailure: _typeInstead,
        ),
        SizedBox(height: tokens.spacing.step5),
        CheckInContextChips(
          type: _interactionType,
          startedLabel: _startedLabel(context),
          durationLabel: _duration == Duration.zero
              ? messages.checkInDurationChip
              : checkInDurationLabel(context, _duration),
          enabled: speechIdle,
          onPickType: _pickType,
          onPickStart: _pickStart,
          onPickDuration: _pickDuration,
        ),
        // Where the numbers came from (design §5): the offer's channel,
        // start and elapsed time, and that every one of them is editable.
        if (prefilledFrom != null) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            prefilledFrom == CheckInInteractionType.call
                ? messages.checkInSourceCall
                : messages.checkInSourceMessage,
            key: const ValueKey('check-in-source-strip'),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step3),
        _MoreHeader(
          open: _moreOpen,
          caption: _moreCaption(messages),
          onToggle: () => setState(() => _moreOpen = !_moreOpen),
        ),
        if (_moreOpen) ...[
          SizedBox(height: tokens.spacing.step4),
          sectionLabel(messages.checkInSentimentLabel),
          Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step3,
            children: [
              for (final sentiment in CheckInSentiment.values)
                DesignSystemChip(
                  key: ValueKey('check-in-sentiment-${sentiment.name}'),
                  label: checkInSentimentLabel(context, sentiment),
                  // The chosen feeling carries a glyph as well as its fill,
                  // so the choice reads without colour.
                  leadingIcon: _sentiment == sentiment
                      ? LottiIcons.confirm
                      : null,
                  selected: _sentiment == sentiment,
                  size: DesignSystemChipSize.touch,
                  // Tapping the selected sentiment clears it again —
                  // sentiment is optional, never forced.
                  onPressed: () => setState(
                    () =>
                        _sentiment = _sentiment == sentiment ? null : sentiment,
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          caption(messages.checkInSentimentOptional),
          // One section gap between the folded sections, whatever each
          // holds: the edit sheet opens on all of them at once.
          SizedBox(height: tokens.spacing.sectionGap),

          // The design system's own input, so the folded details wear the
          // same chrome as the rest of the sheet.
          // Every section under More wears the same heading, one level
          // under the fold trigger, so the inputs read as its children.
          sectionLabel(messages.checkInTopicsLabel),
          DesignSystemTextInput(
            key: const ValueKey('check-in-topics'),
            controller: _topicsController,
            semanticsLabel: messages.checkInTopicsLabel,
            hintText: messages.checkInTopicsHint,
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          sectionLabel(messages.checkInPayAttentionLabel),
          DesignSystemTextInput(
            key: const ValueKey('check-in-pay-attention'),
            controller: _payAttentionController,
            semanticsLabel: messages.checkInPayAttentionLabel,
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          sectionLabel(messages.checkInAvoidLabel),
          DesignSystemTextInput(
            key: const ValueKey('check-in-avoid'),
            controller: _avoidController,
            semanticsLabel: messages.checkInAvoidLabel,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        _BarSlack(handle: widget.handle),
      ],
    );

    // The sheet's own ways out — the back gesture, the barrier — come
    // through here too, so a draft is guarded however the user leaves.
    final guarded = PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_dismiss());
      },
      child: body,
    );
    if (shortcut == null) return guarded;
    return CallbackShortcuts(
      bindings: {
        shortcut.activator: () {
          if (_block == CheckInSaveBlock.none) unawaited(_handleSave());
        },
      },
      child: guarded,
    );
  }
}

/// The *More* row: the section name, what it holds, and the chevron.
/// `a · b · c` → `[a · b · c, a · b, a]`: the caption's own separators are
/// its rungs, whatever the language.
List<String> _captionLadder(String caption) {
  final parts = caption.split(' · ');
  return [
    for (var n = parts.length; n >= 1; n--) parts.take(n).join(' · '),
  ];
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader({
    required this.open,
    required this.caption,
    required this.onToggle,
  });

  final bool open;

  /// What is folded — the field names until a value is set, then the value
  /// (`Good · 2 topics · next time noted`), so the row never says less than
  /// it holds.
  final String caption;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Semantics(
      button: true,
      expanded: open,
      label: messages.checkInMoreSection,
      child: InkWell(
        key: const ValueKey('check-in-more'),
        onTap: onToggle,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        // A full touch target on a row that is mostly caption.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TapTargets.minimum),
          child: Row(
            children: [
              Text(
                messages.checkInMoreSection,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              // Flexible, so a narrow phone or large text trims the caption
              // rather than pushing the chevron off the row.
              if (!open)
                Expanded(
                  child: DsTieredText(
                    // `Feeling · topics · next time` sheds a segment at a
                    // time, so large text never slices a word in half.
                    tiers: _captionLadder(caption),
                    textAlign: TextAlign.end,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                )
              else
                const Spacer(),
              SizedBox(width: tokens.spacing.step2),
              Icon(
                open ? LottiIcons.chevronUp : LottiIcons.chevronDown,
                size: IconSizes.s,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
