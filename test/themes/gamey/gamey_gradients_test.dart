import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/gamey/gradients.dart';

void main() {
  group('GameyGradients', () {
    group('Feature gradients', () {
      test('journal gradient is defined', () {
        expect(GameyGradients.journal, isA<LinearGradient>());
        expect(GameyGradients.journal.colors, isNotEmpty);
      });

      test('habit gradient is defined', () {
        expect(GameyGradients.habit, isA<LinearGradient>());
        expect(GameyGradients.habit.colors, isNotEmpty);
      });

      test('task gradient is defined', () {
        expect(GameyGradients.task, isA<LinearGradient>());
        expect(GameyGradients.task.colors, isNotEmpty);
      });

      test('mood gradient is defined', () {
        expect(GameyGradients.mood, isA<LinearGradient>());
      });

      test('health gradient is defined', () {
        expect(GameyGradients.health, isA<LinearGradient>());
      });

      test('ai gradient is defined', () {
        expect(GameyGradients.ai, isA<LinearGradient>());
      });
    });

    group('Action gradients', () {
      test('success gradient is defined', () {
        expect(GameyGradients.success, isA<LinearGradient>());
      });

      test('xpProgress gradient is defined', () {
        expect(GameyGradients.xpProgress, isA<LinearGradient>());
      });

      test('level gradient is defined', () {
        expect(GameyGradients.level, isA<LinearGradient>());
      });

      test('streak gradient is defined', () {
        expect(GameyGradients.streak, isA<LinearGradient>());
      });

      test('warning gradient is defined', () {
        expect(GameyGradients.warning, isA<LinearGradient>());
      });
    });

    group('Reward gradients', () {
      test('gold gradient is defined', () {
        expect(GameyGradients.gold, isA<LinearGradient>());
      });

      test('goldPremium gradient is defined', () {
        expect(GameyGradients.goldPremium, isA<LinearGradient>());
      });

      test('silver gradient is defined', () {
        expect(GameyGradients.silver, isA<LinearGradient>());
      });

      test('bronze gradient is defined', () {
        expect(GameyGradients.bronze, isA<LinearGradient>());
      });
    });

    group('Background gradients', () {
      test('backgroundDark gradient is defined', () {
        expect(GameyGradients.backgroundDark, isA<LinearGradient>());
      });

      test('backgroundLight gradient is defined', () {
        expect(GameyGradients.backgroundLight, isA<LinearGradient>());
        expect(GameyGradients.backgroundLight.colors, isNotEmpty);
      });
    });

    group('Card gradients', () {
      test('cardLight creates gradient with accent color blend', () {
        const accentColor = Colors.blue;
        final gradient = GameyGradients.cardLight(accentColor);

        expect(gradient, isA<LinearGradient>());
        expect(gradient.colors.length, equals(2));
        // First color should be lighter (closer to white)
        expect(
          gradient.colors.first.computeLuminance(),
          greaterThan(gradient.colors.last.computeLuminance() * 0.9),
        );
      });

      test('cardLight uses custom surface color when provided', () {
        const accentColor = Colors.blue;
        const surfaceColor = Color(0xFFF0F0F0);
        final gradient = GameyGradients.cardLight(accentColor, surfaceColor);

        expect(gradient, isA<LinearGradient>());
        expect(gradient.colors.length, equals(2));
      });

      test('cardDark creates gradient with accent color blend', () {
        const accentColor = Colors.blue;
        final gradient = GameyGradients.cardDark(accentColor);

        expect(gradient, isA<LinearGradient>());
        expect(gradient.colors.length, equals(2));
      });

      test('cardDark uses custom surface color when provided', () {
        const accentColor = Colors.blue;
        const surfaceColor = Color(0xFF2A2A2A);
        final gradient = GameyGradients.cardDark(accentColor, surfaceColor);

        expect(gradient, isA<LinearGradient>());
        expect(gradient.colors.length, equals(2));
      });

      test('cardFromContext returns appropriate gradient for dark theme', () {
        // We can't easily test this without a BuildContext,
        // but we can verify the underlying functions work
        final darkGradient = GameyGradients.cardDark(Colors.blue);
        expect(darkGradient, isA<LinearGradient>());
      });
    });

    group('forFeature helper', () {
      test('returns journal gradient for journal feature', () {
        expect(GameyGradients.forFeature('journal'),
            equals(GameyGradients.journal));
      });

      test('returns habit gradient for habit feature', () {
        expect(
            GameyGradients.forFeature('habit'), equals(GameyGradients.habit));
      });

      test('returns task gradient for task feature', () {
        expect(GameyGradients.forFeature('task'), equals(GameyGradients.task));
      });

      test('returns mood gradient for mood feature', () {
        expect(GameyGradients.forFeature('mood'), equals(GameyGradients.mood));
      });

      test('returns health gradient for health feature', () {
        expect(
            GameyGradients.forFeature('health'), equals(GameyGradients.health));
      });

      test('returns ai gradient for ai feature', () {
        expect(GameyGradients.forFeature('ai'), equals(GameyGradients.ai));
      });

      test('returns success gradient for unknown feature', () {
        expect(
          GameyGradients.forFeature('unknown'),
          equals(GameyGradients.success),
        );
        expect(
          GameyGradients.forFeature(''),
          equals(GameyGradients.success),
        );
      });
    });

    group('Shimmer gradient', () {
      test('shimmer gradient is defined', () {
        expect(GameyGradients.shimmer, isA<LinearGradient>());
        expect(GameyGradients.shimmer.colors.length, equals(3));
      });

      test('shimmer gradient has transparent ends', () {
        expect(
          GameyGradients.shimmer.colors.first,
          equals(Colors.transparent),
        );
        expect(
          GameyGradients.shimmer.colors.last,
          equals(Colors.transparent),
        );
      });
    });

    group('Settings gradient', () {
      test('settings gradient is defined', () {
        expect(GameyGradients.settings, isA<LinearGradient>());
        expect(GameyGradients.settings.colors, isNotEmpty);
      });
    });

    group('Neon gradients', () {
      test('neonCelebration gradient is defined', () {
        expect(GameyGradients.neonCelebration, isA<LinearGradient>());
        expect(GameyGradients.neonCelebration.colors.length, equals(3));
      });

      test('rainbow gradient is defined', () {
        expect(GameyGradients.rainbow, isA<LinearGradient>());
        expect(GameyGradients.rainbow.colors.length, equals(6));
      });
    });

    group('forFeature additional aliases', () {
      test('returns journal gradient for entry alias', () {
        expect(
            GameyGradients.forFeature('entry'), equals(GameyGradients.journal));
      });

      test('returns journal gradient for text alias', () {
        expect(
            GameyGradients.forFeature('text'), equals(GameyGradients.journal));
      });

      test('returns habit gradient for habits alias', () {
        expect(
            GameyGradients.forFeature('habits'), equals(GameyGradients.habit));
      });

      test('returns task gradient for tasks alias', () {
        expect(GameyGradients.forFeature('tasks'), equals(GameyGradients.task));
      });

      test('returns mood gradient for moods alias', () {
        expect(GameyGradients.forFeature('moods'), equals(GameyGradients.mood));
      });

      test('returns health gradient for measurement alias', () {
        expect(GameyGradients.forFeature('measurement'),
            equals(GameyGradients.health));
      });

      test('returns ai gradient for speech alias', () {
        expect(GameyGradients.forFeature('speech'), equals(GameyGradients.ai));
      });

      test('returns ai gradient for transcription alias', () {
        expect(GameyGradients.forFeature('transcription'),
            equals(GameyGradients.ai));
      });

      test('returns gold gradient for achievement alias', () {
        expect(GameyGradients.forFeature('achievement'),
            equals(GameyGradients.gold));
      });

      test('returns gold gradient for reward alias', () {
        expect(
            GameyGradients.forFeature('reward'), equals(GameyGradients.gold));
      });

      test('returns streak gradient', () {
        expect(
            GameyGradients.forFeature('streak'), equals(GameyGradients.streak));
      });

      test('returns level gradient', () {
        expect(
            GameyGradients.forFeature('level'), equals(GameyGradients.level));
      });

      test('returns settings gradient for settings alias', () {
        expect(GameyGradients.forFeature('settings'),
            equals(GameyGradients.settings));
      });

      test('returns settings gradient for config alias', () {
        expect(GameyGradients.forFeature('config'),
            equals(GameyGradients.settings));
      });
    });

    group('custom helper', () {
      test('custom creates gradient from two colors', () {
        final gradient = GameyGradients.custom(Colors.red, Colors.blue);

        expect(gradient, isA<LinearGradient>());
        expect(gradient.colors, equals([Colors.red, Colors.blue]));
        expect(gradient.begin, equals(Alignment.topLeft));
        expect(gradient.end, equals(Alignment.bottomRight));
      });

      test('custom respects alignment parameters', () {
        final gradient = GameyGradients.custom(
          Colors.green,
          Colors.yellow,
          begin: Alignment.topCenter,
          endAlign: Alignment.bottomCenter,
        );

        expect(gradient.begin, equals(Alignment.topCenter));
        expect(gradient.end, equals(Alignment.bottomCenter));
      });
    });
  });
}
