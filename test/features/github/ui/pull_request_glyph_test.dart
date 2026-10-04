import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/ui/pull_request_glyph.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('PullRequestGlyph', () {
    Future<(Icon, BoxDecoration, DsTokens)> pump(
      WidgetTester tester,
      PullRequestGlyph glyph,
    ) async {
      await tester.pumpWidget(makeTestableWidgetWithScaffold(glyph));
      final tokens = tester.element(find.byType(PullRequestGlyph)).designTokens;
      final icon = tester.widget<Icon>(find.byType(Icon));
      final tile = tester.widget<Container>(
        find.descendant(
          of: find.byType(PullRequestGlyph),
          matching: find.byType(Container),
        ),
      );
      return (icon, tile.decoration! as BoxDecoration, tokens);
    }

    for (final (label, status, draft, expectedIcon) in [
      ('open', PullRequestStatus.open, false, LottiIcons.pullRequest),
      ('draft', PullRequestStatus.open, true, LottiIcons.pullRequestDraft),
      ('merged', PullRequestStatus.merged, false, LottiIcons.pullRequestMerged),
      ('closed', PullRequestStatus.closed, false, LottiIcons.pullRequestClosed),
      ('not read yet', null, false, LottiIcons.pullRequest),
    ]) {
      testWidgets('$label has its own glyph, on a wash of its own ink', (
        tester,
      ) async {
        final (icon, tile, tokens) = await pump(
          tester,
          PullRequestGlyph(status: status, draft: draft),
        );

        expect(icon.icon, expectedIcon);
        final ink = switch ((status, draft)) {
          (PullRequestStatus.merged, _) => tokens.colors.alert.success.ink,
          (PullRequestStatus.closed, _) => tokens.colors.alert.error.ink,
          (_, true) => tokens.colors.text.lowEmphasis,
          _ => tokens.colors.text.mediumEmphasis,
        };
        expect(icon.color, ink);
        expect(tile.color, ink.withValues(alpha: SurfaceAlphas.tint));
      });
    }

    testWidgets(
      'merged and closed differ in shape and ink, so neither colour alone '
      'carries the state',
      (tester) async {
        final (merged, _, _) = await pump(
          tester,
          const PullRequestGlyph(status: PullRequestStatus.merged),
        );
        final (closed, _, _) = await pump(
          tester,
          const PullRequestGlyph(status: PullRequestStatus.closed),
        );

        expect(merged.icon, isNot(closed.icon));
        expect(merged.color, isNot(closed.color));
      },
    );
  });

  group('PullRequestTitle', () {
    const style = TextStyle(fontSize: 14);

    testWidgets('sets the number in the quiet ink, the title in the style', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const PullRequestTitle(number: 42, title: 'Waddle', style: style),
        ),
      );
      final tokens = tester.element(find.byType(PullRequestTitle)).designTokens;
      final text = tester.widget<Text>(find.byType(Text));
      final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();

      expect(find.text('#42 Waddle'), findsOneWidget);
      expect(spans.first.text, '#42 ');
      expect(spans.first.style!.color, tokens.colors.text.lowEmphasis);
      expect(spans.last.text, 'Waddle');
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
      'without a number shows the title alone, and a heading may wrap '
      'freely',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const PullRequestTitle(
              number: null,
              title: 'penguin/colony#42',
              style: style,
              maxLines: null,
            ),
          ),
        );
        final text = tester.widget<Text>(find.byType(Text));

        expect(find.text('penguin/colony#42'), findsOneWidget);
        expect((text.textSpan! as TextSpan).children, hasLength(1));
        expect(text.maxLines, isNull);
        expect(text.overflow, isNull);
      },
    );
  });

  testWidgets('pullRequestTitleStyle is the semibold title in high ink', (
    tester,
  ) async {
    late TextStyle style;
    late DsTokens tokens;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            style = pullRequestTitleStyle(context);
            tokens = context.designTokens;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final subtitle2 = tokens.typography.styles.subtitle.subtitle2;
    expect(style.fontSize, subtitle2.fontSize);
    expect(style.fontWeight, subtitle2.fontWeight);
    expect(style.color, tokens.colors.text.highEmphasis);
  });
}
