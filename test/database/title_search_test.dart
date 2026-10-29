import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/title_search.dart';

TitleMatch _match(String id, String title) =>
    TitleMatch(entityId: id, type: 'Task', title: title);

void main() {
  test('searchWords lower-cases and splits like the tokenizers', () {
    expect(searchWords('Pre-launch CHECKS, v2!'), [
      'pre',
      'launch',
      'checks',
      'v2',
    ]);
    expect(searchWords('  '), isEmpty);
  });

  test('titleTrigrams are the letter triples within each word', () {
    expect(titleTrigrams('Roll call'), {'rol', 'oll', 'cal', 'all'});
    expect(titleTrigrams('ab'), isEmpty);
  });

  group('rankTitleMatches', () {
    test('the exact title, then titles starting with the query, then a word '
        'starting with it, then the rest, each in the index order', () {
      final ranked = rankTitleMatches('launch', [
        _match('inside', 'Pre-launch checks'),
        _match('later-word', 'Draft the launch comms plan'),
        _match('starts', 'Launch day rehearsal'),
        _match('exact', 'Launch'),
        _match('middle', 'Relaunched feeder'),
      ]);

      expect(ranked.map((m) => m.entityId), [
        'exact',
        'starts',
        'inside',
        'later-word',
        'middle',
      ]);
    });

    test('every word must be in the title; a short one only as the start of '
        'a word', () {
      final ranked = rankTitleMatches('roll ca', [
        _match('both', 'Emperor penguin roll call'),
        _match('inside-word', 'Roll the arcade'),
        _match('missing', 'Roll out'),
      ]);

      expect(ranked.map((m) => m.entityId), ['both']);
    });

    test('a query with nothing to match keeps nothing', () {
      expect(rankTitleMatches('--', [_match('any', 'Anything')]), isEmpty);
    });
  });

  group('nearestTitles', () {
    test('keeps titles sharing at least half the query triples, most shared '
        'first, marked fuzzy', () {
      final near = nearestTitles('pengiun roll', [
        _match('one', 'Penguin parade'),
        _match('two', 'Emperor penguin roll call'),
        _match('none', 'Sardine futures'),
      ]);

      expect(near.map((m) => m.entityId), ['two']);
      expect(near.single.fuzzy, isTrue);
    });

    test('a query too short to have two triples finds nothing near', () {
      expect(nearestTitles('pen', [_match('any', 'Penguin')]), isEmpty);
    });
  });
}
