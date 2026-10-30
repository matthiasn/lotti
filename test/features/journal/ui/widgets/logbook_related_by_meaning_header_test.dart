import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/logbook_related_by_meaning_header.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('names the entries meaning found, in the caption style', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const LogbookRelatedByMeaningHeader()),
    );

    final text = tester.widget<Text>(find.text('Related by meaning'));
    final context = tester.element(find.byType(LogbookRelatedByMeaningHeader));
    final tokens = context.designTokens;
    expect(
      text.style?.fontSize,
      tokens.typography.styles.others.caption.fontSize,
    );
    expect(text.style?.color, tokens.colors.text.mediumEmphasis);
  });

  testWidgets('is localized', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const LogbookRelatedByMeaningHeader(),
        locale: const Locale('de'),
      ),
    );

    expect(find.text('Inhaltlich verwandt'), findsOneWidget);
  });
}
