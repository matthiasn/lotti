import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/ui/front_ask_options_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  const options = [
    FrontAskOption(kind: FrontDestinationKind.goal, id: 'g1', label: 'Swim'),
    FrontAskOption(kind: FrontDestinationKind.task, id: 't1', label: 'Pool'),
  ];

  testWidgets('one button per option, each answering in its own words', (
    tester,
  ) async {
    final chosen = <FrontAskOption>[];
    await tester.pumpWidget(
      makeTestableWidget(
        FrontAskOptionsRow(options: options, onChosen: chosen.add),
      ),
    );

    final buttons = find.byType(DesignSystemButton);
    expect(buttons, findsNWidgets(2));
    // What the question asks for: full-size neutral outlined buttons —
    // never a filled twin of the user's own bubble — a clear gap apart.
    for (final button in tester.widgetList<DesignSystemButton>(buttons)) {
      expect(button.variant, DesignSystemButtonVariant.outlined);
      expect(button.size, DesignSystemButtonSize.medium);
    }
    final tokens = tester.element(find.byType(FrontAskOptionsRow)).designTokens;
    expect(
      tester.getRect(buttons.last).left - tester.getRect(buttons.first).right,
      tokens.spacing.step3,
    );
    expect(find.text('Swim'), findsOneWidget);
    expect(find.text('Pool'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('front-ask-option-task:t1')));
    expect(chosen.map((o) => o.id), ['t1']);
  });

  testWidgets('while a turn is in flight the buttons do not answer', (
    tester,
  ) async {
    final chosen = <FrontAskOption>[];
    await tester.pumpWidget(
      makeTestableWidget(
        FrontAskOptionsRow(
          options: options,
          onChosen: chosen.add,
          enabled: false,
        ),
      ),
    );

    await tester.tap(find.text('Swim'), warnIfMissed: false);
    expect(chosen, isEmpty);
    for (final chip in tester.widgetList<DesignSystemButton>(
      find.byType(DesignSystemButton),
    )) {
      expect(chip.onPressed, isNull);
    }
  });
}
