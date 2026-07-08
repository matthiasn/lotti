import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/util/text_utils.dart';

/// Generators feeding the property tests for [truncateAgentText].
extension _AnyAgentText on glados.Any {
  /// Text drawn from a charset that includes newlines, tabs and spaces so the
  /// newline-collapse and trim branches are exercised.
  glados.Generator<String> get agentText =>
      glados.any.stringOf(' abcXY12\t\n\r');
}

void main() {
  group('truncateAgentText — properties', () {
    glados.Glados2(
      glados.any.agentText,
      glados.any.intInRange(-2, 40),
      glados.ExploreConfig(numRuns: 150),
    ).test('result fits within the requested budget', (text, maxLength) {
      final result = truncateAgentText(text, maxLength);
      if (maxLength <= 0) {
        expect(result, isEmpty, reason: 'maxLength=$maxLength');
      } else {
        expect(
          result.length,
          lessThanOrEqualTo(maxLength),
          reason: 'maxLength=$maxLength, input length=${text.length}',
        );
      }
    }, tags: 'glados');

    glados.Glados2(
      glados.any.agentText,
      glados.any.intInRange(1, 40),
      glados.ExploreConfig(numRuns: 150),
    ).test('output never contains a newline', (text, maxLength) {
      expect(
        truncateAgentText(text, maxLength).contains('\n'),
        isFalse,
        reason: 'maxLength=$maxLength',
      );
    }, tags: 'glados');

    glados.Glados2(
      glados.any.agentText,
      glados.any.intInRange(2, 40),
      glados.ExploreConfig(numRuns: 150),
    ).test('appends ellipsis exactly when content is truncated', (
      text,
      maxLength,
    ) {
      final singleLine = text.replaceAll('\n', ' ').trim();
      final result = truncateAgentText(text, maxLength);
      if (singleLine.length > maxLength) {
        expect(result.endsWith('…'), isTrue, reason: 'should truncate');
        expect(
          result.length,
          maxLength,
          reason: 'truncated length should equal maxLength',
        );
      } else {
        expect(result, singleLine, reason: 'short content passes through');
      }
    }, tags: 'glados');
  });

  group('truncateAgentText — worked examples', () {
    test('passes short single-line text through unchanged', () {
      expect(truncateAgentText('hello', 10), 'hello');
    });
    test('collapses newlines to spaces and trims', () {
      expect(truncateAgentText('a\nb\nc', 10), 'a b c');
      expect(truncateAgentText('  spaced  ', 100), 'spaced');
    });
    test('truncates with an ellipsis at the budget', () {
      expect(truncateAgentText('hello world', 5), 'hell…');
    });
    test('maxLength of 1 yields just the ellipsis', () {
      expect(truncateAgentText('hello', 1), '…');
    });
    test('non-positive maxLength yields an empty string', () {
      expect(truncateAgentText('hello', 0), '');
      expect(truncateAgentText('hello', -3), '');
    });
  });

  group('sanitizeAgentReportText', () {
    const uuid = '6af9c4b0-7a1d-11f1-aaec-bffd4abbb1e1';

    test('strips a trailing parenthesized id annotation', () {
      expect(
        sanitizeAgentReportText('Guide user to create first task (id: $uuid)'),
        'Guide user to create first task',
      );
    });

    test('strips an id annotation mid-line, leaving one clean space', () {
      expect(
        sanitizeAgentReportText('Ship the API (id: $uuid) before Friday'),
        'Ship the API before Friday',
      );
    });

    test('strips the whole "What is left to do" list from the bug report', () {
      const input = '''
## 📌 What is left to do
- [ ] Guide user to create first task (id: 6af9c4b0-7a1d-11f1-aaec-bffd4abbb1e1)
- [ ] Show assigned agents (id: 6afd6e30-7a1d-11f1-aaec-bffd4abbb1e1)
- [ ] Generate task summary (id: 6b0361a0-7a1d-11f1-aaec-bffd4abbb1e1)''';
      const expected = '''
## 📌 What is left to do
- [ ] Guide user to create first task
- [ ] Show assigned agents
- [ ] Generate task summary''';
      expect(sanitizeAgentReportText(input), expected);
    });

    test('handles bracket, equals, and dash-prefixed annotation shapes', () {
      expect(sanitizeAgentReportText('Item [id: $uuid]'), 'Item');
      expect(sanitizeAgentReportText('Item (id=$uuid)'), 'Item');
      expect(sanitizeAgentReportText('Item — id: $uuid'), 'Item');
      expect(sanitizeAgentReportText('Item id: $uuid'), 'Item');
    });

    test('strips a lone parenthesized UUID', () {
      expect(sanitizeAgentReportText('Ship the API ($uuid)'), 'Ship the API');
    });

    test('preserves a legitimate /tasks/<id> proof-of-work link', () {
      const link = 'See [the parent task](/tasks/$uuid) for context';
      expect(sanitizeAgentReportText(link), link);
    });

    test('leaves indentation and blank lines intact', () {
      const input = '  - [ ] Nested item (id: $uuid)\n\n  next';
      expect(sanitizeAgentReportText(input), '  - [ ] Nested item\n\n  next');
    });

    test('returns the input unchanged when there is no id annotation', () {
      const input = '## TLDR\nEverything is on track. No IDs here.';
      expect(sanitizeAgentReportText(input), same(input));
    });

    test('does not touch non-UUID parentheticals', () {
      const input = 'Reduce latency (currently 200ms) to under 100ms.';
      expect(sanitizeAgentReportText(input), input);
    });

    test('preserves a Markdown hard break on an untouched line while '
        'trimming the line a removal actually touched', () {
      // The first line carries a deliberate two-space hard break; a later line
      // holds an id annotation. Only the annotated line should be trimmed.
      const input = 'First line  \nShip the API ($uuid)  ';
      expect(sanitizeAgentReportText(input), 'First line  \nShip the API');
    });
  });
}
