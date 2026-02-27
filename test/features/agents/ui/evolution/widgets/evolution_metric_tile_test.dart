import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_metric_tile.dart';
import 'package:lotti/themes/gamey/colors.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String label = 'Success Rate',
    String value = '80%',
    IconData icon = Icons.check_circle_outline_rounded,
    Color accentColor = GameyColors.primaryGreen,
    double? progress,
  }) {
    return makeTestableWidgetWithScaffold(
      EvolutionMetricTile(
        label: label,
        value: value,
        icon: icon,
        accentColor: accentColor,
        progress: progress,
      ),
    );
  }

  group('EvolutionMetricTile', () {
    testWidgets('displays label and value', (tester) async {
      await tester.pumpWidget(
        buildSubject(label: 'Total Wakes', value: '42'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Wakes'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('displays icon with accent color', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_outline_rounded),
      );
      expect(icon.color, GameyColors.primaryGreen);
    });

    testWidgets('shows circular progress indicator when progress is set',
        (tester) async {
      await tester.pumpWidget(buildSubject(progress: 0.75));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 0.75);
    });

    testWidgets('hides circular progress when progress is null',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('truncates long labels with ellipsis', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          label: 'A very long metric label that should be truncated',
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.text('A very long metric label that should be truncated'),
      );
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
    });
  });
}
