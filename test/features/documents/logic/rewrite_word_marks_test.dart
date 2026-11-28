import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/documents/logic/rewrite_word_marks.dart';

void main() {
  String m(String words) => '$rewriteWordMarkOpen$words$rewriteWordMarkClose';

  test('a changed word is marked on each side', () {
    final marked = markRewrittenWords(
      'The colony of 37 penguins.',
      'The colony of 38 penguins.',
    );
    expect(marked.base, 'The colony of ${m('37')} penguins.');
    expect(marked.proposed, 'The colony of ${m('38')} penguins.');
  });

  test('words only added leave the current side as written', () {
    final marked = markRewrittenWords(
      'Feed the birds.',
      'Feed the hungry young birds.',
    );
    expect(marked.base, 'Feed the birds.');
    expect(marked.proposed, 'Feed the ${m('hungry young')} birds.');
  });

  test('neighbouring words share a mark, but not across a line break', () {
    final marked = markRewrittenWords(
      'Count at dusk.',
      'Count every bird\nlate at dusk.',
    );
    expect(marked.proposed, 'Count ${m('every bird')}\n${m('late')} at dusk.');
  });

  test('identical text comes back as it was', () {
    final marked = markRewrittenWords('Same text.', 'Same text.');
    expect(marked.base, 'Same text.');
    expect(marked.proposed, 'Same text.');
  });

  test("a list's markers and line breaks stay as written", () {
    final marked = markRewrittenWords(
      '- Morning round\n- Evening round',
      '1. Morning round\n2. Night round',
    );
    expect(marked.base, '- Morning round\n- ${m('Evening')} round');
    expect(marked.proposed, '1. Morning round\n2. ${m('Night')} round');
  });

  test("a heading's marker stays outside the mark", () {
    final marked = markRewrittenWords('## Feeding', '### Feeding times');
    expect(marked.base, '## Feeding');
    expect(marked.proposed, '### Feeding ${m('times')}');
  });

  test('emphasis around a word stays outside its mark', () {
    final marked = markRewrittenWords(
      'Feed the **young** birds.',
      'Feed the **old** birds.',
    );
    expect(marked.base, 'Feed the **${m('young')}** birds.');
    expect(marked.proposed, 'Feed the **${m('old')}** birds.');
  });

  test('a word after emphasis starts a mark of its own', () {
    final marked = markRewrittenWords('a z', 'a *b* c z');
    expect(marked.proposed, 'a *${m('b')}* ${m('c')} z');
  });

  test('words in inline code or a link, and syntax, stay unmarked', () {
    final marked = markRewrittenWords(
      'Run `feed now` or see [the old list](https://example.com) a_b',
      'Run `feed later` or see [the new list](https://example.com) c_d',
    );
    expect(
      marked.base,
      'Run `feed now` or see [the old list](https://example.com) a_b',
    );
    expect(
      marked.proposed,
      'Run `feed later` or see [the new list](https://example.com) c_d',
    );
  });

  test('a fenced code block comes back unmarked', () {
    final marked = markRewrittenWords(
      '```\nfeed(37)\n```',
      '```\nfeed(38) now\n```',
    );
    expect(marked.base, '```\nfeed(37)\n```');
    expect(marked.proposed, '```\nfeed(38) now\n```');
  });

  test('text that already holds a delimiter comes back unmarked', () {
    final base = 'Feed ${m('the')} birds.';
    final marked = markRewrittenWords(base, 'Feed all birds.');
    expect(marked.base, base);
    expect(marked.proposed, 'Feed all birds.');
  });

  test('a block too long to weigh comes back unmarked', () {
    final base = List.filled(501, 'word').join(' ');
    final proposed = List.filled(501, 'other').join(' ');
    final marked = markRewrittenWords(base, proposed);
    expect(marked.base, base);
    expect(marked.proposed, proposed);
  });
}
