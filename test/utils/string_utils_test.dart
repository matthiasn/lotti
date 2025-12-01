import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/string_utils.dart';

void main() {
  group('normalizeWhitespace', () {
    test('trims leading whitespace', () {
      expect(normalizeWhitespace('   hello'), equals('hello'));
    });

    test('trims trailing whitespace', () {
      expect(normalizeWhitespace('hello   '), equals('hello'));
    });

    test('trims both leading and trailing whitespace', () {
      expect(normalizeWhitespace('   hello   '), equals('hello'));
    });

    test('collapses multiple internal spaces to single space', () {
      expect(normalizeWhitespace('hello   world'), equals('hello world'));
    });

    test('collapses tabs to single space', () {
      expect(normalizeWhitespace('hello\t\tworld'), equals('hello world'));
    });

    test('collapses newlines to single space', () {
      expect(normalizeWhitespace('hello\n\nworld'), equals('hello world'));
    });

    test('collapses mixed whitespace to single space', () {
      expect(
        normalizeWhitespace('hello \t\n  world'),
        equals('hello world'),
      );
    });

    test('handles empty string', () {
      expect(normalizeWhitespace(''), equals(''));
    });

    test('handles whitespace-only string', () {
      expect(normalizeWhitespace('   '), equals(''));
    });

    test('handles single word', () {
      expect(normalizeWhitespace('hello'), equals('hello'));
    });

    test('handles multiple words correctly', () {
      expect(
        normalizeWhitespace('  hello   beautiful   world  '),
        equals('hello beautiful world'),
      );
    });

    test('preserves single spaces between words', () {
      expect(
        normalizeWhitespace('hello world'),
        equals('hello world'),
      );
    });

    test('handles special characters', () {
      expect(
        normalizeWhitespace('  C++  is   great  '),
        equals('C++ is great'),
      );
    });

    test('handles Unicode characters', () {
      expect(
        normalizeWhitespace('  Kirkjubæjarklaustur   is   in   Iceland  '),
        equals('Kirkjubæjarklaustur is in Iceland'),
      );
    });

    test('handles carriage return', () {
      expect(normalizeWhitespace('hello\r\nworld'), equals('hello world'));
    });

    test('handles form feed', () {
      expect(normalizeWhitespace('hello\fworld'), equals('hello world'));
    });
  });
}
