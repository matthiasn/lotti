import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/utils/markdown_link_utils.dart';

/// Renders agent-authored markdown using the same typography and surface
/// styling as the entry text editor: body text in `body.bodySmall`, headings
/// mapped to `heading.heading3` / `subtitle.subtitle1` / `subtitle.subtitle2`,
/// and a compact, non-interactive checkbox style mirroring the checklist row.
class AgentMarkdownView extends StatelessWidget {
  const AgentMarkdownView(this.text, {this.style, super.key});

  final String text;

  /// Optional override for the body text style. When null, uses the
  /// editor-aligned `body.bodySmall` token from the design system.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final textColor = theme.textTheme.bodyLarge?.color;
    final bodyStyle = style ?? styles.body.bodySmall.copyWith(color: textColor);

    final markdownTheme = GptMarkdownThemeData(
      brightness: theme.brightness,
      linkColor: theme.colorScheme.primary,
      h1: styles.heading.heading3.copyWith(color: textColor),
      h2: styles.subtitle.subtitle1.copyWith(color: textColor),
      h3: styles.subtitle.subtitle2.copyWith(color: textColor),
      h4: bodyStyle.copyWith(fontWeight: tokens.typography.weight.semiBold),
      h5: bodyStyle,
      h6: styles.others.caption.copyWith(color: textColor),
    );

    return Theme(
      data: theme.copyWith(
        checkboxTheme: theme.checkboxTheme.copyWith(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.xs),
          ),
          side: BorderSide(
            color: tokens.colors.text.lowEmphasis,
            width: 1.5,
          ),
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return tokens.colors.interactive.enabled;
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.basic),
        ),
        extensions: [
          ...theme.extensions.values.where((e) => e is! GptMarkdownThemeData),
          markdownTheme,
        ],
      ),
      child: DefaultTextStyle.merge(
        style: bodyStyle,
        child: GptMarkdown(
          text,
          onLinkTap: handleMarkdownLinkTap,
          linkBuilder: (context, span, url, style) {
            final linkColor = Theme.of(context).colorScheme.primary;
            return Semantics(
              link: true,
              child: InkWell(
                onTap: () => handleMarkdownLinkTap(url, ''),
                mouseCursor: SystemMouseCursors.click,
                child: Text.rich(
                  TextSpan(
                    children: [span],
                    style: style.copyWith(
                      color: linkColor,
                      decoration: TextDecoration.underline,
                      decorationColor: linkColor,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
