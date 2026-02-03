import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/gamey/colors.dart';

void main() {
  group('GameyColors', () {
    group('Primary colors', () {
      test('primaryBlue is defined', () {
        expect(GameyColors.primaryBlue, isA<Color>());
        expect(GameyColors.primaryBlue.a, equals(1.0));
      });

      test('primaryGreen is defined', () {
        expect(GameyColors.primaryGreen, isA<Color>());
      });

      test('primaryPurple is defined', () {
        expect(GameyColors.primaryPurple, isA<Color>());
      });

      test('primaryOrange is defined', () {
        expect(GameyColors.primaryOrange, isA<Color>());
      });

      test('primaryRed is defined', () {
        expect(GameyColors.primaryRed, isA<Color>());
      });
    });

    group('Feature colors', () {
      test('journalTeal is defined', () {
        expect(GameyColors.journalTeal, isA<Color>());
      });

      test('habitPink is defined', () {
        expect(GameyColors.habitPink, isA<Color>());
      });

      test('taskYellow is defined', () {
        expect(GameyColors.taskYellow, isA<Color>());
      });

      test('moodIndigo is defined', () {
        expect(GameyColors.moodIndigo, isA<Color>());
      });

      test('healthGreen is defined', () {
        expect(GameyColors.healthGreen, isA<Color>());
      });

      test('aiCyan is defined', () {
        expect(GameyColors.aiCyan, isA<Color>());
      });
    });

    group('Gamey accent colors', () {
      test('gameyAccent is defined', () {
        expect(GameyColors.gameyAccent, isA<Color>());
      });

      test('gameyAccentLight is defined', () {
        expect(GameyColors.gameyAccentLight, isA<Color>());
      });

      test('gameyAccentLight is lighter than gameyAccent', () {
        final accentLuminance = GameyColors.gameyAccent.computeLuminance();
        final lightLuminance = GameyColors.gameyAccentLight.computeLuminance();
        expect(lightLuminance, greaterThan(accentLuminance));
      });
    });

    group('Reward colors', () {
      test('goldReward is defined', () {
        expect(GameyColors.goldReward, isA<Color>());
      });

      test('silverReward is defined', () {
        expect(GameyColors.silverReward, isA<Color>());
      });

      test('bronzeReward is defined', () {
        expect(GameyColors.bronzeReward, isA<Color>());
      });
    });

    group('Surface colors', () {
      test('surfaceDark is defined', () {
        expect(GameyColors.surfaceDark, isA<Color>());
      });

      test('surfaceDarkElevated is defined', () {
        expect(GameyColors.surfaceDarkElevated, isA<Color>());
      });

      test('surfaceLight is defined', () {
        expect(GameyColors.surfaceLight, isA<Color>());
      });

      test('surfaceLightElevated is defined', () {
        expect(GameyColors.surfaceLightElevated, isA<Color>());
      });

      test('dark surfaces are darker than light surfaces', () {
        final darkLuminance = GameyColors.surfaceDark.computeLuminance();
        final lightLuminance = GameyColors.surfaceLight.computeLuminance();
        expect(darkLuminance, lessThan(lightLuminance));
      });
    });

    group('featureColor helper', () {
      test('returns journalTeal for journal feature', () {
        expect(GameyColors.featureColor('journal'),
            equals(GameyColors.journalTeal));
      });

      test('returns habitPink for habit feature', () {
        expect(
            GameyColors.featureColor('habit'), equals(GameyColors.habitPink));
      });

      test('returns taskYellow for task feature', () {
        expect(
            GameyColors.featureColor('task'), equals(GameyColors.taskYellow));
      });

      test('returns moodIndigo for mood feature', () {
        expect(
            GameyColors.featureColor('mood'), equals(GameyColors.moodIndigo));
      });

      test('returns healthGreen for health feature', () {
        expect(GameyColors.featureColor('health'),
            equals(GameyColors.healthGreen));
      });

      test('returns aiCyan for ai feature', () {
        expect(GameyColors.featureColor('ai'), equals(GameyColors.aiCyan));
      });

      test('returns primaryBlue for unknown feature', () {
        expect(GameyColors.featureColor('unknown'),
            equals(GameyColors.primaryBlue));
        expect(GameyColors.featureColor(''), equals(GameyColors.primaryBlue));
        expect(GameyColors.featureColor('random'),
            equals(GameyColors.primaryBlue));
      });
    });

    group('priorityColor helper', () {
      test('returns red for priority 1 (urgent)', () {
        final color = GameyColors.priorityColor(1);
        expect(color, equals(GameyColors.primaryRed));
      });

      test('returns orange for priority 2 (high)', () {
        final color = GameyColors.priorityColor(2);
        expect(color, equals(GameyColors.primaryOrange));
      });

      test('returns yellow for priority 3 (medium)', () {
        final color = GameyColors.priorityColor(3);
        expect(color, equals(GameyColors.taskYellow));
      });

      test('returns green for default/low priority', () {
        expect(GameyColors.priorityColor(0), equals(GameyColors.primaryGreen));
        expect(GameyColors.priorityColor(4), equals(GameyColors.primaryGreen));
        expect(GameyColors.priorityColor(99), equals(GameyColors.primaryGreen));
      });
    });
  });
}
