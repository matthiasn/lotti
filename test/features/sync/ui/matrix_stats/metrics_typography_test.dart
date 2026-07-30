import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_typography.dart';

// The point of this helper is that four headings on one page cannot drift
// apart. `metrics_section_test.dart` and `message_counts_view_test.dart` assert
// the call sites render at this tier; these tests pin the tier itself, so a
// retune has to be deliberate in both themes rather than landing on light only.
void main() {
  group('metricsGroupHeading', () {
    for (final (name, tokens) in [
      ('light', dsTokensLight),
      ('dark', dsTokensDark),
    ]) {
      group(name, () {
        final style = metricsGroupHeading(tokens);
        final base = tokens.typography.styles.subtitle.subtitle2;

        test('colour is the only thing it changes about subtitle2', () {
          // Normalised to the same colour, the two styles must be identical.
          // The docstring promises no weight override — `subtitle2` already
          // carries semiBold — and this is what makes that promise checkable
          // rather than a comment: any added size, weight or spacing override
          // survives the normalisation and fails here.
          //
          // Compared through a probe rather than `base.color`, which is null:
          // `copyWith(color: null)` keeps the existing colour, so that
          // comparison would pass whatever the helper did.
          expect(style.copyWith(color: _probe), base.copyWith(color: _probe));
          expect(style.color, tokens.colors.text.highEmphasis);
        });

        test('carries the heading weight, not the tier above it', () {
          // A bare `TextStyle(fontWeight: bold)` is what "Sent messages" used
          // to be, and it outshouted its identically-ranked peers.
          expect(style.fontWeight, tokens.typography.weight.semiBold);
          expect(style.fontWeight, isNot(tokens.typography.weight.bold));
        });

        test('ranks strictly below the panel title', () {
          // The section title is subtitle1. If the two ever converged the page
          // would read as one flat list of equal headings — the exact defect
          // this helper exists to prevent.
          expect(
            style.fontSize,
            lessThan(tokens.typography.styles.subtitle.subtitle1.fontSize!),
          );
        });
      });
    }

    test('resolves to the same metrics in both themes', () {
      // Only colour may differ between light and dark; a size or weight that
      // diverged would make the heading hierarchy theme-dependent.
      final light = metricsGroupHeading(dsTokensLight);
      final dark = metricsGroupHeading(dsTokensDark);

      expect(dark.copyWith(color: _probe), light.copyWith(color: _probe));
      expect(dark.color, isNot(light.color));
    });
  });
}

/// A colour neither theme uses, so normalising both sides to it cannot mask a
/// difference in the colours themselves.
const _probe = Color(0xFF00FF00);
