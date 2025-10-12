import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClipboardHelper {
  const ClipboardHelper._();

  /// Copies [text] to the system clipboard, then shows a SnackBar.
  static Future<void> copyTextWithSnackBar(
    BuildContext context,
    String text, {
    SnackBar? snackBar,
  }) async {
    // Capture messenger before the async gap to avoid using context after await.
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      snackBar ?? const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}
