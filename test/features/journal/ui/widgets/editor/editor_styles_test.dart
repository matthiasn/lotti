import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_styles.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The code styles use GoogleFonts.inconsolata; forbid runtime fetching
    // so the lookup stays local and synchronous in tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('customEditorStyles', () {
    for (final (label, theme, tokens) in [
      ('light', DesignSystemTheme.light(), dsTokensLight),
      ('dark', DesignSystemTheme.dark(), dsTokensDark),
    ]) {
      test('maps design-system tokens onto Quill styles ($label)', () {
        final styles = customEditorStyles(themeData: theme, tokens: tokens);
        final textColor = theme.textTheme.bodyLarge?.color;

        // Headings map h1/h2/h3 onto heading3/subtitle1/subtitle2.
        expect(
          styles.h1!.style.fontSize,
          tokens.typography.styles.heading.heading3.fontSize,
        );
        expect(styles.h1!.style.color, textColor);
        expect(
          styles.h2!.style.fontSize,
          tokens.typography.styles.subtitle.subtitle1.fontSize,
        );
        expect(
          styles.h3!.style.fontSize,
          tokens.typography.styles.subtitle.subtitle2.fontSize,
        );

        // Paragraph and lists use bodySmall tinted with the theme text color.
        expect(
          styles.paragraph!.style.fontSize,
          tokens.typography.styles.body.bodySmall.fontSize,
        );
        expect(styles.paragraph!.style.color, textColor);
        expect(styles.lists!.style.fontSize, styles.paragraph!.style.fontSize);

        // Placeholder is the faded paragraph style.
        expect(
          styles.placeHolder!.style.color,
          textColor?.withAlpha(72),
        );

        // Bold uses the token bold weight.
        expect(styles.bold!.fontWeight, tokens.typography.weight.bold);

        // Inline code: token radius, mono size, blended background.
        final expectedCodeBackground = Color.alphaBlend(
          tokens.colors.surface.enabled,
          tokens.colors.background.level02,
        );
        expect(
          styles.inlineCode!.radius,
          Radius.circular(tokens.radii.xs),
        );
        expect(styles.inlineCode!.backgroundColor, expectedCodeBackground);
        expect(
          styles.inlineCode!.style.color,
          tokens.colors.text.highEmphasis,
        );

        // Code block carries the bordered, rounded background decoration.
        final decoration = styles.code!.decoration!;
        expect(decoration.color, expectedCodeBackground);
        expect(
          decoration.borderRadius,
          BorderRadius.circular(tokens.radii.s),
        );
        expect(
          decoration.border!.top.color,
          tokens.colors.decorative.level01,
        );
      });
    }
  });
}
