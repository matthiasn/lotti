import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<(Color page, Color card)> resolve(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    late Color page;
    late Color card;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            page = insightsPageSurface(context);
            card = insightsCardSurface(context);
            return const SizedBox.shrink();
          },
        ),
        theme: theme,
      ),
    );
    return (page, card);
  }

  group('insights surfaces', () {
    testWidgets('dark: darker page (level01) under lighter cards (level02)', (
      tester,
    ) async {
      final (page, card) = await resolve(
        tester,
        ThemeData.dark(useMaterial3: true),
      );
      expect(page, dsTokensDark.colors.background.level01);
      expect(card, dsTokensDark.colors.background.level02);
    });

    testWidgets('light: surfaces swap so the card stays lighter than the page', (
      tester,
    ) async {
      final (page, card) = await resolve(
        tester,
        ThemeData.light(useMaterial3: true),
      );
      // The DS ramp inverts in light mode, so page/card use the opposite levels
      // to keep the card the lighter (raised) surface.
      expect(page, dsTokensLight.colors.background.level02);
      expect(card, dsTokensLight.colors.background.level01);
    });
  });
}
