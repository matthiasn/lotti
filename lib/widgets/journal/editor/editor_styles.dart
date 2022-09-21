import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/themes/theme.dart';
import 'package:tuple/tuple.dart';

DefaultStyles customEditorStyles({
  required Color textColor,
  required Color codeBlockBackground,
}) {
  return DefaultStyles(
    h1: DefaultTextBlockStyle(
      GoogleFonts.oswald(
        fontSize: 24,
        color: textColor,
      ),
      const Tuple2(0, 0),
      const Tuple2(0, 0),
      null,
    ),
    h2: DefaultTextBlockStyle(
      GoogleFonts.oswald(
        fontSize: 20,
        color: textColor,
      ),
      const Tuple2(8, 0),
      const Tuple2(0, 0),
      null,
    ),
    h3: DefaultTextBlockStyle(
      GoogleFonts.oswald(
        fontSize: 18,
        color: textColor,
      ),
      const Tuple2(8, 0),
      const Tuple2(0, 0),
      null,
    ),
    paragraph: DefaultTextBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        color: textColor,
      ),
      const Tuple2(2, 0),
      const Tuple2(0, 0),
      null,
    ),
    bold: GoogleFonts.plusJakartaSans(
      fontSize: 16,
      color: textColor,
      fontWeight: FontWeight.w900,
    ),
    inlineCode: InlineCodeStyle(
      radius: const Radius.circular(8),
      style: GoogleFonts.inconsolata(
        fontSize: 16,
        color: textColor,
      ),
      backgroundColor: codeBlockBackground,
    ),
    lists: DefaultListBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        color: textColor,
      ),
      const Tuple2(4, 0),
      const Tuple2(0, 0),
      null,
      null,
    ),
    code: DefaultTextBlockStyle(
      GoogleFonts.inconsolata(
        fontSize: 16,
        color: textColor,
      ),
      const Tuple2(0, 0),
      const Tuple2(0, 0),
      BoxDecoration(
        color: codeBlockBackground,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

DefaultStyles customTextViewerStyles({
  required Color textColor,
  required Color codeBlockBackground,
}) {
  return DefaultStyles(
    h1: DefaultTextBlockStyle(
      GoogleFonts.oswald(
        fontSize: 16,
        color: textColor,
      ),
      const Tuple2(0, 0),
      const Tuple2(0, 0),
      null,
    ),
    h2: DefaultTextBlockStyle(
      GoogleFonts.oswald(
        fontSize: 16,
        color: textColor,
      ),
      const Tuple2(0, 0),
      const Tuple2(0, 0),
      null,
    ),
    h3: DefaultTextBlockStyle(
      GoogleFonts.oswald(
        fontSize: 16,
        color: textColor,
      ),
      const Tuple2(0, 0),
      const Tuple2(0, 0),
      null,
    ),
    paragraph: DefaultTextBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: textColor,
      ),
      const Tuple2(0, 0),
      const Tuple2(0, 0),
      null,
    ),
    bold: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      color: textColor,
      fontWeight: FontWeight.w900,
    ),
    lists: DefaultListBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: textColor,
      ),
      const Tuple2(0, 0),
      const Tuple2(0, 0),
      null,
      null,
    ),
    inlineCode: InlineCodeStyle(
      radius: const Radius.circular(8),
      style: GoogleFonts.inconsolata(
        fontSize: 12,
        color: colorConfig().editorTextColor,
      ),
    ),
    code: DefaultTextBlockStyle(
      GoogleFonts.inconsolata(
        fontSize: 12,
        color: textColor,
      ),
      const Tuple2(0, 0),
      const Tuple2(0, 0),
      BoxDecoration(
        color: codeBlockBackground,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
