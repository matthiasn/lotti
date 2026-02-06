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

        expect(inactiveShadows, isNotEmpty, reason: 'Should have shadows');
        expect(activeShadows, isNotEmpty, reason: 'Should have shadows');

        final inactiveBlur = inactiveShadows.first.blurRadius;
        final activeBlur = activeShadows.first.blurRadius;
        expect(activeBlur, greaterThanOrEqualTo(inactiveBlur));
      });
    });

    group('Feature-specific glows', () {
      test('forFeature returns shadows for known features', () {
        final features = [
          'journal',
          'habit',
          'task',
          'mood',
          'health',
          'measurement',
          'ai',
          'speech',
          'settings',
        ];

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

        expect(normalShadows, isNotEmpty, reason: 'Should have shadows');
        expect(highlightedShadows, isNotEmpty, reason: 'Should have shadows');

        final normalAlpha = normalShadows.first.color.a;
        final highlightedAlpha = highlightedShadows.first.color.a;
        expect(highlightedAlpha, greaterThanOrEqualTo(normalAlpha));
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

        expect(lowIntensity, isNotEmpty, reason: 'Should have shadows');
        expect(highIntensity, isNotEmpty, reason: 'Should have shadows');

        final lowAlpha = lowIntensity.first.color.a;
        final highAlpha = highIntensity.first.color.a;
        expect(highAlpha, greaterThan(lowAlpha));
      });
    });

    group('Single glow shadows', () {
      test('colorGlow creates shadow with custom parameters', () {
        final shadow = GameyGlows.colorGlow(
          Colors.blue,
          blur: 20,
          spread: 5,
          opacity: 0.5,
          offset: const Offset(2, 4),
        );

        expect(shadow, isA<BoxShadow>());
        expect(shadow.blurRadius, equals(20));
        expect(shadow.spreadRadius, equals(5));
        expect(shadow.color.a, closeTo(0.5, 0.01));
        expect(shadow.offset, equals(const Offset(2, 4)));
      });

      test('colorGlow uses default values', () {
        final shadow = GameyGlows.colorGlow(Colors.red);

        expect(shadow.blurRadius, equals(GameyGlows.glowBlurMedium));
        expect(shadow.spreadRadius, equals(0));
        expect(shadow.color.a, closeTo(GameyGlows.glowOpacityMedium, 0.01));
        expect(shadow.offset, equals(Offset.zero));
      });

      test('subtleGlow creates subtle shadow', () {
        final shadow = GameyGlows.subtleGlow(Colors.green);

        expect(shadow, isA<BoxShadow>());
        expect(shadow.blurRadius, equals(GameyGlows.glowBlurSubtle));
        expect(shadow.color.a, closeTo(GameyGlows.glowOpacitySubtle, 0.01));
      });

      test('strongGlow creates strong shadow', () {
        final shadow = GameyGlows.strongGlow(Colors.purple);

        expect(shadow, isA<BoxShadow>());
        expect(shadow.blurRadius, equals(GameyGlows.glowBlurStrong));
        expect(shadow.color.a, closeTo(GameyGlows.glowOpacityStrong, 0.01));
      });

      test('intenseGlow creates intense shadow', () {
        final shadow = GameyGlows.intenseGlow(Colors.orange);

        expect(shadow, isA<BoxShadow>());
        expect(shadow.blurRadius, equals(GameyGlows.glowBlurIntense));
        expect(shadow.color.a, closeTo(GameyGlows.glowOpacityIntense, 0.01));
      });
    });

    group('Feature-specific glow methods', () {
      test('journalGlow returns shadows', () {
        expect(GameyGlows.journalGlow(), isA<List<BoxShadow>>());
        expect(
            GameyGlows.journalGlow(highlighted: true), isA<List<BoxShadow>>());
      });

      test('habitGlow returns shadows', () {
        expect(GameyGlows.habitGlow(), isA<List<BoxShadow>>());
        expect(GameyGlows.habitGlow(highlighted: true), isA<List<BoxShadow>>());
      });

      test('taskGlow returns shadows', () {
        expect(GameyGlows.taskGlow(), isA<List<BoxShadow>>());
        expect(GameyGlows.taskGlow(highlighted: true), isA<List<BoxShadow>>());
      });

      test('moodGlow returns shadows', () {
        expect(GameyGlows.moodGlow(), isA<List<BoxShadow>>());
        expect(GameyGlows.moodGlow(highlighted: true), isA<List<BoxShadow>>());
      });

      test('achievementGlow returns shadows', () {
        expect(GameyGlows.achievementGlow(), isA<List<BoxShadow>>());
        expect(GameyGlows.achievementGlow(highlighted: true),
            isA<List<BoxShadow>>());
      });

      test('streakGlow returns shadows', () {
        expect(GameyGlows.streakGlow(), isA<List<BoxShadow>>());
        expect(
            GameyGlows.streakGlow(highlighted: true), isA<List<BoxShadow>>());
      });

      test('levelGlow returns shadows', () {
        expect(GameyGlows.levelGlow(), isA<List<BoxShadow>>());
        expect(GameyGlows.levelGlow(highlighted: true), isA<List<BoxShadow>>());
      });

      test('successGlow returns shadows', () {
        expect(GameyGlows.successGlow(), isA<List<BoxShadow>>());
        expect(
            GameyGlows.successGlow(highlighted: true), isA<List<BoxShadow>>());
      });

      test('warningGlow returns shadows', () {
        expect(GameyGlows.warningGlow(), isA<List<BoxShadow>>());
        expect(
            GameyGlows.warningGlow(highlighted: true), isA<List<BoxShadow>>());
      });
    });

    group('forFeature additional aliases', () {
      test('returns journal glow for entry alias', () {
        expect(
          GameyGlows.forFeature('entry'),
          equals(GameyGlows.journalGlow()),
        );
      });

      test('returns journal glow for text alias', () {
        expect(
          GameyGlows.forFeature('text'),
          equals(GameyGlows.journalGlow()),
        );
      });

      test('returns habit glow for habits alias', () {
        expect(
          GameyGlows.forFeature('habits'),
          equals(GameyGlows.habitGlow()),
        );
      });

      test('returns task glow for tasks alias', () {
        expect(
          GameyGlows.forFeature('tasks'),
          equals(GameyGlows.taskGlow()),
        );
      });

      test('returns mood glow for moods alias', () {
        expect(
          GameyGlows.forFeature('moods'),
          equals(GameyGlows.moodGlow()),
        );
      });

      test('returns achievement glow for reward alias', () {
        expect(
          GameyGlows.forFeature('reward'),
          equals(GameyGlows.achievementGlow()),
        );
      });

      test('returns streak glow', () {
        expect(
          GameyGlows.forFeature('streak'),
          equals(GameyGlows.streakGlow()),
        );
      });

      test('returns level glow', () {
        expect(
          GameyGlows.forFeature('level'),
          equals(GameyGlows.levelGlow()),
        );
      });
    });

    group('none constant', () {
      test('none is empty list', () {
        expect(GameyGlows.none, isEmpty);
        expect(GameyGlows.none, isA<List<BoxShadow>>());
      });
    });
  });
}
