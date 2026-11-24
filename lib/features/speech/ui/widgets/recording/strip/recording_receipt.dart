import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_leading.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme_text_styles.dart'
    show numericBadgeFontFeatures;
import 'package:lotti/utils/entry_tools.dart';
import 'package:material_ui/material_ui.dart';

/// What replaces the recording strip, in its place, for a few seconds
/// after Stop: *✓ Saved to …* (*Voice note saved*), the take's length — and
/// that it is being transcribed, where it is — with **Undo**, which deletes
/// the take, and **Open**, which goes to what it was saved to. Open shows
/// only away from where the take started; there it would go nowhere.
///
/// It is handed its [receipt] rather than watching for one, so it can leave
/// with its words still on it once the receipt is gone.
class RecordingReceiptRow extends ConsumerWidget {
  const RecordingReceiptRow({required this.receipt, super.key});

  final RecordingReceipt receipt;

  static const Key receiptKey = ValueKey('recording-receipt');
  static const Key undoKey = ValueKey('recording-receipt-undo');
  static const Key openKey = ValueKey('recording-receipt-open');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final nav = ref.watch(navServiceProvider);
    final title = receipt.subjectTitle;
    final saved = title == null
        ? messages.recordingReceiptSavedVoiceNote
        : messages.recordingReceiptSaved(title);
    final time = formatElapsed(receipt.duration);
    final detail = receipt.transcribing
        ? messages.recordingReceiptTranscribing(time)
        : time;

    return RecordingStrip.surface(
      context,
      key: receiptKey,
      child: SizedBox(
        height: RecordingStrip.height(context),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.spacing.step5,
            end: tokens.spacing.step2,
          ),
          child: Row(
            children: [
              Icon(
                LottiIcons.confirm,
                size: IconSizes.m,
                color: tokens.colors.alert.success.defaultColor,
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
                        saved,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.highEmphasis,
                        ),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                          fontFeatures: numericBadgeFontFeatures,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: nav.activeRouteChanges,
                builder: (context, _) =>
                    isOnRecordingOrigin(nav.activeRoute, receipt.origin)
                    ? const SizedBox.shrink()
                    : DesignSystemButton(
                        key: openKey,
                        label: messages.recordingReceiptOpen,
                        variant: DesignSystemButtonVariant.tertiary,
                        tapTargetSize: MaterialTapTargetSize.padded,
                        onPressed: () =>
                            ref.read(recordingSessionProvider).openReceipt(),
                      ),
              ),
              DesignSystemButton(
                key: undoKey,
                label: messages.recordingReceiptUndo,
                variant: DesignSystemButtonVariant.tertiary,
                tapTargetSize: MaterialTapTargetSize.padded,
                onPressed: () => ref
                    .read(recordingReceiptControllerProvider.notifier)
                    .undo(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
