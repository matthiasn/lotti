import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_switch_row.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  late List<bool> changes;

  setUp(() => changes = []);

  Future<void> pump(WidgetTester tester, {required bool value}) =>
      tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          AgentSwitchRow(
            title: 'Remind me to stay in touch',
            toggleKey: const ValueKey('toggle'),
            value: value,
            onChanged: changes.add,
            body: const Text('Turns on reminders and a briefing.'),
          ),
        ),
      );

  testWidgets('the label itself toggles, from either state', (tester) async {
    await pump(tester, value: false);
    await tester.tap(find.text('Remind me to stay in touch'));
    await pump(tester, value: true);
    await tester.tap(find.text('Remind me to stay in touch'));

    expect(changes, [true, false]);
  });

  testWidgets('the switch shows the value and reports a flip', (tester) async {
    await pump(tester, value: true);

    expect(
      tester
          .widget<DesignSystemToggle>(find.byKey(const ValueKey('toggle')))
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('toggle')));
    expect(changes, [false]);
  });

  testWidgets('the line under it is a quiet caption, the title a field label', (
    tester,
  ) async {
    await pump(tester, value: false);

    final tokens = tester.element(find.byType(AgentSwitchRow)).designTokens;
    final body = DefaultTextStyle.of(
      tester.element(find.text('Turns on reminders and a briefing.')),
    ).style;
    expect(body.fontSize, tokens.typography.styles.others.caption.fontSize);
    expect(body.color, tokens.colors.text.mediumEmphasis);
    expect(
      tester
          .widget<Text>(find.text('Remind me to stay in touch'))
          .style
          ?.fontSize,
      tokens.typography.styles.subtitle.subtitle2.fontSize,
    );
  });
}
