import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/themes/theme.dart';

DefaultStyles customEditorStyles({
  required ThemeData themeData,
}) {
  final textColor = themeData.textTheme.bodyLarge?.color;
  final codeBlockBackground = themeData.primaryColorLight;

  return DefaultStyles(
    h1: DefaultTextBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: fontSizeLarge,
        color: textColor,
      ),
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    h2: DefaultTextBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        color: textColor,
      ),
      const HorizontalSpacing(8, 0),
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    h3: DefaultTextBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: 18,
        color: textColor,
      ),
      const HorizontalSpacing(8, 0),
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    paragraph: DefaultTextBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: fontSizeMedium,
        color: textColor,
      ),
      const HorizontalSpacing(2, 0),
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    placeHolder: DefaultTextBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: fontSizeMedium,
        color: textColor?.withAlpha(72),
      ),
      const HorizontalSpacing(2, 0),
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    bold: GoogleFonts.plusJakartaSans(
      fontSize: fontSizeMedium,
      color: textColor,
      fontWeight: FontWeight.w900,
    ),
    inlineCode: InlineCodeStyle(
      radius: const Radius.circular(8),
      style: GoogleFonts.inconsolata(
        fontSize: fontSizeMedium,
        color: Colors.black,
      ),
      backgroundColor: codeBlockBackground,
    ),
    lists: DefaultListBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: fontSizeMedium,
        color: textColor,
      ),
      const HorizontalSpacing(4, 0),
      const VerticalSpacing(0, 4),
      VerticalSpacing.zero,
      null,
      null,
    ),
    code: DefaultTextBlockStyle(
      GoogleFonts.inconsolata(
        fontSize: fontSizeMedium,
        color: Colors.black,
      ),
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      BoxDecoration(
        color: codeBlockBackground,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
