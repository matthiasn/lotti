import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_cs.dart';
import 'package:lotti/l10n/app_localizations_da.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/l10n/app_localizations_it.dart';
import 'package:lotti/l10n/app_localizations_nl.dart';
import 'package:lotti/l10n/app_localizations_pt.dart';
import 'package:lotti/l10n/app_localizations_sv.dart';

/// The two messages the task-unlink confirmation is built from. An untranslated
/// key does not fail the build — `gen_l10n` falls back to the English string —
/// so a locale can silently answer in English inside an otherwise translated
/// screen. These assert the translation itself, which is what the fallback
/// looks like when it is missing.
void main() {
  final english = AppLocalizationsEn();

  final catalogs = <String, AppLocalizations>{
    'da': AppLocalizationsDa(),
    'it': AppLocalizationsIt(),
    'nl': AppLocalizationsNl(),
    'pt': AppLocalizationsPt(),
    'sv': AppLocalizationsSv(),
  };

  group('unlink task messages', () {
    test('every catalog names the task it is about', () {
      for (final MapEntry(key: locale, value: messages) in catalogs.entries) {
        expect(
          messages.unlinkTaskConfirmNamed('Pip Frostbeak'),
          contains('Pip Frostbeak'),
          reason: '$locale drops the title placeholder',
        );
      }
    });

    test('no catalog falls back to English', () {
      for (final MapEntry(key: locale, value: messages) in catalogs.entries) {
        expect(
          messages.unlinkTaskConfirmNamed('Pip Frostbeak'),
          isNot(english.unlinkTaskConfirmNamed('Pip Frostbeak')),
          reason: '$locale still shows the English confirmation',
        );
        expect(
          messages.unlinkTaskFailedMessage,
          isNot(english.unlinkTaskFailedMessage),
          reason: '$locale still shows the English failure',
        );
      }
    });

    test('each catalog uses the unlink verb it already uses elsewhere', () {
      expect(
        AppLocalizationsDa().unlinkTaskConfirmNamed('Pip'),
        'Koble „Pip“ fra? Selve opgaven bliver ikke slettet.',
      );
      expect(
        AppLocalizationsIt().unlinkTaskConfirmNamed('Pip'),
        'Scollegare «Pip»? L’attività non viene eliminata.',
      );
      expect(
        AppLocalizationsNl().unlinkTaskConfirmNamed('Pip'),
        '„Pip“ ontkoppelen? De taak zelf wordt niet verwijderd.',
      );
      expect(
        AppLocalizationsPt().unlinkTaskConfirmNamed('Pip'),
        'Desvincular «Pip»? A tarefa em si não é excluída.',
      );
      expect(
        AppLocalizationsSv().unlinkTaskConfirmNamed('Pip'),
        'Koppla bort „Pip“? Själva uppgiften raderas inte.',
      );
    });

    test('the failure message keeps the informal register', () {
      // The app addresses users informally everywhere but Romanian, and this
      // Czech string was the catalog's own outlier: "Zkuste" against 35 uses
      // of "Zkus".
      expect(
        AppLocalizationsCs().unlinkTaskFailedMessage,
        'Propojení úkolu se nepodařilo zrušit. Zkus to prosím znovu.',
      );
      expect(
        AppLocalizationsIt().unlinkTaskFailedMessage,
        isNot(contains('Si prega di')),
      );
    });
  });
}
