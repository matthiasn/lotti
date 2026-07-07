import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_table_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        ImpactTableCard(
          title: 'Shared shell',
          childrenBuilder: (context, headerStyle, numberStyle) => [
            Text('Header child', style: headerStyle),
            Text('Number child', style: numberStyle),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the shared title and passes table styles to children', (
    tester,
  ) async {
    await pumpCard(tester);

    final context = tester.element(find.byType(ImpactTableCard));
    final tokens = context.designTokens;
    final title = tester.widget<Text>(find.text('Shared shell'));
    final header = tester.widget<Text>(find.text('Header child'));
    final number = tester.widget<Text>(find.text('Number child'));

    expect(
      title.style?.color,
      tokens.colors.text.highEmphasis,
    );
    expect(
      header.style?.color,
      tokens.colors.text.mediumEmphasis,
    );
    expect(
      number.style?.color,
      tokens.colors.text.highEmphasis,
    );
    expect(
      number.style?.fontFamily,
      'Inconsolata',
    );
    expect(number.style, isNot(equals(header.style)));
  });
}
