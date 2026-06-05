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
    ).test('appends ellipsis exactly when content is truncated',
        (text, maxLength) {
      final singleLine = text.replaceAll('\n', ' ').trim();
      final result = truncateAgentText(text, maxLength);
      if (singleLine.length > maxLength) {
        expect(result.endsWith('…'), isTrue, reason: 'should truncate');
        expect(result.length, maxLength,
            reason: 'truncated length should equal maxLength');
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
}
