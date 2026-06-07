import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Pumps [AgentMarkdownView] inside the standard scaffolded test harness and
/// settles the first frame. Returns nothing; callers locate widgets/elements
/// via the usual finders.
Future<void> _pumpView(
  WidgetTester tester,
  String text, {
  TextStyle? style,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      AgentMarkdownView(text, style: style),
      theme: theme,
    ),
  );
  await tester.pump();
}

/// Reads the [GptMarkdownThemeData] that is in effect at the [GptMarkdown]
/// element, i.e. the theme extension injected by [AgentMarkdownView.build].
GptMarkdownThemeData _resolvedMarkdownTheme(WidgetTester tester) {
  final gptContext = tester.element(find.byType(GptMarkdown));
  return GptMarkdownTheme.of(gptContext);
}

/// Reads the effective default text style at the [GptMarkdown] element.
TextStyle _resolvedBodyStyle(WidgetTester tester) {
  final gptContext = tester.element(find.byType(GptMarkdown));
  return DefaultTextStyle.of(gptContext).style;
}

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  group('AgentMarkdownView', () {
    testWidgets('renders GptMarkdown with provided text', (tester) async {
      const markdownText = '# Hello World\n\nThis is a test.';

      await _pumpView(tester, markdownText);

      final gptMarkdown = tester.widget<GptMarkdown>(
        find.byType(GptMarkdown),
      );
      expect(gptMarkdown.data, markdownText);
    });

    testWidgets('applies custom style to body text when provided', (
      tester,
    ) async {
      const customStyle = TextStyle(
        fontSize: 20,
        color: Colors.red,
        fontWeight: FontWeight.bold,
      );

      await _pumpView(tester, 'Custom styled text', style: customStyle);

      final effectiveStyle = _resolvedBodyStyle(tester);
      expect(effectiveStyle.fontSize, 20);
      expect(effectiveStyle.color, Colors.red);
      expect(effectiveStyle.fontWeight, FontWeight.bold);
    });

    testWidgets('falls back to design system body.bodySmall by default', (
      tester,
    ) async {
      await _pumpView(tester, 'Fallback styled text');

      final context = tester.element(find.byType(AgentMarkdownView));
      final expected = context.designTokens.typography.styles.body.bodySmall;

      final effectiveStyle = _resolvedBodyStyle(tester);
      expect(effectiveStyle.fontSize, expected.fontSize);
      expect(effectiveStyle.fontWeight, expected.fontWeight);
      expect(effectiveStyle.fontFamily, expected.fontFamily);
    });

    testWidgets(
      'maps heading styles to the design system heading/subtitle tokens',
      (tester) async {
        await _pumpView(tester, '# H1\n## H2\n### H3');

        final context = tester.element(find.byType(AgentMarkdownView));
        final styles = context.designTokens.typography.styles;
        final markdownTheme = _resolvedMarkdownTheme(tester);

        // h1 -> heading.heading3, h2 -> subtitle.subtitle1,
        // h3 -> subtitle.subtitle2. Compare the intrinsic metrics that the
        // tokens carry (color is overridden with the body text color, so it
        // is intentionally not asserted here).
        expect(markdownTheme.h1?.fontSize, styles.heading.heading3.fontSize);
        expect(
          markdownTheme.h1?.fontWeight,
          styles.heading.heading3.fontWeight,
        );
        expect(
          markdownTheme.h1?.fontFamily,
          styles.heading.heading3.fontFamily,
        );

        expect(markdownTheme.h2?.fontSize, styles.subtitle.subtitle1.fontSize);
        expect(
          markdownTheme.h2?.fontWeight,
          styles.subtitle.subtitle1.fontWeight,
        );

        expect(markdownTheme.h3?.fontSize, styles.subtitle.subtitle2.fontSize);
        expect(
          markdownTheme.h3?.fontWeight,
          styles.subtitle.subtitle2.fontWeight,
        );

        // The three heading levels are visually distinct (decreasing size),
        // proving each branch is wired to its own token rather than one shared
        // style.
        expect(
          markdownTheme.h1!.fontSize! > markdownTheme.h2!.fontSize!,
          isTrue,
        );
        expect(
          markdownTheme.h2!.fontSize! > markdownTheme.h3!.fontSize!,
          isTrue,
        );
      },
    );

    testWidgets(
      'maps h4/h5/h6 to body-derived and caption tokens',
      (tester) async {
        await _pumpView(tester, '#### H4\n##### H5\n###### H6');

        final context = tester.element(find.byType(AgentMarkdownView));
        final tokens = context.designTokens;
        final styles = tokens.typography.styles;
        final markdownTheme = _resolvedMarkdownTheme(tester);

        // h4 = bodySmall weight-bumped to semiBold.
        expect(markdownTheme.h4?.fontSize, styles.body.bodySmall.fontSize);
        expect(markdownTheme.h4?.fontWeight, tokens.typography.weight.semiBold);

        // h5 = the plain body style.
        expect(markdownTheme.h5?.fontSize, styles.body.bodySmall.fontSize);
        expect(markdownTheme.h5?.fontWeight, styles.body.bodySmall.fontWeight);

        // h6 = caption token.
        expect(markdownTheme.h6?.fontSize, styles.others.caption.fontSize);
        expect(markdownTheme.h6?.fontWeight, styles.others.caption.fontWeight);
      },
    );

    testWidgets(
      'sets markdown link color from the theme primary color',
      (tester) async {
        await _pumpView(tester, 'plain text');

        final context = tester.element(find.byType(AgentMarkdownView));
        final primary = Theme.of(context).colorScheme.primary;
        final markdownTheme = _resolvedMarkdownTheme(tester);

        expect(markdownTheme.linkColor, primary);
      },
    );

    testWidgets(
      'injects a compact, non-interactive checkbox theme from tokens',
      (tester) async {
        await _pumpView(tester, '- [x] done\n- [ ] todo');

        final context = tester.element(find.byType(AgentMarkdownView));
        final tokens = context.designTokens;

        final gptContext = tester.element(find.byType(GptMarkdown));
        final checkbox = Theme.of(gptContext).checkboxTheme;

        expect(
          checkbox.materialTapTargetSize,
          MaterialTapTargetSize.shrinkWrap,
        );
        expect(checkbox.visualDensity, VisualDensity.compact);

        final side = checkbox.side!;
        expect(side.color, tokens.colors.text.lowEmphasis);
        expect(side.width, 1.5);

        // fillColor: transparent when unselected, interactive.enabled when
        // selected.
        expect(
          checkbox.fillColor?.resolve(<WidgetState>{}),
          Colors.transparent,
        );
        expect(
          checkbox.fillColor?.resolve(<WidgetState>{WidgetState.selected}),
          tokens.colors.interactive.enabled,
        );

        // Non-interactive: no hover overlay, basic (non-clickable) cursor.
        expect(
          checkbox.overlayColor?.resolve(<WidgetState>{WidgetState.hovered}),
          Colors.transparent,
        );
        expect(
          checkbox.mouseCursor?.resolve(<WidgetState>{}),
          SystemMouseCursors.basic,
        );
      },
    );

    testWidgets(
      'replaces a pre-existing GptMarkdownThemeData from the host theme',
      (tester) async {
        // Host theme already carries a GptMarkdownThemeData with sentinel
        // values. AgentMarkdownView must inject its own and not leak the host
        // one through to GptMarkdown. DsTokens must be present so that
        // context.designTokens resolves inside the widget.
        final hostTheme = ThemeData(useMaterial3: true).copyWith(
          extensions: <ThemeExtension<dynamic>>[
            dsTokensLight,
            GptMarkdownThemeData(
              brightness: Brightness.light,
              linkColor: Colors.purple,
              h1: const TextStyle(fontSize: 999),
            ),
          ],
        );

        await _pumpView(tester, '# Heading', theme: hostTheme);

        final markdownTheme = _resolvedMarkdownTheme(tester);
        // Sentinel link color is gone; widget's primary color wins.
        expect(markdownTheme.linkColor, isNot(Colors.purple));
        // Sentinel h1 size is gone; the design-token mapping wins.
        expect(markdownTheme.h1?.fontSize, isNot(999));

        // Exactly one GptMarkdownThemeData survives in the resolved theme.
        final gptContext = tester.element(find.byType(GptMarkdown));
        final extensions = Theme.of(gptContext).extensions.values;
        final markdownExtensions = extensions
            .whereType<GptMarkdownThemeData>()
            .toList();
        expect(markdownExtensions.length, 1);
        // DsTokens from the host theme is preserved across the injection.
        expect(extensions.whereType<DsTokens>(), isNotEmpty);
      },
    );

    testWidgets(
      'wires GptMarkdown link callbacks to the shared markdown handlers',
      (tester) async {
        // Register a recording NavService so the wired callbacks can be
        // exercised behaviorally (identity comparison of function tear-offs is
        // brittle across signature widening, so we invoke them instead).
        final navService = RecordingMockNavService();
        await tearDownTestGetIt();
        await setUpTestGetIt(
          additionalSetup: () {
            getIt.registerSingleton<NavService>(navService);
          },
        );

        await _pumpView(tester, '[task](/tasks/123)');

        final gptMarkdown = tester.widget<GptMarkdown>(
          find.byType(GptMarkdown),
        );
        expect(gptMarkdown.onLinkTap, isNotNull);
        expect(gptMarkdown.linkBuilder, isNotNull);

        // onLinkTap is wired to handleMarkdownLinkTap: an internal route is
        // forwarded to NavService.
        gptMarkdown.onLinkTap!('/tasks/onTap', '');
        await tester.pump();
        expect(navService.navigationHistory, ['/tasks/onTap']);

        // linkBuilder is wired to buildMarkdownLink: it produces a tappable
        // widget that routes internal links the same way.
        final builderContext = tester.element(find.byType(GptMarkdown));
        final built = gptMarkdown.linkBuilder!(
          builderContext,
          const TextSpan(text: 'built link'),
          '/tasks/builder',
          const TextStyle(),
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(builder: (_) => built),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('built link'));
        await tester.pump();
        expect(navService.navigationHistory, [
          '/tasks/onTap',
          '/tasks/builder',
        ]);
      },
    );
  });
}
