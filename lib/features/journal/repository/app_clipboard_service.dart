import 'package:flutter/services.dart';
import 'package:lotti/utils/platform.dart';
import 'package:riverpod/riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Abstraction over clipboard operations to enable mocking in tests.
class AppClipboard {
  const AppClipboard({required this.writePlainText});
  final Future<void> Function(String text) writePlainText;
}

AppClipboard makeSuperClipboardService() => AppClipboard(
      writePlainText: (String text) async {
        final trimmed =
            text; // keep newlines; only test for emptiness elsewhere
        if (trimmed.isEmpty) return;

        // In tests or if the native clipboard isn't available, fall back to
        // Flutter's basic Clipboard API to avoid plugin channels.
        if (isTestEnv) {
          await Clipboard.setData(ClipboardData(text: trimmed));
          return;
        }

        final clipboard = SystemClipboard.instance;
        if (clipboard != null) {
          final item = DataWriterItem()..add(Formats.plainText(trimmed));
          await clipboard.write([item]);
          return;
        }
        await Clipboard.setData(ClipboardData(text: trimmed));
      },
    );

final appClipboardProvider = Provider<AppClipboard>((ref) {
  return makeSuperClipboardService();
});
