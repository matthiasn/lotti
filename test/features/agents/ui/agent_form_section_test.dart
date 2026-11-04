import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_form_section.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets(
    'a heading in the section tier, its intro a quiet line, then the fields',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const AgentFormSection(
            title: 'Your agent',
            intro: 'This starts version 4.',
            introKey: ValueKey('intro'),
            child: Text('Agent name', key: ValueKey('field')),
          ),
        ),
      );

      final tokens = tester.element(find.byType(AgentFormSection)).designTokens;
      final heading = tester.widget<Text>(find.text('Your agent'));
      expect(
        heading.style?.fontSize,
        tokens.typography.styles.heading.heading3.fontSize,
      );
      final intro = tester.widget<Text>(find.byKey(const ValueKey('intro')));
      expect(intro.style?.color, tokens.colors.text.mediumEmphasis);
      // Heading, intro, fields, top to bottom.
      final y = [
        find.text('Your agent'),
        find.byKey(const ValueKey('intro')),
        find.byKey(const ValueKey('field')),
      ].map((finder) => tester.getTopLeft(finder).dy).toList();
      expect(y, orderedEquals([...y]..sort()));
      // The heading is announced as one.
      expect(
        tester.getSemantics(find.text('Your agent')),
        isSemantics(label: 'Your agent', isHeader: true),
      );
    },
  );

  testWidgets('without an intro the fields follow the heading directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const AgentFormSection(
          title: 'Who',
          child: Text('Name', key: ValueKey('field')),
        ),
      ),
    );

    final tokens = tester.element(find.byType(AgentFormSection)).designTokens;
    final headingBottom = tester.getBottomLeft(find.text('Who')).dy;
    final fieldTop = tester.getTopLeft(find.byKey(const ValueKey('field'))).dy;
    expect(fieldTop - headingBottom, moreOrLessEquals(tokens.spacing.step5));
  });
}
