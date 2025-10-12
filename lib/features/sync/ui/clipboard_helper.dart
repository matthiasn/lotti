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
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      snackBar ?? const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}
