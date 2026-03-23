import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/health_panel.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 700, child: child),
          ),
        ),
      ),
    );
  }

  group('HealthPanel', () {
    testWidgets('renders health score value', (tester) async {
      final record = makeTestProjectRecord(healthScore: 85);

      await tester.pumpWidget(
        wrap(HealthPanel(record: record)),
      );
      await tester.pump();

      expect(find.text('85'), findsOneWidget);
      expect(find.text('Health Score'), findsOneWidget);
    });

    testWidgets('renders blocked task count', (tester) async {
      final record = makeTestProjectRecord(blockedTaskCount: 3);

      await tester.pumpWidget(
        wrap(HealthPanel(record: record)),
      );
      await tester.pump();

      expect(find.textContaining('3'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders tasks completion progress', (tester) async {
      final record = makeTestProjectRecord(
        completedTaskCount: 4,
        totalTaskCount: 8,
      );

      await tester.pumpWidget(
        wrap(HealthPanel(record: record)),
      );
      await tester.pump();

      expect(find.textContaining('4'), findsAtLeastNWidgets(1));
      expect(find.textContaining('8'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders legend items', (tester) async {
      final record = makeTestProjectRecord(
        completedTaskCount: 2,
      );

      await tester.pumpWidget(
        wrap(HealthPanel(record: record)),
      );
      await tester.pump();

      expect(find.textContaining('Completed'), findsOneWidget);
      expect(find.textContaining('Blocked'), findsOneWidget);
    });

    testWidgets('renders view blocker button', (tester) async {
      final record = makeTestProjectRecord();

      await tester.pumpWidget(
        wrap(HealthPanel(record: record)),
      );
      await tester.pump();

      expect(find.text('View blocker'), findsOneWidget);
    });
  });
}
