import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_leading.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme_text_styles.dart'
    show dateFigureFontFeatures;
import 'package:lotti/utils/entry_tools.dart';
import 'package:material_ui/material_ui.dart';

/// What replaces the recording strip, in its place, for a few seconds
/// after Stop, in the strip's own grammar: a tick in the leading glyph's
/// slot, *Saved · 0:42* (*· transcribing*, where a transcript is coming)
/// over what the take was saved to (*Voice note* for one saved to nothing),
/// then two bounded buttons: **Undo**, which deletes the take, a neutral
/// outline, and **Open**, which goes to what it was saved to, the primary,
/// at the trailing edge — the way forward outweighs the delete. Open shows only where it leads somewhere: a voice note's own entry,
/// or — away from where the take started — back to a subject that is still
/// there.
///
/// It takes no tap for [armDelay] after it appears — with or without
/// motion — so a second tap meant for the Stop it replaced can never land on
/// Undo.
///
/// It is handed its [receipt] rather than watching for one, so it can leave
/// with its words still on it once the receipt is gone.
class RecordingReceiptRow extends ConsumerStatefulWidget {
  const RecordingReceiptRow({required this.receipt, super.key});

  final RecordingReceipt receipt;

  static const Key receiptKey = ValueKey('recording-receipt');
  static const Key undoKey = ValueKey('recording-receipt-undo');
  static const Key openKey = ValueKey('recording-receipt-open');

  /// How long the receipt ignores taps after it appears.
  static const Duration armDelay = MotionDurations.medium1;

  @override
  ConsumerState<RecordingReceiptRow> createState() =>
      _RecordingReceiptRowState();
}

class _RecordingReceiptRowState extends ConsumerState<RecordingReceiptRow> {
  bool _armed = false;
  Timer? _arm;

  @override
  void initState() {
    super.initState();
    _arm = Timer(RecordingReceiptRow.armDelay, () {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  void dispose() {
    _arm?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    final tokens = context.designTokens;
    final messages = context.messages;
    final nav = ref.watch(navServiceProvider);
    final time = formatElapsed(receipt.duration);
    final caption = receipt.transcribing
        ? messages.recordingReceiptTranscribing(time)
        : messages.recordingReceiptSaved(time);
    final title = receipt.subjectTitle ?? messages.recordingStripVoiceNote;
    // A subject's take goes back to its origin, which needs both; a voice
    // note opens its own entry.
    final canOpen =
        receipt.subjectId == null ||
        (receipt.subjectTitle != null && receipt.origin != null);

    return RecordingStrip.surface(
      context,
      key: RecordingReceiptRow.receiptKey,
      child: SizedBox(
        height: RecordingStrip.height(context),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
          child: Row(
            children: [
              SizedBox(width: tokens.spacing.step3),
              Icon(
                LottiIcons.confirm,
                size: RecordingStripLeading.glyphSlot,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: recordingCaptionStyle(
                          tokens,
                        ).copyWith(fontFeatures: dateFigureFontFeatures),
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: recordingTitleStyle(tokens),
                      ),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: !_armed,
                child: DesignSystemButton(
                  key: RecordingReceiptRow.undoKey,
                  label: messages.recordingReceiptUndo,
                  variant: DesignSystemButtonVariant.outlined,
                  tapTargetSize: MaterialTapTargetSize.padded,
                  onPressed: () => ref
                      .read(recordingReceiptControllerProvider.notifier)
                      .undo(),
                ),
              ),
              ListenableBuilder(
                listenable: nav.activeRouteChanges,
                builder: (context, _) =>
                    !canOpen ||
                        isOnRecordingOrigin(nav.activeRoute, receipt.origin)
                    ? const SizedBox.shrink()
                    // Kept clear of Undo, so aiming for one never lands on
                    // the other.
                    : Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: tokens.spacing.step5,
                        ),
                        child: IgnorePointer(
                          ignoring: !_armed,
                          child: DesignSystemButton(
                            key: RecordingReceiptRow.openKey,
                            label: messages.recordingReceiptOpen,
                            tapTargetSize: MaterialTapTargetSize.padded,
                            onPressed: () => ref
                                .read(recordingSessionProvider)
                                .openReceipt(),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
