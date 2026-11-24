import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/state/front_draft_pages.dart';

void main() {
  const typed = FrontDraftPage('Also check the ridge nests');
  const edit = FrontDraftPage(
    'Count the chicks at the north colony',
    editingMessageId: 'u1',
  );
  const blank = FrontDraftPage('  ');

  List<String> texts(FrontDraftPages pages) => [
    for (final page in pages.pages) page.text,
  ];

  group('FrontDraftPage', () {
    test('is a value: same words and turn, same page', () {
      expect(
        const FrontDraftPage('a', editingMessageId: 'u1'),
        const FrontDraftPage('a', editingMessageId: 'u1'),
      );
      expect(
        const FrontDraftPage('a', editingMessageId: 'u1').hashCode,
        const FrontDraftPage('a', editingMessageId: 'u1').hashCode,
      );
      expect(const FrontDraftPage('a'), isNot(const FrontDraftPage('b')));
      expect(
        const FrontDraftPage('a'),
        isNot(const FrontDraftPage('a', editingMessageId: 'u1')),
      );
    });

    test('only whitespace is blank', () {
      expect(blank.isBlank, isTrue);
      expect(typed.isBlank, isFalse);
    });
  });

  group('FrontDraftPages', () {
    test('is put together from the page in the box and those aside, and '
        'taken apart the same way', () {
      final pages = FrontDraftPages.of(
        current: edit,
        aside: const [typed, FrontDraftPage('Later')],
        index: 1,
      );

      expect(texts(pages), [typed.text, edit.text, 'Later']);
      expect(pages.current, edit);
      expect(pages.aside, const [typed, FrontDraftPage('Later')]);
    });

    test('Edit on a box with words keeps them as the page before it', () {
      final pages = FrontDraftPages(const [typed], 0).adding(edit);

      expect(pages.pages, [typed, edit]);
      expect(pages.current, edit);
    });

    test('Edit on a blank box simply fills it', () {
      final pages = FrontDraftPages(const [blank], 0).adding(edit);

      expect(pages.pages, [edit]);
      expect(pages.index, 0);
    });

    test('Edit on a turn already paged shows that page, as the user left '
        'it, instead of paging it twice', () {
      const changed = FrontDraftPage(
        'Count them twice',
        editingMessageId: 'u1',
      );
      final pages = FrontDraftPages(const [changed, typed], 1).adding(edit);

      expect(pages.pages, [changed, typed]);
      expect(pages.current, changed);
    });

    test('flipping shows the page asked for and drops one left blank', () {
      final pages = FrontDraftPages(const [typed, blank, edit], 2).showing(0);

      expect(pages.pages, [typed, edit]);
      expect(pages.current, typed);
    });

    test('flipping to a page that is not there changes nothing', () {
      final pages = FrontDraftPages(const [typed, edit], 1);

      expect(pages.showing(-1), same(pages));
      expect(pages.showing(2), same(pages));
    });

    test('after a send the last page with words is in the box, or an empty '
        'box when none has', () {
      final settled = FrontDraftPages.settle(const [typed, edit, blank]);
      expect(settled.pages, [typed, edit]);
      expect(settled.current, edit);

      final empty = FrontDraftPages.settle(const [blank]);
      expect(empty.pages, const [FrontDraftPage('')]);
      expect(empty.aside, isEmpty);
    });
  });
}
