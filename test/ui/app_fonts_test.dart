import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/ui/app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late bool originalAllow;

  setUp(() {
    originalAllow = GoogleFonts.config.allowRuntimeFetching;
  });

  tearDown(() {
    GoogleFonts.config.allowRuntimeFetching = originalAllow;
  });

  test('inconsolata falls back without runtime fetching', () {
    GoogleFonts.config.allowRuntimeFetching = false;
    final style = AppFonts.inconsolata(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Colors.red,
      letterSpacing: 1.2,
    );
    expect(style.fontFamily, 'Inconsolata');
    expect(style.fontSize, 14);
    expect(style.fontWeight, FontWeight.w400);
    expect(style.color, Colors.red);
    expect(style.letterSpacing, 1.2);
  });

  test('inclusiveSansFamily falls back without runtime fetching', () {
    GoogleFonts.config.allowRuntimeFetching = false;
    expect(AppFonts.inclusiveSansFamily(), 'Inclusive Sans');
  });

  test('delegates to google_fonts when runtime fetching allowed', () {
    GoogleFonts.config.allowRuntimeFetching = true;
    final gf = GoogleFonts.inconsolata();
    final style = AppFonts.inconsolata();
    expect(style.fontFamily, gf.fontFamily);
    expect(
        AppFonts.inclusiveSansFamily(), GoogleFonts.inclusiveSans().fontFamily);
  });

  test('inconsolata returns a style with defaults when no args', () {
    GoogleFonts.config.allowRuntimeFetching = false;
    final style = AppFonts.inconsolata();
    expect(style, isA<TextStyle>());
    expect(style.fontFamily, 'Inconsolata');
  });
}
// End of file
