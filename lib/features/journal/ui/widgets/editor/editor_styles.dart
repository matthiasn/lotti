import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Maps the design-system typography/color tokens onto Quill's [DefaultStyles]
/// so editor and read-only viewers render headings, body text, lists, and
/// inline/block code consistent with the rest of the app. Shared by the live
/// editor and both text-viewer widgets.
DefaultStyles customEditorStyles({
  required ThemeData themeData,
  required DsTokens tokens,
}) {
  final textColor = themeData.textTheme.bodyLarge?.color;
  final styles = tokens.typography.styles;
  final boldWeight = tokens.typography.weight.bold;
  final codeBackground = Color.alphaBlend(
    tokens.colors.surface.enabled,
    tokens.colors.background.level02,
  );
  final codeBorderColor = tokens.colors.decorative.level01;
  final codeTextColor = tokens.colors.text.highEmphasis;

  final paragraphStyle = styles.body.bodySmall.copyWith(color: textColor);
  final monoFontSize = styles.body.bodySmall.fontSize;

  return DefaultStyles(
    h1: DefaultTextBlockStyle(
      styles.heading.heading3.copyWith(color: textColor),
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    h2: DefaultTextBlockStyle(
      styles.subtitle.subtitle1.copyWith(color: textColor),
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    h3: DefaultTextBlockStyle(
      styles.subtitle.subtitle2.copyWith(color: textColor),
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    paragraph: DefaultTextBlockStyle(
      paragraphStyle,
      // No left indent — the body/note text must hang from the same content
      // gutter as the timestamp and value lines (the 2px inset pushed the body
      // off the shared left edge).
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    placeHolder: DefaultTextBlockStyle(
      paragraphStyle.copyWith(color: textColor?.withAlpha(72)),
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    bold: TextStyle(fontWeight: boldWeight),
    inlineCode: InlineCodeStyle(
      radius: Radius.circular(tokens.radii.xs),
      style: GoogleFonts.inconsolata(
        fontSize: monoFontSize,
        color: codeTextColor,
      ),
      backgroundColor: codeBackground,
    ),
    lists: DefaultListBlockStyle(
      paragraphStyle,
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
      null,
    ),
    code: DefaultTextBlockStyle(
      GoogleFonts.inconsolata(
        fontSize: monoFontSize,
        color: codeTextColor,
      ),
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      BoxDecoration(
        color: codeBackground,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(color: codeBorderColor),
      ),
    ),
  );
}
