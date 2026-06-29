import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/demo/dance_performance.dart';
import 'package:lotti/features/character/demo/dance_stage_view.dart';

const _words = <DanceWord>[
  (start: 0.0, end: 0.5, word: 'one', voice: 'lead', section: 'verse'),
  (start: 1.0, end: 1.5, word: 'two', voice: 'lead', section: 'verse'),
  (start: 2.0, end: 2.5, word: 'three', voice: 'lead', section: 'verse'),
];

void main() {
  group('DanceCaption.captionWordIndex', () {
    test('no words → null', () {
      expect(DanceCaption.captionWordIndex(const [], 1), isNull);
    });

    test('before the first word → null', () {
      expect(DanceCaption.captionWordIndex(_words, -0.1), isNull);
    });

    test('returns the most recently started word', () {
      expect(DanceCaption.captionWordIndex(_words, 1.2), 1);
      expect(DanceCaption.captionWordIndex(_words, 2.4), 2);
    });

    test('hides during an instrumental gap (>2 s after the last word end)', () {
      // Last word ends at 2.5; 2.5 + 2 = 4.5 is the cutoff.
      expect(DanceCaption.captionWordIndex(_words, 4.4), 2);
      expect(DanceCaption.captionWordIndex(_words, 4.6), isNull);
    });
  });

  group('DanceCaption.captionWindow', () {
    test('clamps a few words either side of the active one', () {
      expect(DanceCaption.captionWindow(0, 10), (from: 0, to: 4));
      expect(DanceCaption.captionWindow(6, 10), (from: 3, to: 10));
      expect(DanceCaption.captionWindow(9, 10), (from: 6, to: 10));
    });
  });

  group('DanceCaption.captionWordStyle', () {
    test('the active word is brighter, larger and bolder', () {
      final active = DanceCaption.captionWordStyle(active: true);
      final inactive = DanceCaption.captionWordStyle(active: false);
      expect(active.color, Colors.white);
      expect(inactive.color, Colors.white54);
      expect(active.fontSize, greaterThan(inactive.fontSize!));
      expect(active.fontWeight, FontWeight.w700);
      expect(inactive.fontWeight, FontWeight.w400);
    });
  });

  group('DanceCaption widget', () {
    testWidgets('renders the active word window, empty when no word is on', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: DanceCaption(words: _words, positionSeconds: 1.2),
        ),
      );
      // The active word and a neighbour are shown.
      expect(find.byType(RichText), findsOneWidget);
      final text = tester
          .widget<RichText>(find.byType(RichText))
          .text
          .toPlainText();
      expect(text, contains('two'));
      expect(text, contains('one'));

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: DanceCaption(words: _words, positionSeconds: 10),
        ),
      );
      // Past the instrumental-gap cutoff → nothing rendered.
      expect(find.byType(RichText), findsNothing);
    });
  });
}
