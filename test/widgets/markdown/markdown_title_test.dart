import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/markdown/markdown_title.dart';

void main() {
  test('drops a leading heading that repeats the title, and the blank '
      'lines after it', () {
    expect(
      withoutRepeatedTitle(
        '\n# Habitat brief\n\n\nFeed at noon.',
        'Habitat brief',
      ),
      'Feed at noon.',
    );
  });

  test('matches trimmed and without case, closing hashes included', () {
    expect(
      withoutRepeatedTitle('#   habitat BRIEF  ##\nFeed.', ' Habitat brief '),
      'Feed.',
    );
  });

  for (final (name, markdown) in [
    ('a heading that says something else', '# Habitat inspection\nFeed.'),
    ('a level-two heading', '## Habitat brief\nFeed.'),
    ('a heading after text', 'Intro.\n# Habitat brief'),
    ('no heading at all', 'Feed at noon.'),
    ('only blank lines', '\n\n'),
  ]) {
    test('keeps $name', () {
      expect(withoutRepeatedTitle(markdown, 'Habitat brief'), markdown);
    });
  }

  test('keeps everything without a title to compare', () {
    expect(withoutRepeatedTitle('# Brief\nx', null), '# Brief\nx');
    expect(withoutRepeatedTitle('# Brief\nx', '  '), '# Brief\nx');
  });
}
