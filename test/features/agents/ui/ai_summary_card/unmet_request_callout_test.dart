import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/unmet_request_callout.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  late int observationsTaps;
  late int clearTaps;

  setUp(() {
    observationsTaps = 0;
    clearTaps = 0;
  });

  Future<void> pump(WidgetTester tester, {String? reason}) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        UnmetRequestCallout(
          reason: reason,
          onShowObservations: () => observationsTaps++,
          onClear: () => clearTaps++,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("names the failure in the agent's voice and gives its reason", (
    tester,
  ) async {
    await pump(tester, reason: '  I could log only one time block.  ');

    expect(find.text("I couldn't do what you asked"), findsOneWidget);
    expect(find.text('I could log only one time block.'), findsOneWidget);
    expect(find.text('My observations say what went wrong.'), findsNothing);
    expect(find.byIcon(LottiIcons.warning), findsOneWidget);
  });

  for (final reason in [null, '   ']) {
    testWidgets('points at the observations when the reason is '
        '${reason == null ? 'missing' : 'blank'}', (tester) async {
      await pump(tester, reason: reason);

      expect(find.text("I couldn't do what you asked"), findsOneWidget);
      expect(find.text('My observations say what went wrong.'), findsOneWidget);
    });
  }

  testWidgets('each action answers its own callback', (tester) async {
    await pump(tester, reason: 'A reason.');

    await tester.tap(find.byKey(const ValueKey('unmet-request-observations')));
    expect((observationsTaps, clearTaps), (1, 0));

    await tester.tap(find.byKey(const ValueKey('unmet-request-clear')));
    expect((observationsTaps, clearTaps), (1, 1));

    expect(find.text('See observations'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('announces itself once, title and reason together', (
    tester,
  ) async {
    await pump(tester, reason: 'A reason.');

    final node = tester.getSemantics(
      find.text("I couldn't do what you asked"),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    expect(node.label, contains("I couldn't do what you asked"));
    expect(node.label, contains('A reason.'));
  });
}
