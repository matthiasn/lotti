import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The day page's count captions read naturally at one as well as at many:
/// "1 gestionado", not "1 gestionados". Each language's own singular is
/// asserted where it differs from its plural, so a catalog that drops its
/// ICU plural back to a single form fails here.
void main() {
  AppLocalizations l(String code) => lookupAppLocalizations(Locale(code));

  final singulars = <String, List<(String Function(AppLocalizations), String)>>{
    'es': [
      ((m) => m.dailyOsNextActivityHandledCount(1), '1 gestionado'),
      ((m) => m.dailyOsNextActivityWaitingCount(1), '1 pendiente'),
      ((m) => m.dailyOsNextAgendaLeft(1, '30m'), 'Queda 1 · 30m'),
      ((m) => m.dailyOsNextBriefingDoneCaption(1), '1 hecha'),
    ],
    'fr': [
      ((m) => m.dailyOsNextActivityHandledCount(1), '1 traité'),
      ((m) => m.dailyOsNextAgendaLeft(1, '30m'), '1 restant · 30m'),
      ((m) => m.dailyOsNextBriefingDoneCaption(1), '1 terminée'),
      ((m) => m.dailyOsNextBriefingMoreCategories(1), '+1 autre'),
    ],
    'it': [
      ((m) => m.dailyOsNextActivityHandledCount(1), '1 gestito'),
      ((m) => m.dailyOsNextBriefingDoneCaption(1), '1 fatta'),
      ((m) => m.dailyOsNextBriefingMoreCategories(1), '+1 altra'),
    ],
    'pt': [
      ((m) => m.dailyOsNextActivityHandledCount(1), '1 tratado'),
      ((m) => m.dailyOsNextActivityWaitingCount(1), '1 pendente'),
      ((m) => m.dailyOsNextAgendaLeft(1, '30m'), 'Falta 1 · 30m'),
      ((m) => m.dailyOsNextBriefingDoneCaption(1), '1 concluída'),
    ],
    'ro': [
      ((m) => m.dailyOsNextActivityHandledCount(1), '1 rezolvat'),
      ((m) => m.dailyOsNextAgendaLeft(1, '30m'), 'Rămâne 1 · 30m'),
      ((m) => m.dailyOsNextBriefingDoneCaption(1), '1 finalizată'),
    ],
    'da': [
      ((m) => m.dailyOsNextBriefingDoneCaption(1), '1 færdig'),
    ],
    'sv': [
      ((m) => m.dailyOsNextActivityHandledCount(1), '1 hanterad'),
      ((m) => m.dailyOsNextBriefingDoneCaption(1), '1 klar'),
    ],
    'cs': [
      ((m) => m.dailyOsNextActivityHandledCount(1), '1 vyřízená'),
      ((m) => m.dailyOsNextActivityWaitingCount(3), 'Čekají 3'),
      ((m) => m.dailyOsNextAgendaLeft(2, '1h'), 'Zbývají 2 · 1h'),
      ((m) => m.dailyOsNextBriefingMoreCategories(5), '+5 dalších'),
    ],
  };

  for (final MapEntry(key: code, value: cases) in singulars.entries) {
    test('$code writes its count captions in the right number', () {
      final messages = l(code);
      for (final (label, expected) in cases) {
        expect(label(messages), expected);
      }
    });
  }

  test('Portuguese counts zero in the plural, not as one', () {
    // intl's Portuguese rule puts 0 in `one`; each caption names zero.
    final pt = l('pt');
    expect(pt.dailyOsNextActivityHandledCount(0), '0 tratados');
    expect(pt.dailyOsNextActivityWaitingCount(0), '0 pendentes');
    expect(pt.dailyOsNextAgendaLeft(0, '0m'), 'Faltam 0 · 0m');
    expect(pt.dailyOsNextBriefingDoneCaption(0), '0 concluídas');
  });

  test('the plural forms still read at many', () {
    expect(l('es').dailyOsNextActivityHandledCount(3), '3 gestionados');
    expect(l('fr').dailyOsNextBriefingMoreCategories(2), '+2 autres');
    expect(l('ro').dailyOsNextActivityHandledCount(3), '3 rezolvate');
    // Romanian puts "de" before a counted noun from twenty on.
    expect(l('ro').dailyOsNextActivityHandledCount(20), '20 de rezolvate');
  });

  test('the no-plan row names no particular day', () {
    for (final code in ['en', 'de', 'fr', 'sv']) {
      final title = l(code).dailyOsNextAgendaNoPlanTitle.toLowerCase();
      for (final today in ['today', 'heute', "aujourd'hui", 'idag']) {
        expect(title, isNot(contains(today)), reason: code);
      }
    }
  });
}
