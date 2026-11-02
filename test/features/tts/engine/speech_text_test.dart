import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/engine/speech_text.dart';

void main() {
  group('withoutEmoji', () {
    test('drops emoji and the space they leave', () {
      expect(withoutEmoji('Great job 🎉!'), 'Great job!');
      expect(withoutEmoji('🐧 Penguins swim'), 'Penguins swim');
      expect(withoutEmoji('Fish ⭐ ice ⌚ snow ☀️'), 'Fish ice snow');
    });

    test('drops a sequence whole: joiners, skin tones, flags, selectors', () {
      // A zero-width-joined profession, a toned thumb, a flag and a heart
      // with its variation selector leave nothing a voice could stumble on.
      expect(withoutEmoji('Done 👩🏽‍💻 👍🏽 🇩🇪 ❤️ now'), 'Done now');
      expect(withoutEmoji('a\u200Db'), 'ab');
    });

    test('a keycap keeps its digit, plain digits and symbols stay', () {
      expect(withoutEmoji('Step 1️⃣ first'), 'Step 1 first');
      expect(withoutEmoji('Room #4, 2 * 3'), 'Room #4, 2 * 3');
    });

    test('keeps line breaks, which decide where a voice pauses', () {
      expect(
        withoutEmoji('Done 🎉 \n\n 🐧 Next up'),
        'Done\n\nNext up',
      );
    });

    test('leaves text without emoji exactly as it was', () {
      const text = '  Grüß dich,  さようなら — fine. ';
      expect(identical(withoutEmoji(text), text), isTrue);
    });

    test('nothing but emoji leaves nothing to say', () {
      expect(withoutEmoji(' 🎉🐧 👍🏽 '), isEmpty);
    });
  });

  group('withoutMarkdown', () {
    test('a link or an image says its label', () {
      expect(
        withoutMarkdown('Due: [Feed the penguins](lotti://task/t-1).'),
        'Due: Feed the penguins.',
      );
      expect(withoutMarkdown('![a penguin](https://x/p.png)'), 'a penguin');
    });

    test('emphasis and code say their words', () {
      expect(
        withoutMarkdown('**Two** left, *one* soon, __now__ `rookery-map`'),
        'Two left, one soon, now rookery-map',
      );
    });

    test(
      'heading, quote and bullet markers are not read, line breaks stay',
      () {
        expect(
          withoutMarkdown('## Today\n- Feed\n* Count\n> Note\n1. First'),
          'Today\nFeed\nCount\nNote\n1. First',
        );
      },
    );

    test('leaves arithmetic, snake_case and lone marks alone', () {
      const text = 'Room #4, 2 * 3 = 6, file_name_here, 5 - 2';
      expect(withoutMarkdown(text), text);
    });
  });
}
