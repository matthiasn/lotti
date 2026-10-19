import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/download_size.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// Asks whether to download the voice [model], showing its size, before
/// anything is fetched (App Store guideline 4.2.3(ii)). Answers true only
/// when the user chose to download.
///
/// Every read-aloud control passes this as
/// `TtsPlaybackController.speak(confirmModelDownload:)`, the one way the
/// model is ever downloaded.
Future<bool> confirmTtsModelDownload(
  BuildContext context,
  TtsModelOption model,
) async {
  if (!context.mounted) return false;
  final messages = context.messages;
  final size = formatDownloadMegabytes(messages, model.totalBytes);
  return showConfirmationModal(
    context: context,
    title: messages.ttsModelDownloadTitle,
    message: messages.ttsModelDownloadMessage(size),
    confirmLabel: messages.ttsModelDownloadConfirm(size),
    isDestructive: false,
  );
}
