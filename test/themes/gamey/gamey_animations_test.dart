import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/gamey/animations.dart';

void main() {
  group('GameyAnimations', () {
    group('Duration constants', () {
      test('fast duration is shortest', () {
        expect(GameyAnimations.fast.inMilliseconds,
            lessThan(GameyAnimations.normal.inMilliseconds));
      });

      test('normal duration is between fast and slow', () {
        expect(GameyAnimations.normal.inMilliseconds,
            greaterThan(GameyAnimations.fast.inMilliseconds));
        expect(GameyAnimations.normal.inMilliseconds,
            lessThan(GameyAnimations.slow.inMilliseconds));
      });

      test('celebration durations are longer', () {
        expect(GameyAnimations.celebration.inMilliseconds,
            greaterThan(GameyAnimations.slow.inMilliseconds));
        expect(GameyAnimations.celebrationLong.inMilliseconds,
            greaterThan(GameyAnimations.celebration.inMilliseconds));
      });

      test('shimmer and pulse durations are defined', () {
        expect(GameyAnimations.shimmer.inMilliseconds, greaterThan(0));
        expect(GameyAnimations.pulse.inMilliseconds, greaterThan(0));
      });

      test('wiggle duration is defined', () {
        expect(GameyAnimations.wiggle.inMilliseconds, greaterThan(0));
      });
    });

    group('Curve constants', () {
      test('bounce curve is elasticOut', () {
        expect(GameyAnimations.bounce, equals(Curves.elasticOut));
      });

      test('smooth curve is easeOutCubic', () {
        expect(GameyAnimations.smooth, equals(Curves.easeOutCubic));
      });

      test('sharp curve is easeOutQuart', () {
        expect(GameyAnimations.sharp, equals(Curves.easeOutQuart));
      });

      test('playful curve is easeOutBack', () {
        expect(GameyAnimations.playful, equals(Curves.easeOutBack));
      });

      test('snappy curve is easeOutExpo', () {
        expect(GameyAnimations.snappy, equals(Curves.easeOutExpo));
      });

      test('symmetrical curve is easeInOut', () {
        expect(GameyAnimations.symmetrical, equals(Curves.easeInOut));
      });

      test('reveal curve is easeOutCirc', () {
        expect(GameyAnimations.reveal, equals(Curves.easeOutCirc));
      });
    });

    group('Scale values', () {
      test('tapScale is less than 1 (shrink effect)', () {
        expect(GameyAnimations.tapScale, lessThan(1.0));
        expect(GameyAnimations.tapScale, greaterThan(0.5));
      });

      test('hoverScale is less than 1', () {
        expect(GameyAnimations.hoverScale, lessThan(1.0));
      });

      test('hoverScaleUp is greater than 1', () {
        expect(GameyAnimations.hoverScaleUp, greaterThan(1.0));
      });

      test('pulse scale range is valid', () {
        expect(GameyAnimations.pulseScaleMin, lessThan(1.0));
        expect(GameyAnimations.pulseScaleMax, greaterThan(1.0));
        expect(GameyAnimations.pulseScaleMin,
            lessThan(GameyAnimations.pulseScaleMax));
      });

      test('celebrationScale is significantly larger', () {
        expect(GameyAnimations.celebrationScale, greaterThan(1.1));
      });

      test('iconTapScale is defined', () {
        expect(GameyAnimations.iconTapScale, lessThan(1.0));
      });

      test('wiggleScale is slightly larger than 1', () {
        expect(GameyAnimations.wiggleScale, greaterThan(1.0));
        expect(GameyAnimations.wiggleScale, lessThan(1.2));
      });
    });

    group('Rotation values', () {
      test('wiggleRotation is small positive value', () {
        expect(GameyAnimations.wiggleRotation, greaterThan(0));
        expect(GameyAnimations.wiggleRotation, lessThan(0.5));
      });

      test('shakeRotation is larger than wiggle', () {
        expect(GameyAnimations.shakeRotation,
            greaterThan(GameyAnimations.wiggleRotation));
      });
    });

    group('Opacity values', () {
      test('tapOpacity is between 0 and 1', () {
        expect(GameyAnimations.tapOpacity, greaterThan(0));
        expect(GameyAnimations.tapOpacity, lessThan(1.0));
      });

      test('disabledOpacity is 0.5', () {
        expect(GameyAnimations.disabledOpacity, equals(0.5));
      });

      test('hoverHighlightOpacity is subtle', () {
        expect(GameyAnimations.hoverHighlightOpacity, lessThan(0.2));
        expect(GameyAnimations.hoverHighlightOpacity, greaterThan(0));
      });
    });

    group('Offset values', () {
      test('slideInDistance is positive', () {
        expect(GameyAnimations.slideInDistance, greaterThan(0));
      });

      test('floatDistance is small', () {
        expect(GameyAnimations.floatDistance, greaterThan(0));
        expect(GameyAnimations.floatDistance, lessThan(20));
      });

      test('bounceDistance is defined', () {
        expect(GameyAnimations.bounceDistance, greaterThan(0));
      });
    });

    group('Stagger delays', () {
      test('staggerDelay is positive', () {
        expect(GameyAnimations.staggerDelay.inMilliseconds, greaterThan(0));
      });

      test('staggerDelayGrid is larger than staggerDelay', () {
        expect(
          GameyAnimations.staggerDelayGrid.inMilliseconds,
          greaterThan(GameyAnimations.staggerDelay.inMilliseconds),
        );
      });

      test('revealDelay is defined', () {
        expect(GameyAnimations.revealDelay.inMilliseconds, greaterThan(0));
      });
    });

    group('Animation helpers', () {
      test('staggeredDelay returns correct duration for index', () {
        expect(GameyAnimations.staggeredDelay(0), equals(Duration.zero));
        expect(
          GameyAnimations.staggeredDelay(1),
          equals(GameyAnimations.staggerDelay),
        );
        expect(
          GameyAnimations.staggeredDelay(2),
          equals(GameyAnimations.staggerDelay * 2),
        );
      });

      test('staggeredDelay uses custom base duration', () {
        const customBase = Duration(milliseconds: 100);
        expect(
          GameyAnimations.staggeredDelay(3, base: customBase),
          equals(customBase * 3),
        );
      });

      test('staggeredInterval returns valid Interval', () {
        final interval = GameyAnimations.staggeredInterval(0);
        expect(interval, isA<Interval>());
        expect(interval.begin, greaterThanOrEqualTo(0.0));
        expect(interval.end, lessThanOrEqualTo(1.0));
      });

      test('staggeredInterval indices produce different intervals', () {
        final interval0 = GameyAnimations.staggeredInterval(0);
        final interval1 = GameyAnimations.staggeredInterval(1);
        final interval2 = GameyAnimations.staggeredInterval(2);

        expect(interval0.begin, lessThan(interval1.begin));
        expect(interval1.begin, lessThan(interval2.begin));
      });

      test('staggeredInterval respects totalItems', () {
        final intervalSmall =
            GameyAnimations.staggeredInterval(0, totalItems: 5);
        final intervalLarge =
            GameyAnimations.staggeredInterval(0, totalItems: 20);

        // With more total items, each item's interval is shorter
        final smallDuration = intervalSmall.end - intervalSmall.begin;
        final largeDuration = intervalLarge.end - intervalLarge.begin;
        expect(smallDuration, greaterThan(largeDuration));
      });
    });

    group('Tween factories', () {
      test('tapScaleTween creates correct tween', () {
        final tween = GameyAnimations.tapScaleTween();
        expect(tween.begin, equals(1.0));
        expect(tween.end, equals(GameyAnimations.tapScale));
      });

      test('pulseScaleTween creates correct tween', () {
        final tween = GameyAnimations.pulseScaleTween();
        expect(tween.begin, equals(GameyAnimations.pulseScaleMin));
        expect(tween.end, equals(GameyAnimations.pulseScaleMax));
      });

      test('celebrationScaleTween creates correct tween', () {
        final tween = GameyAnimations.celebrationScaleTween();
        expect(tween.begin, equals(0.0));
        expect(tween.end, equals(GameyAnimations.celebrationScale));
      });

      test('fadeInTween creates 0 to 1 tween', () {
        final tween = GameyAnimations.fadeInTween();
        expect(tween.begin, equals(0.0));
        expect(tween.end, equals(1.0));
      });

      test('slideUpTween creates correct offset tween', () {
        final tween = GameyAnimations.slideUpTween();
        expect(tween.begin, equals(const Offset(0, 0.2)));
        expect(tween.end, equals(Offset.zero));
      });

      test('slideRightTween creates correct offset tween', () {
        final tween = GameyAnimations.slideRightTween();
        expect(tween.begin, equals(const Offset(0.2, 0)));
        expect(tween.end, equals(Offset.zero));
      });
    });
  });
}
