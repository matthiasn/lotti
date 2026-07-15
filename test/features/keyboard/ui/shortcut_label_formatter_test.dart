import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_catalog.dart';
import 'package:lotti/features/keyboard/ui/shortcut_label_formatter.dart';
import 'package:lotti/l10n/app_localizations.dart';

void main() {
  test('uses localized Windows modifiers and compact macOS symbols', () async {
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final german = await AppLocalizations.delegate.load(const Locale('de'));
    final palette = AppCommandCatalog.definition(
      AppCommandId.openCommandPalette,
    );

    expect(
      ShortcutLabelFormatter.bindings(
        english,
        palette.bindings,
        platform: TargetPlatform.windows,
      ),
      'Ctrl+K',
    );
    expect(
      ShortcutLabelFormatter.bindings(
        german,
        palette.bindings,
        platform: TargetPlatform.windows,
      ),
      'Strg+K',
    );
    expect(
      ShortcutLabelFormatter.bindings(
        english,
        palette.bindings,
        platform: TargetPlatform.macOS,
      ),
      '⌘K',
    );
  });

  test('formats alternate bindings and layout-aware characters', () async {
    final messages = await AppLocalizations.delegate.load(const Locale('en'));
    final help = AppCommandCatalog.definition(AppCommandId.openShortcutHelp);

    expect(
      ShortcutLabelFormatter.bindings(
        messages,
        help.bindings,
        platform: TargetPlatform.macOS,
      ),
      '⌘? or F1',
    );
  });

  test(
    'falls back to the activator description for custom activators',
    () async {
      final messages = await AppLocalizations.delegate.load(const Locale('en'));
      final activator = LogicalKeySet(LogicalKeyboardKey.keyA);

      expect(
        ShortcutLabelFormatter.activatorLabel(
          messages,
          activator,
          TargetPlatform.windows,
        ),
        activator.toString(),
      );
    },
  );
}
