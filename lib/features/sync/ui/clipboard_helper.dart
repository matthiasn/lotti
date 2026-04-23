import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';

class ClipboardHelper {
  const ClipboardHelper._();

  /// Copies [text] to the system clipboard, then shows a [DesignSystemToast].
  ///
  /// The toast uses [title] / [description] / [tone] / [duration]. Callers
  /// are responsible for passing localized strings.
  static Future<void> copyTextAndNotify(
    BuildContext context,
    String text, {
    required String title,
    String? description,
    DesignSystemToastTone tone = DesignSystemToastTone.success,
    Duration duration = const Duration(seconds: 4),
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    context.showToast(
      tone: tone,
      title: title,
      description: description,
      duration: duration,
    );
  }
}
