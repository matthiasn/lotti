import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The agent list toolbars count what they list, and an empty list passes
/// zero. intl's French and Portuguese rules put 0 in `one`, so a catalog that
/// spells its singular as a literal "1 …" would show "1 âme" for an empty
/// list.
void main() {
  AppLocalizations l(String code) => lookupAppLocalizations(Locale(code));

  test('French counts zero in the singular, with the real number', () {
    final fr = l('fr');
    expect(fr.agentInstancesGroupActiveCount(0), '0 actif');
    expect(fr.agentInstancesResultCountAll(0), '0 instance');
    expect(fr.agentPendingWakesResultCountAll(0), '0 réveil');
    expect(fr.agentSoulsResultCountAll(0), '0 âme');
    expect(fr.agentTemplatesResultCountAll(0), '0 modèle');
    expect(fr.agentSoulsResultCountAll(1), '1 âme');
    expect(fr.agentSoulsResultCountAll(3), '3 âmes');
  });

  test('Portuguese counts zero in the plural, not as one', () {
    final pt = l('pt');
    expect(pt.agentInstancesGroupActiveCount(0), '0 ativos');
    expect(pt.agentInstancesResultCountAll(0), '0 instâncias');
    expect(pt.agentPendingWakesResultCountAll(0), '0 ativações');
    expect(pt.agentSoulsResultCountAll(0), '0 almas');
    expect(pt.agentTemplatesResultCountAll(0), '0 modelos');
    expect(pt.agentTemplatesResultCountAll(1), '1 modelo');
    expect(pt.agentInstancesGroupActiveCount(3), '3 ativos');
  });

  test('the Portuguese busiest-hour hint names the Análises tab', () {
    final pt = l('pt');
    expect(pt.goalPatternBusiestHour('9'), contains(pt.navTabTitleInsights));
  });
}
