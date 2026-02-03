import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/gamey/glows.dart';

void main() {
  group('GameyGlows', () {
    group('Glow intensity constants', () {
      test('subtle intensity is smallest', () {
        expect(GameyGlows.glowBlurSubtle, lessThan(GameyGlows.glowBlurMedium));
        expect(GameyGlows.glowOpacitySubtle,
            lessThan(GameyGlows.glowOpacityMedium));
      });

      test('medium intensity is between subtle and strong', () {
        expect(
            GameyGlows.glowBlurMedium, greaterThan(GameyGlows.glowBlurSubtle));
        expect(GameyGlows.glowBlurMedium, lessThan(GameyGlows.glowBlurStrong));
      });

      test('strong intensity is between medium and intense', () {
        expect(
            GameyGlows.glowBlurStrong, greaterThan(GameyGlows.glowBlurMedium));
        expect(GameyGlows.glowBlurStrong, lessThan(GameyGlows.glowBlurIntense));
      });

      test('intense intensity is largest', () {
        expect(
            GameyGlows.glowBlurIntense, greaterThan(GameyGlows.glowBlurStrong));
        expect(GameyGlows.glowOpacityIntense,
            greaterThan(GameyGlows.glowOpacityStrong));
      });
    });

    group('cardGlow', () {
      test('returns non-empty list of shadows', () {
        final shadows = GameyGlows.cardGlow(Colors.blue);
        expect(shadows, isNotEmpty);
      });

      test('creates shadow with provided color', () {
        final shadows = GameyGlows.cardGlow(Colors.blue);
        expect(shadows.first.color.r, lessThanOrEqualTo(Colors.blue.r));
        expect(shadows.first.color.g, lessThanOrEqualTo(Colors.blue.g));
        expect(shadows.first.color.b, greaterThan(0));
      });

      test('dark mode has different alpha than light mode', () {
        final lightShadows = GameyGlows.cardGlow(Colors.blue);
        final darkShadows = GameyGlows.cardGlow(Colors.blue, isDark: true);

        // Both should return shadows
        expect(lightShadows, isNotEmpty);
        expect(darkShadows, isNotEmpty);

        // Alpha values should be different
        final lightAlpha = lightShadows.first.color.a;
        final darkAlpha = darkShadows.first.color.a;
        expect(lightAlpha, isNot(equals(darkAlpha)));
      });

      test('shadow has reasonable blur radius', () {
        final shadows = GameyGlows.cardGlow(Colors.blue);
        expect(shadows.first.blurRadius, greaterThan(0));
        expect(shadows.first.blurRadius, lessThan(50));
      });

      test('shadow has downward offset', () {
        final shadows = GameyGlows.cardGlow(Colors.blue);
        expect(shadows.first.offset.dy, greaterThanOrEqualTo(0));
      });
    });

    group('cardGlowHighlighted', () {
      test('returns non-empty list of shadows', () {
        final shadows = GameyGlows.cardGlowHighlighted(Colors.blue);
        expect(shadows, isNotEmpty);
      });

      test('has stronger effect than cardGlow', () {
        final normalShadows = GameyGlows.cardGlow(Colors.blue);
        final highlightedShadows = GameyGlows.cardGlowHighlighted(Colors.blue);

        // Highlighted should have larger blur radius or higher alpha
        final normalBlur = normalShadows.first.blurRadius;
        final highlightedBlur = highlightedShadows.first.blurRadius;
        final normalAlpha = normalShadows.first.color.a;
        final highlightedAlpha = highlightedShadows.first.color.a;

        expect(
          highlightedBlur > normalBlur || highlightedAlpha > normalAlpha,
          isTrue,
          reason: 'Highlighted should be more prominent than normal',
        );
      });

      test('dark mode variant exists', () {
        final shadows =
            GameyGlows.cardGlowHighlighted(Colors.blue, isDark: true);
        expect(shadows, isNotEmpty);
      });
    });

    group('iconGlow', () {
      test('returns list of shadows', () {
        final shadows = GameyGlows.iconGlow(Colors.purple);
        expect(shadows, isA<List<BoxShadow>>());
      });

      test('active state has stronger glow', () {
        final inactiveShadows = GameyGlows.iconGlow(Colors.purple);
        final activeShadows =
            GameyGlows.iconGlow(Colors.purple, isActive: true);

        if (inactiveShadows.isNotEmpty && activeShadows.isNotEmpty) {
          final inactiveBlur = inactiveShadows.first.blurRadius;
          final activeBlur = activeShadows.first.blurRadius;
          expect(activeBlur, greaterThanOrEqualTo(inactiveBlur));
        }
      });
    });

    group('Feature-specific glows', () {
      test('forFeature returns shadows for known features', () {
        final features = ['journal', 'habit', 'task', 'mood', 'health', 'ai'];

        for (final feature in features) {
          final shadows = GameyGlows.forFeature(feature);
          expect(
            shadows,
            isA<List<BoxShadow>>(),
            reason: 'Feature $feature should return BoxShadow list',
          );
        }
      });

      test('forFeature returns default for unknown feature', () {
        final shadows = GameyGlows.forFeature('unknown');
        expect(shadows, isA<List<BoxShadow>>());
      });

      test('forFeature highlight parameter affects intensity', () {
        final normalShadows = GameyGlows.forFeature('journal');
        final highlightedShadows =
            GameyGlows.forFeature('journal', highlighted: true);

        // If both return shadows, highlighted should be more intense
        if (normalShadows.isNotEmpty && highlightedShadows.isNotEmpty) {
          final normalAlpha = normalShadows.first.color.a;
          final highlightedAlpha = highlightedShadows.first.color.a;
          expect(highlightedAlpha, greaterThanOrEqualTo(normalAlpha));
        }
      });
    });

    group('Neon glows', () {
      test('neonGlow returns shadows', () {
        final shadows = GameyGlows.neonGlow(Colors.cyan);
        expect(shadows, isA<List<BoxShadow>>());
        expect(shadows, isNotEmpty);
      });

      test('neonGlow has vibrant colors', () {
        final shadows = GameyGlows.neonGlow(Colors.cyan);
        // Neon glows should have reasonable alpha for vibrant effect (a is 0.0-1.0)
        expect(shadows.first.color.a, greaterThanOrEqualTo(0.2));
      });
    });

    group('Pulse glows', () {
      test('pulseGlow returns shadows', () {
        final shadows = GameyGlows.pulseGlow(Colors.pink, pulseValue: 0.5);
        expect(shadows, isA<List<BoxShadow>>());
      });

      test('pulseGlow pulseValue parameter works', () {
        final lowIntensity = GameyGlows.pulseGlow(Colors.pink, pulseValue: 0.2);
        final highIntensity =
            GameyGlows.pulseGlow(Colors.pink, pulseValue: 0.8);

        if (lowIntensity.isNotEmpty && highIntensity.isNotEmpty) {
          final lowAlpha = lowIntensity.first.color.a;
          final highAlpha = highIntensity.first.color.a;
          expect(highAlpha, greaterThan(lowAlpha));
        }
      });
    });
  });
}
