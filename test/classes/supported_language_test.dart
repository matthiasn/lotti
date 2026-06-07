import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../widget_test_utils.dart';

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
      expect(SupportedLanguage.fromCode('tw'), equals(SupportedLanguage.tw));
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
      expect(SupportedLanguage.tw.code, equals('tw'));
    });

    test('name property returns expected values', () {
      expect(SupportedLanguage.en.name, equals('English'));
      expect(SupportedLanguage.de.name, equals('German'));
      expect(SupportedLanguage.es.name, equals('Spanish'));
      expect(SupportedLanguage.ig.name, equals('Igbo'));
      expect(SupportedLanguage.pcm.name, equals('Nigerian Pidgin'));
      expect(SupportedLanguage.yo.name, equals('Yoruba'));
      expect(SupportedLanguage.tw.name, equals('Twi'));
    });

    test('all languages can be looked up by their code', () {
      // Ensure the map is properly initialized for all languages
      for (final language in SupportedLanguage.values) {
        final result = SupportedLanguage.fromCode(language.code);
        expect(result, equals(language));
      }
    });

    glados.Glados(
      glados.any.generatedSupportedLanguage,
      glados.ExploreConfig(numRuns: 120),
    ).test('looks up generated languages by their exact code', (language) {
      expect(
        SupportedLanguage.fromCode(language.code),
        equals(language),
        reason: '${language.code} should resolve to $language',
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.generatedInvalidLanguageCode,
      glados.ExploreConfig(numRuns: 50),
    ).test('rejects generated non-canonical language codes', (scenario) {
      expect(
        SupportedLanguage.fromCode(scenario.code),
        isNull,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });
  group('SupportedLanguage.localizedName', () {
    testWidgets('every language resolves a non-empty localized label', (
      tester,
    ) async {
      await tester.pumpWidget(makeTestableWidgetWithScaffold(const SizedBox()));
      final context = tester.element(find.byType(SizedBox));

      for (final language in SupportedLanguage.values) {
        expect(
          language.localizedName(context),
          isNotEmpty,
          reason: '$language',
        );
      }

      // Spot-check exact resolution against the live ARB bundle.
      final messages = context.messages;
      expect(
        SupportedLanguage.en.localizedName(context),
        messages.taskLanguageEnglish,
      );
      expect(
        SupportedLanguage.de.localizedName(context),
        messages.taskLanguageGerman,
      );
      expect(
        SupportedLanguage.ro.localizedName(context),
        messages.taskLanguageRomanian,
      );
    });
  });
}

enum _GeneratedInvalidLanguageCodeKind {
  empty,
  uppercase,
  leadingWhitespace,
  trailingWhitespace,
  suffix,
  prefix,
  unknown,
}

class _GeneratedInvalidLanguageCode {
  const _GeneratedInvalidLanguageCode({
    required this.language,
    required this.kind,
  });

  final SupportedLanguage language;
  final _GeneratedInvalidLanguageCodeKind kind;

  String get code => switch (kind) {
    _GeneratedInvalidLanguageCodeKind.empty => '',
    _GeneratedInvalidLanguageCodeKind.uppercase => language.code.toUpperCase(),
    _GeneratedInvalidLanguageCodeKind.leadingWhitespace => ' ${language.code}',
    _GeneratedInvalidLanguageCodeKind.trailingWhitespace => '${language.code} ',
    _GeneratedInvalidLanguageCodeKind.suffix => '${language.code}-x',
    _GeneratedInvalidLanguageCodeKind.prefix => 'x-${language.code}',
    _GeneratedInvalidLanguageCodeKind.unknown => 'zz',
  };

  @override
  String toString() {
    return '_GeneratedInvalidLanguageCode('
        'language: $language, kind: $kind, code: "$code")';
  }
}

extension _AnySupportedLanguage on glados.Any {
  glados.Generator<SupportedLanguage> get generatedSupportedLanguage =>
      glados.AnyUtils(this).choose(SupportedLanguage.values);

  glados.Generator<_GeneratedInvalidLanguageCodeKind>
  get _invalidLanguageCodeKind =>
      glados.AnyUtils(this).choose(_GeneratedInvalidLanguageCodeKind.values);

  glados.Generator<_GeneratedInvalidLanguageCode>
  get generatedInvalidLanguageCode => glados.CombinableAny(this).combine2(
    generatedSupportedLanguage,
    _invalidLanguageCodeKind,
    (
      SupportedLanguage language,
      _GeneratedInvalidLanguageCodeKind kind,
    ) => _GeneratedInvalidLanguageCode(language: language, kind: kind),
  );
}
