import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('keeps agent regions ordered inside the shared AI surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(
          body: AgentSummaryCardSurface(
            children: [
              Text('Identity'),
              Text('Report'),
              Text('Controls'),
            ],
          ),
        ),
      ),
    );

    final surface = find.byType(AgentSummaryCardSurface);
    final context = tester.element(surface);
    final decorated = tester.widget<DecoratedBox>(
      find.descendant(of: surface, matching: find.byType(DecoratedBox)).first,
    );
    final actual = decorated.decoration as BoxDecoration;
    final expected = aiCardDecoration(context);

    expect(actual.gradient, expected.gradient);
    expect(actual.borderRadius, expected.borderRadius);
    expect(actual.border, expected.border);
    final identityTop = tester.getTopLeft(find.text('Identity')).dy;
    final reportTop = tester.getTopLeft(find.text('Report')).dy;
    final controlsTop = tester.getTopLeft(find.text('Controls')).dy;
    expect(identityTop, lessThan(reportTop));
    expect(reportTop, lessThan(controlsTop));
  });
}
