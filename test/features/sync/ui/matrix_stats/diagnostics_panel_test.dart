import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/matrix_stats/diagnostics_panel.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('DiagnosticsPanel expands and renders parsed diagnostics', (
    tester,
  ) async {
    final text = [
      'dbMissingBase=2',
      'staleAttachmentPurges=5',
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
    expect(find.text('dbMissingBase: 2'), findsNothing);

    // Expand tile (bounded pump instead of pumpAndSettle for the
    // ExpansionTile animation + immediately-resolving future).
    await tester.tap(find.text('Diagnostics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Expanding triggers exactly one fetch and renders the parsed values.
    expect(fetchCount, 1);
    expect(find.text('dbMissingBase: 2'), findsOneWidget);
    expect(find.text('staleAttachmentPurges: 5'), findsOneWidget);
    expect(find.text('Last Ignored:'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('bb'), findsOneWidget);
    expect(find.text('Last Prefetched:'), findsNothing);
  });

  testWidgets('DiagnosticsPanel defaults missing keys to 0', (tester) async {
    // No dbMissingBase / staleAttachmentPurges / lastIgnoredCount keys.
    Future<String> fetch() async => 'unrelatedKey=7';

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DiagnosticsPanel(fetchDiagnostics: fetch),
      ),
    );

    await tester.tap(find.text('Diagnostics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Absent numeric keys fall back to '0'.
    expect(find.text('dbMissingBase: 0'), findsOneWidget);
    expect(find.text('staleAttachmentPurges: 0'), findsOneWidget);
    // No ignored entries → the "Last Ignored:" section is omitted.
    expect(find.text('Last Ignored:'), findsNothing);
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

    await tester.tap(find.text('Diagnostics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('dbMissingBase: 1'), findsOneWidget);

    // Tapping the refresh icon re-runs the fetch and renders the new value.
    await tester.tap(find.byTooltip('Refresh diagnostics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fetchCount, 2);
    expect(find.text('dbMissingBase: 2'), findsOneWidget);
    expect(find.text('dbMissingBase: 1'), findsNothing);
  });

  testWidgets('DiagnosticsPanel shows loading indicator', (tester) async {
    final completer = Completer<String>();

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DiagnosticsPanel(fetchDiagnostics: () => completer.future),
      ),
    );

    await tester.tap(find.text('Diagnostics'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete('dbMissingBase=0');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('dbMissingBase: 0'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
