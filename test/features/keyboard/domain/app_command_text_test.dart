import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_text.dart';
import 'package:lotti/l10n/app_localizations.dart';

void main() {
  test(
    'every command and category has copy in every supported language',
    () async {
      for (final locale in AppLocalizations.supportedLocales) {
        final messages = await AppLocalizations.delegate.load(locale);
        for (final id in AppCommandId.values) {
          expect(
            AppCommandText.label(messages, id),
            isNotEmpty,
            reason: '${locale.languageCode}:${id.name}',
          );
        }
        for (final category in AppCommandCategory.values) {
          expect(
            AppCommandText.category(messages, category),
            isNotEmpty,
            reason: '${locale.languageCode}:${category.name}',
          );
        }
      }
    },
  );
}
