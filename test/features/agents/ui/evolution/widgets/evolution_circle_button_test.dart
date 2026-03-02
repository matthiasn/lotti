import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_circle_button.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    IconData icon = Icons.mic,
    VoidCallback? onPressed,
    bool forceActive = false,
    String? tooltip,
  }) {
    return makeTestableWidgetWithScaffold(
      EvolutionCircleButton(
        icon: icon,
        onPressed: onPressed,
        forceActive: forceActive,
        tooltip: tooltip,
      ),
    );
  }

  testWidgets('renders the given icon', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('invokes onPressed when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildSubject(onPressed: () => tapped = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('does not invoke callback when onPressed is null',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.onPressed, isNull);

    // Tap should not throw — button is disabled
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
  });

  testWidgets('shows active gradient when forceActive even without onPressed',
      (tester) async {
    await tester.pumpWidget(buildSubject(forceActive: true));
    await tester.pump();

    // forceActive makes icon white (active state) even without onPressed
    final icon = tester.widget<Icon>(find.byIcon(Icons.mic));
    expect(icon.color, Colors.white);
  });

  testWidgets('shows tooltip', (tester) async {
    await tester.pumpWidget(
      buildSubject(onPressed: () {}, tooltip: 'Record'),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Record'), findsOneWidget);
  });
}
