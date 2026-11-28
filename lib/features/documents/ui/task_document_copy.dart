import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Puts a document's [markdown] on the clipboard and says so — the one copy
/// path the section's rows and the document page share.
Future<void> copyTaskDocumentMarkdown(
  BuildContext context,
  String markdown,
) async {
  await Clipboard.setData(ClipboardData(text: markdown));
  if (!context.mounted) return;
  context.showToast(
    tone: DesignSystemToastTone.success,
    title: context.messages.taskDocumentsCopied,
    duration: const Duration(seconds: 2),
  );
}
