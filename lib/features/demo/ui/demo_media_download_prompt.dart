import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// What the user chose when asked about the demo's photos.
enum DemoMediaChoice {
  /// Download the photos into the demo world.
  download,

  /// Enter the demo without them; the blurred stand-ins take their place.
  skip,
}

/// Asks whether to download the demo's photos, disclosing their size in
/// [bytes] before anything is fetched (App Store guideline 4.2.3(ii)).
///
/// Returns null when the prompt is dismissed without a choice — the caller
/// then enters nothing.
Future<DemoMediaChoice?> showDemoMediaDownloadPrompt(
  BuildContext context, {
  required int bytes,
}) async {
  DemoMediaChoice? choice;
  await ModalUtils.showSinglePageModal<void>(
    context: context,
    hasTopBarLayer: false,
    builder: (modalContext) => DemoMediaDownloadPrompt(
      bytes: bytes,
      onChoice: (selected) {
        choice = selected;
        Navigator.of(modalContext).pop();
      },
    ),
  );
  return choice;
}

/// [bytes] as megabytes for the prompt, rounded UP to one decimal so the
/// size shown never understates the download.
String formatDemoMediaSize(AppLocalizations messages, int bytes) {
  final tenths = (bytes / 100000).ceil();
  return messages.demoMediaPromptSize(
    NumberFormat('0.0', messages.localeName).format(tenths / 10),
  );
}

/// Body of [showDemoMediaDownloadPrompt]: the size, what skipping means, and
/// one button per [DemoMediaChoice].
class DemoMediaDownloadPrompt extends StatelessWidget {
  const DemoMediaDownloadPrompt({
    required this.bytes,
    required this.onChoice,
    super.key,
  });

  final int bytes;
  final ValueChanged<DemoMediaChoice> onChoice;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final size = formatDemoMediaSize(messages, bytes);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LottiIcons.photoLibrary,
          size: tokens.spacing.step9,
          color: tokens.colors.interactive.enabled,
        ),
        SizedBox(height: tokens.spacing.step4),
        Text(
          messages.demoMediaPromptTitle,
          style: tokens.typography.styles.heading.heading3.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.demoMediaPromptMessage(size),
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.step7),
        DesignSystemModalActionBar(
          secondary: [
            DesignSystemButton(
              onPressed: () => onChoice(DemoMediaChoice.skip),
              label: messages.demoMediaPromptSkip,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.large,
            ),
          ],
          primary: DesignSystemButton(
            onPressed: () => onChoice(DemoMediaChoice.download),
            label: messages.demoMediaPromptDownload(size),
            leadingIcon: LottiIcons.download,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
          ),
        ),
      ],
    );
  }
}
