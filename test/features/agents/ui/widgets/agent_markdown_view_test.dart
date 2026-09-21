import 'package:flutter/material.dart' as legacy;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Pumps [AgentMarkdownView] inside the standard scaffolded test harness and
/// settles the first frame. Returns nothing; callers locate widgets/elements
/// via the usual finders.
Future<void> _pumpView(
  WidgetTester tester,
  String text, {
  TextStyle? style,
  int? maxLines,
  TextOverflow? overflow,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      AgentMarkdownView(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      ),
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
    testWidgets('inline citations scale once with surrounding text', (
      tester,
    ) async {
      Future<double> citationHeight(double scale) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const AgentMarkdownView(
                'Approved [1](#query-evidence-1).',
              ),
            ),
          ),
        );
        await tester.pump();
        final link = find.byWidgetPredicate(
          (widget) => widget is InkWell && widget.onTap != null,
        );
        final box = tester.renderObject<RenderBox>(link);
        return (box.localToGlobal(Offset(0, box.size.height)) -
                box.localToGlobal(Offset.zero))
            .distance;
      }

      final regular = await citationHeight(1);
      final enlarged = await citationHeight(1.5);
      expect(enlarged / regular, closeTo(1.5, 0.05));
    });
    testWidgets('owner citations respond to pointer and keyboard activation', (
      tester,
    ) async {
      final visited = <(String, String)>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          AgentMarkdownView(
            'The feeder was approved [1](#query-evidence-1).',
            onLinkTap: (url, title) => visited.add((url, title)),
          ),
        ),
      );
      await tester.pump();
      final link = find.byWidgetPredicate(
        (widget) => widget is InkWell && widget.onTap != null,
      );
      await tester.tap(link);
      await tester.pump();
      expect(visited, [('#query-evidence-1', '1')]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(visited, [('#query-evidence-1', '1'), ('#query-evidence-1', '1')]);
    });
    testWidgets('renders GptMarkdown with provided text', (tester) async {
      const markdownText = '# Hello World\n\nThis is a test.';

      await _pumpView(tester, markdownText);

      final gptMarkdown = tester.widget<GptMarkdown>(
        find.byType(GptMarkdown),
      );
      expect(gptMarkdown.data, markdownText);
    });

    testWidgets('forwards an optional line clamp to the markdown renderer', (
      tester,
    ) async {
      await _pumpView(
        tester,
        'A long answer',
        maxLines: 8,
        overflow: TextOverflow.ellipsis,
      );

      final gptMarkdown = tester.widget<GptMarkdown>(
        find.byType(GptMarkdown),
      );
      expect(gptMarkdown.maxLines, 8);
      expect(gptMarkdown.overflow, TextOverflow.ellipsis);
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
      'renders links in the theme primary color, also on hover',
      (tester) async {
        await _pumpView(tester, 'See [task](/tasks/123).');

        final context = tester.element(find.byType(AgentMarkdownView));
        final primary = Theme.of(context).colorScheme.primary;

        final gptMarkdown = tester.widget<GptMarkdown>(
          find.byType(GptMarkdown),
        );
        expect(gptMarkdown.styleSheet?.link?.hoverColor, primary);

        final linkText = tester.widget<Text>(
          find.descendant(
            of: find.byType(InkWell),
            matching: find.byType(Text),
          ),
        );
        final linkSpan = linkText.textSpan! as TextSpan;
        expect(linkSpan.style?.color, primary);
        expect(linkSpan.style?.decoration, TextDecoration.underline);
        expect(linkSpan.toPlainText(), 'task');
      },
    );

    testWidgets(
      'injects a compact, non-interactive checkbox theme from tokens',
      (tester) async {
        await _pumpView(tester, '- [x] done\n- [ ] todo');

        final context = tester.element(find.byType(AgentMarkdownView));
        final tokens = context.designTokens;

        final gptContext = tester.element(find.byType(GptMarkdown));
        final checkbox = legacy.Theme.of(gptContext).checkboxTheme;

        expect(
          checkbox.materialTapTargetSize,
          legacy.MaterialTapTargetSize.shrinkWrap,
        );
        expect(checkbox.visualDensity, legacy.VisualDensity.compact);

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
            LegacyMaterialExtensions([
              GptMarkdownThemeData(
                brightness: Brightness.light,
                linkColor: Colors.purple,
                h1: const TextStyle(fontSize: 999),
              ),
            ]),
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
        final extensions = legacy.Theme.of(gptContext).extensions.values;
        final markdownExtensions = extensions
            .whereType<GptMarkdownThemeData>()
            .toList();
        expect(markdownExtensions.length, 1);
        // DsTokens from the host theme is preserved across the injection.
        expect(Theme.of(gptContext).extension<DsTokens>(), isNotNull);
      },
    );

    testWidgets(
      'wires GptMarkdown link callbacks to the shared markdown handlers',
      (tester) async {
        // A recording NavService shows where a tapped internal link went.
        final navService = RecordingMockNavService();
        await tearDownTestGetIt();
        await setUpTestGetIt(
          additionalSetup: () {
            getIt.registerSingleton<NavService>(navService);
          },
        );

        await _pumpView(tester, '[task](/tasks/123)');

        // Without an owner handler, links fall back to handleMarkdownLinkTap,
        // which forwards an internal route to NavService.
        await tester.tap(find.text('task'));
        await tester.pump();
        expect(navService.navigationHistory, ['/tasks/123']);

        // The link is announced to assistive technology as a link.
        expect(
          find.ancestor(
            of: find.byType(InkWell),
            matching: find.byWidgetPredicate(
              (widget) => widget is Semantics && widget.properties.link == true,
            ),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
