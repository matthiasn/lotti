part of 'check_in_capture_sheet.dart';

/// The composer's pinned actions (design 2026-09-13): *Save check-in* is
/// visible whenever saving is a thing the user could do next, and when it
/// is held the bar says why. Cancel beside it — and, while editing, delete
/// on the leading edge. On a phone with the keyboard up the bar slims to
/// the context summary and a short *Save*, so the words the user is typing
/// keep the room (option 1g). While the recorder is up there is no bar at
/// all: the recorder carries its own Discard · Pause and the orb, whose
/// caption says what stops the take, and a second row of Cancel and a held
/// Save beneath it was two action bars on one screen, with Cancel and
/// Discard a finger apart and different fates. Reads the form through its
/// [handle].
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
    // Recording has no bar to say why: the recorder's orb caption does.
    CheckInSaveBlock.none ||
    CheckInSaveBlock.saving ||
    CheckInSaveBlock.recording => null,
    CheckInSaveBlock.preparing => messages.checkInPreparingLabel,
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

          // One action bar at a time: while the recorder owns the field, its
          // own discard ✕ · pause · Stop are the actions — so the bar is
          // nothing at all.
          // A strip holding only "Stop recording to save" was read as a
          // hollow bar with a second Stop instruction; the one settle when
          // Stop brings the actions back costs less than that.
          if (handle.block == CheckInSaveBlock.recording) {
            return const SizedBox.shrink(
              key: ValueKey('check-in-actions-recording'),
            );
          }

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

/// The room the form keeps under its last field for the pinned action bar,
/// so the last field can scroll fully above it: the bar's predicted height
/// for this layout — so the desktop dialog, whose bar has no reason line of
/// its own, carries no blank band above its footer — or the *measured* bar
/// when it stacked taller on a narrow phone. While a take runs the bar is
/// gone, so the reserve is only a group's gap under the recorder.
class _BarReserve extends StatelessWidget {
  const _BarReserve({required this.handle});

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
        // While a take runs the bar is gone: a group's gap under the
        // recorder's controls, not the bar's height of nothing.
        if (handle.block == CheckInSaveBlock.recording) {
          return SizedBox(
            key: const ValueKey('check-in-bar-reserve-recording'),
            height: tokens.spacing.sectionGap,
          );
        }
        final measured = handle.barHeight;
        return SizedBox(
          key: const ValueKey('check-in-bar-reserve'),
          height: measured == null || measured <= predicted
              ? predicted
              : measured,
        );
      },
    );
  }
}
