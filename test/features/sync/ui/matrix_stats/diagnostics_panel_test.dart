import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/matrix_stats/diagnostics_panel.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_de.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/material_ui_finders.dart';
import '../../../../widget_test_utils.dart';

void main() {
  // The panel's own labels are localized, punctuation included, so word order
  // and the French space-before-colon stay the translator's to choose. The
  // diagnostic *keys* parsed out of the service text are not translated.
  final AppLocalizations messages = AppLocalizationsEn();
  final lastIgnored = messages.matrixStatsLastIgnored;
  final diagnosticsTitle = messages.matrixStatsDiagnostics;
  testWidgets('DiagnosticsPanel expands and renders parsed diagnostics', (
    tester,
  ) async {
    final text = [
      'dbMissingBase=2',
      'lastIgnoredCount=2',
      'lastIgnored.1=a',
      'lastIgnored.2=bb',
      // Prefetch removed
    ].join('\n');

    var fetchCount = 0;
    Future<String> fetch() async {
      fetchCount++;
      return text;
    }

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DiagnosticsPanel(fetchDiagnostics: fetch),
      ),
    );

    // Collapsed by default: no diagnostics fetched or rendered yet.
    expect(fetchCount, 0);
    expect(
      find.text(messages.matrixStatsDbMissingBaseValue('2')),
      findsNothing,
    );

    // Expand tile (bounded pump instead of pumpAndSettle for the
    // ExpansionTile animation + immediately-resolving future).
    await tester.tap(find.text(diagnosticsTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Expanding triggers exactly one fetch and renders the parsed values.
    expect(fetchCount, 1);
    expect(
      find.text(messages.matrixStatsDbMissingBaseValue('2')),
      findsOneWidget,
    );
    expect(find.text(lastIgnored), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('bb'), findsOneWidget);
    expect(find.text('Last Prefetched:'), findsNothing);
  });

  testWidgets('DiagnosticsPanel defaults missing keys to 0', (tester) async {
    // No dbMissingBase / lastIgnoredCount keys.
    Future<String> fetch() async => 'unrelatedKey=7';

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DiagnosticsPanel(fetchDiagnostics: fetch),
      ),
    );

    await tester.tap(find.text(diagnosticsTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Absent numeric keys fall back to '0'.
    expect(
      find.text(messages.matrixStatsDbMissingBaseValue('0')),
      findsOneWidget,
    );
    // No ignored entries → the "Last Ignored:" section is omitted.
    expect(find.text(lastIgnored), findsNothing);
  });

  testWidgets('DiagnosticsPanel refresh button re-fetches diagnostics', (
    tester,
  ) async {
    var fetchCount = 0;
    Future<String> fetch() async {
      fetchCount++;
      return 'dbMissingBase=$fetchCount';
    }

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DiagnosticsPanel(fetchDiagnostics: fetch),
      ),
    );

    await tester.tap(find.text(diagnosticsTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(messages.matrixStatsDbMissingBaseValue('1')),
      findsOneWidget,
    );

    // Tapping the refresh icon re-runs the fetch and renders the new value.
    await tester.tap(
      findMaterialTooltip(messages.matrixStatsRefreshDiagnosticsTooltip),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fetchCount, 2);
    expect(
      find.text(messages.matrixStatsDbMissingBaseValue('2')),
      findsOneWidget,
    );
    expect(
      find.text(messages.matrixStatsDbMissingBaseValue('1')),
      findsNothing,
    );
  });

  testWidgets('DiagnosticsPanel shows loading indicator', (tester) async {
    final completer = Completer<String>();

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DiagnosticsPanel(fetchDiagnostics: () => completer.future),
      ),
    );

    await tester.tap(find.text(diagnosticsTitle));
    await tester.pump();

    expect(find.byType(DesignSystemSpinner), findsOneWidget);

    completer.complete('dbMissingBase=0');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(messages.matrixStatsDbMissingBaseValue('0')),
      findsOneWidget,
    );
    expect(find.byType(DesignSystemSpinner), findsNothing);
  });

  // The panel's four visible strings were hardcoded English literals. Asserting
  // them against the English catalog would still pass if they were reverted to
  // literals, so this renders under German instead: only a real ARB lookup can
  // produce these.
  testWidgets('every label of the panel comes from the catalog', (
    tester,
  ) async {
    final AppLocalizations german = AppLocalizationsDe();

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DiagnosticsPanel(
          fetchDiagnostics: () async =>
              ['dbMissingBase=2', 'lastIgnoredCount=1', 'lastIgnored.1=a'].join(
                '\n',
              ),
        ),
        locale: const Locale('de'),
      ),
    );
    await tester.pump();

    expect(find.text(german.matrixStatsDiagnostics), findsOneWidget);
    // Guard the guard: a German catalog that simply echoed English would make
    // the assertions above vacuous.
    expect(german.matrixStatsDiagnostics, isNot(diagnosticsTitle));

    await tester.tap(find.text(german.matrixStatsDiagnostics));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(german.matrixStatsDbMissingBaseValue('2')),
      findsOneWidget,
    );
    expect(find.text(german.matrixStatsLastIgnored), findsOneWidget);
    expect(
      findMaterialTooltip(german.matrixStatsRefreshDiagnosticsTooltip),
      findsOneWidget,
    );
    // The parsed diagnostic value itself is service data, not a label, so it
    // stays verbatim in every locale.
    expect(find.text('a'), findsOneWidget);
  });

  // Both gaps in this panel were a raw 6 — a value with no step on the ramp.
  // They now round up to step3, and are asserted against the token so the
  // panel cannot drift back off the scale unnoticed.
  testWidgets('the panel spaces its blocks on the spacing ramp', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DiagnosticsPanel(
          fetchDiagnostics: () async =>
              ['dbMissingBase=2', 'lastIgnoredCount=1', 'lastIgnored.1=a'].join(
                '\n',
              ),
        ),
      ),
    );

    await tester.tap(find.text(diagnosticsTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final tokens = tester.element(find.byType(DiagnosticsPanel)).designTokens;
    final gaps = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(DiagnosticsPanel),
            matching: find.byType(SizedBox),
          ),
        )
        .where((box) => box.height != null && box.width == null)
        .toList();

    // With an ignored entry present both gaps render.
    expect(gaps, hasLength(2));
    for (final gap in gaps) {
      expect(gap.height, tokens.spacing.step3);
    }
  });
}
