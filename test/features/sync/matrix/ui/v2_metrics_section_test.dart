import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/matrix_stats/v2_metrics_section.dart';

void main() {
  testWidgets('V2MetricsSection shows EntryLink No-ops tile', (tester) async {
    final metrics = <String, int>{
      'dbEntryLinkNoop': 3,
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2MetricsSection(
            metrics: metrics,
            lastUpdated: DateTime.now(),
            onForceRescan: () {},
            onRetryNow: () {},
            onCopyDiagnostics: () {},
            onRefresh: () {},
            fetchDiagnostics: () async => 'diag',
            title: 'title',
            lastUpdatedLabel: 'now',
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('metric:dbEntryLinkNoop')), findsOneWidget);
    expect(find.text('EntryLink No-ops'), findsOneWidget);
  });

  testWidgets('V2MetricsSection shows Dropped (entryLink) tile',
      (tester) async {
    final metrics = <String, int>{
      'droppedByType.entryLink': 2,
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2MetricsSection(
            metrics: metrics,
            lastUpdated: DateTime.now(),
            onForceRescan: () {},
            onRetryNow: () {},
            onCopyDiagnostics: () {},
            onRefresh: () {},
            fetchDiagnostics: () async => 'diag',
            title: 'title',
            lastUpdatedLabel: 'now',
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('metric:droppedByType.entryLink')),
        findsOneWidget);
    expect(find.text('Dropped (entryLink)'), findsOneWidget);
  });
}
