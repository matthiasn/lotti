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
    await tester.pumpAndSettle();

    // Tap should not throw — button is disabled
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
  });

  testWidgets('shows active gradient when forceActive even without onPressed',
      (tester) async {
    await tester.pumpWidget(buildSubject(forceActive: true));
    await tester.pumpAndSettle();

    // The button should still render (visual test — mainly ensures no errors)
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('shows tooltip', (tester) async {
    await tester.pumpWidget(
      buildSubject(onPressed: () {}, tooltip: 'Record'),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Record'), findsOneWidget);
  });
}
