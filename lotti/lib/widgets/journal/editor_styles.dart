import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
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
      GoogleFonts.lato(
        fontSize: 16,
        color: textColor,
      ),
      const Tuple2(2, 0),
      const Tuple2(0, 0),
      null,
    ),
    lists: DefaultListBlockStyle(
      GoogleFonts.lato(
        fontSize: 16,
        color: textColor,
      ),
      const Tuple2(4, 0),
      const Tuple2(0, 0),
      null,
      null,
    ),
    code: DefaultTextBlockStyle(
      GoogleFonts.shareTechMono(
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
