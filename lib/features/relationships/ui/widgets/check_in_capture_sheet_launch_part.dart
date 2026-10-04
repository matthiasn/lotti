part of 'check_in_capture_sheet.dart';

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
