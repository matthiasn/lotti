import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/supported_language.dart';

void main() {
  group('SupportedLanguage', () {
    test('fromCode returns correct language for valid codes', () {
      // Test a few representative language codes
      expect(SupportedLanguage.fromCode('en'), equals(SupportedLanguage.en));
      expect(SupportedLanguage.fromCode('de'), equals(SupportedLanguage.de));
      expect(SupportedLanguage.fromCode('es'), equals(SupportedLanguage.es));
      expect(SupportedLanguage.fromCode('fr'), equals(SupportedLanguage.fr));
      expect(SupportedLanguage.fromCode('zh'), equals(SupportedLanguage.zh));
      expect(SupportedLanguage.fromCode('ar'), equals(SupportedLanguage.ar));
      expect(SupportedLanguage.fromCode('ja'), equals(SupportedLanguage.ja));
      expect(SupportedLanguage.fromCode('pt'), equals(SupportedLanguage.pt));
      expect(SupportedLanguage.fromCode('ig'), equals(SupportedLanguage.ig));
      expect(SupportedLanguage.fromCode('pcm'), equals(SupportedLanguage.pcm));
      expect(SupportedLanguage.fromCode('yo'), equals(SupportedLanguage.yo));
    });

    test('fromCode returns null for invalid codes', () {
      expect(SupportedLanguage.fromCode('invalid'), isNull);
      expect(SupportedLanguage.fromCode(''), isNull);
      expect(SupportedLanguage.fromCode('xyz'), isNull);
      expect(SupportedLanguage.fromCode('EN'), isNull); // Case sensitive
    });

    test('all language codes are unique', () {
      final codes = SupportedLanguage.values.map((lang) => lang.code).toList();
      final uniqueCodes = codes.toSet();
      expect(codes.length, equals(uniqueCodes.length));
    });

    test('all language names are unique', () {
      final names = SupportedLanguage.values.map((lang) => lang.name).toList();
      final uniqueNames = names.toSet();
      expect(names.length, equals(uniqueNames.length));
    });

    test('code property returns expected values', () {
      expect(SupportedLanguage.en.code, equals('en'));
      expect(SupportedLanguage.de.code, equals('de'));
      expect(SupportedLanguage.es.code, equals('es'));
      expect(SupportedLanguage.ig.code, equals('ig'));
      expect(SupportedLanguage.pcm.code, equals('pcm'));
      expect(SupportedLanguage.yo.code, equals('yo'));
    });

    test('name property returns expected values', () {
      expect(SupportedLanguage.en.name, equals('English'));
      expect(SupportedLanguage.de.name, equals('German'));
      expect(SupportedLanguage.es.name, equals('Spanish'));
      expect(SupportedLanguage.ig.name, equals('Igbo'));
      expect(SupportedLanguage.pcm.name, equals('Nigerian Pidgin'));
      expect(SupportedLanguage.yo.name, equals('Yoruba'));
    });

    test('all languages can be looked up by their code', () {
      // Ensure the map is properly initialized for all languages
      for (final language in SupportedLanguage.values) {
        final result = SupportedLanguage.fromCode(language.code);
        expect(result, equals(language));
      }
    });

    test('fromCode performance - Map lookup is O(1)', () {
      // This test verifies that the Map-based implementation is efficient
      // by performing many lookups and ensuring they complete quickly
      final stopwatch = Stopwatch()..start();

      // Perform 10000 lookups
      for (var i = 0; i < 10000; i++) {
        SupportedLanguage.fromCode('en');
        SupportedLanguage.fromCode('de');
        SupportedLanguage.fromCode('invalid');
      }

      stopwatch.stop();

      // Map lookups should be very fast - typically under 10ms for 30000 operations
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}
