import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/front_agent/ui/front_starter_prompts.dart';

import '../../../widget_test_utils.dart';

void main() {
  final labels = {
    FrontStarterPromptsKeys.dueToday: 'What is due today?',
    FrontStarterPromptsKeys.overdue: 'What is overdue?',
    FrontStarterPromptsKeys.thisWeek: 'What did I work on this week?',
  };

  testWidgets('offers three questions as neutral outlined buttons, each '
      'sent in its own words', (tester) async {
    final chosen = <String>[];
    await tester.pumpWidget(
      makeTestableWidget(FrontStarterPrompts(onChosen: chosen.add)),
    );

    final buttons = tester.widgetList<DesignSystemButton>(
      find.byType(DesignSystemButton),
    );
    expect(buttons.map((b) => b.label), labels.values);
    for (final button in buttons) {
      expect(button.variant, DesignSystemButtonVariant.outlined);
    }

    for (final key in labels.keys) {
      await tester.tap(find.byKey(key));
    }
    expect(chosen, labels.values);
  });

  testWidgets('while a turn is in flight the buttons do not answer', (
    tester,
  ) async {
    final chosen = <String>[];
    await tester.pumpWidget(
      makeTestableWidget(
        FrontStarterPrompts(onChosen: chosen.add, enabled: false),
      ),
    );

    for (final button in tester.widgetList<DesignSystemButton>(
      find.byType(DesignSystemButton),
    )) {
      expect(button.onPressed, isNull);
    }
    await tester.tap(
      find.byKey(FrontStarterPromptsKeys.overdue),
      warnIfMissed: false,
    );
    expect(chosen, isEmpty);
  });
}
