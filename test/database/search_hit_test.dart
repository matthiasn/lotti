import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/search_hit.dart';

void main() {
  test('snippetSpans splits a snippet at its match markers', () {
    expect(
      snippetSpans(
        '…refill the ${snippetMatchStart}krill$snippetMatchEnd tubs',
      ),
      [
        (text: '…refill the ', matched: false),
        (text: 'krill', matched: true),
        (text: ' tubs', matched: false),
      ],
    );
  });

  test('adjacent and leading matches, and text without any', () {
    expect(
      snippetSpans(
        '${snippetMatchStart}krill$snippetMatchEnd'
        '${snippetMatchStart}run$snippetMatchEnd!',
      ),
      [
        (text: 'krill', matched: true),
        (text: 'run', matched: true),
        (text: '!', matched: false),
      ],
    );
    expect(snippetSpans('plain'), [(text: 'plain', matched: false)]);
    expect(snippetSpans(''), isEmpty);
  });
}
