import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/matrix_stats/diagnostics_panel.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('DiagnosticsPanel expands and renders parsed diagnostics',
      (tester) async {
    final text = [
      'dbMissingBase=2',
      'lastIgnoredCount=2',
      'lastIgnored.1=a',
      'lastIgnored.2=bb',
      'lastPrefetchedCount=1',
      'lastPrefetched.1=ccc',
    ].join('\n');

    Future<String> fetch() async => text;

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DiagnosticsPanel(fetchDiagnostics: fetch),
      ),
    );

    // Expand tile
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('dbMissingBase: 2'), findsOneWidget);
    expect(find.text('Last Ignored:'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('bb'), findsOneWidget);
    expect(find.text('Last Prefetched:'), findsOneWidget);
    expect(find.text('ccc'), findsOneWidget);
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
    await tester.pumpAndSettle();
    expect(find.text('dbMissingBase: 0'), findsOneWidget);
  });
}
