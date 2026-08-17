import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_de.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/l10n/device_messages.dart';

void main() {
  // The shared resolver for copy produced outside the widget tree: OS
  // notification text, durable notification rows, sync observers. Its two
  // behaviours are "follow the device locale" and "never throw".
  group('deviceMessages', () {
    testWidgets('resolves a shipped locale', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('de');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final messages = deviceMessages();

      expect(messages, isA<AppLocalizationsDe>());
      expect(
        messages.relationshipCheckInReminderTitle('Anna'),
        'Bei Anna melden?',
      );
    });

    testWidgets('falls back to English for a locale we do not ship', (
      tester,
    ) async {
      // A reminder in the wrong language is a far smaller failure than a
      // reminder that throws and never fires.
      tester.platformDispatcher.localeTestValue = const Locale('xx');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final messages = deviceMessages();

      expect(messages, isA<AppLocalizationsEn>());
      expect(
        messages.relationshipCheckInReminderTitle('Anna'),
        'Check in with Anna?',
      );
    });

    testWidgets('reads the binding dispatcher, not the global singleton', (
      tester,
    ) async {
      // `localeTestValue` only overrides the binding's dispatcher. If the
      // implementation read the global `PlatformDispatcher.instance` instead,
      // this override would not be visible and the assertion would see the
      // host locale.
      tester.platformDispatcher.localeTestValue = const Locale('de');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      expect(deviceMessages(), isA<AppLocalizationsDe>());

      tester.platformDispatcher.clearLocaleTestValue();

      expect(deviceMessages(), isA<AppLocalizations>());
    });
  });
}
