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
      GoogleFonts.plusJakartaSans(
        fontSize: fontSizeLarge,
        color: textColor,
      ),
      const Tuple2(0, 0),
      const Tuple2(0, 0),
      null,
    ),
    h2: DefaultTextBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        color: textColor,
      ),
      const Tuple2(8, 0),
      const Tuple2(0, 0),
      null,
    ),
    h3: DefaultTextBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: 18,
        color: textColor,
      ),
      const Tuple2(8, 0),
      const Tuple2(0, 0),
      null,
    ),
    paragraph: DefaultTextBlockStyle(
      GoogleFonts.plusJakartaSans(
        fontSize: fontSizeMedium,
        color: textColor,
      ),
      const Tuple2(2, 0),
      const Tuple2(0, 0),
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
      const Tuple2(4, 0),
      const Tuple2(0, 0),
      null,
      null,
    ),
    code: DefaultTextBlockStyle(
      GoogleFonts.inconsolata(
        fontSize: fontSizeMedium,
        color: Colors.black,
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
